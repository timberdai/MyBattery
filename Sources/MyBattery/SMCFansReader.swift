import Foundation
import IOKit

struct FanReading: Equatable {
    let index: Int
    let rpm: Double
}

/// Minimal read-only, thread-safe SMC client for fans on macOS.
final class SMCFansReader {
    static let shared = SMCFansReader()

    private var connection: io_connect_t = 0
    private var lastFailureTime: Date?
    private var consecutiveFailures = 0
    private let lock = NSLock()

    enum ReadCommand: UInt8 { case bytes = 5, keyInfo = 9 }

    // Injectable transport keeps regression tests on the actual command path.
    private let openConnection: () -> io_connect_t?
    private let closeConnection: (io_connect_t) -> Void
    private let transport: (io_connect_t, inout SMCParamStruct) -> SMCParamStruct?
    private let now: () -> Date
    private var unavailableUntil: Date?
    private var temperatureUnavailableUntil: Date?

    init(openConnection: @escaping () -> io_connect_t? = SMCFansReader.nativeOpen,
         closeConnection: @escaping (io_connect_t) -> Void = { IOServiceClose($0) },
         transport: @escaping (io_connect_t, inout SMCParamStruct) -> SMCParamStruct? = SMCFansReader.nativeCall,
         now: @escaping () -> Date = Date.init) {
        self.openConnection = openConnection
        self.closeConnection = closeConnection
        self.transport = transport
        self.now = now
    }

    deinit {
        close()
    }

    private func close() {
        if connection != 0 {
            closeConnection(connection)
            connection = 0
        }
    }

    struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    struct SMCParamStruct {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
                   (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private static func nativeOpen() -> io_connect_t? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess, connection != 0 else {
            if connection != 0 { IOServiceClose(connection) }
            return nil
        }
        return connection
    }

    private func open() -> Bool {
        if let last = lastFailureTime, consecutiveFailures >= 3,
           now().timeIntervalSince(last) < 15 { return false }
        if connection != 0 { return true }
        guard let opened = openConnection() else { recordFailure(); return false }
        connection = opened
        // Only a successful read clears failures, not a successful reconnect.
        return true
    }

    private func recordFailure() {
        consecutiveFailures = min(consecutiveFailures + 1, 3)
        lastFailureTime = now()
        close()
    }

    private func fourCC(_ code: String) -> UInt32 {
        var value: UInt32 = 0
        for byte in code.utf8 {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }

    private static func nativeCall(_ connection: io_connect_t, _ input: inout SMCParamStruct) -> SMCParamStruct? {
        // Selector 2 must never receive the write-bytes command (6).
        guard ReadCommand(rawValue: input.data8) != nil else { return nil }
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(connection, 2, &input,
            MemoryLayout<SMCParamStruct>.stride, &output, &outputSize)
        guard result == kIOReturnSuccess,
              outputSize == MemoryLayout<SMCParamStruct>.stride else { return nil }
        return output
    }

    private func callSMC(_ key: String, command: ReadCommand,
                         info: SMCKeyInfoData = SMCKeyInfoData(), cacheMissingFan: Bool = true) -> SMCParamStruct? {
        guard key.utf8.count == 4, key.utf8.allSatisfy({ $0 >= 32 && $0 < 127 }) else { return nil }
        var input = SMCParamStruct()
        input.key = fourCC(key)
        input.data8 = command.rawValue
        input.keyInfo = info
        guard let output = transport(connection, &input) else { recordFailure(); return nil }
        guard output.result == 0 else {
            // A missing key is a hardware capability result, not a reconnect loop.
            if cacheMissingFan { unavailableUntil = now().addingTimeInterval(60) }
            return nil
        }
        return output
    }

    static func decodeRPM(type: UInt32, size: UInt32, bytes: [UInt8]) -> Double? {
        let rpm: Double
        if type == 0x666c7420, size == 4, bytes.count >= 4 { // flt : little endian
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 |
                       UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            rpm = Double(Float(bitPattern: bits))
        } else if type == 0x66706532, size == 2, bytes.count >= 2 { // fpe2: big endian
            rpm = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        } else { return nil }
        return rpm.isFinite && (0...100_000).contains(rpm) ? rpm : nil
    }

    static func decodeTemperature(type: UInt32, size: UInt32, bytes: [UInt8]) -> Int? {
        let degrees: Double
        if type == 0x666c7420, size == 4, bytes.count >= 4 {
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 |
                       UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            degrees = Double(Float(bitPattern: bits))
        } else if type == 0x73703738, size == 2, bytes.count >= 2 {
            let bits = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            degrees = Double(Int16(bitPattern: bits)) / 256
        } else { return nil }
        guard degrees.isFinite, (-50...150).contains(degrees) else { return nil }
        return Int((degrees * 100).rounded())
    }

    /// TB0T is the battery-pack sensor; never substitute a CPU/charger sensor.
    func readBatteryTemperature() -> Int? {
        lock.lock()
        defer { lock.unlock() }
        if let until = temperatureUnavailableUntil, now() < until { return nil }
        guard open() else { return nil }
        guard let metadata = callSMC("TB0T", command: .keyInfo, cacheMissingFan: false),
              (metadata.keyInfo.dataType == fourCC("flt ") && metadata.keyInfo.dataSize == 4) ||
              (metadata.keyInfo.dataType == fourCC("sp78") && metadata.keyInfo.dataSize == 2),
              let output = callSMC("TB0T", command: .bytes, info: metadata.keyInfo, cacheMissingFan: false),
              let degrees = Self.decodeTemperature(type: metadata.keyInfo.dataType,
                size: metadata.keyInfo.dataSize, bytes: withUnsafeBytes(of: output.bytes) { Array($0) }) else {
            temperatureUnavailableUntil = now().addingTimeInterval(60)
            return nil
        }
        temperatureUnavailableUntil = nil
        // A temperature success must not erase a repeated fan transport failure.
        return degrees
    }

    func readFans() -> [FanReading]? {
        lock.lock()
        defer { lock.unlock() }
        if let until = unavailableUntil, now() < until { return nil }
        guard open(), let info = callSMC("FNum", command: .keyInfo) else { return nil }
        guard info.keyInfo.dataType == fourCC("ui8 "), info.keyInfo.dataSize == 1 else {
            unavailableUntil = now().addingTimeInterval(60)
            return nil
        }
        guard let count = callSMC("FNum", command: .bytes, info: info.keyInfo) else { return nil }
        let fanCount = Int(count.bytes.0)
        // Four-character decimal fan keys F0Ac...F9Ac only.
        guard fanCount <= 10 else { unavailableUntil = now().addingTimeInterval(60); return nil }
        var readings: [FanReading] = []
        for index in 0..<fanCount {
            let key = "F\(index)Ac"
            guard let metadata = callSMC(key, command: .keyInfo) else { return nil }
            guard (metadata.keyInfo.dataType == fourCC("flt ") && metadata.keyInfo.dataSize == 4) ||
                  (metadata.keyInfo.dataType == fourCC("fpe2") && metadata.keyInfo.dataSize == 2) else {
                unavailableUntil = now().addingTimeInterval(60)
                return nil
            }
            guard let output = callSMC(key, command: .bytes, info: metadata.keyInfo) else { return nil }
            let bytes = withUnsafeBytes(of: output.bytes) { Array($0) }
            guard let rpm = Self.decodeRPM(type: metadata.keyInfo.dataType,
                                          size: metadata.keyInfo.dataSize, bytes: bytes) else {
                unavailableUntil = now().addingTimeInterval(60)
                return nil
            }
            readings.append(FanReading(index: index, rpm: rpm))
        }
        consecutiveFailures = 0
        lastFailureTime = nil
        unavailableUntil = nil
        return readings
    }
}
