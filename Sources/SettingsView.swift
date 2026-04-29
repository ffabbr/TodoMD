import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var hotkey = HotKeyManager.shared
    @AppStorage(AppDelegate.hideMenuBarEntryAfterLaunchKey) private var hideMenuBarEntryAfterLaunch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section(title: "Markdown File") {
                HStack {
                    Text(store.fileURL?.path ?? "No file selected")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(store.fileURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                    Button("Choose…") { store.pickFile() }
                }
            }

            Divider()

            section(title: "Toggle Shortcut") {
                HStack(spacing: 8) {
                    ShortcutRecorder(hotkey: hotkey)
                    if hotkey.current != nil {
                        Button("Clear") { hotkey.clear() }
                            .buttonStyle(.borderless)
                    }
                }
                Text("Press this shortcut from anywhere to open or close the editor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            section(title: "Menu Bar") {
                Toggle("Hide menu bar entry after 5 seconds", isOn: $hideMenuBarEntryAfterLaunch)
                    .onChange(of: hideMenuBarEntryAfterLaunch) { _, enabled in
                        AppDelegate.shared.updateMenuBarEntryAutoHide(enabled: enabled)
                    }
                Text("Opening TodoMD again temporarily shows the menu bar entry.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}

struct ShortcutRecorder: View {
    @ObservedObject var hotkey: HotKeyManager
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            if recording { stop() } else { start() }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(minWidth: 140, minHeight: 26)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(recording ? Color.accentColor : .white.opacity(0.06),
                                      lineWidth: recording ? 2 : 1)
                )
                .foregroundStyle(recording ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .onDisappear { stop() }
    }

    private var label: String {
        if recording { return "Press shortcut…" }
        return hotkey.displayString ?? "Click to record"
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Require at least one modifier to avoid catching plain typing.
            guard !mods.isEmpty else { return event }
            // Ignore pure modifier presses.
            if event.charactersIgnoringModifiers?.isEmpty != false
                && Self.isNonCharKey(Int(event.keyCode)) == false {
                return event
            }
            let display = ShortcutDisplay.name(for: event)
            hotkey.set(keyCode: Int(event.keyCode), modifiers: mods, display: display)
            stop()
            return nil
        }
    }

    private func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        recording = false
    }

    private static func isNonCharKey(_ code: Int) -> Bool {
        // We accept these even if charactersIgnoringModifiers is empty.
        let allowed: Set<Int> = [
            kVK_Space, kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab, kVK_Escape,
            kVK_Delete, kVK_ForwardDelete,
            kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
            kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12
        ]
        return allowed.contains(code)
    }
}
