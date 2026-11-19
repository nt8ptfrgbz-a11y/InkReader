import Foundation

enum MarkdownRenderer {
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func inline(_ text: String) -> String {
        var value = escape(text)
        var code: [String] = []
        let regex = try! NSRegularExpression(pattern: "`([^`]+)`")
        for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
            guard let range = Range(match.range, in: value), let inner = Range(match.range(at: 1), in: value) else { continue }
            let token = "\u{E000}\(code.count)\u{E001}"
            code.append("<code>\(value[inner])</code>")
            value.replaceSubrange(range, with: token)
        }
        for (pattern, template) in [
            (#"!\[([^\]]*)\]\([^\)]*\)"#, "$1"),
            (#"\[([^\]]+)\]\([^\)]*\)"#, "$1"),
            (#"\*\*(.+?)\*\*"#, "<strong>$1</strong>"),
            (#"__(.+?)__"#, "<strong>$1</strong>"),
            (#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, "<em>$1</em>"),
            (#"~~(.+?)~~"#, "<del>$1</del>")
        ] { value = value.replacingOccurrences(of: pattern, with: template, options: .regularExpression) }
        for (index, snippet) in code.enumerated() { value = value.replacingOccurrences(of: "\u{E000}\(index)\u{E001}", with: snippet) }
        return value
    }

    static func render(_ markdown: String) -> String {
        var output: [String] = []
        var paragraph: [String] = []
        var code: [String] = []
        var fence: String?
        var listType: String?
        func flushParagraph() {
            if !paragraph.isEmpty { output.append("<p>\(inline(paragraph.joined(separator: "\n")))</p>"); paragraph.removeAll() }
        }
        func closeList() { if let type = listType { output.append("</\(type)>"); listType = nil } }
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                if fence == nil { flushParagraph(); closeList(); fence = marker }
                else if fence == marker { output.append("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>"); code.removeAll(); fence = nil }
                else { code.append(line) }
                continue
            }
            if fence != nil { code.append(line); continue }
            if trimmed.isEmpty { flushParagraph(); closeList(); continue }
            if let h = NovelParser.heading(trimmed) {
                flushParagraph(); closeList(); let level = min(h.level + 1, 6)
                output.append("<h\(level)>\(inline(h.title))</h\(level)>")
            } else if trimmed.range(of: #"^(?:\*\s*){3,}$|^(?:-\s*){3,}$|^(?:_\s*){3,}$"#, options: .regularExpression) != nil {
                flushParagraph(); closeList(); output.append("<hr>")
            } else if trimmed.hasPrefix(">") {
                flushParagraph(); closeList(); output.append("<blockquote>\(inline(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))</blockquote>")
            } else if let range = trimmed.range(of: #"^(?:[-*+]\s+|\d+[.)]\s+)"#, options: .regularExpression) {
                flushParagraph()
                let type = trimmed.first?.isNumber == true ? "ol" : "ul"
                if listType != type { closeList(); listType = type; output.append("<\(type)>") }
                output.append("<li>\(inline(String(trimmed[range.upperBound...])))</li>")
            } else { closeList(); paragraph.append(line) }
        }
        flushParagraph(); closeList()
        if fence != nil { output.append("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>") }
        return output.joined(separator: "\n")
    }
}
