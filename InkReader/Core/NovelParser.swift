import Foundation

struct NovelChapter: Identifiable, Equatable {
    let id: Int
    let title: String
    let markdown: String
    var characterCount: Int { markdown.filter { $0.isLetter || $0.isNumber }.count }
}

struct ParsedNovel {
    let title: String
    let chapters: [NovelChapter]
    var characterCount: Int { chapters.reduce(0) { $0 + $1.characterCount } }
}

enum NovelParser {
    private static let chapterPattern = #"^(?:第\s*[零〇一二三四五六七八九十百千万两0-9０-９]+\s*[章回节卷部篇]|[Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+)(?:\s|[、.：:·]|$|[^0-9]).*$"#

    static func parse(_ source: String, fallbackTitle: String) -> ParsedNovel {
        var lines = source.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            lines.removeSubrange(0...end)
        }
        var headings: [(index: Int, level: Int, title: String)] = []
        var named: [(index: Int, level: Int, title: String)] = []
        var fence: String?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                if fence == nil { fence = marker } else if fence == marker { fence = nil }
                continue
            }
            guard fence == nil else { continue }
            if let heading = heading(trimmed) {
                let item = (index, heading.level, heading.title)
                headings.append(item)
                if matches(heading.title, chapterPattern) { named.append(item) }
            } else if matches(trimmed, chapterPattern) {
                named.append((index, 0, trimmed))
            }
        }
        let firstTitle = headings.first(where: { $0.level == 1 && !matches($0.title, chapterPattern) })
        let title = firstTitle?.title ?? fallbackTitle
        var boundaries = named
        if boundaries.isEmpty {
            boundaries = headings.filter { $0.index != firstTitle?.index && !["目录", "目錄", "Contents", "Table of Contents"].contains($0.title) }
            if let level = boundaries.map(\.level).min() { boundaries = boundaries.filter { $0.level == level } }
        }
        if boundaries.isEmpty {
            var body = lines
            if let firstTitle { body.remove(at: firstTitle.index) }
            return ParsedNovel(title: title, chapters: [NovelChapter(id: 0, title: "正文", markdown: body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))])
        }
        var chapters: [NovelChapter] = []
        // The generated table of contents and editorial preamble are not reading chapters.
        // Preserve a real preface in generic Markdown without explicit chapter numbering.
        if named.isEmpty, let first = boundaries.first {
            let preamble = lines[..<first.index].enumerated().filter { $0.offset != firstTitle?.index }.map(\.element)
            if !preamble.contains(where: { heading($0)?.title == "目录" }),
               preamble.joined().trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
                chapters.append(NovelChapter(id: 0, title: "前言", markdown: preamble.joined(separator: "\n")))
            }
        }
        for (offset, boundary) in boundaries.enumerated() {
            let end = offset + 1 < boundaries.count ? boundaries[offset + 1].index : lines.count
            let body = lines[(boundary.index + 1)..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            chapters.append(NovelChapter(id: chapters.count, title: boundary.title, markdown: body))
        }
        return ParsedNovel(title: title, chapters: chapters)
    }

    static func heading(_ line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level), trimmed.dropFirst(level).first?.isWhitespace == true else { return nil }
        let title = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"\s+#+\s*$"#, with: "", options: .regularExpression)
        return (level, title)
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
