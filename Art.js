.pragma library

// The cover of a song, made safe to show. Shazam hands over the cover as an https://
// address. It is never shown as it is:
//   * it is downloaded by curl, https only, with a size cap (8 MiB) and a time limit
//   * the download is made into a small PNG (at most 256 by 256, no metadata) by
//     vipsthumbnail, in its own process, under prlimit: 512 MiB of memory and 10 seconds
//     of processor at most, with only plain image loaders (VIPS_BLOCK_UNTRUSTED=1) and
//     one worker thread (VIPS_CONCURRENCY=1)
// Only that PNG is ever decoded, by the panel and by the notification. A cover built to
// swell up while it downloads or decodes can then only stop its own helper.

var MAX_BYTES = 8 * 1048576
var MEMORY = 536870912
var KEEP = 24

// a cover address we fetch: https only, one line, not too long
function isCover(url) {
    const s = String(url || "")
    return s.length > 0 && s.length <= 2048 && !/[\s\0]/.test(s) && /^https:\/\/[^\/\s]+/i.test(s)
}

// a stable file name for a cover address: two 32-bit hashes
function nameOf(url) {
    const s = String(url || "")
    let a = 0x811c9dc5, b = 5381
    for (let i = 0; i < s.length; i++) {
        const c = s.charCodeAt(i)
        a = Math.imul(a ^ c, 16777619) >>> 0
        b = (Math.imul(b, 33) + c) >>> 0
    }
    const hex = (n) => ("00000000" + n.toString(16)).slice(-8)
    return hex(a) + hex(b)
}

function isName(n) { return /^[0-9a-f]{16}$/.test(String(n)); }

function curlArgs(url, out) {
    if (!isCover(url) || !/^\/[^\0\[\]]*\/[0-9a-f]{16}\.img$/.test(String(out))) return null
    return ["curl", "-q", "--fail", "--silent", "--show-error", "--location", "--max-redirs", "3",
            "--proto", "=https", "--proto-redir", "=https", "--max-time", "15",
            "--max-filesize", String(MAX_BYTES), "-o", out, "--url", String(url)]
}

function thumbArgs(src, out) {
    if (!/^\/[^\0\[\]]*$/.test(String(src)) || !/^\/[^\0\[\]]*\/[0-9a-f]{16}\.png$/.test(String(out))) return null
    return ["prlimit", "--as=" + MEMORY, "--cpu=10", "--",
            "vipsthumbnail", src, "--size", "256x256", "-o", out + "[keep=none]"]
}
