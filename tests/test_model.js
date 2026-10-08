// Run: node tests/test_model.js   (no Qt needed)
const fs = require("fs"), path = require("path"), assert = require("assert");
const root = path.join(__dirname, "..");
const load = f => fs.readFileSync(path.join(root, f), "utf8").replace(".pragma library", "");
const M = new Function(load("Model.js") + `;return {str,safeUrl,plain,coverFileName,parseRecognition,
  statusText,historyPush,resolveColors,normalizeSettings,parseOmarchyTheme,MONO,songKey,isFavourite,toggleFavourite}`)();
const S = new Function(load("Settings.js") + ";return { SCHEMA, PALETTE, GROUPS, realSettings, defaults }")();

let n = 0;
function t(name, fn) { fn(); n++; console.log("ok -", name); }

// A realistic-shaped Shazam response (fields as SongRec prints them).
const SHAZAM = JSON.stringify({
  matches: [{ id: "1" }],
  track: {
    title: "Blinding Lights",
    subtitle: "The Weeknd",
    url: "https://www.shazam.com/track/1",
    share: { subject: "Blinding Lights", href: "https://www.shazam.com/track/1/blinding-lights" },
    images: { coverart: "https://is1.example.com/c.jpg", coverarthq: "https://is1.example.com/hq.jpg" },
    sections: [{ type: "SONG", metadata: [{ title: "Album", text: "After Hours" }, { title: "Released", text: "2019" }] }]
  }
});

t("parses a full Shazam track", () => {
  const r = M.parseRecognition(SHAZAM);
  assert.deepStrictEqual(r, {
    title: "Blinding Lights", artist: "The Weeknd", album: "After Hours",
    cover: "https://is1.example.com/hq.jpg", url: "https://www.shazam.com/track/1/blinding-lights"
  });
});
t("falls back to coverart and url when hq/share are missing", () => {
  const r = M.parseRecognition(JSON.stringify({ track: { title: "A", subtitle: "B",
    images: { coverart: "https://x.example/a.jpg" }, url: "https://x.example/t" } }));
  assert.strictEqual(r.cover, "https://x.example/a.jpg");
  assert.strictEqual(r.url, "https://x.example/t");
  assert.strictEqual(r.album, "");
});
t("accepts a result.track wrapper", () => {
  assert.strictEqual(M.parseRecognition(JSON.stringify({ result: { track: { title: "X", subtitle: "Y" } } })).title, "X");
});
t("no match, junk and empty titles give null", () => {
  assert.strictEqual(M.parseRecognition("{}"), null);
  assert.strictEqual(M.parseRecognition(""), null);
  assert.strictEqual(M.parseRecognition("not json"), null);
  assert.strictEqual(M.parseRecognition(JSON.stringify({ track: { subtitle: "No title" } })), null);
  assert.strictEqual(M.parseRecognition("null"), null);
});
t("unsafe URLs are dropped", () => {
  const r = M.parseRecognition(JSON.stringify({ track: { title: "T", images: { coverarthq: "file:///etc/passwd" },
    url: "https://ok.example/x\"; rm -rf ~" } }));
  assert.strictEqual(r.cover, "");
  assert.strictEqual(r.url, "");
  assert.strictEqual(M.safeUrl("javascript:alert(1)"), "");
  assert.strictEqual(M.safeUrl("http://a.example/b"), "http://a.example/b");
});
t("long and messy text is trimmed", () => {
  const r = M.parseRecognition(JSON.stringify({ track: { title: "  Many   spaces\n here  ", subtitle: "x".repeat(500) } }));
  assert.strictEqual(r.title, "Many spaces here");
  assert.ok(r.artist.length <= 200 && r.artist.endsWith("…"));
});
t("plain() strips markup characters", () => {
  assert.strictEqual(M.plain("<b>hi</b>"), "‹b›hi‹/b›");
});
t("cover file names are stable and differ per URL", () => {
  assert.strictEqual(M.coverFileName("https://a/x.jpg"), M.coverFileName("https://a/x.jpg"));
  assert.notStrictEqual(M.coverFileName("https://a/x.jpg"), M.coverFileName("https://a/y.jpg"));
  assert.ok(/^cover-[0-9a-f]+\.jpg$/.test(M.coverFileName("https://a/x.jpg")));
});
t("status text", () => {
  assert.strictEqual(M.statusText("listening", 7, ""), "Listening… 7 s");
  assert.strictEqual(M.statusText("listening", -1, ""), "Listening… 0 s");
  assert.strictEqual(M.statusText("identifying", 0, ""), "Identifying…");
  assert.strictEqual(M.statusText("error", 0, "X"), "Nothing found");
  assert.strictEqual(M.statusText("idle", 0, "Blinding Lights"), "Blinding Lights");
  assert.strictEqual(M.statusText("idle", 0, ""), "Listen for a song");
});

t("history: newest first, duplicates move to top, capped", () => {
  let h = [];
  const a = { title: "A", artist: "1" }, b = { title: "B", artist: "2" }, c = { title: "C", artist: "3" };
  h = M.historyPush(h, a, 2); h = M.historyPush(h, b, 2); h = M.historyPush(h, c, 2);
  assert.deepStrictEqual(h.map(x => x.title), ["C", "B"]);
  h = M.historyPush(h, { title: "B", artist: "2", at: "now" }, 2);
  assert.deepStrictEqual(h.map(x => x.title), ["B", "C"]);
  assert.strictEqual(h[0].at, "now");
  assert.strictEqual(M.historyPush(null, a, 0).length, 1, "max is at least 1");
});

t("favourites: saved at the top, same song ignores case, toggling removes it", () => {
  const a = { title: "Song", artist: "Band", url: "https://x.example/1" };
  const b = { title: "Other", artist: "Band" };
  let f = M.toggleFavourite([], a);
  assert.strictEqual(M.isFavourite(f, a), true);
  f = M.toggleFavourite(f, b);
  assert.deepStrictEqual(f.map(x => x.title), ["Other", "Song"]);
  assert.strictEqual(M.isFavourite(f, { title: "SONG", artist: "band" }), true, "case does not matter");
  f = M.toggleFavourite(f, { title: "song", artist: "BAND" });
  assert.deepStrictEqual(f.map(x => x.title), ["Other"]);
  assert.strictEqual(M.isFavourite(f, a), false);
  assert.strictEqual(M.isFavourite(f, null), false);
  assert.strictEqual(M.toggleFavourite(f, null).length, 1, "nothing to save is a no-op");
  assert.strictEqual(M.toggleFavourite([{ title: "1", artist: "" }], { title: "2", artist: "" }, 1).length, 1, "capped");
});

const OMA = { text: "#e8dcc8", background: "#1a1815", accent: "#d4a35a" };
t("colours: follow uses Omarchy, custom uses valid hex, mono is grey", () => {
  assert.deepStrictEqual(M.resolveColors({ theme: "follow" }, OMA), { background: "#1a1815", text: "#e8dcc8", accent: "#d4a35a" });
  assert.deepStrictEqual(M.resolveColors({ theme: "follow" }, null), M.MONO, "follow without a theme falls back to mono");
  assert.deepStrictEqual(M.resolveColors({ theme: "mono" }, OMA), M.MONO);
  assert.strictEqual(M.normalizeSettings({ theme: "brown" }, S.SCHEMA).theme, "follow", "brown was removed");
  assert.strictEqual(M.normalizeSettings({ theme: "custom" }, S.SCHEMA).theme, "custom");
  const c = M.resolveColors({ theme: "custom", customBackground: "#000000", customText: "nope", customAccent: "#ff0000" }, OMA);
  assert.deepStrictEqual(c, { background: "#000000", text: M.MONO.text, accent: "#ff0000" }, "bad hex falls back per field");
});

t("settings: clamp, coerce and default", () => {
  const cfg = M.normalizeSettings({ duration: 99, notify: "false", theme: "neon", historySize: "12",
    customAccent: "  #abcdef  ", barIcon: "<b>♪ very long icon text</b>" }, S.SCHEMA);
  assert.strictEqual(cfg.duration, 20);
  assert.strictEqual(cfg.notify, false);
  assert.strictEqual(cfg.theme, "follow");
  assert.strictEqual(cfg.historySize, 12);
  assert.strictEqual(cfg.customAccent, "#abcdef");
  assert.ok(cfg.barIcon.length <= 40);
  assert.strictEqual(M.normalizeSettings({ duration: "abc", source: "tape" }, S.SCHEMA).duration, 5);
  assert.strictEqual(M.normalizeSettings({ duration: -4 }, S.SCHEMA).duration, 4);
  assert.deepStrictEqual(M.normalizeSettings({}, S.SCHEMA), S.defaults());
});

t("manifest.json matches Settings.js (run tools/gen-manifest.js after editing)", () => {
  const m = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
  assert.strictEqual(m.id, "io.github.qempexe.omatune");
  assert.deepStrictEqual(m.barWidget.defaults, S.defaults());
  assert.deepStrictEqual(m.barWidget.schema.map(s => s.key), S.realSettings().map(s => s.key));
  assert.ok(!m.barWidget.schema.some(s => s.type === "palette"), "the picker row is not a setting");
});

t("settings: every option has a label, groups are known, palette is UI-only", () => {
  for (const d of S.realSettings()) {
    assert.ok(S.GROUPS.includes(d.group), d.key + " has an unknown group");
    if (d.type === "enum") assert.strictEqual(d.labels.length, d.options.length, d.key + " labels");
    if (d.type === "enum") assert.ok(d.options.includes(d.defaultValue), d.key + " default");
  }
  assert.ok(S.SCHEMA.some(d => d.type === "palette" && d.showWhen === "custom"));
  assert.ok(!S.defaults().customPalette, "palette has no saved value");
  assert.ok(S.PALETTE.every(c => /^#[0-9a-f]{6}$/.test(c)), "swatches are hex");
  assert.strictEqual(S.realSettings().find(d => d.key === "theme").options.includes("brown"), false);
});

t("follow: a live Omarchy theme drives the colours, and a bare name is kept", () => {
  const live = M.parseOmarchyTheme("@@NAME gruvbox\n@@FILE colors.toml\nbackground = \"#1d2021\"\nforeground = \"#ebdbb2\"\naccent = \"#fabd2f\"\n");
  assert.strictEqual(live.name, "gruvbox");
  assert.deepStrictEqual(M.resolveColors({ theme: "follow" }, live), { background: "#1d2021", text: "#ebdbb2", accent: "#fabd2f" });
  const noAccent = M.parseOmarchyTheme("@@FILE colors.toml\nbackground = \"#101010\"\nforeground = \"#eeeeee\"\ncolor4 = \"#3366aa\"\n");
  assert.strictEqual(M.resolveColors({ theme: "follow" }, noAccent).accent, "#3366aa", "falls back to color4");
});

t("Omarchy theme parsing (colors.toml)", () => {
  const txt = "@@FILE colors.toml\nbackground = \"#1a1b26\"\nforeground = \"#c0caf5\"\naccent = \"#7aa2f7\"\n";
  const th = M.parseOmarchyTheme(txt);
  assert.deepStrictEqual([th.background, th.text, th.accent], ["#1a1b26", "#c0caf5", "#7aa2f7"]);
  assert.strictEqual(M.parseOmarchyTheme("@@FILE colors.toml\n"), null);
});

console.log("\n" + n + " tests passed");
