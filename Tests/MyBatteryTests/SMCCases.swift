import Foundation
import IOKit
#if !DIRECT_REGRESSION
@testable import MyBattery
#endif

func runSMCRound2(_ check: @escaping (Bool, String) -> Void) {
    typealias Param = SMCFansReader.SMCParamStruct
    check(MemoryLayout<Param>.stride == 80, "R01 ABI stride 80")
    check(MemoryLayout<Param>.offset(of: \.result) == 40, "R01 ABI result 40")
    check(MemoryLayout<Param>.offset(of: \.data8) == 42, "R01 ABI data8 42")
    check(MemoryLayout<Param>.offset(of: \.bytes) == 48, "R01 ABI bytes 48")
    check(SMCFansReader.decodeRPM(type: 0x666c7420, size: 4, bytes: [0, 0, 250, 68]) == 2000, "R01 float little endian nonzero")
    check(SMCFansReader.decodeRPM(type: 0x66706532, size: 2, bytes: [31, 64]) == 2000, "R01 fpe2 big endian nonzero")
    for type: UInt32 in [0, 0x75693136] {
        check(SMCFansReader.decodeRPM(type: type, size: 2, bytes: [31, 64]) == nil, "R01 unknown format \(type)")
    }
    check(SMCFansReader.decodeRPM(type: 0x666c7420, size: 4, bytes: [0, 0, 128, 127]) == nil, "R01 infinity RPM")
    check(SMCFansReader.decodeTemperature(type: 0x73703738, size: 2, bytes: [40, 128]) == 4050, "V1 sp78 battery temperature")
    check(SMCFansReader.decodeTemperature(type: 0x73703738, size: 2, bytes: [251, 0]) == -500, "V1 signed sp78 temperature")
    check(SMCFansReader.decodeTemperature(type: 0x666c7420, size: 4, bytes: [0, 0, 34, 66]) == 4050, "V1 float battery temperature")
    check(SMCFansReader.decodeTemperature(type: 0, size: 2, bytes: [40, 0]) == nil, "V1 unknown temperature type")
    var tempCommands: [UInt8] = []
    let temperature = SMCFansReader(openConnection: { 1 }, closeConnection: { _ in }, transport: { _, input in
        tempCommands.append(input.data8)
        check(input.key == 0x54423054 && [5, 9].contains(input.data8), "V1 TB0T read-only command")
        var out = Param(); out.keyInfo.dataType = 0x73703738; out.keyInfo.dataSize = 2
        out.bytes.0 = 40; out.bytes.1 = 128
        return out
    })
    check(temperature.readBatteryTemperature() == 4050 && tempCommands == [9, 5], "V1 battery sensor actual path")
    var missingTempCalls = 0
    let absentTemperature = SMCFansReader(openConnection: { 1 }, closeConnection: { _ in }, transport: { _, input in
        var out = Param()
        if input.key == 0x54423054 { missingTempCalls += 1; out.result = 132 }
        else { out.keyInfo.dataType = 0x75693820; out.keyInfo.dataSize = 1 }
        return out
    })
    check(absentTemperature.readBatteryTemperature() == nil && absentTemperature.readBatteryTemperature() == nil && missingTempCalls == 1, "V1 missing temperature cooldown")
    check(absentTemperature.readFans() == [], "V1 missing temperature does not hide fans")
    var mixedOpens = 0
    let mixed = SMCFansReader(openConnection: { mixedOpens += 1; return 1 }, closeConnection: { _ in }, transport: { _, input in
        if input.key != 0x54423054 { return nil }
        var out = Param(); out.keyInfo.dataType = 0x73703738; out.keyInfo.dataSize = 2; out.bytes.0 = 32
        return out
    })
    for _ in 0..<3 { _ = mixed.readBatteryTemperature(); _ = mixed.readFans() }
    check(mixed.readBatteryTemperature() == nil && mixedOpens == 3, "V1 temperature success preserves fan failure backoff")
    var commands: [UInt8] = []
    let reader = SMCFansReader(openConnection: { 1 }, closeConnection: { _ in }, transport: { _, input in
        commands.append(input.data8)
        check([5, 9].contains(input.data8), "R01 mocked transport forbids writes")
        var result = Param()
        if input.key == 0x464e756d {
            result.keyInfo.dataSize = 1; result.keyInfo.dataType = 0x75693820; result.bytes.0 = 1
        } else {
            result.keyInfo.dataSize = 4; result.keyInfo.dataType = 0x666c7420
            result.bytes.2 = 250; result.bytes.3 = 68
        }
        return result
    })
    check(reader.readFans() == [FanReading(index: 0, rpm: 2000)], "R01 actual read path")
    check(commands == [9, 5, 9, 5], "R01 actual command sequence")
    for (type, size, count): (UInt32, UInt32, UInt8) in [(0, 1, 1), (0x75693820, 2, 1), (0x75693820, 1, 11)] {
        let invalid = SMCFansReader(openConnection: { 1 }, closeConnection: { _ in }, transport: { _, _ in
            var out = Param(); out.keyInfo.dataType = type; out.keyInfo.dataSize = size; out.bytes.0 = count
            return out
        })
        check(invalid.readFans() == nil, "R01 invalid FNum \(type)/\(size)/\(count)")
    }
    let fanless = SMCFansReader(openConnection: { 1 }, closeConnection: { _ in }, transport: { _, _ in
        var out = Param(); out.keyInfo.dataType = 0x75693820; out.keyInfo.dataSize = 1; return out
    })
    check(fanless.readFans() == [], "R01 fanless count zero")
    var clock = Date(timeIntervalSince1970: 0), opens = 0, closes = 0, calls = 0
    let failing = SMCFansReader(openConnection: { opens += 1; return 1 }, closeConnection: { _ in closes += 1 }, transport: { _, _ in calls += 1; return nil }, now: { clock })
    for _ in 0..<5 { check(failing.readFans() == nil, "R01 read failure safe") }
    check(opens == 3 && closes == 3 && calls == 3, "R01 reconnect does not reset backoff")
    clock = clock.addingTimeInterval(16)
    check(failing.readFans() == nil && opens == 4, "R01 backoff expiration")
    var failedOpens = 0
    let openFail = SMCFansReader(openConnection: { failedOpens += 1; return nil }, now: { clock })
    for _ in 0..<5 { _ = openFail.readFans() }
    check(failedOpens == 3, "R01 connection-open failure bounded")
    var missingCalls = 0
    let missing = SMCFansReader(openConnection: { 1 }, closeConnection: { _ in }, transport: { _, _ in
        missingCalls += 1; var out = Param(); out.result = 132; return out
    }, now: { clock })
    for _ in 0..<5 { _ = missing.readFans() }
    check(missingCalls == 1, "R01 missing key cooldown")
}
