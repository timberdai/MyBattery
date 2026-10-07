// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

/// Minimal command runner with a hard timeout. Returns stdout as UTF-8 text on a
/// clean (exit 0, within `timeout`) run, or nil if the process can't launch,
/// exits non-zero, times out, or its output isn't UTF-8. stderr is discarded.
///
/// Robustness guarantees — a hung child must NEVER wedge the caller (a menu-bar
/// app's poll loop calls this; a subprocess that never exits used to freeze the
/// whole status item):
///   - a child that overruns `timeout` is terminated (SIGTERM, then SIGKILL) and
///     the call returns nil instead of blocking forever;
///   - stdin is /dev/null so the child can't block waiting for input;
///   - stderr is drained concurrently so a chatty child can't deadlock by filling
///     its stderr pipe while we're reading stdout.
public enum Shell {
    public static func run(_ path: String, _ args: [String], timeout: TimeInterval = 10,
                           env: [String: String]? = nil) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        // `env` overlays the inherited environment rather than replacing it —
        // some CLIs (Tailscale) change behavior on vars like TERM, and a
        // login-launched app's environment doesn't carry them.
        if let env {
            task.environment = ProcessInfo.processInfo.environment
                .merging(env) { _, new in new }
        }
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        task.standardInput = FileHandle.nullDevice

        // Signalled when the process exits — on its own, or after we kill it.
        let exited = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in exited.signal() }

        do { try task.run() } catch { return nil }

        // Read both pipes on background queues: readDataToEndOfFile() blocks until
        // the child closes its write end (exit or kill), so it must not run on the
        // thread that enforces the timeout. Draining stderr avoids a full-pipe
        // deadlock even though we throw the bytes away.
        let io = DispatchQueue(label: "statusitemkit.shell.io", attributes: .concurrent)
        let outReady = DispatchSemaphore(value: 0)
        var outData = Data()
        io.async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            outReady.signal()
        }
        io.async {
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
        }

        // Bound the wait by `timeout`; escalate SIGTERM -> SIGKILL if it overruns.
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            task.terminate()                                    // SIGTERM
            if exited.wait(timeout: .now() + 2) == .timedOut {
                kill(task.processIdentifier, SIGKILL)           // force
                exited.wait()                                   // reap
            }
            outReady.wait()                                     // let the reader unwind
            return nil
        }

        outReady.wait()
        guard task.terminationStatus == 0,
              let text = String(data: outData, encoding: .utf8) else { return nil }
        return text
    }
}
