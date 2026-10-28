// node tests/test_model.js
// The pure logic (Model.js, Schema.js, Theme.js, Art.js) and the manifest, without Qt.
const fs = require("fs"), path = require("path"), assert = require("assert");
const root = path.join(__dirname, "..");
const load = (file, names) => new Function(fs.readFileSync(path.join(root, "qml", "js", file), "utf8")
    .replace(/^\.pragma.*$/m, "") + "; return { " + names.join(", ") + " };")();

const M = load("Model.js", ["str", "safeUrl", "plain", "parseRecognition", "statusText", "historyPush", "songKey",
    "isFavourite", "toggleFavourite", "cleanSongs"]);
const S = load("Schema.js", ["groups", "settingKeys", "defaults", "resolve", "clean", "isHex", "readableOn"]);
const T = load("Theme.js", ["parseBorder", "parsePalette"]);
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

t("custom colours are kept exactly as picked", () => {
    const c = S.resolve({ colorMode: "custom", customBg: "#E0DEF4", customFg: "#f8f8f2", accentColor: "#ffffff" }, {});
    assert.deepStrictEqual([c.colorMode, c.customBg, c.customFg, c.accentColor], ["custom", "#e0def4", "#f8f8f2", "#ffffff"]);
    assert.strictEqual(S.resolve({ customBg: "nope" }, {}).customBg, "#141414");
});

t("settings are clamped to what the schema allows", () => {
    const c = S.resolve({ duration: 99, colorMode: "pink", notify: "false", barIcon: "<b>", windowWidth: "5000" }, {});
    assert.strictEqual(c.duration, 20);
    assert.strictEqual(c.colorMode, "theme");
    assert.strictEqual(c.notify, false);
    assert.strictEqual(c.barIcon, "b");
    assert.strictEqual(c.windowWidth, 1200);
    assert.deepStrictEqual(Object.keys(c).sort(), S.settingKeys.slice().sort());
    assert.deepStrictEqual(S.resolve({}, {}), S.defaults);
});

t("a custom text color that was never picked reads on the background", () => {
    assert.strictEqual(S.resolve({ colorMode: "custom", customBg: "#f8f8f2" }, {}).customFg, "#141414");
    assert.strictEqual(S.resolve({ colorMode: "custom", customBg: "#1f1714" }, {}).customFg, "#e0e0e0");
    assert.strictEqual(S.resolve({ colorMode: "custom", customBg: "#f8f8f2", customFg: "#ffffff" }, {}).customFg, "#ffffff");
    // a 1.1 text color is not mixed with colors picked since
    const c = S.resolve({ theme: "follow", customText: "#ffffff", colorMode: "custom", customBg: "#f8f8f2" }, { theme: "follow" });
    assert.deepStrictEqual([c.colorMode, c.customBg, c.customFg], ["custom", "#f8f8f2", "#141414"]);
});

t("the settings file wins over the bar's settings", () => {
    assert.strictEqual(S.resolve({ duration: 7 }, { duration: 9 }).duration, 7);
    assert.strictEqual(S.resolve({}, { duration: 9 }).duration, 9);
});

t("settings saved by 1.1 still apply", () => {
    const c = S.resolve({ theme: "custom", customBackground: "#101010", customText: "#fafafa", customAccent: "#ff0000", barShowResult: false }, {});
    assert.deepStrictEqual([c.colorMode, c.customBg, c.customFg, c.accentColor, c.barDisplay], ["custom", "#101010", "#fafafa", "#ff0000", "icon"]);
    assert.strictEqual(S.resolve({ theme: "mono" }, {}).colorMode, "monochrome");
    assert.strictEqual(S.resolve({ theme: "follow", colorMode: "borders" }, {}).colorMode, "borders");
});

t("the window border is read from the theme's files", () => {
    const lua = T.parseBorder('local active_border_color = { colors = { "rgba(1ee9d6ee)", "rgba(fe4fb6ee)" }, angle = 45 }');
    assert.deepStrictEqual(lua, { colors: ["#1ee9d6", "#fe4fb6"], angle: 45 });
    const conf = T.parseBorder("col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg");
    assert.deepStrictEqual(conf.colors, ["#33ccff", "#00ff99"]);
    assert.deepStrictEqual(T.parseBorder("").colors, []);
});

t("the clip is recorded privately, never through a link", () => {
    const os = require("os"), cp = require("child_process");
    const qml = fs.readFileSync(path.join(root, "qml", "BarWidget.qml"), "utf8");
    const a = qml.indexOf("captureScript: [") + 15, b = qml.indexOf("].join(\"\\n\")", a);
    const script = eval(qml.slice(a, b + 1)).join("\n");
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "omatune-"));
    fs.mkdirSync(path.join(tmp, "bin"));
    fs.writeFileSync(path.join(tmp, "bin", "pw-record"), "#!/bin/sh\nfor a; do f=\"$a\"; done; echo RIFF > \"$f\"\n", { mode: 0o755 });
    fs.writeFileSync(path.join(tmp, "bin", "songrec"), "#!/bin/sh\n", { mode: 0o755 });
    const env = Object.assign({}, process.env, { PATH: path.join(tmp, "bin") + ":" + process.env.PATH });
    const run = (f) => cp.execFileSync("sh", ["-c", "umask 022; " + script, "sh", f, "system", "1"], { env, encoding: "utf8" });
    const cache = path.join(tmp, "omatune");
    fs.mkdirSync(cache, { mode: 0o755 });          // left by an older version
    const clip = path.join(cache, "capture", "clip.wav");
    assert.ok(run(clip).includes("@@OK"));
    const mode = (p) => fs.statSync(p).mode & 0o777;
    assert.deepStrictEqual([mode(cache), mode(path.dirname(clip)), mode(clip)], [0o700, 0o700, 0o600]);
    fs.rmSync(path.dirname(clip), { recursive: true });
    fs.symlinkSync(os.tmpdir(), path.dirname(clip));
    assert.ok(run(clip).includes("@@ERR"), "a link is refused");
    fs.rmSync(tmp, { recursive: true, force: true });
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

t("manifest matches Schema.js", () => {
    const m = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
    assert.strictEqual(m.id, "io.github.qempexe.omatune");
    assert.strictEqual(m.version, "1.2.0");
    assert.ok(fs.readFileSync(path.join(root, "CHANGELOG.md"), "utf8").includes("## [" + m.version + "] - "), "the version has a changelog entry");
    assert.deepStrictEqual(m.barWidget.schema.map((e) => e.key), S.settingKeys);
    assert.deepStrictEqual(m.barWidget.defaults, S.defaults);
    assert.ok(fs.existsSync(path.join(root, m.entryPoints.barWidget)));
});

console.log("\nALL OK (" + n + ")");
