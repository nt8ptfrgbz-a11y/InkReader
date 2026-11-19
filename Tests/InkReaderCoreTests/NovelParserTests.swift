import XCTest
@testable import InkReaderCore

final class NovelParserTests: XCTestCase {
    func testBundledNovelHasExactlyFiftyChaptersWithoutTOC() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent("InkReader/Resources/诛仙同人·长相守.md"), encoding: .utf8)
        let novel = NovelParser.parse(text, fallbackTitle: "fallback")
        XCTAssertEqual(novel.title, "诛仙同人·长相守")
        XCTAssertEqual(novel.chapters.count, 50)
        XCTAssertEqual(novel.chapters.first?.title, "第01章 铃声未歇")
        XCTAssertEqual(novel.chapters.last?.title, "第50章 此后皆春")
        XCTAssertTrue(novel.chapters[0].markdown.hasPrefix("刀尖刚抵上旧伤"))
        XCTAssertGreaterThan(novel.characterCount, 150000)
        XCTAssertFalse(novel.chapters.contains(where: { $0.title == "目录" }))
    }

    func testPlainTextChineseChaptersAndWindowsLineEndings() {
        let novel = NovelParser.parse("\u{FEFF}第一章 开端\r\n正文甲\r\n\r\n第二章 风起\r\n正文乙", fallbackTitle: "测试小说")
        XCTAssertEqual(novel.title, "测试小说")
        XCTAssertEqual(novel.chapters.map(\.title), ["第一章 开端", "第二章 风起"])
        XCTAssertEqual(novel.chapters[1].markdown, "正文乙")
    }

    func testFrontMatterAndCodeFenceDoNotBecomeChapters() {
        let text = "---\ntitle: meta\n---\n# 我的书\n## 第一章 开始\n```md\n## 第二章 伪标题\n```\n正文\n## 第二章 结束\n结尾"
        let novel = NovelParser.parse(text, fallbackTitle: "fallback")
        XCTAssertEqual(novel.chapters.count, 2)
        XCTAssertTrue(novel.chapters[0].markdown.contains("伪标题"))
    }

    func testGenericMarkdownKeepsPrefaceAndNestedHeadings() {
        let novel = NovelParser.parse("# 旅途\n引言内容\n## 清晨\n天亮了\n### 一个小节\n出发\n## 黄昏\n回家", fallbackTitle: "fallback")
        XCTAssertEqual(novel.chapters.map(\.title), ["前言", "清晨", "黄昏"])
        XCTAssertTrue(novel.chapters[1].markdown.contains("### 一个小节"))
    }

    func testNoHeadingsKeepsAllText() {
        let novel = NovelParser.parse("一段正文。\n\n另一段正文。", fallbackTitle: "短篇")
        XCTAssertEqual(novel.chapters.count, 1)
        XCTAssertEqual(novel.chapters[0].title, "正文")
        XCTAssertEqual(novel.chapters[0].markdown, "一段正文。\n\n另一段正文。")
    }

    func testEnglishAndFullWidthChapterNumbers() {
        XCTAssertEqual(NovelParser.parse("# Book\n## Chapter 1: A\none\n## Chapter 2: B\ntwo", fallbackTitle: "Book").chapters.count, 2)
        XCTAssertEqual(NovelParser.parse("第０１章 春\n花开\n第０２章 夏\n雨落", fallbackTitle: "四季").chapters.count, 2)
    }

    func testRendererEscapesHTMLAndDisallowsActiveLinks() {
        let result = MarkdownRenderer.render("<script>alert('x')</script>\n\n[链接](https://example.com) **重点**")
        XCTAssertFalse(result.contains("<script>"))
        XCTAssertFalse(result.contains("href="))
        XCTAssertTrue(result.contains("&lt;script&gt;"))
        XCTAssertTrue(result.contains("<strong>重点</strong>"))
    }

    func testRendererHasNoExtraneousPunctuationAndProtectsCode() {
        XCTAssertEqual(MarkdownRenderer.render("正文。\n\n- 项目"), "<p>正文。</p>\n<ul>\n<li>项目</li>\n</ul>")
        XCTAssertEqual(MarkdownRenderer.inline("`**literal**`"), "<code>**literal**</code>")
        XCTAssertTrue(MarkdownRenderer.render("```\n<a>\n```").contains("&lt;a&gt;"))
    }
}
