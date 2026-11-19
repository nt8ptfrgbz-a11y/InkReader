import SwiftUI

struct ReaderView: View {
    let book: LibraryBook
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var novel: ParsedNovel?
    @State private var chapterIndex = 0
    @State private var fraction: Double = 0
    @State private var initialFraction: Double = 0
    @State private var jumpID = UUID()
    @State private var chromeVisible = true
    @State private var activeSheet: ReaderSheet?
    @State private var searchTerm = ""
    @State private var loadError: String?
    @State private var bookmarkNotice = false

    private var theme: ReadingTheme { library.settings.theme }
    private var chapter: NovelChapter? { novel?.chapters[safe: chapterIndex] }

    var body: some View {
        VStack(spacing: 0) {
            if chromeVisible { topBar }
            if let chapter, let novel {
                ChapterWebView(chapter: chapter, bookID: book.id, chapterCount: novel.chapters.count, fraction: initialFraction, jumpID: jumpID, settings: library.settings, searchTerm: searchTerm, onProgress: { index, value in
                    guard index == chapterIndex else { return }
                    fraction = value
                    library.updatePosition(bookID: book.id, chapter: index, fraction: value)
                }, onTap: { withAnimation(.easeInOut(duration: 0.2)) { chromeVisible.toggle() } })
            } else if let loadError {
                ContentUnavailableView("这本书暂时无法打开", systemImage: "doc.text", description: Text(loadError)).frame(maxHeight: .infinity)
            } else { ProgressView().frame(maxHeight: .infinity) }
            if chromeVisible { bottomBar }
        }
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.text)
        .statusBarHidden(!chromeVisible)
        .preferredColorScheme(theme == .night ? .dark : .light)
        .task {
            guard novel == nil else { return }
            do {
                novel = try library.novel(for: book)
                let p = library.position(for: book)
                chapterIndex = min(max(0, p.chapter), max(0, (novel?.chapters.count ?? 1) - 1))
                fraction = p.fraction; initialFraction = p.fraction
                UIApplication.shared.isIdleTimerDisabled = library.settings.keepAwake
            } catch { loadError = error.localizedDescription }
        }
        .onChange(of: library.settings.keepAwake) { _, value in UIApplication.shared.isIdleTimerDisabled = value }
        .onChange(of: scenePhase) { _, value in
            UIApplication.shared.isIdleTimerDisabled = value == .active && library.settings.keepAwake
            if value != .active { persist() }
        }
        .onDisappear { persist(); UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .contents:
                if let novel { ContentsView(book: book, novel: novel, currentChapter: chapterIndex) { index, offset in go(to: index, fraction: offset) }.environmentObject(library) }
            case .settings: ReaderSettingsView().environmentObject(library).presentationDetents([.height(460)])
            case .search:
                if let novel { NovelSearchView(novel: novel) { index, term in go(to: index, fraction: 0, term: term) } }
            }
        }
        .overlay(alignment: .top) {
            if bookmarkNotice { Label("已添加书签", systemImage: "bookmark.fill").font(.subheadline).padding(.horizontal, 20).padding(.vertical, 12).background(.regularMaterial, in: Capsule()).padding(.top, 68).allowsHitTesting(false) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { persist(); dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 19, weight: .medium)).frame(width: 36, height: 44) }.accessibilityLabel("返回书架").accessibilityIdentifier("backToLibrary")
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.system(size: 13, weight: .medium, design: .serif)).lineLimit(1)
                Text(chapter?.title ?? "墨卷").font(.system(size: 10)).opacity(0.5).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                library.addBookmark(book: book, chapter: chapterIndex, fraction: fraction, title: chapter?.title ?? "正文")
                withAnimation { bookmarkNotice = true }
                Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { bookmarkNotice = false } }
            } label: { Image(systemName: "bookmark").font(.system(size: 18)).frame(width: 38, height: 44) }.accessibilityLabel("添加书签").accessibilityIdentifier("addBookmark")
        }.padding(.horizontal, 15).padding(.top, 2).padding(.bottom, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.text.opacity(0.08)).frame(height: 0.5) }
    }

    private var bottomBar: some View {
        VStack(spacing: 13) {
            HStack {
                Button { go(to: chapterIndex - 1) } label: { Label("上一章", systemImage: "chevron.left").font(.caption) }.disabled(chapterIndex == 0).accessibilityIdentifier("previousChapter")
                Spacer()
                Text("\(chapterIndex + 1) / \(novel?.chapters.count ?? book.chapterCount)  ·  本章 \(Int(fraction * 100))%")
                    .font(.system(size: 10, design: .monospaced)).opacity(0.55).accessibilityIdentifier("readingProgress")
                Spacer()
                Button { go(to: chapterIndex + 1) } label: { HStack(spacing: 4) { Text("下一章"); Image(systemName: "chevron.right") }.font(.caption) }.disabled(chapterIndex >= (novel?.chapters.count ?? 1) - 1).accessibilityIdentifier("nextChapter")
            }
            HStack {
                readerButton("目录", icon: "list.bullet", id: "showContents") { activeSheet = .contents }
                Spacer()
                Text("轻点正文，沉浸阅读").font(.system(size: 10)).opacity(0.35)
                Spacer()
                readerButton("搜索", icon: "magnifyingglass", id: "searchNovel") { activeSheet = .search }
                readerButton("排版", icon: "textformat.size", id: "showSettings") { activeSheet = .settings }.padding(.leading, 20)
            }
        }.padding(.horizontal, 26).padding(.top, 16).padding(.bottom, 8)
            .overlay(alignment: .top) { Rectangle().fill(theme.text.opacity(0.08)).frame(height: 0.5) }
    }

    private func readerButton(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 5) { Image(systemName: icon).font(.system(size: 18)); Text(title).font(.system(size: 9)) }.frame(minWidth: 32, minHeight: 44) }.accessibilityLabel(title).accessibilityIdentifier(id)
    }

    private func go(to index: Int, fraction offset: Double = 0, term: String = "") {
        guard let novel, novel.chapters.indices.contains(index) else { return }
        chapterIndex = index; fraction = offset; initialFraction = offset; searchTerm = term; jumpID = UUID()
        library.updatePosition(bookID: book.id, chapter: index, fraction: offset)
        library.saveNow()
    }

    private func persist() { library.updatePosition(bookID: book.id, chapter: chapterIndex, fraction: fraction); library.saveNow() }
}

enum ReaderSheet: String, Identifiable { case contents, settings, search; var id: String { rawValue } }
