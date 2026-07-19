import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let baseURL: URL?
    var fileID: URL?
    var find: FindState
    var theme: Theme = .system
    var customCSS: String = ""
    var zoom: Double = 1.0

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(LocalFileSchemeHandler(), forURLScheme: LocalFileSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.pageZoom = zoom

        find.webView = webView
        loadTemplate(in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        find.webView = webView

        if webView.pageZoom != zoom {
            webView.pageZoom = zoom
        }

        // Base URL changed (different folder): reload the template so relative
        // images resolve against the new file's directory.
        if coordinator.loadedBaseURL != baseURL {
            loadTemplate(in: webView, coordinator: coordinator)
            return
        }

        guard coordinator.isTemplateLoaded else {
            coordinator.fileID = fileID
            coordinator.lastMarkdown = markdown
            coordinator.pendingMarkdown = markdown
            coordinator.theme = theme
            coordinator.customCSS = customCSS
            return
        }

        if coordinator.theme != theme {
            coordinator.theme = theme
            coordinator.applyTheme(theme, in: webView)
        }
        if coordinator.customCSS != customCSS {
            coordinator.customCSS = customCSS
            coordinator.applyCustomCSS(customCSS, in: webView)
        }

        let fileChanged = coordinator.fileID != fileID
        guard fileChanged || markdown != coordinator.lastMarkdown else { return }
        coordinator.fileID = fileID
        coordinator.lastMarkdown = markdown
        coordinator.render(markdown, in: webView, resetScroll: fileChanged)
    }

    private func loadTemplate(in webView: WKWebView, coordinator: Coordinator) {
        coordinator.isTemplateLoaded = false
        coordinator.loadedBaseURL = baseURL
        coordinator.fileID = fileID
        coordinator.lastMarkdown = markdown
        coordinator.pendingMarkdown = markdown
        coordinator.theme = theme
        coordinator.customCSS = customCSS
        let resolvedBaseURL = baseURL.flatMap(LocalFileSchemeHandler.schemeURL(for:))
        webView.loadHTMLString(HTMLTemplate.page, baseURL: resolvedBaseURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var isTemplateLoaded = false
        var loadedBaseURL: URL?
        var fileID: URL?
        var lastMarkdown: String?
        var pendingMarkdown: String?
        var theme: Theme = .system
        var customCSS: String = ""

        func render(_ markdown: String, in webView: WKWebView, resetScroll: Bool) {
            guard let json = jsonString(markdown) else { return }
            webView.evaluateJavaScript("renderMarkdown(\(json), \(resetScroll))")
        }

        func applyTheme(_ theme: Theme, in webView: WKWebView) {
            let forced = theme.forcedAppearance.map { "\"\($0)\"" } ?? "null"
            webView.evaluateJavaScript("setTheme(\"\(theme.rawValue)\", \(forced))")
        }

        func applyCustomCSS(_ css: String, in webView: WKWebView) {
            guard let json = jsonString(css) else { return }
            webView.evaluateJavaScript("setCustomCSS(\(json))")
        }

        private func jsonString(_ string: String) -> String? {
            guard let data = try? JSONEncoder().encode(string) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isTemplateLoaded = true
            applyTheme(theme, in: webView)
            if !customCSS.isEmpty {
                applyCustomCSS(customCSS, in: webView)
            }
            if let pending = pendingMarkdown {
                pendingMarkdown = nil
                render(pending, in: webView, resetScroll: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Send web links to the default browser; keep in-page anchor jumps
            // (footnotes, heading links) inside the preview.
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               ["http", "https", "mailto"].contains(scheme) {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

/// Serves `markable-local://` requests by reading the matching path straight
/// off disk. Markable itself isn't sandboxed, so this has no more access
/// than the app already does — it just avoids WKWebView's separate,
/// unrelated restriction on reading local files loaded via `loadHTMLString`.
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "markable-local"

    /// Rewrites a `file://` directory URL to the matching `markable-local://`
    /// URL so relative resources resolve through this handler instead of
    /// hitting WKWebView's local-file read restriction.
    static func schemeURL(for fileURL: URL) -> URL? {
        guard var components = URLComponents(url: fileURL, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = scheme
        return components.url
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let fileURL = URL(fileURLWithPath: url.path)
        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        let response = URLResponse(
            url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
