import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class Store: ObservableObject {
    @Published var fileURL: URL?
    @Published var text: String = ""

    private var frontmatter: String = ""
    private let key = "filePath"

    init() {
        if let path = UserDefaults.standard.string(forKey: key) {
            fileURL = URL(fileURLWithPath: path)
        }
        reload()
    }

    func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let md = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [md, .plainText, .text]
        }
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: key)
            fileURL = url
            reload()
        }
    }

    func reload() {
        guard let url = fileURL,
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            frontmatter = ""
            text = ""
            return
        }
        let (fm, body) = Self.splitFrontmatter(raw)
        frontmatter = fm
        text = body
    }

    func save() {
        guard let url = fileURL else { return }
        let combined = frontmatter + text
        try? combined.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Splits a YAML frontmatter block (`---\n...\n---\n`) off the start.
    /// Returns (frontmatter including trailing newline, remaining body).
    static func splitFrontmatter(_ raw: String) -> (String, String) {
        let lines = raw.components(separatedBy: "\n")
        guard lines.first == "---" else { return ("", raw) }
        // find closing --- on its own line, after the first
        for i in 1..<lines.count {
            if lines[i] == "---" {
                let fm = lines[0...i].joined(separator: "\n") + "\n"
                let body = lines[(i + 1)...].joined(separator: "\n")
                // Drop a single leading blank line if present.
                if body.hasPrefix("\n") {
                    return (fm, String(body.dropFirst()))
                }
                return (fm, body)
            }
        }
        return ("", raw)
    }
}
