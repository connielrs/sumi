import SwiftUI
import WebKit
import Markdown

/// Muestra el Markdown ya formateado, listo para leer.
struct ReaderView: NSViewRepresentable {
    let markdown: String
    let palette: Palette
    let fontFamily: String
    let fontSize: Double
    let column: Int
    let baseURL: URL?
    /// Clave para recordar hasta dónde se leyó (la ruta del archivo).
    var positionKey: String? = nil
    var rememberPosition: Bool = false
    var jump: JumpRequest? = nil
    var onCurrentHeading: (Int) -> Void = { _ in }

    /// Posiciones de esta sesión, para no perder el lugar al pasar a editar y volver.
    static var sessionPositions: [String: Double] = [:]
    static let savedPositionsKey = "posicionesDeLectura"

    var cssVars: String {
        "--bg:\(palette.bg);--line:\(palette.line);--text:\(palette.text);--muted:\(palette.muted);"
            + "--faint:\(palette.faint);--accent:\(palette.accent);--code:\(palette.code);--sel:\(palette.sel);"
            + "--fam:\(fontFamily);--size:\(fontSize)px;--col:\(column)px"
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "sumi")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        context.coordinator.webView = webView
        webView.loadHTMLString(ReaderTemplate.html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply()
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sumi")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ReaderView
        weak var webView: WKWebView?
        private var loaded = false
        private var lastVars: String?
        private var lastMarkdown: String?
        private var lastJump: UUID?
        private var restored = false

        init(parent: ReaderView) { self.parent = parent }

        func apply() {
            guard loaded, let webView else { return }
            let vars = parent.cssVars
            if vars != lastVars {
                lastVars = vars
                webView.evaluateJavaScript("setVars(\(Self.js(vars)))")
            }
            if parent.markdown != lastMarkdown {
                lastMarkdown = parent.markdown
                let html = HTMLFormatter.format(parent.markdown)
                webView.evaluateJavaScript("setDoc(\(Self.js(html)))")
                if !restored {
                    restored = true
                    if let fraction = savedPosition(), fraction > 0 {
                        webView.evaluateJavaScript("restore(\(fraction))")
                    }
                }
            }
            if let jump = parent.jump, jump.id != lastJump {
                lastJump = jump.id
                webView.evaluateJavaScript("jumpTo(\(jump.index))")
            }
        }

        private func savedPosition() -> Double? {
            guard let key = parent.positionKey else { return nil }
            if let value = ReaderView.sessionPositions[key] { return value }
            guard parent.rememberPosition else { return nil }
            let saved = UserDefaults.standard.dictionary(forKey: ReaderView.savedPositionsKey) as? [String: Double]
            return saved?[key]
        }

        private func store(position: Double) {
            guard let key = parent.positionKey else { return }
            ReaderView.sessionPositions[key] = position
            guard parent.rememberPosition else { return }
            var saved = UserDefaults.standard.dictionary(forKey: ReaderView.savedPositionsKey) as? [String: Double] ?? [:]
            saved[key] = position
            if saved.count > 300 { saved = Dictionary(uniqueKeysWithValues: saved.suffix(200).map { ($0.key, $0.value) }) }
            UserDefaults.standard.set(saved, forKey: ReaderView.savedPositionsKey)
        }

        static func js(_ value: String) -> String {
            let data = (try? JSONEncoder().encode(value)) ?? Data("\"\"".utf8)
            return String(decoding: data, as: UTF8.self)
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            apply()
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            if url.isFileURL, ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased()) {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            } else if url.scheme != "about" {
                NSWorkspace.shared.open(url)
            }
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            if let fraction = body["frac"] as? Double { store(position: fraction) }
            if let current = body["current"] as? Int { parent.onCurrentHeading(current) }
        }
    }
}

enum ReaderTemplate {
    static let html = """
    <!doctype html>
    <html><head><meta charset="utf-8">
    <style>
    :root{color-scheme:light dark}
    html,body{margin:0;background:transparent}
    body{color:var(--text);-webkit-font-smoothing:antialiased}
    #doc{max-width:var(--col);margin:0 auto;padding:56px 40px 140px;font-family:var(--fam);font-size:var(--size);line-height:1.65}
    #doc>*:first-child{margin-top:0}
    h1{font-size:2em;line-height:1.2;margin:0 0 .45em;font-weight:650;letter-spacing:-.02em}
    h2{font-size:1.35em;line-height:1.3;margin:1.7em 0 .45em;font-weight:650;letter-spacing:-.01em}
    h3{font-size:1.12em;margin:1.5em 0 .4em;font-weight:650}
    h4,h5,h6{font-size:1em;margin:1.4em 0 .4em;font-weight:650}
    p{margin:0 0 1em}
    a{color:var(--accent);text-decoration:none}
    a:hover{text-decoration:underline}
    ul,ol{margin:0 0 1em;padding-left:1.4em}
    li{margin:.2em 0}
    li>p{margin:0}
    li:has(> input[type=checkbox]){list-style:none;margin-left:-1.4em}
    input[type=checkbox]{accent-color:var(--accent);margin:0 .55em 0 0;transform:translateY(1px)}
    blockquote{margin:0 0 1em;padding:.05em 0 .05em 1em;border-left:2px solid var(--line);color:var(--muted)}
    blockquote p:last-child{margin-bottom:0}
    code{font-family:ui-monospace,'SF Mono',Menlo,monospace;font-size:.86em;background:var(--code);padding:.12em .38em;border-radius:5px}
    pre{background:var(--code);padding:14px 16px;border-radius:10px;overflow-x:auto;margin:0 0 1em;line-height:1.5}
    pre code{background:none;padding:0;font-size:.84em}
    table{border-collapse:collapse;font-size:.92em;margin:0 0 1em;display:block;overflow-x:auto}
    th,td{text-align:left;padding:.45em 1.2em .45em 0;border-bottom:1px solid var(--line);vertical-align:top}
    th{font-weight:600;color:var(--muted);font-size:.88em}
    hr{border:0;border-top:1px solid var(--line);margin:2em 0}
    img{max-width:100%;border-radius:6px}
    .vacio{color:var(--faint)}
    ::selection{background:var(--sel)}
    ::-webkit-scrollbar{width:10px}
    ::-webkit-scrollbar-thumb{background:var(--line);border-radius:5px;border:3px solid transparent;background-clip:content-box}
    </style></head>
    <body><article id="doc"></article>
    <script>
    function setVars(v){document.documentElement.setAttribute('style',v)}
    function heads(){return [...document.querySelectorAll('#doc h1,#doc h2,#doc h3,#doc h4,#doc h5,#doc h6')]}
    function setDoc(h){
      const d=document.getElementById('doc');
      d.innerHTML=h.trim()?h:'<p class="vacio">Este documento está vacío. Presiona ⌘E para escribir.</p>';
      heads().forEach((e,i)=>e.id='h-'+i);
      report();
    }
    function jumpTo(i){
      const e=document.getElementById('h-'+i);
      if(e) window.scrollTo({top:e.getBoundingClientRect().top+window.scrollY-28,behavior:'smooth'});
    }
    function restore(f){
      requestAnimationFrame(()=>{const m=document.documentElement.scrollHeight-innerHeight;if(m>0)window.scrollTo(0,f*m)});
    }
    function report(){
      let cur=0;
      heads().forEach((e,i)=>{if(e.getBoundingClientRect().top<120)cur=i});
      const m=document.documentElement.scrollHeight-innerHeight;
      window.webkit.messageHandlers.sumi.postMessage({frac:m>0?window.scrollY/m:0,current:cur});
    }
    let t;addEventListener('scroll',()=>{clearTimeout(t);t=setTimeout(report,80)});
    </script></body></html>
    """
}
