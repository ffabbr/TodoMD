import SwiftUI
import AppKit

struct EditorView: View {
    @EnvironmentObject var store: Store
    @FocusState private var focused: Bool

    private let cornerRadius: CGFloat = 26

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.regularMaterial)

            VStack(spacing: 0) {
                if store.fileURL == nil {
                    emptyState
                } else {
                    editor
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { focused = true }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            // Top bar: filename centered, gear button on the right.
            ZStack {
                Text(store.fileURL?.lastPathComponent ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack {
                    Spacer()
                    Button { openSettings() } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Settings")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            MarkdownTextView(
                text: $store.text,
                onCommandReturn: {
                    store.save()
                    dismissWindow()
                },
                onCommandComma: { openSettings() }
            )
            .padding(.horizontal, 10)

            // Bottom bar: keycap hint on the right.
            HStack(spacing: 6) {
                Spacer()
                KeyCap("⌘")
                KeyCap("⏎")
                Text("to save")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 14)
            .padding(.trailing, 22)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("No file selected")
                .font(.headline)
            Text("Pick a markdown file in Settings to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { openSettings() } label: {
                Text("Open Settings…")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
                .padding(.top, 4)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSettings() {
        AppDelegate.shared.openSettings()
    }

    private func dismissWindow() {
        AppDelegate.shared.hideEditor()
    }
}

struct KeyCap: View {
    let symbol: String
    init(_ symbol: String) { self.symbol = symbol }

    var body: some View {
        Text(symbol)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
    }
}
