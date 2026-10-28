// node tests/test_model.js
// The pure logic (Model.js, Settings.js, Art.js) and the manifest, without Qt.
const fs = require("fs"), path = require("path"), assert = require("assert");
const root = path.join(__dirname, "..");
const load = (file, names) => new Function(fs.readFileSync(path.join(root, "qml", "js", file), "utf8")
    .replace(/^\.pragma.*$/m, "") + "; return { " + names.join(", ") + " };")();

const M = load("Model.js", ["str", "safeUrl", "plain", "parseRecognition", "statusText", "historyPush", "songKey",
    "isFavourite", "toggleFavourite", "cleanSongs", "resolveColors", "normalizeSettings", "parseOmarchyTheme", "themeSlug"]);
const S = load("Settings.js", ["SCHEMA", "GROUPS", "realSettings", "defaults"]);
const A = load("Art.js", ["isCover", "nameOf", "isName", "curlArgs", "thumbArgs", "MAX_BYTES"]);

let n = 0;
const t = (name, fn) => { fn(); n++; console.log("  ok   " + name); };

t("a Shazam answer becomes a song", () => {
    const json = JSON.stringify({ track: { title: " Night  Drive ", subtitle: "The Glass Cases",
        images: { coverarthq: "https://is1-ssl.mzstatic.com/a.jpg" }, share: { href: "https://www.shazam.com/track/1" },
        sections: [{ metadata: [{ title: "Album", text: "Afterglow" }] }] } });
    assert.deepStrictEqual(M.parseRecognition(json), { title: "Night Drive", artist: "The Glass Cases", album: "Afterglow",
        cover: "https://is1-ssl.mzstatic.com/a.jpg", url: "https://www.shazam.com/track/1" });
    assert.strictEqual(M.parseRecognition("{}"), null);
    assert.strictEqual(M.parseRecognition("not json"), null);
    assert.strictEqual(M.parseRecognition(JSON.stringify({ track: { title: "" } })), null);
    assert.strictEqual(M.parseRecognition(JSON.stringify({ track: { title: "A", images: { coverart: "file:///etc/passwd" } } })).cover, "");
});

t("links are plain web addresses, text never carries markup", () => {
    assert.strictEqual(M.safeUrl("https://a.b/c"), "https://a.b/c");
    assert.strictEqual(M.safeUrl("javascript:alert(1)"), "");
    assert.strictEqual(M.safeUrl("https://a.b/\"x"), "");
    assert.strictEqual(M.plain("<b>x</b>"), "‹b›x‹/b›");
    assert.strictEqual(M.str({}), "");
    assert.strictEqual(M.str("a".repeat(300)).length, 200);
});

t("history keeps the newest first, each song once", () => {
    const a = { title: "A", artist: "x" }, b = { title: "B", artist: "y" };
    const h = M.historyPush(M.historyPush(M.historyPush([], a, 5), b, 5), a, 5);
    assert.deepStrictEqual(h.map((e) => e.title), ["A", "B"]);
    assert.strictEqual(M.historyPush(h, { title: "C", artist: "z" }, 1).length, 1);
});

t("favourites toggle, whatever the case", () => {
    let f = M.toggleFavourite([], { title: "Song", artist: "Me" });
    assert.ok(M.isFavourite(f, { title: "SONG", artist: "me" }));
    f = M.toggleFavourite(f, { title: "song", artist: "ME" });
    assert.strictEqual(f.length, 0);
});

t("songs read back from disk are cleaned", () => {
    const out = M.cleanSongs([{ title: "A", artist: "B", cover: "file:///etc/passwd", url: "javascript:x",
        at: "2026-10-28T01:02:03.000Z", extra: 1 }, null, { title: "" }, "s", { title: {} }, { title: "C", at: "soon" }], 10);
    assert.deepStrictEqual(out, [
        { title: "A", artist: "B", album: "", cover: "", url: "", at: "2026-10-28T01:02:03.000Z" },
        { title: "C", artist: "", album: "", cover: "", url: "", at: "" }]);
    assert.strictEqual(M.cleanSongs(Array(50).fill({ title: "x" }), 20).length, 20);
    assert.deepStrictEqual(M.cleanSongs({ title: "x" }, 5), []);
});

t("custom colours are used exactly as picked", () => {
    const cfg = { theme: "custom", customBackground: "#e0def4", customText: "#f8f8f2", customAccent: "#ffffff" };
    assert.deepStrictEqual(M.resolveColors(cfg, null), { background: "#e0def4", text: "#f8f8f2", accent: "#ffffff" });
    assert.strictEqual(M.resolveColors({ theme: "custom", customBackground: "nope" }, null).background, "#141414");
    assert.strictEqual(M.resolveColors({ theme: "mono" }, null).accent, "#aaaaaa");
});

t("settings are clamped to what the schema allows", () => {
    const c = M.normalizeSettings({ duration: 99, theme: "pink", notify: "false", barIcon: "<b>" }, S.SCHEMA);
    assert.strictEqual(c.duration, 20);
    assert.strictEqual(c.theme, "follow");
    assert.strictEqual(c.notify, false);
    assert.strictEqual(c.barIcon, "<b>");
    assert.strictEqual(c.customPalette, undefined);
    assert.deepStrictEqual(Object.keys(S.defaults()).sort(), S.realSettings().map((d) => d.key).sort());
    for (const d of S.SCHEMA) assert.ok(S.GROUPS.indexOf(d.group) >= 0, d.key + " is in a group");
});

t("the Omarchy theme is read from colors.toml", () => {
    const th = M.parseOmarchyTheme("@@NAME Tokyo Night\n@@FILE colors.toml\nbackground = \"#1a1b26\"\nforeground = \"#c0caf5\"\naccent = \"#7aa2f7\"\n");
    assert.deepStrictEqual([th.background, th.text, th.accent, th.name], ["#1a1b26", "#c0caf5", "#7aa2f7", "Tokyo Night"]);
    assert.strictEqual(M.parseOmarchyTheme(""), null);
    assert.strictEqual(M.themeSlug("Tokyo_Night"), "tokyo-night");
});

t("covers are fetched over https only, with limits, and shrunk in a capped process", () => {
    assert.ok(A.isCover("https://is1-ssl.mzstatic.com/a.jpg"));
    for (const bad of ["http://a/b", "file:///etc/passwd", "https://a/b c", "", "https://" + "a".repeat(3000)]) assert.ok(!A.isCover(bad), bad);
    const name = A.nameOf("https://x/y");
    assert.ok(A.isName(name));
    const curl = A.curlArgs("https://x/y", "/c/" + name + ".img");
    assert.strictEqual(curl[0], "curl");
    assert.ok(curl.indexOf("=https") > 0 && curl.indexOf(String(A.MAX_BYTES)) > 0 && curl.indexOf("--max-time") > 0);
    assert.strictEqual(A.curlArgs("http://x/y", "/c/" + name + ".img"), null);
    assert.strictEqual(A.curlArgs("https://x/y", "/c/../x.img"), null);
    const thumb = A.thumbArgs("/c/" + name + ".img", "/c/" + name + ".png");
    assert.deepStrictEqual(thumb.slice(0, 5), ["prlimit", "--as=536870912", "--cpu=10", "--", "vipsthumbnail"]);
    assert.strictEqual(A.thumbArgs("/c/a[x].img", "/c/" + name + ".png"), null);
});

t("manifest matches Settings.js", () => {
    const m = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
    assert.strictEqual(m.id, "io.github.qempexe.omatune");
    assert.deepStrictEqual(m.barWidget.schema.map((e) => e.key), S.realSettings().map((d) => d.key));
    assert.deepStrictEqual(m.barWidget.defaults, S.defaults());
    assert.ok(fs.existsSync(path.join(root, m.entryPoints.barWidget)));
});

console.log("\nALL OK (" + n + ")");
