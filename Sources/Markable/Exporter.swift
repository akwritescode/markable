import AppKit
import WebKit
import UniformTypeIdentifiers

/// Exports the current document by rendering it in an offscreen web view —
/// independent of the visible mode, so it works even from edit-only mode.
@MainActor
final class Exporter {
    static let shared = Exporter()

    /// Serializes the rendered DOM minus the (multi-MB) script tags.
    private static let captureHTMLJS = """
        (function () {
            var clone = document.documentElement.cloneNode(true);
            clone.querySelectorAll("script").forEach(function (s) { s.remove(); });
            return "<!DOCTYPE html>\\n" + clone.outerHTML;
        })()
        """

    private var sessions: [ObjectIdentifier: RenderSession] = [:]

    // MARK: - Public entry points

    func exportPDF() {
        guard let destination = savePanel(type: .pdf) else { return }
        withRenderedPreview { webView, finish in
            webView.createPDF { result in
                if case .success(let data) = result {
                    try? data.write(to: destination)
                } else {
                    NSSound.beep()
                }
                finish()
            }
        }
    }

    func exportHTML() {
        guard let destination = savePanel(type: .html) else { return }
        withRenderedPreview { webView, finish in
            webView.evaluateJavaScript(Self.captureHTMLJS) { value, _ in
                if let html = value as? String {
                    try? html.write(to: destination, atomically: true, encoding: .utf8)
                }
                finish()
            }
        }
    }

    func exportWord() {
        guard let docxType = UTType(filenameExtension: "docx"),
              let destination = savePanel(type: docxType)
        else { return }
        withRenderedPreview { webView, finish in
            webView.evaluateJavaScript(Self.captureHTMLJS) { value, _ in
                defer { finish() }
                guard let html = value as? String else { return }
                let tempFile = FileManager.default.temporaryDirectory
                    .appendingPathComponent("markable-export-\(UUID().uuidString).html")
                do {
                    try html.write(to: tempFile, atomically: true, encoding: .utf8)
                    let textutil = Process()
                    textutil.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
                    textutil.arguments = [
                        "-convert", "docx", tempFile.path, "-output", destination.path,
                    ]
                    try textutil.run()
                    textutil.waitUntilExit()
                    try? FileManager.default.removeItem(at: tempFile)
                } catch {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }

    func printDocument() {
        withRenderedPreview { webView, finish in
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.topMargin = 36
            printInfo.bottomMargin = 36
            printInfo.leftMargin = 36
            printInfo.rightMargin = 36
            let operation = webView.printOperation(with: printInfo)
            operation.showsPrintPanel = true
            operation.showsProgressPanel = true
            operation.view?.frame = webView.bounds
            operation.run()
            finish()
        }
    }

    // MARK: - Offscreen rendering

    private func savePanel(type: UTType) -> URL? {
        let model = WorkspaceModel.shared
        guard let file = model.selectedFile else { return nil }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = file.deletingPathExtension().lastPathComponent
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Renders the current document offscreen, then hands the web view to
    /// `completion`; call `finish` when done with it.
    private func withRenderedPreview(
        _ completion: @escaping @MainActor (WKWebView, @escaping @MainActor () -> Void) -> Void
    ) {
        let model = WorkspaceModel.shared
        guard model.selectedFile != nil else { return }

        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 794, height: 1123),
            configuration: configuration
        )

        let key = ObjectIdentifier(webView)
        let session = RenderSession(markdown: model.text) { [weak self] webView in
            completion(webView) {
                self?.sessions[key] = nil
            }
        }
        sessions[key] = session
        webView.navigationDelegate = session
        webView.loadHTMLString(
            HTMLTemplate.page,
            baseURL: model.selectedFile?.deletingLastPathComponent()
        )
    }

    private final class RenderSession: NSObject, WKNavigationDelegate {
        private let markdown: String
        private let onReady: @MainActor (WKWebView) -> Void

        init(markdown: String, onReady: @escaping @MainActor (WKWebView) -> Void) {
            self.markdown = markdown
            self.onReady = onReady
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let theme = Theme.current(from: UserDefaults.standard.string(forKey: "theme") ?? "")
            let forced = theme.forcedAppearance.map { "\"\($0)\"" } ?? "null"
            webView.evaluateJavaScript("setTheme(\"\(theme.rawValue)\", \(forced))")

            let cssPath = UserDefaults.standard.string(forKey: "customCSSPath") ?? ""
            if !cssPath.isEmpty,
               let css = try? String(contentsOfFile: cssPath, encoding: .utf8),
               let cssJSON = jsonString(css) {
                webView.evaluateJavaScript("setCustomCSS(\(cssJSON))")
            }

            guard let json = jsonString(markdown) else { return }
            webView.evaluateJavaScript("renderMarkdown(\(json), true)")

            // Give hljs/mermaid time to finish, then size the view to the
            // full content so createPDF captures everything.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                webView.evaluateJavaScript("document.body.scrollHeight") { value, _ in
                    let height = max(value as? Double ?? 1123, 100)
                    webView.frame = NSRect(x: 0, y: 0, width: 794, height: height)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onReady(webView)
                    }
                }
            }
        }

        private func jsonString(_ string: String) -> String? {
            guard let data = try? JSONEncoder().encode(string) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }
}
