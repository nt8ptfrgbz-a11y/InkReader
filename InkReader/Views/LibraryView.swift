import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var selectedBook: LibraryBook?
    @State private var importing = false
    @State private var query = ""
    @State private var notice: String?
    @State private var deleting: LibraryBook?

    private var filtered: [LibraryBook] { library.books.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if query.isEmpty, let book = library.currentBook { continueCard(book) }
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("我的书架").font(.system(size: 23, weight: .semibold, design: .serif)).foregroundStyle(Color.ink)
                            Text("\(library.books.count) 本").font(.subheadline).foregroundStyle(Color.mutedInk)
                            Spacer()
                            Image(systemName: "square.grid.2x2").font(.subheadline).foregroundStyle(Color.mutedInk)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Color.mutedInk)
                            TextField("查找书架中的小说", text: $query).font(.subheadline).accessibilityIdentifier("librarySearch")
                            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.mutedInk) }.accessibilityLabel("清空搜索") }
                        }
                        .padding(14).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                        if filtered.isEmpty {
                            ContentUnavailableView(query.isEmpty ? "书架还空着" : "没有找到这本书", systemImage: "books.vertical", description: Text("点击右上角，导入你的 MD 或 TXT 小说。"))
                        }
                        ForEach(filtered) { book in bookRow(book) }
                    }
                    HStack(spacing: 7) {
                        Image(systemName: "leaf")
                        Text("文字留在本机，故事随时继续。")
                    }.font(.caption).foregroundStyle(Color.mutedInk).frame(maxWidth: .infinity).padding(.top, 6)
                    if let notice { Text(notice).font(.footnote).foregroundStyle(Color.ink).frame(maxWidth: .infinity) }
                }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 32)
            }
            .background(Color.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .text, UTType(filenameExtension: "markdown") ?? .text], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    let count = library.importBooks(urls)
                    notice = count > 0 ? "已添加 \(count) 本小说" : "这些小说已经在书架中"
                case .failure(let error): library.errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(item: $selectedBook) { book in ReaderView(book: book).environmentObject(library) }
            .confirmationDialog("从书架删除《\(deleting?.title ?? "")》？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("删除小说和阅读记录", role: .destructive) { if let book = deleting { library.remove(book) }; deleting = nil }
                Button("取消", role: .cancel) { deleting = nil }
            } message: { Text("原始文件不会受影响，可以重新导入。") }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text("INK / READER").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(3).foregroundStyle(Color.mutedInk)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("墨卷").font(.system(size: 36, weight: .medium, design: .serif)).tracking(3).foregroundStyle(Color.ink)
                    Text("把时间，留给故事").font(.caption).foregroundStyle(Color.mutedInk)
                }
            }
            Spacer(minLength: 8)
            Button { importing = true } label: {
                Image(systemName: "plus").font(.system(size: 20, weight: .medium)).frame(width: 46, height: 46).background(Color.ink, in: Circle()).foregroundStyle(.white)
            }.accessibilityLabel("导入小说").accessibilityIdentifier("importBook")
        }
    }

    private func continueCard(_ book: LibraryBook) -> some View {
        let p = library.position(for: book)
        let chapterTitle = (try? library.novel(for: book))?.chapters[safe: p.chapter]?.title ?? "从第一章开始"
        return Button { open(book) } label: {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label(library.positions[book.id] == nil ? "为你展开的故事" : "上次读到这里", systemImage: "bookmark").font(.caption).tracking(1)
                    Spacer()
                    Text("本地书库").font(.system(size: 10)).padding(.horizontal, 9).padding(.vertical, 5).overlay(Capsule().stroke(.white.opacity(0.25)))
                }.foregroundStyle(Color(hex: "D6DFCD"))
                HStack(alignment: .center, spacing: 18) {
                    BookCover(book: book, large: true).frame(width: 88, height: 123).rotationEffect(.degrees(-4)).shadow(color: .black.opacity(0.2), radius: 12, x: 2, y: 8)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(book.title).font(.system(size: 23, weight: .medium, design: .serif)).foregroundStyle(.white).multilineTextAlignment(.leading)
                        Text("\(book.chapterCount) 章 · \(wordCount(book.characterCount))字").font(.caption).foregroundStyle(Color(hex: "D6DFCD"))
                        Text(chapterTitle).font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(library.positions[book.id] == nil ? "开始阅读" : "继续阅读").font(.subheadline.weight(.medium))
                    Image(systemName: "arrow.right").font(.subheadline)
                    Spacer()
                    Text("\(Int(library.progress(for: book) * 100))% ").font(.system(.caption, design: .monospaced))
                }.foregroundStyle(.white)
                ProgressView(value: library.progress(for: book)).tint(Color(hex: "DAC79A")).background(.white.opacity(0.12)).padding(.top, -14)
            }
            .padding(24)
            .background {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(colors: [Color(hex: "2A493B"), Color(hex: "1B332A")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "leaf").font(.system(size: 175, weight: .ultraLight)).rotationEffect(.degrees(-30)).foregroundStyle(.white.opacity(0.035)).offset(x: 35, y: -15)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain).accessibilityIdentifier("continueReading")
    }

    private func bookRow(_ book: LibraryBook) -> some View {
        Button { open(book) } label: {
            HStack(spacing: 18) {
                BookCover(book: book, large: false).frame(width: 66, height: 92)
                VStack(alignment: .leading, spacing: 9) {
                    Text(book.title).font(.system(size: 18, weight: .medium, design: .serif)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                    Text("\(book.chapterCount) 章  /  \(wordCount(book.characterCount))字").font(.caption).foregroundStyle(Color.mutedInk)
                    Text(library.positions[book.id] == nil ? "尚未开始 · 点击展开" : "已读 \(Int(library.progress(for: book) * 100))% · 第 \(library.position(for: book).chapter + 1) 章").font(.caption2).foregroundStyle(Color.mutedInk)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.mutedInk.opacity(0.6))
            }.padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contextMenu { if !book.isBundled { Button("删除小说", systemImage: "trash", role: .destructive) { deleting = book } } }
        .accessibilityIdentifier("book-\(book.title)")
    }

    private func open(_ book: LibraryBook) { library.open(book); selectedBook = book }
    private func wordCount(_ count: Int) -> String { count >= 10000 ? String(format: "%.1f 万", Double(count) / 10000) : "\(count) " }
}

struct BookCover: View {
    let book: LibraryBook
    let large: Bool
    private var shortTitle: String {
        let parts = book.title.components(separatedBy: "·")
        return parts.last ?? book.title
    }
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "EAE1C8"), Color(hex: "D4CAA9")], startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(spacing: 0) {
                Rectangle().fill(Color.ink.opacity(0.15)).frame(width: 5)
                Spacer()
            }
            VStack(spacing: large ? 10 : 7) {
                Rectangle().fill(Color.ink.opacity(0.3)).frame(width: 22, height: 1)
                Text(shortTitle.prefix(8).map(String.init).joined(separator: "\n"))
                    .font(.system(size: large ? 18 : 13, weight: .medium, design: .serif)).lineSpacing(large ? 2 : 1).foregroundStyle(Color.ink).lineLimit(5)
                Image(systemName: "leaf").font(.system(size: large ? 13 : 10, weight: .light)).foregroundStyle(Color.ink.opacity(0.6))
            }.padding(.vertical, 8)
        }.clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 7, topTrailingRadius: 7))
            .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.4)).frame(width: 2).padding(.vertical, 5).padding(.trailing, 3) }
            .accessibilityHidden(true)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
