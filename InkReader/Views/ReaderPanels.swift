import SwiftUI

struct ContentsView: View {
    let book: LibraryBook
    let novel: ParsedNovel
    let currentChapter: Int
    var onSelect: (Int, Double) -> Void
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var section = 0
    @State private var query = ""

    private var bookmarks: [ReadingBookmark] { library.bookmarks.filter { $0.bookID == book.id }.sorted { $0.createdAt > $1.createdAt } }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("查看", selection: $section) { Text("章节 · \(novel.chapters.count)").tag(0); Text("书签 · \(bookmarks.count)").tag(1) }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.bottom, 12)
                if section == 0 {
                    ScrollViewReader { proxy in
                        List(novel.chapters.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { chapter in
                            Button {
                                onSelect(chapter.id, 0); dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Text(String(format: "%02d", chapter.id + 1)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.mutedInk).frame(width: 26)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(chapter.title).font(.system(size: 16, weight: currentChapter == chapter.id ? .semibold : .regular, design: .serif)).foregroundStyle(Color.ink)
                                        Text("约 \(chapter.characterCount) 字").font(.caption2).foregroundStyle(Color.mutedInk)
                                    }
                                    Spacer()
                                    if currentChapter == chapter.id { Image(systemName: "waveform").font(.caption).foregroundStyle(Color.ink).accessibilityLabel("正在阅读") }
                                }.padding(.vertical, 6)
                            }.id(chapter.id).accessibilityIdentifier("chapter-\(chapter.id)")
                        }
                        .listStyle(.plain)
                        .searchable(text: $query, prompt: "查找章节")
                        .onAppear { proxy.scrollTo(currentChapter, anchor: .center) }
                    }
                } else if bookmarks.isEmpty {
                    ContentUnavailableView("留住喜欢的段落", systemImage: "bookmark", description: Text("阅读时点击右上角的书签，即可标记当前位置。"))
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button { onSelect(bookmark.chapter, bookmark.fraction); dismiss() } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(bookmark.title).font(.system(.body, design: .serif)).foregroundStyle(Color.ink)
                                    Text("本章 \(Int(bookmark.fraction * 100))% · \(bookmark.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Color.mutedInk)
                                }.padding(.vertical, 5)
                            }.swipeActions { Button("删除", role: .destructive) { library.removeBookmark(bookmark) } }
                        }
                    }.listStyle(.plain)
                }
            }
            .navigationTitle("目录与书签").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.accessibilityIdentifier("closeContents") } }
            .background(Color.canvas)
        }.tint(.ink).preferredColorScheme(.light)
    }
}

struct ReaderSettingsView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    ForEach(ReadingTheme.allCases, id: \.self) { theme in
                        Button { library.settings.theme = theme } label: {
                            VStack(spacing: 8) {
                                Text("读").font(.system(size: 25, design: .serif))
                                Text(theme.title).font(.caption)
                            }
                            .frame(maxWidth: .infinity).frame(height: 78)
                            .foregroundStyle(theme.text).background(theme.background, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(library.settings.theme == theme ? Color.ink : Color.ink.opacity(0.1), lineWidth: library.settings.theme == theme ? 2 : 1))
                        }.accessibilityIdentifier("theme-\(theme.rawValue)")
                    }
                }
                HStack(spacing: 18) {
                    Text("字号").font(.subheadline).frame(width: 34)
                    Image(systemName: "textformat.size.smaller").font(.caption)
                    Slider(value: $library.settings.fontSize, in: 16...32, step: 1).accessibilityIdentifier("fontSize")
                    Image(systemName: "textformat.size.larger").font(.subheadline)
                    Text("\(Int(library.settings.fontSize))").font(.system(.caption, design: .monospaced)).frame(width: 22)
                }
                HStack(spacing: 18) {
                    Text("行距").font(.subheadline).frame(width: 34)
                    Picker("行距", selection: $library.settings.lineHeight) { Text("紧凑").tag(1.6); Text("舒适").tag(1.95); Text("宽松").tag(2.3) }.pickerStyle(.segmented)
                }
                HStack {
                    Text("字体").font(.subheadline).frame(width: 34)
                    Spacer()
                    Picker("字体", selection: $library.settings.serif) { Text("宋体").tag(true); Text("黑体").tag(false) }.pickerStyle(.segmented).frame(width: 220)
                }
                Toggle("阅读时保持屏幕常亮", isOn: $library.settings.keepAwake).font(.subheadline)
            }
            .padding(24)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("阅读排版").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { library.saveNow(); dismiss() }.accessibilityIdentifier("closeSettings") } }
        }.tint(.ink).preferredColorScheme(.light)
    }
}

private struct SearchHit: Identifiable {
    let chapter: Int
    let title: String
    let snippet: String
    var id: Int { chapter }
}

struct NovelSearchView: View {
    let novel: ParsedNovel
    var onSelect: (Int, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var hits: [SearchHit] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView("寻找故事中的一句话", systemImage: "text.magnifyingglass", description: Text("输入人名或关键词，搜索本书全部章节。"))
                } else if searching { ProgressView("正在查找…") }
                else if hits.isEmpty { ContentUnavailableView.search(text: query) }
                else {
                    List(hits) { hit in
                        Button { onSelect(hit.chapter, query.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(hit.title).font(.system(.body, design: .serif)).foregroundStyle(Color.ink)
                                Text(hit.snippet).font(.subheadline).foregroundStyle(Color.mutedInk).lineLimit(3)
                            }.padding(.vertical, 7)
                        }.accessibilityIdentifier("searchResult-\(hit.chapter)")
                    }.listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("搜索全书").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "人名、情节或一句话")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .task(id: query) {
                let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !term.isEmpty else { hits = []; searching = false; return }
                searching = true
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                let chapters = novel.chapters
                let result = await Task.detached(priority: .userInitiated) {
                    chapters.compactMap { chapter -> SearchHit? in
                        let text = chapter.markdown
                        if let range = text.range(of: term, options: .caseInsensitive) {
                            let start = text.index(range.lowerBound, offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
                            let end = text.index(range.upperBound, offsetBy: 65, limitedBy: text.endIndex) ?? text.endIndex
                            return SearchHit(chapter: chapter.id, title: chapter.title, snippet: (start == text.startIndex ? "" : "…") + text[start..<end].replacingOccurrences(of: "\n", with: " ") + "…")
                        }
                        if chapter.title.localizedCaseInsensitiveContains(term) { return SearchHit(chapter: chapter.id, title: chapter.title, snippet: String(text.prefix(85))) }
                        return nil
                    }
                }.value
                guard !Task.isCancelled else { return }
                hits = result; searching = false
            }
        }.tint(.ink).preferredColorScheme(.light)
    }
}
