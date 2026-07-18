"use strict";

var md = window.markdownit({
    html: true,
    linkify: true,
    highlight: function (str, lang) {
        if (lang && lang !== "mermaid" && window.hljs.getLanguage(lang)) {
            try {
                return '<pre><code class="hljs language-' + lang + '">' +
                    window.hljs.highlight(str, { language: lang, ignoreIllegals: true }).value +
                    "</code></pre>";
            } catch (e) { /* fall through to default escaping */ }
        }
        return "";
    }
})
    .use(window.markdownitFootnote)
    .use(window.markdownitTaskLists);

var currentSrc = "";
var renderSeq = 0;
var themeDark = null; // null = follow system; true/false = forced by theme

function effectiveDark() {
    if (themeDark !== null) { return themeDark; }
    return window.matchMedia("(prefers-color-scheme: dark)").matches;
}

function applyHighlightStyles() {
    var light = document.getElementById("hljs-light-style");
    var dark = document.getElementById("hljs-dark-style");
    if (!light || !dark) { return; }
    light.media = effectiveDark() ? "not all" : "all";
    dark.media = effectiveDark() ? "all" : "not all";
}

function setTheme(name, forced) {
    document.documentElement.dataset.theme = name;
    themeDark = forced === "light" ? false : forced === "dark" ? true : null;
    document.documentElement.style.colorScheme = forced || "light dark";
    applyHighlightStyles();
    if (currentSrc) { renderMarkdown(currentSrc, false); } // re-render for mermaid colors
}

function setCustomCSS(css) {
    var el = document.getElementById("custom-css");
    if (el) { el.textContent = css || ""; }
}

function jumpToHeading(index) {
    var el = document.getElementById("content");
    var headings = el.querySelectorAll(
        "#content > h1, #content > h2, #content > h3, #content > h4, #content > h5, #content > h6"
    );
    if (headings[index]) {
        headings[index].scrollIntoView({ behavior: "smooth", block: "start" });
    }
}

function renderMarkdown(src, resetScroll) {
    currentSrc = src;
    var seq = ++renderSeq;
    var el = document.getElementById("content");
    el.innerHTML = md.render(src);
    if (resetScroll) { window.scrollTo(0, 0); }

    var blocks = el.querySelectorAll("pre > code.language-mermaid");
    if (blocks.length === 0) { return; }

    window.mermaid.initialize({
        startOnLoad: false,
        theme: effectiveDark() ? "dark" : "default",
        securityLevel: "loose"
    });
    blocks.forEach(function (code) {
        var div = document.createElement("div");
        div.className = "mermaid";
        div.textContent = code.textContent;
        code.parentElement.replaceWith(div);
    });
    window.mermaid.run({ nodes: el.querySelectorAll(".mermaid") }).catch(function (err) {
        // Invalid diagram source mid-keystroke is normal in split mode; only
        // surface the error if this is still the latest render.
        if (seq !== renderSeq) { return; }
        el.querySelectorAll(".mermaid:not([data-processed])").forEach(function (node) {
            node.className = "mermaid-error";
            node.textContent = String(err && err.message ? err.message : err);
        });
    });
}

// Mermaid bakes theme colors into its SVG output, so re-render on appearance change.
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function () {
    applyHighlightStyles();
    renderMarkdown(currentSrc, false);
});

applyHighlightStyles();
