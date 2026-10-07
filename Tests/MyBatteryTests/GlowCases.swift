import AppKit
#if !DIRECT_REGRESSION
@testable import MyBattery
#endif

func runGlowRound2(_ check: (Bool, String) -> Void) {
    precondition(Thread.isMainThread)
    _ = NSApplication.shared
    let count = NSScreen.screens.count
    print("REAL_SCREEN_COUNT=\(count)")
    check(count > 0, "R08 real NSScreen available")
    guard count > 0 else { return }
    let saved = UserDefaults.standard.object(forKey: "plugInGlowEnabled")
    defer {
        if let saved = saved { UserDefaults.standard.set(saved, forKey: "plugInGlowEnabled") }
        else { UserDefaults.standard.removeObject(forKey: "plugInGlowEnabled") }
    }
    let controller = PlugInGlowController()
    controller.isEnabled = true
    for index in 0..<10 {
        controller.celebrate()
        check(controller.windows.count == count && controller.isCelebrating, "R08 trigger \(index + 1) replaces windows")
    }
    let token = controller.celebrationToken
    let oldWindows = controller.windows
    controller.isEnabled = false
    check(oldWindows.allSatisfy { !$0.isVisible }, "R08 disabled windows ordered out")
    check(controller.windows.isEmpty && !controller.isCelebrating && controller.celebrationToken > token, "R08 disable synchronous cleanup")
    controller.isEnabled = true
    controller.celebrate()
    RunLoop.main.run(until: Date().addingTimeInterval(1.5))
    controller.celebrate()
    let newToken = controller.celebrationToken
    RunLoop.main.run(until: Date().addingTimeInterval(0.85))
    check(controller.celebrationToken == newToken && controller.isCelebrating && controller.windows.count == count, "R08 old callback cannot remove new windows")
    RunLoop.main.run(until: Date().addingTimeInterval(1.5))
    check(controller.windows.isEmpty && !controller.isCelebrating, "R08 animation-end cleanup")
    controller.celebrate()
    NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    check(controller.windows.isEmpty, "R08 screen-change notification cleanup")
    controller.celebrate()
    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
    check(controller.windows.isEmpty, "V1 sleep notification cleanup")
    controller.celebrate()
    NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
    check(controller.windows.isEmpty, "R08 termination notification cleanup")
    var disposable: PlugInGlowController? = PlugInGlowController()
    disposable?.celebrate()
    weak var released = disposable
    disposable = nil
    check(released == nil, "R08 controller deinit with active windows")
}
