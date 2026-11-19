import SwiftUI
import CryptoKit
import CoreFoundation

struct LibraryBook: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let fileName: String
    let chapterCount: Int
    let characterCount: Int
    let addedAt: Date
    let isBundled: Bool
}

struct ReadingPosition: Codable, Equatable {
    var chapter: Int = 0
    var fraction: Double = 0
    var updatedAt: Date = Date()
}

struct ReadingBookmark: Codable, Identifiable {
    var id = UUID()
    let bookID: String
    let chapter: Int
    let fraction: Double
    let title: String
    let createdAt: Date
}

enum ReadingTheme: String, Codable, CaseIterable {
    case paper, light, night
    var title: String { switch self { case .paper: return "暖纸"; case .light: return "素白"; case .night: return "夜读" } }
    var backgroundHex: String { switch self { case .paper: return "F6F0E5"; case .light: return "FAFAF8"; case .night: return "181C1B" } }
    var textHex: String { switch self { case .paper: return "343A34"; case .light: return "292E2B"; case .night: return "C6CEC7" } }
    var background: Color { Color(hex: backgroundHex) }
    var text: Color { Color(hex: textHex) }
}

struct ReaderSettings: Codable, Equatable {
    var fontSize: Double = 21
    var lineHeight: Double = 1.95
    var theme: ReadingTheme = .paper
    var serif: Bool = true
    var keepAwake: Bool = false
}

private struct LibraryState: Codable {
    var books: [LibraryBook] = []
    var positions: [String: ReadingPosition] = [:]
    var bookmarks: [ReadingBookmark] = []
    var settings = ReaderSettings()
    var lastOpenedID: String?
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [LibraryBook] = []
    @Published private(set) var positions: [String: ReadingPosition] = [:]
    @Published private(set) var bookmarks: [ReadingBookmark] = []
    @Published var settings = ReaderSettings() { didSet { scheduleSave() } }
    @Published private(set) var lastOpenedID: String?
    @Published var errorMessage: String?
    private let root: URL
    private var cache: [String: ParsedNovel] = [:]
    private var pendingSave: DispatchWorkItem?
    private var ready = false

    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("InkLibrary", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let stateURL = root.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: stateURL.path) {
                do {
                    let state = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: stateURL))
                    books = state.books; positions = state.positions; bookmarks = state.bookmarks
                    settings = state.settings; lastOpenedID = state.lastOpenedID
                } catch {
                    try FileManager.default.copyItem(at: stateURL, to: root.appendingPathComponent("library-backup-\(Int(Date().timeIntervalSince1970)).json"))
                    errorMessage = "书架记录读取失败，原记录已备份。小说文件仍保存在本机。"
                }
            }
            if books.isEmpty, let url = Bundle.main.url(forResource: "诛仙同人·长相守", withExtension: "md") {
                _ = try add(data: Data(contentsOf: url), name: url.lastPathComponent, bundled: true)
            }
            ready = true
            saveNow()
        } catch { ready = true; errorMessage = "无法打开本地书架：\(error.localizedDescription)" }
    }

    var currentBook: LibraryBook? { books.first(where: { $0.id == lastOpenedID }) ?? books.first }

    func novel(for book: LibraryBook) throws -> ParsedNovel {
        if let cached = cache[book.id] { return cached }
        let source = try Self.decode(Data(contentsOf: root.appendingPathComponent(book.fileName)))
        let novel = NovelParser.parse(source, fallbackTitle: book.title)
        cache[book.id] = novel
        return novel
    }

    func position(for book: LibraryBook) -> ReadingPosition { positions[book.id] ?? ReadingPosition() }

    func open(_ book: LibraryBook) { lastOpenedID = book.id; saveNow() }

    func updatePosition(bookID: String, chapter: Int, fraction: Double) {
        guard fraction.isFinite, let book = books.first(where: { $0.id == bookID }) else { return }
        positions[bookID] = ReadingPosition(chapter: min(max(0, chapter), book.chapterCount - 1), fraction: min(max(0, fraction), 1), updatedAt: Date())
        scheduleSave()
    }

    func progress(for book: LibraryBook) -> Double {
        guard let p = positions[book.id], book.chapterCount > 0 else { return 0 }
        return min(1, (Double(p.chapter) + p.fraction) / Double(book.chapterCount))
    }

    @discardableResult
    func importBooks(_ urls: [URL]) -> Int {
        var count = 0
        var failures: [String] = []
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do { if try add(data: Data(contentsOf: url), name: url.lastPathComponent, bundled: false) { count += 1 } }
            catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
        }
        saveNow()
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
        return count
    }

    @discardableResult
    private func add(data: Data, name: String, bundled: Bool) throws -> Bool {
        guard data.count <= 30 * 1024 * 1024 else { throw ReaderError.message("文件超过 30 MB，请按卷拆分后导入。") }
        let source = try Self.decode(data)
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReaderError.message("文件中没有可阅读的正文。") }
        let id = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
        guard !books.contains(where: { $0.id == id }) else { return false }
        let novel = NovelParser.parse(source, fallbackTitle: (name as NSString).deletingPathExtension)
        let fileName = "\(id).md"
        try Data(source.utf8).write(to: root.appendingPathComponent(fileName), options: .atomic)
        let book = LibraryBook(id: id, title: novel.title, fileName: fileName, chapterCount: novel.chapters.count, characterCount: novel.characterCount, addedAt: Date(), isBundled: bundled)
        books.append(book); cache[id] = novel
        return true
    }

    func remove(_ book: LibraryBook) {
        do {
            let url = root.appendingPathComponent(book.fileName)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            books.removeAll { $0.id == book.id }; positions.removeValue(forKey: book.id)
            bookmarks.removeAll { $0.bookID == book.id }; cache.removeValue(forKey: book.id)
            if lastOpenedID == book.id { lastOpenedID = nil }
            saveNow()
        } catch { errorMessage = "删除失败：\(error.localizedDescription)" }
    }

    func addBookmark(book: LibraryBook, chapter: Int, fraction: Double, title: String) {
        bookmarks.append(ReadingBookmark(bookID: book.id, chapter: chapter, fraction: fraction, title: title, createdAt: Date()))
        saveNow()
    }

    func removeBookmark(_ bookmark: ReadingBookmark) { bookmarks.removeAll { $0.id == bookmark.id }; saveNow() }

    func saveNow() {
        guard ready else { return }
        pendingSave?.cancel()
        do {
            let state = LibraryState(books: books, positions: positions, bookmarks: bookmarks, settings: settings, lastOpenedID: lastOpenedID)
            try JSONEncoder().encode(state).write(to: root.appendingPathComponent("library.json"), options: .atomic)
        } catch { errorMessage = "阅读记录保存失败：\(error.localizedDescription)" }
    }

    private func scheduleSave() {
        guard ready else { return }
        pendingSave?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: task)
    }

    private static func decode(_ data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]), let text = String(data: data, encoding: .utf16) { return text }
        let gb = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let text = String(data: data, encoding: gb) { return text }
        throw ReaderError.message("无法识别文字编码，请保存为 UTF-8 后重试。")
    }
}

enum ReaderError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
    static let ink = Color(hex: "243D32")
    static let canvas = Color(hex: "F7F6F2")
    static let mutedInk = Color(hex: "778178")
}
