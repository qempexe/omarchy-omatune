import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Settings.js" as Settings

// Omatune: click the bar to record a few seconds, identify the song with SongRec,
// then show it in a notification (with cover), on the bar and in the history.
BarWidget {
    id: root
    moduleName: "io.github.qempexe.omatune"

    // settings: local overrides win over `omarchy bar set` (see SettingsStore.qml)
    SettingsStore { id: settingsStore }

    function buildRaw(v) {
        var raw = {}, rows = Settings.realSettings()
        for (var i = 0; i < rows.length; i++) {
            var d = rows[i]
            raw[d.key] = v[d.key] !== undefined ? v[d.key] : setting(d.key, d.defaultValue)
        }
        return raw
    }
    readonly property var cfg: Model.normalizeSettings(buildRaw(settingsStore.values), Settings.SCHEMA)
    readonly property string themeChoice: cfg.theme

    function setValue(key, value) { settingsStore.set(key, value) }

    // paths (outside the plugin folder, so hot-reload never restarts the bar)
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omatune"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/omatune"
    readonly property string capturePath: cacheDir + "/capture.wav"
    readonly property string coverDir: cacheDir + "/covers"
    readonly property string omarchyConfig: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/omarchy"

    // ── recording state ──
    property string phase: "idle"          // idle | listening | identifying | error
    property int secondsLeft: 0
    property string errorText: ""
    property var last: null                // newest recognised song
    property bool continuous: false        // keep identifying one song after another until switched off
    property var history: []
    property var pending: null             // song waiting for its notification cover
    property var omarchy: null             // live Omarchy theme, or null

    readonly property var colors: Model.resolveColors(cfg, omarchy)

    readonly property string barLabel: {
        if (phase === "listening") return secondsLeft + " s"
        if (phase === "identifying") return "…"
        if (phase === "error") return "no match"
        return cfg.barShowResult && last ? last.title : ""
    }

    function tooltip() {
        var lines = ["Omatune: left click to listen, middle click for history, right click for settings."]
        if (last) lines.push("Last: " + last.title + (last.artist ? " — " + last.artist : ""))
        return lines.map(function(l) { return Model.plain(l) }).join("\n")
    }

    // listening: record, then identify
    // Everything runs in one shell script. It prints @@OK or @@ERR <message> as its last line,
    // so the outcome never depends on the order in which the process streams finish.
    readonly property string captureScript: [
        'f="$1"; mode="$2"; secs="$3"',
        'mkdir -p "$(dirname "$f")"; rm -f "$f"',
        'command -v songrec >/dev/null 2>&1 || { echo "@@ERR songrec is not installed. Install it, then press Recheck."; exit 0; }',
        'if command -v pw-record >/dev/null 2>&1; then',
        '  if [ "$mode" = system ]; then timeout -s INT "$secs" pw-record -P \'{ stream.capture.sink=true }\' "$f" >/dev/null 2>&1',
        '  else timeout -s INT "$secs" pw-record "$f" >/dev/null 2>&1; fi',
        'elif command -v parecord >/dev/null 2>&1; then',
        '  if [ "$mode" = system ]; then src=@DEFAULT_MONITOR@; else src=@DEFAULT_SOURCE@; fi',
        '  timeout -s INT "$secs" parecord --device="$src" --file-format=wav "$f" >/dev/null 2>&1',
        'else echo "@@ERR no recorder found (PipeWire or PulseAudio)"; exit 0; fi',
        'if [ -s "$f" ]; then echo "@@OK"; else echo "@@ERR no audio was recorded"; fi'
    ].join("\n")

    // SongRec is a separate package the user installs themselves. Omatune only
    // checks whether `songrec` is on the PATH; it never invokes a package
    // manager and never installs, upgrades or removes anything.
    property bool recognizerMissing: false

    function recheckRecognizer() { if (!checkProc.running) checkProc.running = true }
    Process {
        id: checkProc
        command: ["sh", "-c", 'command -v songrec >/dev/null 2>&1 && echo "@@OK" || echo "@@MISSING"']
        stdout: StdioCollector {
            id: checkOut
            onStreamFinished: root.recognizerMissing = String(checkOut.text).indexOf("@@MISSING") >= 0
        }
    }

    function listen() {
        if (recognizerMissing) {
            fail("SongRec is not installed yet. Install it, then press Recheck.")
            return
        }
        if (phase === "listening" || phase === "identifying" || captureProc.running || recogProc.running) return
        errorText = ""
        phase = "listening"
        secondsLeft = cfg.duration
        countdown.start()
        captureProc.command = ["sh", "-c", captureScript, "sh", capturePath,
                               cfg.source === "microphone" ? "microphone" : "system", String(cfg.duration)]
        captureProc.running = true
    }

    function captureDone(text) {
        countdown.stop()
        var lines = String(text || "").split("\n")
        var err = ""
        for (var i = 0; i < lines.length; i++)
            if (lines[i].indexOf("@@ERR ") === 0) err = lines[i].slice(6)
        if (lines.indexOf("@@OK") < 0) { fail(err || "recording failed"); scheduleNext(); return }
        phase = "identifying"
        recogProc.command = ["sh", "-c", 'songrec audio-file-to-recognized-song "$1"; rm -f "$1"', "sh", capturePath]
        recogProc.running = true
    }

    function recognitionDone(text) {
        var r = Model.parseRecognition(text)
        if (!r) { fail("no match, try a longer listen"); scheduleNext(); return }
        phase = "idle"
        // while continuous, the same song heard again is not logged or notified twice
        var repeat = continuous && !!last && Model.songKey(last) === Model.songKey(r)
        last = r
        if (!repeat) {
            var entry = { title: r.title, artist: r.artist, album: r.album, cover: r.cover, url: r.url,
                          at: new Date().toISOString() }
            history = Model.historyPush(history, entry, cfg.historySize)
            saveHistory()
            if (cfg.notify) notify(entry)
        }
        scheduleNext()
    }

    // Continuous listening: start the next clip shortly after the last one finished.
    function setContinuous(on) {
        continuous = on
        if (on) listen()
        else nextTimer.stop()
    }
    function scheduleNext() { if (root.continuous) nextTimer.restart() }
    Timer { id: nextTimer; interval: 1500; repeat: false
            onTriggered: if (root.continuous) root.listen() }

    function fail(msg) {
        countdown.stop()
        phase = "error"
        errorText = Model.plain(msg)
        resetTimer.restart()
    }

    Timer { id: countdown; interval: 1000; repeat: true
            onTriggered: root.secondsLeft = Math.max(0, root.secondsLeft - 1) }
    Timer { id: resetTimer; interval: 6000
            onTriggered: if (root.phase === "error") root.phase = "idle" }

    Process {
        id: captureProc
        stdout: StdioCollector { id: captureOut; onStreamFinished: root.captureDone(captureOut.text) }
    }
    Process {
        id: recogProc
        stdout: StdioCollector { id: recogOut; onStreamFinished: root.recognitionDone(recogOut.text) }
    }

    // notification: cover photo (downloaded once and cached), artist and title
    function notify(entry) {
        pending = entry
        if (cfg.notifyCover && entry.cover) {
            var file = coverDir + "/" + Model.coverFileName(entry.cover)
            coverProc.command = ["sh", "-c",
                'mkdir -p "$1"; [ -s "$2" ] || curl -fsSL --max-time 10 -o "$2" "$3" 2>/dev/null; [ -s "$2" ] && echo "@@COVER"',
                "sh", coverDir, file, entry.cover]
            coverProc.running = true
        } else {
            sendNotification("")
        }
    }

    Process {
        id: coverProc
        stdout: StdioCollector {
            id: coverOut
            onStreamFinished: {
                var ok = String(coverOut.text).indexOf("@@COVER") >= 0
                root.sendNotification(ok && root.pending ? root.coverDir + "/" + Model.coverFileName(root.pending.cover) : "")
            }
        }
    }

    function sendNotification(iconPath) {
        var e = pending
        if (!e) return
        var body = e.artist + (e.album ? "\n" + e.album : "")
        notifyProc.command = ["notify-send", "-a", "Omatune", "-i", iconPath || "audio-x-generic",
                              "-t", String(cfg.notifyTimeout * 1000),
                              Model.plain(e.title), Model.plain(body)]
        notifyProc.running = true
    }
    Process { id: notifyProc }

    // opening a result in the browser
    function openLink(url) {
        var u = Model.safeUrl(url)
        if (!u) return
        openProc.command = ["xdg-open", u]
        openProc.running = true
    }
    Process { id: openProc }

    // history on disk
    function loadHistory(text) {
        try {
            var arr = JSON.parse(String(text || "[]"))
            history = Array.isArray(arr) ? arr.slice(0, 100) : []
        } catch (e) { history = [] }
        last = history.length ? history[0] : null
    }
    function saveHistory() { historyFile.setText(JSON.stringify(history, null, 2) + "\n") }
    function clearHistory() { history = []; last = null; saveHistory() }

    // favourites (kept separately, so they survive the history limit)
    property var favourites: []
    function isFavourite(entry) { return Model.isFavourite(root.favourites, entry) }
    function toggleFavourite(entry) {
        if (!entry) return
        var copy = { title: entry.title, artist: entry.artist, album: entry.album || "", cover: entry.cover || "",
                     url: entry.url || "", at: entry.at || new Date().toISOString() }
        favourites = Model.toggleFavourite(favourites, copy)
        favFile.setText(JSON.stringify(favourites, null, 2) + "\n")
    }
    FileView {
        id: favFile
        path: root.stateDir + "/favourites.json"
        onLoaded: {
            try {
                var a = JSON.parse(text())
                root.favourites = Array.isArray(a) ? a : []
            } catch (e) { root.favourites = [] }
        }
        onLoadFailed: root.favourites = []
    }

    Process {
        id: mkDirs
        command: ["mkdir", "-p", root.stateDir, root.coverDir]
        onExited: { historyFile.reload(); favFile.reload() }
    }
    FileView {
        id: historyFile
        path: root.stateDir + "/history.json"
        onLoaded: root.loadHistory(text())
        onLoadFailed: root.history = []
    }

    // Omarchy theme: read the active theme's files, follow every change
    // Reads <omarchy>/current/theme (or the named theme's folder) with one short shell script.
    // It is re-run when current/theme.name changes, shortly after that (the swap is not atomic),
    // on a slow poll while following, and when the choice switches to "Follow Omarchy".
    readonly property var themeScriptArgs: [omarchyConfig + "/current", omarchyConfig]
    readonly property string themeScript: [
        'd="$1"; cfg="$2"; n=""',
        '[ -r "$d/theme.name" ] && n=$(tr -d "\r\n" < "$d/theme.name")',
        '[ -z "$n" ] && n=$(omarchy-theme-current 2>/dev/null)',
        'n=$(printf %s "$n" | tr "A-Z " "a-z-")',
        'echo "@@NAME $n"',
        'found=0',
        'for t in "$d/theme" "$cfg/themes/$n"; do',
        '  [ "$found" = 1 ] && break',
        '  [ -d "$t" ] || continue',
        '  for f in colors.toml alacritty.toml kitty.conf; do',
        '    if [ -r "$t/$f" ]; then echo "@@FILE $f"; cat "$t/$f"; echo; found=1; fi',
        '  done',
        'done',
        '# no current theme folder: dump every installed theme; QML picks the one matching the shell',
        'if [ "$found" = 0 ]; then',
        '  for t in "$cfg"/themes/*; do',
        '    [ -d "$t" ] || continue',
        '    for f in colors.toml alacritty.toml kitty.conf; do',
        '      if [ -r "$t/$f" ]; then echo "@@THEME $(basename "$t")"; echo "@@FILE $f"; cat "$t/$f"; echo; break; fi',
        '    done',
        '  done',
        'fi',
        'exit 0'
    ].join("\n")

    // What the reader found, shown under the theme choice in Settings.
    property string omarchyNote: "Looking for your Omarchy theme…"

    function refreshTheme() { if (!themeProc.running) themeProc.running = true }

    // The shell's bar colour, passed in by Panel: used to find the installed theme that matches it.
    property var shellBg: null
    property string lastThemeText: ""
    function hexOf(c) {
        function h(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2) }
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }
    onShellBgChanged: if (lastThemeText.indexOf("@@THEME") >= 0) themeRead(lastThemeText)

    function themeRead(text) {
        lastThemeText = String(text || "")
        var t = null
        if (lastThemeText.indexOf("@@THEME") >= 0) {
            var installed = Model.parseOmarchyThemes(lastThemeText)
            var named = /^@@NAME[ \t]*(.*)$/m.exec(lastThemeText)
            var want = named ? Model.themeSlug(named[1]) : ""
            // 1) the theme Omarchy reports as active: found by name, so it works in light and dark alike
            for (var i = 0; i < installed.length && !t; i++)
                if (want && Model.themeSlug(installed[i].name) === want) t = installed[i]
            // 2) otherwise the installed theme nearest the shell's bar colour, when that colour is known
            if (!t && shellBg !== null && shellBg !== undefined) {
                var best = Model.closestTheme(installed, hexOf(shellBg))
                t = best && best.dist < 0.012 ? best.theme : null
            }
        } else {
            t = Model.parseOmarchyTheme(lastThemeText)
        }
        omarchy = t
        omarchyNote = t
            ? "Following “" + (t.name || "your current theme") + "”."
            : "Using the shell's own colours."
    }

    Process {
        id: themeProc
        command: ["sh", "-c", root.themeScript, "sh", root.themeScriptArgs[0], root.themeScriptArgs[1]]
        stdout: StdioCollector { onStreamFinished: root.themeRead(text) }
    }
    FileView {
        id: themeNameFile
        path: root.omarchyConfig + "/current/theme.name"
        watchChanges: true
        onFileChanged: { reload(); root.refreshTheme(); themeSettle.restart() }
    }
    Timer { id: themeSettle; interval: 600; onTriggered: root.refreshTheme() }
    Timer {
        interval: 2000
        repeat: true
        running: root.cfg.theme === "follow"
        onTriggered: root.refreshTheme()
    }
    onThemeChoiceChanged: if (themeChoice === "follow") refreshTheme()
    Component.onCompleted: { mkDirs.running = true; refreshTheme(); recheckRecognizer() }

    // ── panel host (same pattern as Omatravel) ──
    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
        panelLoader.item.widget = root
    }
    function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

    // Bar clicks: left opens Listen, middle opens History, right opens Settings.
    // Only the X closes the panel.
    //
    // If the compositor dismissed the popup on click-outside, Panel's controller
    // still believes it is showing, so a bare `show()` would be a no-op and the
    // panel would never reappear. Closing first brings the controller back to a
    // clean "hidden" state, then opening genuinely shows the panel again.
    function openTab(tab) {
        if (!panelLoader.item) return
        panelLoader.item.currentTab = tab
        if (panelLoader.item.opened)
            panelLoader.item.close()
        Qt.callLater(function() {
            if (panelLoader.item)
                panelLoader.item.open()
        })
    }
    function openSettings() { openTab("settings") }

    // Which tab a mouse button opens. Accepts Qt's button values or plain names.
    function tabForButton(code) {
        if (code === Qt.MiddleButton || code === "middle" || code === "MiddleButton") return "history"
        if (code === Qt.RightButton || code === "right" || code === "RightButton") return "settings"
        return "listen"
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onBarChanged: injectPanel()

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: Model.plain(root.cfg.barIcon) + (root.barLabel ? " " + Model.plain(root.barLabel) : "")
        tooltipText: root.tooltip()
        onPressed: function(buttonCode) {
            root.openTab(root.tabForButton(buttonCode))
        }
    }
}
