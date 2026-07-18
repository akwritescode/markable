import Foundation

enum HTMLTemplate {
    /// The full preview page with all JS libraries inlined. Loaded once per
    /// window; content updates go through renderMarkdown() instead of reloads.
    static let page: String = {
        let js = [
            "markdown-it.min",
            "markdown-it-footnote.min",
            "markdown-it-task-lists.min",
            "highlight.min",
            "mermaid.min",
            "bootstrap",
        ]
        .map { resource(named: $0, ext: "js") }
        .joined(separator: "\n</script>\n<script>\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style id="hljs-light-style">\(resource(named: "hljs-github.min", ext: "css"))</style>
        <style id="hljs-dark-style" media="not all">\(resource(named: "hljs-github-dark.min", ext: "css"))</style>
        <style>
        \(css)
        </style>
        <style>
        \(themeCSS)
        </style>
        <style id="custom-css"></style>
        </head>
        <body>
        <div id="content"></div>
        <script>
        \(js)
        </script>
        </body>
        </html>
        """
    }()

    private static func resource(named name: String, ext: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("Missing bundled resource \(name).\(ext)")
            return ""
        }
        return contents
    }

    private static let css = """
        :root {
            color-scheme: light dark;
            --fg: #1f2328;
            --fg-muted: #59636e;
            --border: #d1d9e0;
            --border-muted: #d1d9e0b3;
            --accent: #0969da;
            --code-bg: #818b981f;
            --pre-bg: #f6f8fa;
            --quote-border: #d1d9e0;
            --table-stripe: #f6f8fa;
            --mark-bg: #fff8c5;
            --error: #d1242f;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --fg: #f0f6fc;
                --fg-muted: #9198a1;
                --border: #3d444d;
                --border-muted: #3d444db3;
                --accent: #4493f8;
                --code-bg: #656c7633;
                --pre-bg: #151b23;
                --quote-border: #3d444d;
                --table-stripe: #151b23;
                --mark-bg: #bb800926;
                --error: #f85149;
            }
        }
        :root {
            --page-bg: transparent;
            --font-body: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        }
        * { box-sizing: border-box; }
        html, body { background: var(--page-bg); }
        body {
            font-family: var(--font-body);
            font-size: 15px;
            line-height: 1.6;
            color: var(--fg);
            max-width: 760px;
            margin: 0 auto;
            padding: 32px 40px 64px;
            word-wrap: break-word;
            -webkit-text-size-adjust: 100%;
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.5em;
            margin-bottom: 0.6em;
            font-weight: 600;
            line-height: 1.25;
        }
        h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid var(--border-muted); }
        h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid var(--border-muted); }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: var(--fg-muted); }
        #content > h1:first-child { margin-top: 0; }
        p, ul, ol, blockquote, table, pre { margin-top: 0; margin-bottom: 16px; }
        a { color: var(--accent); text-decoration: none; }
        a:hover { text-decoration: underline; }
        ul, ol { padding-left: 2em; }
        li + li { margin-top: 0.25em; }
        li > p { margin-bottom: 8px; }
        ul.contains-task-list { padding-left: 1.2em; }
        li.task-list-item { list-style: none; }
        li.task-list-item input[type="checkbox"] { margin-right: 0.4em; }
        blockquote {
            padding: 0 1em;
            color: var(--fg-muted);
            border-left: 4px solid var(--quote-border);
            margin-left: 0;
            margin-right: 0;
        }
        code, pre {
            font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
            font-size: 85%;
        }
        code {
            background: var(--code-bg);
            padding: 0.2em 0.4em;
            border-radius: 6px;
        }
        pre {
            background: var(--pre-bg);
            padding: 16px;
            border-radius: 8px;
            overflow-x: auto;
            line-height: 1.45;
        }
        pre code, code.hljs { background: transparent; padding: 0; font-size: 100%; }
        table {
            border-collapse: collapse;
            border-spacing: 0;
            display: block;
            width: max-content;
            max-width: 100%;
            overflow-x: auto;
        }
        th, td {
            border: 1px solid var(--border);
            padding: 6px 13px;
        }
        th { font-weight: 600; }
        tbody tr:nth-child(even) { background: var(--table-stripe); }
        img { max-width: 100%; border-radius: 4px; }
        hr {
            height: 2px;
            background: var(--border-muted);
            border: 0;
            margin: 24px 0;
        }
        mark { background: var(--mark-bg); color: inherit; padding: 0.1em 0.2em; border-radius: 3px; }
        kbd {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 80%;
            padding: 2px 5px;
            border: 1px solid var(--border);
            border-bottom-width: 2px;
            border-radius: 5px;
            background: var(--pre-bg);
        }
        .mermaid { text-align: center; margin-bottom: 16px; }
        .mermaid-error {
            font-family: ui-monospace, Menlo, monospace;
            font-size: 85%;
            color: var(--error);
            background: var(--pre-bg);
            padding: 16px;
            border-radius: 8px;
            white-space: pre-wrap;
            margin-bottom: 16px;
        }
        .footnotes { font-size: 90%; color: var(--fg-muted); }
        .footnotes-sep { margin-top: 40px; }
        .footnote-ref a, a.footnote-backref { text-decoration: none; }
        ::selection { background: color-mix(in srgb, var(--accent) 30%, transparent); }
        """

    // Theme variable sets. [data-theme] attribute selectors outrank the :root
    // media-query defaults, so fixed themes hold regardless of system appearance.
    private static let themeCSS = """
        html[data-theme="github"] { --page-bg: #ffffff; }
        @media (prefers-color-scheme: dark) {
            html[data-theme="github"] { --page-bg: #0d1117; }
        }

        html[data-theme="serif"] {
            --font-body: "New York", ui-serif, Georgia, "Times New Roman", serif;
        }

        html[data-theme="sepia"] {
            --page-bg: #f4ecd8; --fg: #5b4636; --fg-muted: #8a7455;
            --border: #dcd0b4; --border-muted: #dcd0b4b3; --accent: #9a6c37;
            --code-bg: #e8dcc0; --pre-bg: #ede3ca; --quote-border: #d5c6a1;
            --table-stripe: #ede3ca; --mark-bg: #f5e1a4; --error: #b23a2f;
        }

        html[data-theme="solarized-light"] {
            --page-bg: #fdf6e3; --fg: #657b83; --fg-muted: #93a1a1;
            --border: #e6dfc8; --border-muted: #e6dfc8b3; --accent: #268bd2;
            --code-bg: #eee8d5; --pre-bg: #eee8d5; --quote-border: #d9d2bb;
            --table-stripe: #f5efdc; --mark-bg: #e8e1b8; --error: #dc322f;
        }

        html[data-theme="solarized-dark"] {
            --page-bg: #002b36; --fg: #839496; --fg-muted: #586e75;
            --border: #0e3a45; --border-muted: #0e3a45b3; --accent: #268bd2;
            --code-bg: #073642; --pre-bg: #073642; --quote-border: #1a4a56;
            --table-stripe: #05323d; --mark-bg: #26485226; --error: #dc322f;
        }

        html[data-theme="dracula"] {
            --page-bg: #282a36; --fg: #f8f8f2; --fg-muted: #9fa3bc;
            --border: #44475a; --border-muted: #44475ab3; --accent: #bd93f9;
            --code-bg: #383b4c; --pre-bg: #21222c; --quote-border: #6272a4;
            --table-stripe: #2e303e; --mark-bg: #f1fa8c33; --error: #ff5555;
        }

        html[data-theme="nord"] {
            --page-bg: #2e3440; --fg: #d8dee9; --fg-muted: #9aa5b8;
            --border: #434c5e; --border-muted: #434c5eb3; --accent: #88c0d0;
            --code-bg: #3b4252; --pre-bg: #3b4252; --quote-border: #4c566a;
            --table-stripe: #343b4a; --mark-bg: #ebcb8b33; --error: #bf616a;
        }

        html[data-theme="tokyo-night"] {
            --page-bg: #1a1b26; --fg: #a9b1d6; --fg-muted: #6b7089;
            --border: #2f334d; --border-muted: #2f334db3; --accent: #7aa2f7;
            --code-bg: #24283b; --pre-bg: #16161e; --quote-border: #414868;
            --table-stripe: #1f2233; --mark-bg: #e0af6833; --error: #f7768e;
        }

        html[data-theme="one-dark"] {
            --page-bg: #282c34; --fg: #abb2bf; --fg-muted: #7f848e;
            --border: #3e4451; --border-muted: #3e4451b3; --accent: #61afef;
            --code-bg: #31353f; --pre-bg: #21252b; --quote-border: #4b5263;
            --table-stripe: #2c313a; --mark-bg: #e5c07b33; --error: #e06c75;
        }

        html[data-theme="one-light"] {
            --page-bg: #fafafa; --fg: #383a42; --fg-muted: #696c77;
            --border: #dbdbdc; --border-muted: #dbdbdcb3; --accent: #4078f2;
            --code-bg: #ececed; --pre-bg: #f0f0f1; --quote-border: #d3d4d5;
            --table-stripe: #f2f2f3; --mark-bg: #f2df9f; --error: #ca1243;
        }

        html[data-theme="terminal"] {
            --page-bg: #0a0f0a; --fg: #4af626; --fg-muted: #2f9e1d;
            --border: #1d3a1d; --border-muted: #1d3a1db3; --accent: #6dff9c;
            --code-bg: #10240f; --pre-bg: #0e1c0d; --quote-border: #245c1e;
            --table-stripe: #0d180c; --mark-bg: #4af62626; --error: #ff5f56;
            --font-body: ui-monospace, "SF Mono", Menlo, monospace;
        }
        """
}
