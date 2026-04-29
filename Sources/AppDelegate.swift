import SwiftUI
import AppKit

final class KeyablePanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!

    static let hideMenuBarEntryAfterLaunchKey = "hideMenuBarEntryAfterLaunch"

    let store = Store()

    private var statusItem: NSStatusItem?
    private var editorWindow: NSWindow!
    private var settingsWindow: NSWindow?
    private let editorFrameOriginKey = "editorFrameOrigin"
    private var hideStatusItemTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        buildMainMenu()
        showStatusItemForCurrentPreference()
        buildEditorWindow()

        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.toggleEditor()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStatusItemForCurrentPreference()
        return false
    }

    // MARK: - Main menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit TodoMD",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")),
                         keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",
                         action: Selector(("redo:")),
                         keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)),
                         keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)),
                         keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)),
                         keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status item

    private func buildStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "square.and.pencil",
                                   accessibilityDescription: "TodoMD")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }

    private func showStatusItemForCurrentPreference() {
        buildStatusItem()

        if UserDefaults.standard.bool(forKey: Self.hideMenuBarEntryAfterLaunchKey) {
            scheduleStatusItemHide()
        } else {
            hideStatusItemTimer?.invalidate()
            hideStatusItemTimer = nil
        }
    }

    private func scheduleStatusItemHide() {
        hideStatusItemTimer?.invalidate()
        hideStatusItemTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.hideStatusItem()
        }
    }

    private func hideStatusItem() {
        hideStatusItemTimer?.invalidate()
        hideStatusItemTimer = nil

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    func updateMenuBarEntryAutoHide(enabled: Bool) {
        if enabled {
            showStatusItemForCurrentPreference()
        } else {
            hideStatusItemTimer?.invalidate()
            hideStatusItemTimer = nil
            buildStatusItem()
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown
            || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            toggleEditor()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings),
                     keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TodoMD",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Detach so left-click goes back to our action handler.
        statusItem?.menu = nil
    }

    // MARK: - Editor window

    private func buildEditorWindow() {
        let window = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 416, height: 234),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self

        let hosting = NSHostingView(
            rootView: EditorView().environmentObject(store)
        )
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = window.contentView!.bounds
        window.contentView?.addSubview(hosting)
        window.contentView?.wantsLayer = true

        editorWindow = window
    }

    private let editorSize = NSSize(width: 416, height: 234)

    func toggleEditor() {
        if editorWindow.isVisible {
            hideEditor()
            return
        }
        store.reload()

        let target = targetFrame()
        editorWindow.setFrame(target, display: false)
        editorWindow.alphaValue = 0

        // Visually scale the layer (window stays at full size, so text doesn't reflow).
        let size = editorWindow.contentView?.bounds.size ?? target.size
        let startScale: CGFloat = 0.96
        if let layer = editorWindow.contentView?.layer {
            layer.sublayerTransform = Self.scaleTransform(startScale, in: size)
        }

        NSApp.activate(ignoringOtherApps: true)
        editorWindow.makeKeyAndOrderFront(nil)
        focusEditorText(atEnd: true)
        DispatchQueue.main.async { [weak self] in
            self?.focusEditorText(atEnd: true)
        }

        let timing = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.3, 1.02)
        let duration: CFTimeInterval = 0.22

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = timing
            editorWindow.animator().alphaValue = 1
        }

        if let layer = editorWindow.contentView?.layer {
            let anim = CABasicAnimation(keyPath: "sublayerTransform")
            anim.fromValue = NSValue(caTransform3D: Self.scaleTransform(startScale, in: size))
            anim.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            anim.duration = duration
            anim.timingFunction = timing
            layer.sublayerTransform = CATransform3DIdentity
            layer.add(anim, forKey: "openScale")
        }
    }

    func hideEditor() {
        guard editorWindow.isVisible else { return }
        store.save()
        saveEditorFrame()
        let window = editorWindow!
        let size = window.contentView?.bounds.size ?? targetFrame().size
        let endScale: CGFloat = 0.97
        let timing = CAMediaTimingFunction(name: .easeIn)
        let duration: CFTimeInterval = 0.14

        if let layer = window.contentView?.layer {
            let anim = CABasicAnimation(keyPath: "sublayerTransform")
            anim.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
            anim.toValue = NSValue(caTransform3D: Self.scaleTransform(endScale, in: size))
            anim.duration = duration
            anim.timingFunction = timing
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            layer.add(anim, forKey: "closeScale")
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = timing
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
            window.contentView?.layer?.removeAnimation(forKey: "closeScale")
            window.contentView?.layer?.sublayerTransform = CATransform3DIdentity
        })
    }

    func windowDidMove(_ notification: Notification) {
        guard notification.object as? NSWindow === editorWindow,
              editorWindow.isVisible else { return }
        saveEditorFrame()
    }

    private static func scaleTransform(_ scale: CGFloat, in size: NSSize) -> CATransform3D {
        let dx = size.width / 2
        let dy = size.height / 2
        var t = CATransform3DMakeTranslation(-dx, -dy, 0)
        t = CATransform3DConcat(t, CATransform3DMakeScale(scale, scale, 1))
        t = CATransform3DConcat(t, CATransform3DMakeTranslation(dx, dy, 0))
        return t
    }

    private func firstTextView(in view: NSView?) -> NSTextView? {
        guard let view = view else { return nil }
        if let tv = view as? NSTextView { return tv }
        for sub in view.subviews {
            if let found = firstTextView(in: sub) { return found }
        }
        return nil
    }

    private func focusEditorText(atEnd: Bool) {
        guard let tv = firstTextView(in: editorWindow.contentView) else { return }
        editorWindow.makeFirstResponder(tv)
        if atEnd {
            let end = tv.string.utf16.count
            tv.setSelectedRange(NSRange(location: end, length: 0))
            tv.scrollRangeToVisible(NSRange(location: end, length: 0))
        }
    }

    private func targetFrame() -> NSRect {
        if let savedFrame = savedEditorFrame() {
            return savedFrame
        }

        let screen = NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: screen.midX - editorSize.width / 2,
            y: screen.midY - editorSize.height / 2,
            width: editorSize.width,
            height: editorSize.height
        )
    }

    private func savedEditorFrame() -> NSRect? {
        guard let originString = UserDefaults.standard.string(forKey: editorFrameOriginKey) else {
            return nil
        }

        let origin = NSPointFromString(originString)
        let frame = NSRect(origin: origin, size: editorSize)
        return frameMovedOnScreen(frame)
    }

    private func saveEditorFrame() {
        guard editorWindow != nil else { return }
        UserDefaults.standard.set(NSStringFromPoint(editorWindow.frame.origin), forKey: editorFrameOriginKey)
    }

    private func frameMovedOnScreen(_ frame: NSRect) -> NSRect {
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard !visibleFrames.isEmpty else { return frame }

        let screenFrame = visibleFrames
            .max { first, second in
                intersectionArea(first, frame) < intersectionArea(second, frame)
            } ?? visibleFrames[0]

        var adjusted = frame
        adjusted.origin.x = min(max(adjusted.minX, screenFrame.minX), screenFrame.maxX - adjusted.width)
        adjusted.origin.y = min(max(adjusted.minY, screenFrame.minY), screenFrame.maxY - adjusted.height)
        return adjusted
    }

    private func intersectionArea(_ first: NSRect, _ second: NSRect) -> CGFloat {
        let intersection = first.intersection(second)
        return intersection.width * intersection.height
    }

    private func scaledFrame(_ scale: CGFloat) -> NSRect {
        let target = targetFrame()
        let w = target.width * scale
        let h = target.height * scale
        return NSRect(
            x: target.midX - w / 2,
            y: target.midY - h / 2,
            width: w,
            height: h
        )
    }

    // MARK: - Settings window

    @objc func openSettings() {
        if let window = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingView(
            rootView: SettingsView().environmentObject(store)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
