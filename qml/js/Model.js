.pragma library

// Pure logic for Omatune: parsing SongRec/Shazam results, the status line and
// keeping the history and favourites. No Qt here, so it can be unit-tested with node.

function str(v, max) {
    const s = (typeof v === "string" || typeof v === "number" ? String(v) : "").replace(/\s+/g, " ").trim()
    return s.length > (max || 200) ? s.slice(0, (max || 200) - 1) + "…" : s
}

// Shell-safe-ish URL check: only plain http(s) links, no quotes, spaces or angle brackets.
function safeUrl(u) {
    const s = String(u === undefined || u === null ? "" : u).trim()
    return /^https?:\/\/[^\s"'<>]+$/.test(s) ? s : ""
}

// Plain-text for places that may render markup (bar tooltip, notifications).
function plain(s) {
    return String(s === undefined || s === null ? "" : s).replace(/</g, "‹").replace(/>/g, "›")
}

// SongRec's `audio-file-to-recognized-song` prints the Shazam response as JSON.
// The track lives under "track" (title, subtitle = artist, images, share, sections).
// Returns { title, artist, album, cover, url } or null when nothing was recognised.
function parseRecognition(text) {
    let d = null
    try { d = JSON.parse(String(text === undefined || text === null ? "" : text)) } catch (e) { return null }
    if (!d || typeof d !== "object") return null
    const t = d.track || (d.result && d.result.track) || null
    if (!t || typeof t !== "object") return null
    const title = str(t.title)
    if (!title) return null
    const artist = str(t.subtitle || t.artist || "")
    const imgs = t.images || {}
    const cover = safeUrl(imgs.coverarthq || imgs.coverart || "")
    const url = safeUrl((t.share && t.share.href) || t.url || "")
    let album = ""
    const sections = Array.isArray(t.sections) ? t.sections : []
    for (let i = 0; i < sections.length && !album; i++) {
        const md = sections[i] && Array.isArray(sections[i].metadata) ? sections[i].metadata : []
        for (let j = 0; j < md.length; j++)
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
    const out = [entry], src = Array.isArray(list) ? list : []
    for (let i = 0; i < src.length; i++) {
        const e = src[i]
        if (e && e.title === entry.title && e.artist === entry.artist) continue
        out.push(e)
    }
    const cap = Math.max(1, Math.round(Number(max) || 20))
    return out.slice(0, cap)
}

// A list read back from history.json or favourites.json, which could be edited by hand:
// only songs with a title, only these fields, links that are plain https or http, at most `max`.
function cleanSongs(list, max) {
    const out = [], src = Array.isArray(list) ? list : []
    const cap = Math.max(1, Math.round(Number(max) || 100))
    for (let i = 0; i < src.length && out.length < cap; i++) {
        const e = src[i]
        if (!e || typeof e !== "object") continue
        const title = str(e.title)
        if (!title) continue
        const at = /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/.test(String(e.at || "")) ? String(e.at) : ""
        out.push({ title, artist: str(e.artist), album: str(e.album), cover: safeUrl(e.cover), url: safeUrl(e.url), at })
    }
    return out
}

// favourites
// A song is the same song when its title and artist match, whatever the case.
function songKey(e) {
    return String(e && e.title || "").toLowerCase() + "|" + String(e && e.artist || "").toLowerCase()
}

function isFavourite(list, e) {
    if (!e) return false
    const k = songKey(e), src = Array.isArray(list) ? list : []
    for (let i = 0; i < src.length; i++) if (songKey(src[i]) === k) return true
    return false
}

// Saves the song at the top, or removes it when it is already saved. Returns the new list.
function toggleFavourite(list, e, max) {
    const src = Array.isArray(list) ? list : []
    if (!e) return src
    if (isFavourite(src, e)) {
        const k = songKey(e)
        return src.filter(function(x) { return songKey(x) !== k })
    }
    return [e].concat(src).slice(0, Math.max(1, Math.round(Number(max) || 500)))
}
