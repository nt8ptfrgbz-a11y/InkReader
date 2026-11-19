import SwiftUI
import WebKit

struct ChapterWebView: UIViewRepresentable {
    let chapter: NovelChapter
    let bookID: String
    let chapterCount: Int
    let fraction: Double
    let jumpID: UUID
    let settings: ReaderSettings
    let searchTerm: String
    var onProgress: (Int, Double) -> Void
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "reader")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.accessibilityIdentifier = "chapterContent"
        webView.allowsLinkPreview = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        webView.backgroundColor = UIColor(settings.theme.background)
        webView.scrollView.backgroundColor = UIColor(settings.theme.background)
        let key = "\(bookID)-\(chapter.id)-\(jumpID)"
        if context.coordinator.key != key {
            context.coordinator.key = key
            context.coordinator.ready = false
            context.coordinator.lastSettings = settings
            webView.loadHTMLString(document(key: key), baseURL: nil)
        } else if context.coordinator.lastSettings != settings {
            context.coordinator.lastSettings = settings
            webView.evaluateJavaScript("window.applySettings(\(settingsJSON));")
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.report(webView.scrollView, force: true)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "reader")
        webView.scrollView.delegate = nil
    }

    private var settingsJSON: String {
        json(["size": settings.fontSize, "height": settings.lineHeight, "bg": "#\(settings.theme.backgroundHex)", "fg": "#\(settings.theme.textHex)", "font": settings.serif ? "'Songti SC','STSong','Noto Serif CJK SC',serif" : "-apple-system,BlinkMacSystemFont,sans-serif"])
    }

    private func json(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]), let text = String(data: data, encoding: .utf8) else { return "null" }
        return text.replacingOccurrences(of: "</", with: "<\\/")
    }

    private func document(key: String) -> String {
        """
        <!doctype html><html lang="zh-CN"><head>
        <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <style>
        :root{--bg:#\(settings.theme.backgroundHex);--fg:#\(settings.theme.textHex);--size:\(settings.fontSize)px;--height:\(settings.lineHeight);--font:\(settings.serif ? "'Songti SC','STSong',serif" : "-apple-system,sans-serif")}
        *{box-sizing:border-box}html{background:var(--bg);color:var(--fg);-webkit-text-size-adjust:100%;overflow-wrap:anywhere}
        body{margin:0;padding:30px 27px 44px;font-family:var(--font);font-size:var(--size);line-height:var(--height);font-weight:400}
        main{max-width:720px;margin:0 auto}h1{font-size:1.3em;line-height:1.6;font-weight:600;letter-spacing:.04em;margin:12px 0 30px}
        .eyebrow{font-family:-apple-system,sans-serif;font-size:10px;letter-spacing:.22em;opacity:.45;margin-bottom:12px}
        p{margin:0 0 1.05em;text-align:justify;text-indent:2em;white-space:pre-line}h2,h3,h4,h5,h6{font-size:1.1em;margin:1.6em 0 .8em}
        blockquote{margin:1em 0;padding:.2em 1em;border-left:2px solid;opacity:.75;font-size:.94em}hr{border:0;text-align:center;margin:2em 0}hr:after{content:'·　·　·';opacity:.4}
        ul,ol{padding-left:1.5em}li{margin-bottom:.5em}code{font-family:ui-monospace,monospace;font-size:.82em}pre{white-space:pre-wrap;padding:16px;background:rgba(128,128,128,.08);border-radius:8px}
        .end{font-family:-apple-system,sans-serif;text-align:center;font-size:12px;letter-spacing:.15em;opacity:.4;margin:40px 0 10px}
        mark{background:#DAC79A99;color:inherit;border-radius:3px}::selection{background:#C9BA8D80}
        </style></head><body><main>
        <div class="eyebrow">CHAPTER \(String(format: "%02d", chapter.id + 1)) / \(String(format: "%02d", chapterCount))</div>
        <h1>\(MarkdownRenderer.escape(chapter.title))</h1>
        \(MarkdownRenderer.render(chapter.markdown))
        <div class="end">\(chapter.id + 1 == chapterCount ? "全 书 完 · 感 谢 相 伴" : "本 章 完")</div>
        </main><script>
        const key=\(json(key));
        const send=(type)=>window.webkit.messageHandlers.reader.postMessage({type,key});
        const ratio=()=>scrollY/Math.max(1,document.documentElement.scrollHeight-innerHeight);
        window.applySettings=(s)=>{let p=ratio();let r=document.documentElement.style;r.setProperty('--bg',s.bg);r.setProperty('--fg',s.fg);r.setProperty('--size',s.size+'px');r.setProperty('--height',s.height);r.setProperty('--font',s.font);requestAnimationFrame(()=>scrollTo(0,p*Math.max(0,document.documentElement.scrollHeight-innerHeight)));};
        const term=\(json(searchTerm));
        if(term){const walker=document.createTreeWalker(document.querySelector('main'),NodeFilter.SHOW_TEXT);let nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);for(const node of nodes){let t=node.textContent;let start=0;let found=t.toLocaleLowerCase().indexOf(term.toLocaleLowerCase());if(found<0)continue;let frag=document.createDocumentFragment();while(found>=0){frag.append(t.slice(start,found));let mark=document.createElement('mark');mark.textContent=t.slice(found,found+term.length);frag.append(mark);start=found+term.length;found=t.toLocaleLowerCase().indexOf(term.toLocaleLowerCase(),start);}frag.append(t.slice(start));node.replaceWith(frag);}}
        requestAnimationFrame(()=>requestAnimationFrame(()=>{scrollTo(0,\(min(max(fraction, 0), 1))*Math.max(0,document.documentElement.scrollHeight-innerHeight));if(term)document.querySelector('mark')?.scrollIntoView({block:'center'});send('ready');}));
        document.addEventListener('click',()=>{if(!getSelection().toString())send('tap');});
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIScrollViewDelegate {
        var parent: ChapterWebView
        var key = ""
        var ready = false
        var lastSettings: ReaderSettings?
        private var lastReport: TimeInterval = 0
        init(_ parent: ChapterWebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let value = message.body as? [String: String], value["key"] == key else { return }
            if value["type"] == "ready" { ready = true; if let web = message.webView { report(web.scrollView, force: true) } }
            if value["type"] == "tap" { parent.onTap() }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) { report(scrollView, force: false) }
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { report(scrollView, force: true) }
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { report(scrollView, force: true) } }

        func report(_ scrollView: UIScrollView, force: Bool) {
            guard ready, force || Date.timeIntervalSinceReferenceDate - lastReport > 0.2 else { return }
            lastReport = Date.timeIntervalSinceReferenceDate
            let distance = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let fraction = distance > 0 ? min(max(0, scrollView.contentOffset.y / distance), 1) : 1
            let chapter = parent.chapter.id
            let callback = parent.onProgress
            DispatchQueue.main.async { callback(chapter, fraction) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.navigationType == .linkActivated ? .cancel : .allow)
        }
    }
}
