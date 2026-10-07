// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

/// What `<app> --login [on|off|status]` was asked to do.
public enum LoginCommand: Equatable {
    case enable
    case disable
    case status
}

/// The result of looking for `--login` on a command line.
///
/// Parsing is kept separate from acting on it so the fiddly argument handling is
/// unit-testable without registering anything with launchd.
public enum LoginRequest: Equatable {
    /// No `--login` flag — run the menu-bar app as usual.
    case absent
    case command(LoginCommand)
    /// `--login` followed by something that is not `on`, `off` or `status`.
    case unrecognized(String)

    public static let flag = "--login"

    public static func usage(executable: String) -> String {
        StatusItemLanguage.text("用法: \(executable) --login [on|off|status]", "Usage: \(executable) --login [on|off|status]")
    }

    /// The binary's own name, for usage text. Each app then needs no literal
    /// copy of its own name that could drift after a rename.
    public static func executableName(arguments: [String] = CommandLine.arguments) -> String {
        guard let path = arguments.first, !path.isEmpty else { return "app" }
        return (path as NSString).lastPathComponent
    }

    public static func parse(arguments: [String]) -> LoginRequest {
        guard let flagIndex = arguments.firstIndex(of: flag) else { return .absent }

        // A bare `--login`, or one followed by another flag, only reports:
        // an incomplete command must not silently change registration.
        let valueIndex = flagIndex + 1
        guard valueIndex < arguments.count else { return .command(.status) }
        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else { return .command(.status) }

        switch value {
        case "on": return .command(.enable)
        case "off": return .command(.disable)
        case "status": return .command(.status)
        default: return .unrecognized(value)
        }
    }
}

/// Handles `--login` before the menu bar comes up.
///
/// Start at Login is `SMAppService.mainApp`, which can only register the calling
/// process's own bundle — so nothing outside the app can turn it on, and every
/// installer has to run the installed binary to do it. This is that entry point,
/// shared by every app in the suite.
public enum LoginCLI {
    /// Acts on `--login` and exits; returns normally only when the flag is absent,
    /// so callers put this first in `main` and then build their UI.
    ///
    /// Headless on purpose: no NSApplication, no menu bar, no alert — an installer
    /// or a script calling this must get an exit code, not a window.
    public static func runIfRequested(
        arguments: [String] = CommandLine.arguments,
        executable: String? = nil
    ) {
        let name = executable ?? LoginRequest.executableName(arguments: arguments)
        switch LoginRequest.parse(arguments: arguments) {
        case .absent:
            return
        case .command(.status):
            print(LoginItem.isEnabled ? "on" : "off")
            exit(0)
        case .command(let command):
            let enable = command == .enable
            do {
                try LoginItem.setEnabled(enable)
                print(enable ? "on" : "off")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data(
                    StatusItemLanguage.text("\(name): 无法\(enable ? "开启" : "关闭")开机自启动 — \(error.localizedDescription)\n", "\(name): could not \(enable ? "enable" : "disable") Launch at Login — \(error.localizedDescription)\n").utf8
                ))
                exit(1)
            }
        case .unrecognized(let value):
            FileHandle.standardError.write(Data(
                StatusItemLanguage.text("\(name): 未知的 --login 参数值 '\(value)'\n\(LoginRequest.usage(executable: name))\n", "\(name): unknown --login value '\(value)'\n\(LoginRequest.usage(executable: name))\n").utf8
            ))
            exit(2)
        }
    }
}
