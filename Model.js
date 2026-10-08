.pragma library

// Pure logic for Omatune: parsing SongRec/Shazam results, choosing colours,
// validating settings and keeping the history. No Qt here, so it can be unit-tested with node.

function str(v, max) {
    var s = String(v === undefined || v === null ? "" : v).replace(/\s+/g, " ").trim()
    return s.length > (max || 200) ? s.slice(0, (max || 200) - 1) + "…" : s
}

// Shell-safe-ish URL check: only plain http(s) links, no quotes, spaces or angle brackets.
function safeUrl(u) {
    var s = String(u === undefined || u === null ? "" : u).trim()
    return /^https?:\/\/[^\s"'<>]+$/.test(s) ? s : ""
}

// Plain-text for places that may render markup (bar tooltip, notifications).
function plain(s) {
    return String(s === undefined || s === null ? "" : s).replace(/</g, "‹").replace(/>/g, "›")
}

// Stable file name for a cover image, derived from its URL.
function coverFileName(url) {
    var h = 5381
    for (var i = 0; i < url.length; i++) h = ((h * 33) ^ url.charCodeAt(i)) >>> 0
    return "cover-" + h.toString(16) + ".jpg"
}

// SongRec's `audio-file-to-recognized-song` prints the Shazam response as JSON.
// The track lives under "track" (title, subtitle = artist, images, share, sections).
// Returns { title, artist, album, cover, url } or null when nothing was recognised.
function parseRecognition(text) {
    var d = null
    try { d = JSON.parse(String(text === undefined || text === null ? "" : text)) } catch (e) { return null }
    if (!d || typeof d !== "object") return null
    var t = d.track || (d.result && d.result.track) || null
    if (!t || typeof t !== "object") return null
    var title = str(t.title)
    if (!title) return null
    var artist = str(t.subtitle || t.artist || "")
    var imgs = t.images || {}
    var cover = safeUrl(imgs.coverarthq || imgs.coverart || "")
    var url = safeUrl((t.share && t.share.href) || t.url || "")
    var album = ""
    var sections = Array.isArray(t.sections) ? t.sections : []
    for (var i = 0; i < sections.length && !album; i++) {
        var md = sections[i] && Array.isArray(sections[i].metadata) ? sections[i].metadata : []
        for (var j = 0; j < md.length; j++)
            if (md[j] && /album/i.test(String(md[j].title || "")) && md[j].text) { album = str(md[j].text); break }
    }
    return { title: title, artist: artist, album: album, cover: cover, url: url }
}

// Human text for the bar and the panel status line.
function statusText(state, secondsLeft, lastTitle) {
    if (state === "listening") return "Listening… " + Math.max(0, secondsLeft) + " s"
    if (state === "identifying") return "Identifying…"
    if (state === "error") return "Nothing found"
    return lastTitle || "Listen for a song"
}

// history
// Newest first. The same song (title + artist) moves to the top instead of being repeated.
function historyPush(list, entry, max) {
    var out = [entry], src = Array.isArray(list) ? list : []
    for (var i = 0; i < src.length; i++) {
        var e = src[i]
        if (e && e.title === entry.title && e.artist === entry.artist) continue
        out.push(e)
    }
    var cap = Math.max(1, Math.round(Number(max) || 20))
    return out.slice(0, cap)
}

// favourites
// A song is the same song when its title and artist match, whatever the case.
function songKey(e) {
    return String(e && e.title || "").toLowerCase() + "|" + String(e && e.artist || "").toLowerCase()
}

function isFavourite(list, e) {
    if (!e) return false
    var k = songKey(e), src = Array.isArray(list) ? list : []
    for (var i = 0; i < src.length; i++) if (songKey(src[i]) === k) return true
    return false
}

// Saves the song at the top, or removes it when it is already saved. Returns the new list.
function toggleFavourite(list, e, max) {
    var src = Array.isArray(list) ? list : []
    if (!e) return src
    if (isFavourite(src, e)) {
        var k = songKey(e)
        return src.filter(function(x) { return songKey(x) !== k })
    }
    return [e].concat(src).slice(0, Math.max(1, Math.round(Number(max) || 500)))
}

// colours
var MONO = { background: "#141414", text: "#e0e0e0", accent: "#aaaaaa" }

function isHex(s) { return /^#[0-9a-fA-F]{6}$/.test(String(s || "")) }

// readability
// WCAG relative luminance and contrast ratio between two "#rrggbb" colours.
function _lum(hex) {
    var n = parseInt(String(hex).slice(1), 16), out = 0, w = [0.2126, 0.7152, 0.0722]
    for (var i = 0; i < 3; i++) {
        var c = ((n >> (16 - 8 * i)) & 255) / 255
        out += w[i] * (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4))
    }
    return out
}
function contrast(a, b) {
    var x = _lum(a), y = _lum(b), hi = Math.max(x, y), lo = Math.min(x, y)
    return (hi + 0.05) / (lo + 0.05)
}
// Keep `fg` when it reads well on `bg`; otherwise use near-black or near-white, whichever reads better.
function readableOn(fg, bg, minRatio) {
    if (contrast(fg, bg) >= minRatio) return fg
    return contrast("#141414", bg) >= contrast("#f5f5f5", bg) ? "#141414" : "#f5f5f5"
}

// theme: "follow" | "custom" | "mono". omarchy = parsed Omarchy theme or null.
// Custom colours are never stored changed, but text and accent are shown readable on the
// chosen background (a light background with the default light text would otherwise vanish).
function resolveColors(cfg, omarchy) {
    if (cfg.theme === "custom") {
        var bg = isHex(cfg.customBackground) ? cfg.customBackground : MONO.background
        var tx = isHex(cfg.customText) ? cfg.customText : MONO.text
        var ac = isHex(cfg.customAccent) ? cfg.customAccent : MONO.accent
        return { background: bg, text: readableOn(tx, bg, 4.5), accent: readableOn(ac, bg, 3) }
    }
    if (cfg.theme === "follow" && omarchy && isHex(omarchy.background) && isHex(omarchy.text))
        return { background: omarchy.background, text: omarchy.text, accent: isHex(omarchy.accent) ? omarchy.accent : omarchy.text }
    return { background: MONO.background, text: MONO.text, accent: MONO.accent }
}

// settings
// Clamp every setting to what the schema allows. `raw` is the merged value map.
function normalizeSettings(raw, schema) {
    var out = {}, src = raw || {}
    for (var i = 0; i < schema.length; i++) {
        var d = schema[i], v = src[d.key]
        if (d.type === "palette") continue
        if (v === undefined || v === null) { out[d.key] = d.defaultValue; continue }
        if (d.type === "boolean") {
            out[d.key] = (v === true || v === "true") ? true : (v === false || v === "false") ? false : d.defaultValue
        } else if (d.type === "integer") {
            var n = Number(v)
            out[d.key] = isFinite(n) ? Math.max(d.min, Math.min(d.max, Math.round(n))) : d.defaultValue
        } else if (d.type === "enum") {
            out[d.key] = d.options.indexOf(String(v)) >= 0 ? String(v) : d.defaultValue
        } else {
            out[d.key] = str(v, 40) || d.defaultValue
        }
    }
    return out
}

// Omarchy theme reader (colors.toml, alacritty.toml, kitty.conf)
function _hex(v) {
    var m = /^(?:#|0x)?([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?$/.exec(String(v).trim());
    return m ? "#" + m[1].toLowerCase() : "";
}

function parseOmarchyTheme(text) {
    var files = {}, cur = null, curName = "", sec = "", name = "";
    var lines = String(text === undefined || text === null ? "" : text).split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var ln = lines[i], m;
        if ((m = /^@@NAME\s*(.*)$/.exec(ln))) { name = m[1].trim(); continue; }
        if ((m = /^@@FILE\s+(\S+)\s*$/.exec(ln))) { curName = m[1]; cur = files[curName] = {}; sec = ""; continue; }
        if (!cur) continue;
        var h;
        if (curName === "colors.toml") {                      // background = "#1a1b26"
            m = /^\s*([A-Za-z0-9_]+)\s*=\s*["']?((?:#|0x)?[0-9a-fA-F]{6})["']?/.exec(ln);
            if (m && !(m[1] in cur)) cur[m[1]] = _hex(m[2]);
        } else if (curName === "alacritty.toml") {            // [colors.primary]  background = "#1a1b26"
            if ((m = /^\s*\[([^\]]+)\]/.exec(ln))) { sec = m[1].trim(); continue; }
            m = /^\s*([A-Za-z0-9_]+)\s*=\s*["']([^"']+)["']/.exec(ln);
            if (m && (h = _hex(m[2])) && !((sec + "." + m[1]) in cur)) cur[sec + "." + m[1]] = h;
        } else if (curName === "kitty.conf") {                // background #1a1b26
            m = /^\s*(foreground|background|cursor|color4)\s+((?:#|0x)?[0-9a-fA-F]{6})\s*$/.exec(ln);
            if (m && !(m[1] in cur)) cur[m[1]] = _hex(m[2]);
        } else if (curName === "waybar.css") {                // @define-color background #1a1b26;
            m = /@define-color\s+([\w-]+)\s+(#[0-9a-fA-F]{6})/.exec(ln);
            if (m && !(m[1] in cur)) cur[m[1]] = _hex(m[2]);
        } else if (curName === "btop.theme") {                // theme[main_bg]="#1a1b26"
            m = /^\s*theme\[(\w+)\]\s*=\s*"(#[0-9a-fA-F]{6})"/.exec(ln);
            if (m && !(m[1] in cur)) cur[m[1]] = _hex(m[2]);
        } else if (curName === "mako.ini") {                  // background-color=#1a1b26ee
            m = /^\s*([a-z-]+)\s*=\s*(#[0-9a-fA-F]{6})/.exec(ln);
            if (m && !(m[1] in cur)) cur[m[1]] = _hex(m[2]);
        } else if (curName === "hyprland.conf") {             // $activeBorderColor = rgb(7aa2f7)
            m = /active_?border\w*\s*=.*?rgba?\(([0-9a-fA-F]{6})/i.exec(ln);
            if (m && !cur.accent) cur.accent = _hex(m[1]);
        }
    }
    var c = files["colors.toml"] || {}, a = files["alacritty.toml"] || {}, k = files["kitty.conf"] || {},
        w = files["waybar.css"] || {}, b = files["btop.theme"] || {}, mk = files["mako.ini"] || {},
        hy = files["hyprland.conf"] || {};
    var bg = c.background || a["colors.primary.background"] || k.background || w.background
             || b.main_bg || mk["background-color"] || "";
    var fg = c.foreground || a["colors.primary.foreground"] || k.foreground || w.foreground
             || b.main_fg || mk["text-color"] || "";
    if (!bg || !fg) return null;
    var accent = c.accent || hy.accent || b.hi_fg || mk["border-color"] || k.color4
                 || a["colors.normal.blue"] || c.color4 || k.cursor || a["colors.cursor.cursor"] || fg;
    var src = "";
    var order = ["colors.toml", "alacritty.toml", "kitty.conf", "waybar.css", "btop.theme", "mako.ini"];
    for (var j = 0; j < order.length && !src; j++) if (files[order[j]] && Object.keys(files[order[j]]).length) src = order[j];
    return { text: fg, background: bg, accent: accent, name: name, source: src };
}

// installed themes: match the shell's bar colour
// When no "current" theme folder exists, the reader dumps every installed theme and the
// one whose background is nearest to the shell's bar colour is the active one.
function parseOmarchyThemes(text) {
    var out = [], chunks = String(text === undefined || text === null ? "" : text).split(/^@@THEME\s+/m);
    for (var i = 1; i < chunks.length; i++) {
        var nl = chunks[i].indexOf("\n");
        var nm = (nl < 0 ? chunks[i] : chunks[i].slice(0, nl)).trim();
        var t = parseOmarchyTheme("@@NAME " + nm + "\n" + (nl < 0 ? "" : chunks[i].slice(nl + 1)));
        if (t) out.push(t);
    }
    return out;
}

function _dist(a, b) {                                  // 0..1 distance between two "#rrggbb"
    var x = parseInt(a.slice(1), 16), y = parseInt(b.slice(1), 16), s = 0;
    for (var sh = 0; sh < 24; sh += 8) { var d = ((x >> sh) & 255) - ((y >> sh) & 255); s += d * d; }
    return Math.sqrt(s) / 441.67;
}

// The installed theme whose background is nearest to `bgHex` -> {theme, dist} or null.
function closestTheme(list, bgHex) {
    var best = null;
    for (var i = 0; i < list.length; i++) {
        var d = _dist(list[i].background, bgHex);
        if (!best || d < best.dist) best = { theme: list[i], dist: d };
    }
    return best;
}

// Theme names compared loosely: "Tokyo Night", "tokyo-night" and "tokyo_night" are the same theme.
function themeSlug(s) {
    return String(s === undefined || s === null ? "" : s).trim().toLowerCase().replace(/[\s_]+/g, "-")
}
