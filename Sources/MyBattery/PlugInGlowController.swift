import AppKit

/// 接通电源时屏幕边缘的绿色呼吸光晕庆祝动效 (Plug-in Celebration Glow)
final class PlugInGlowController {
    // Swift 5.9 contract: all state and AppKit lifetimes belong to main.
    // Background callers must dispatch to main before accessing shared.
    static var shared: PlugInGlowController {
        precondition(Thread.isMainThread)
        return instance
    }
    private static let instance = PlugInGlowController()

    private(set) var windows: [NSWindow] = []
    private(set) var celebrationToken = 0
    private(set) var isCelebrating = false

    private static let kGlowEnabled = "plugInGlowEnabled"

    var isEnabled: Bool {
        get {
            precondition(Thread.isMainThread)
            return UserDefaults.standard.object(forKey: Self.kGlowEnabled) as? Bool ?? true
        }
        set {
            precondition(Thread.isMainThread)
            UserDefaults.standard.set(newValue, forKey: Self.kGlowEnabled)
            if !newValue { cancelAndHide() }
        }
    }

    init() {
        precondition(Thread.isMainThread)
        NSWorkspace.shared.notificationCenter.addObserver(self,
            selector: #selector(handleAppTerminate), name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        // ARC may release a controller on a background thread. Move the retained
        // windows to main before ordering out and releasing the final references.
        let retainedWindows = windows
        if Thread.isMainThread {
            retainedWindows.forEach { $0.orderOut(nil); $0.close() }
        } else {
            DispatchQueue.main.async { retainedWindows.forEach { $0.orderOut(nil); $0.close() } }
        }
    }

    @objc private func handleScreenChange() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handleScreenChange() }
            return
        }
        if isCelebrating {
            cancelAndHide()
        }
    }

    @objc private func handleAppTerminate() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handleAppTerminate() }
            return
        }
        cancelAndHide()
    }

    /// 取消当前正在进行的光效并立即移除窗口
    func cancelAndHide() {
        precondition(Thread.isMainThread)
        celebrationToken += 1
        isCelebrating = false
        hideWindows()
    }

    /// Main-thread-only entry. The caller dispatches before accessing shared.
    func celebrate() {
        precondition(Thread.isMainThread)
        performCelebrate()
    }

    private func performCelebrate() {
        precondition(Thread.isMainThread)
        guard isEnabled else { return }
        celebrationToken += 1
        let token = celebrationToken
        isCelebrating = true

        showWindows()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, self.celebrationToken == token else { return }
            self.fadeOutWindows()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self = self, self.celebrationToken == token else { return }
            self.hideWindows()
            self.isCelebrating = false
        }
    }

    private func showWindows() {
        precondition(Thread.isMainThread)
        hideWindows()
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.setFrame(screen.frame, display: true)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.contentView = GlowEdgeView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.alphaValue = 0.0
            window.orderFrontRegardless()
            windows.append(window)

            // 快速淡入
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1.0
            }
        }
    }

    private func fadeOutWindows() {
        precondition(Thread.isMainThread)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.9
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in windows {
                window.animator().alphaValue = 0.0
            }
        }
    }

    private func hideWindows() {
        precondition(Thread.isMainThread)
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}

// MARK: - 屏幕边缘纯原生绘制光晕视图 (零 SwiftUI 依赖，高性能低开销)

final class GlowEdgeView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds.insetBy(dx: 1, dy: 1)
        let cornerRadius: CGFloat = 20.0
        let path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        ctx.saveGState()

        // 柔和深远的外层漫射光晕
        ctx.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.20).cgColor)
        ctx.setLineWidth(48)
        ctx.addPath(path)
        ctx.strokePath()

        // 中度发光层
        ctx.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(16)
        ctx.addPath(path)
        ctx.strokePath()

        // 核心亮绿霓虹边缘线
        ctx.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.90).cgColor)
        ctx.setLineWidth(4)
        ctx.addPath(path)
        ctx.strokePath()

        ctx.restoreGState()
    }
}
