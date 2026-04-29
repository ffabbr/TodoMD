import AppKit
import Carbon.HIToolbox
import Combine

struct Shortcut: Codable, Equatable {
    let keyCode: Int
    let modifiers: UInt
    let display: String
}

final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()

    @Published private(set) var current: Shortcut?
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let key = "shortcut"
    private let signature: OSType = 0x4D424D44 // 'MBMD'

    private init() {
        installHandler()
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Shortcut.self, from: data) {
            current = s
            register(s)
        }
    }

    func set(keyCode: Int, modifiers: NSEvent.ModifierFlags, display: String) {
        let cleaned = modifiers.intersection([.command, .option, .control, .shift])
        let s = Shortcut(keyCode: keyCode, modifiers: cleaned.rawValue, display: display)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key)
        }
        current = s
        register(s)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        unregister()
        current = nil
    }

    var displayString: String? {
        guard let s = current else { return nil }
        let mods = NSEvent.ModifierFlags(rawValue: s.modifiers)
        var str = ""
        if mods.contains(.control) { str += "⌃" }
        if mods.contains(.option) { str += "⌥" }
        if mods.contains(.shift) { str += "⇧" }
        if mods.contains(.command) { str += "⌘" }
        return str + s.display
    }

    // MARK: - Registration

    private func register(_ s: Shortcut) {
        unregister()
        let mods = carbonModifiers(NSEvent.ModifierFlags(rawValue: s.modifiers))
        let id = EventHotKeyID(signature: signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(s.keyCode),
            mods,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr { hotKeyRef = ref }
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.onTrigger?() }
                return noErr
            },
            1, &spec, ptr, &eventHandler
        )
    }

    private func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }
}

enum ShortcutDisplay {
    static func name(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            let chars = event.charactersIgnoringModifiers ?? ""
            return chars.uppercased()
        }
    }
}
