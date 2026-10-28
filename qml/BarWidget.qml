import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "core"
import "js/Model.js" as Model
import "js/Schema.js" as Schema
import "js/Theme.js" as Theme

// Omatune: click the bar to record a few seconds, identify the song with SongRec,
// then show it in a notification (with cover), on the bar and in the history.
//
// This file is also the "service" the window talks to (`ui.service`): the song,
// the history and favourites, opening links, the capped clipboard read, the
// manifest, and the theme's window border.
BarWidget {
    id: root
    moduleName: "io.github.qempexe.omatune"

    // ---- settings ------------------------------------------------------------------
    // Local overrides (Settings tab, see SettingsStore.qml) win over `omarchy bar set`.
    // Every key read here is declared in manifest.json (tools/gen-manifest.js).
    SettingsStore { id: settingsStore }

    function shellValues() {
        const out = {}
        for (const k of Schema.settingKeys) {
            const v = setting(k, undefined)
            if (v !== undefined && v !== null) out[k] = v
        }
        return out
    }
    readonly property var cfg: Schema.resolve(settingsStore.values, shellValues())
    function setValue(key, value) { settingsStore.set(key, value) }

    // paths (outside the plugin folder, so hot-reload never restarts the bar)
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omatune"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/omatune"
    // The clip is recorded into a folder only you can open, and lives only until
    // SongRec has read it.
    readonly property string captureDir: cacheDir + "/capture"
    readonly property string capturePath: captureDir + "/clip.wav"

    // ── recording state ──
    property string phase: "idle"          // idle | listening | identifying | error
    property int secondsLeft: 0
    property string errorText: ""
    property var last: null                // newest recognised song
    property bool continuous: false        // keep identifying one song after another until switched off
    property var history: []
    property var pending: null             // song waiting for its notification cover

    readonly property string barLabel: {
        if (phase === "listening") return secondsLeft + " s"
        if (phase === "identifying") return "…"
        if (phase === "error") return "no match"
        return last ? last.title : ""
    }

    function tooltip() {
        const middle = cfg.middleClick === "listen" ? ", middle click to listen now"
                     : (cfg.middleClick === "history" ? ", middle click for history" : "")
        const lines = ["Omatune: left click to open" + middle + ", right click for settings."]
        if (last) lines.push("Last: " + last.title + (last.artist ? " — " + last.artist : ""))
        return lines.map(l => Model.plain(l)).join("\n")
    }

    // listening: record, then identify
    // Everything runs in one shell script. It prints @@OK or @@ERR <message> as its last line,
    // so the outcome never depends on the order in which the process streams finish.
    readonly property string captureScript: [
        'f="$1"; mode="$2"; secs="$3"',
        // new files are yours alone (0600), in folders yours alone (0700), never
        // through a link someone else placed there
        'umask 077',
        'd=$(dirname -- "$f")',
        'for x in "$(dirname -- "$d")" "$d"; do',
        '  [ -L "$x" ] && { echo "@@ERR $x is a link, not recording"; exit 0; }',
        '  mkdir -p -m 700 -- "$x" 2>/dev/null',
        '  [ -d "$x" ] && [ -O "$x" ] || { echo "@@ERR $x is not your folder, not recording"; exit 0; }',
        '  chmod 700 -- "$x" || { echo "@@ERR could not make $x private"; exit 0; }',
        'done',
        'rm -f -- "$f"',
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
        const lines = String(text || "").split("\n")
        let err = ""
        for (let i = 0; i < lines.length; i++)
            if (lines[i].indexOf("@@ERR ") === 0) err = lines[i].slice(6)
        if (lines.indexOf("@@OK") < 0) { fail(err || "recording failed"); scheduleNext(); return }
        phase = "identifying"
        recogProc.command = ["sh", "-c", 'songrec audio-file-to-recognized-song "$1"; rm -f -- "$1"', "sh", capturePath]
        recogProc.running = true
    }

    function recognitionDone(text) {
        const r = Model.parseRecognition(text)
        if (!r) { fail("no match, try a longer listen"); scheduleNext(); return }
        phase = "idle"
        // while continuous, the same song heard again is not logged or notified twice
        const repeat = continuous && !!last && Model.songKey(last) === Model.songKey(r)
        last = r
        if (!repeat) {
            const entry = { title: r.title, artist: r.artist, album: r.album, cover: r.cover, url: r.url,
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

    // notification: artist and title, with the cover once it has been made safe (see ArtCache.qml)
    ArtCache {
        id: artCache
        onMade: function(url) {
            if (root.pending && root.pending.cover === url) root.sendNotification(artCache.pathFor(url))
        }
        onFailedUrl: function(url) {
            if (root.pending && root.pending.cover === url) root.sendNotification("")
        }
    }
    readonly property alias covers: artCache
    function notify(entry) {
        pending = entry
        if (cfg.notifyCover && entry.cover) {
            coverWait.restart()
            artCache.ask(entry.cover)
        } else {
            sendNotification("")
        }
    }
    // a cover that takes too long: the notification goes without it
    Timer { id: coverWait; interval: 30000; onTriggered: root.sendNotification("") }
    // the last song's cover, for the panel
    onLastChanged: if (root.last && root.last.cover) artCache.ask(root.last.cover)

    function sendNotification(iconPath) {
        const e = pending
        if (!e) return
        pending = null
        coverWait.stop()
        const body = e.artist + (e.album ? "\n" + e.album : "")
        notifyProc.command = ["notify-send", "-a", "Omatune", "-i", iconPath || "audio-x-generic",
                              "-t", String(cfg.notifyTimeout * 1000),
                              Model.plain(e.title), Model.plain(body)]
        notifyProc.running = true
    }
    Process { id: notifyProc }

    // opening a result in the browser
    function openLink(url) {
        const u = Model.safeUrl(url)
        if (!u) return
        openProc.command = ["xdg-open", u]
        openProc.running = true
    }
    Process { id: openProc }
    function openUrl(url) { openLink(url) }

    // history on disk
    function loadHistory(text) {
        try {
            const arr = JSON.parse(String(text || "[]"))
            history = Model.cleanSongs(arr, 100)
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
        const copy = { title: entry.title, artist: entry.artist, album: entry.album || "", cover: entry.cover || "",
                     url: entry.url || "", at: entry.at || new Date().toISOString() }
        favourites = Model.toggleFavourite(favourites, copy)
        favFile.setText(JSON.stringify(favourites, null, 2) + "\n")
    }
    FileView {
        id: favFile
        path: root.stateDir + "/favourites.json"
        onLoaded: {
            try {
                const a = JSON.parse(text())
                root.favourites = Model.cleanSongs(a, 500)
            } catch (e) { root.favourites = [] }
        }
        onLoadFailed: root.favourites = []
    }

    // The history and favourites folder is yours alone (0700). At start, a clip left
    // behind by a crash, and the clip of Omatune 1.1 and before, are removed.
    Process {
        id: mkDirs
        command: ["sh", "-c", 'umask 077; mkdir -p -m 700 -- "$1" && [ ! -L "$1" ] && chmod 700 -- "$1"; rm -f -- "$2" "$3"',
                  "sh", root.stateDir, root.capturePath, root.cacheDir + "/capture.wav"]
        onExited: { historyFile.reload(); favFile.reload() }
    }
    FileView {
        id: historyFile
        path: root.stateDir + "/history.json"
        onLoaded: root.loadHistory(text())
        onLoadFailed: root.history = []
    }


    // ---- the plugin's own manifest (the About tab shows its version) ----------------
    property var manifest: null
    FileView {
        id: manifestFile
        path: decodeURIComponent(Qt.resolvedUrl("../manifest.json").toString().replace(/^file:\/\//, ""))
        onLoaded: {
            let m = null
            try { m = JSON.parse(root.readText(manifestFile)) } catch (e) { m = null }
            const v = m && typeof m.version === "string" && /^[0-9A-Za-z.+-]{1,32}$/.test(m.version) ? m.version : ""
            root.manifest = { version: v }
        }
    }
    function readText(fv) {
        try { return String(typeof fv.text === "function" ? fv.text() : fv.text) } catch (e) { return "" }
    }

    // ---- the theme's window border ----------------------------------------------------
    // For the Window borders color scheme and the window outline: the active border's
    // colors and angle, from the theme's hyprland.lua (or .conf, or the line some themes
    // keep in colors.toml). Only #rrggbb values and an angle are taken from these files.
    property var tomlBorder: ({ colors: [], angle: 0 })
    property var luaBorder: ({ colors: [], angle: 0 })
    property var confBorder: ({ colors: [], angle: 0 })
    property bool luaMissing: false
    readonly property var borderColors: luaBorder.colors.length > 0 ? luaBorder.colors
        : (confBorder.colors.length > 0 ? confBorder.colors : tomlBorder.colors)
    readonly property real borderAngle: luaBorder.colors.length > 0 ? luaBorder.angle
        : (confBorder.colors.length > 0 ? confBorder.angle : tomlBorder.angle)
    readonly property string themeDir: {
        try { return Color.currentThemePath ? String(Color.currentThemePath) : "" } catch (e) { return "" }
    }

    FileView {
        id: paletteFile
        path: root.themeDir !== "" ? root.themeDir + "/colors.toml" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.tomlBorder = Theme.parseBorder(root.readText(paletteFile))
        onLoadFailed: { root.tomlBorder = ({ colors: [], angle: 0 }); root.retryTheme() }
    }
    FileView {
        id: borderLua
        path: root.themeDir !== "" ? root.themeDir + "/hyprland.lua" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.luaMissing = false; root.luaBorder = Theme.parseBorder(root.readText(borderLua)) }
        onLoadFailed: { root.luaBorder = ({ colors: [], angle: 0 }); root.luaMissing = true }
    }
    FileView {
        id: borderConf
        // only looked at when the theme has no hyprland.lua
        path: root.themeDir !== "" && root.luaMissing ? root.themeDir + "/hyprland.conf" : ""
        watchChanges: true
        onFileChanged: reload()
        onPathChanged: if (path === "") root.confBorder = ({ colors: [], angle: 0 })
        onLoaded: root.confBorder = Theme.parseBorder(root.readText(borderConf))
        onLoadFailed: root.confBorder = ({ colors: [], angle: 0 })
    }
    // A theme switch replaces the theme folder, so for a moment the files are gone and
    // the watch can lose track of them: read them again shortly after, a few times at most.
    property int themeTries: 0
    function retryTheme() { if (themeTries < 3) { themeTries++; themeRetry.restart() } }
    Timer {
        id: themeRetry
        interval: 800
        onTriggered: { paletteFile.reload(); borderLua.reload(); borderConf.reload() }
    }
    Connections {
        target: Color
        ignoreUnknownSignals: true
        function onAccentChanged() { root.themeTries = 0; themeRetry.restart() }
        function onBackgroundChanged() { root.themeTries = 0; themeRetry.restart() }
    }

    // ---- clipboard paste (capped, no shell) -------------------------------------------
    // Pasting into the search box never reads the clipboard on the UI thread. wl-paste
    // runs directly (no shell) and its output is read in chunks. Reading stops as soon
    // as 1024 bytes are in, or after 2 seconds, and the process is stopped. The text is
    // then sent back through `pasted`, addressed to the field that asked.
    property string pasteKey: ""
    property string pasteBuf: ""
    readonly property int pasteMax: 1024
    signal pasted(string key, string text)

    function requestPaste(key) {
        if (pasteKey !== "" || pasteProc.running) return   // one paste at a time
        pasteKey = key
        pasteBuf = ""
        pasteProc.running = true
        pasteKill.restart()
    }
    function finishPaste() {
        const k = pasteKey
        if (k === "") return                              // already delivered
        pasteKey = ""
        pasteKill.stop()
        const text = pasteBuf.slice(0, pasteMax)
        pasteBuf = ""
        if (pasteProc.running) pasteProc.running = false  // stop reading the clipboard
        root.pasted(k, text)
    }
    Timer { id: pasteKill; interval: 2000; onTriggered: root.finishPaste() }
    Process {
        id: pasteProc
        running: false
        command: ["wl-paste", "--no-newline"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                if (root.pasteBuf.length >= root.pasteMax) return
                root.pasteBuf += data
                if (root.pasteBuf.length >= root.pasteMax) root.finishPaste()
            }
        }
        onExited: root.finishPaste()
    }

    Component.onCompleted: { mkDirs.running = true; recheckRecognizer() }

    // ---- the window: docked to the bar, or popped out ----------------------------------
    // One UiState feeds whichever surface is showing, so the tab, the search and the
    // history filter survive popping out and docking back.
    property bool popped: false
    // Set only by the header's Pop out / Dock buttons. Until then "Open as" decides
    // how the bar button opens, every time, so a change in settings takes effect at once.
    property bool userPicked: false

    // The bar's own colours. Fall back to the shell palette if the bar does not expose them.
    readonly property color barFg: (root.bar && root.bar.barForeground !== undefined)
        ? root.bar.barForeground : (Color.foreground !== undefined ? Color.foreground : "white")
    readonly property color barBg: (root.bar && root.bar.barBackground !== undefined)
        ? root.bar.barBackground : (Color.background !== undefined ? Color.background : "#121217")

    // The shell theme's accent, tried under a few likely names. Unknown names are
    // skipped, and with none found the window falls back to the bar foreground.
    function themeColor(names) {
        for (const name of names) {
            let raw
            try { raw = Color[name] } catch (e) { raw = undefined }
            if (raw === undefined || raw === null) continue
            try {
                const c = Qt.color(raw)
                if (c && c.valid !== false) return c
            } catch (e2) { }
        }
        return null
    }
    readonly property var shellAccent: themeColor(["accent", "primary", "highlight", "accentColor", "color4", "blue"])

    UiState {
        id: ux
        service: root
        themeAccent: root.shellAccent ? root.shellAccent : "transparent"
        store: settingsStore
        cfg: root.cfg
        opened: root.panelOpened || root.windowShown
        popped: root.popped
        barFg: root.barFg
        barBg: root.barBg
        fontName: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family
        onPopOutRequested: root.popOut()
        onDockRequested: root.dock()
        onCloseRequested: root.close()
    }

    readonly property bool panelOpened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool windowShown: windowLoader.item ? windowLoader.item.visible === true : false

    // The shell only knows about the bar-panel state.
    readonly property bool opened: panelOpened
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true : false

    // Until the header's buttons are used, "Open as" decides.
    function chooseMode() {
        if (userPicked) return
        const want = cfg.openAs === "window"
        if (want === popped) return
        if (windowShown) hideWindow()
        if (panelOpened) closePanel()
        popped = want
    }

    // The window exists exactly while it is wanted. Showing it again after it was
    // closed (by the header, or by the window manager) always creates a fresh one,
    // so a dead window handle can never leave the bar button doing nothing.
    property bool windowRequested: false
    function showWindow() {
        windowRequested = true
        if (windowLoader.item) windowLoader.item.visible = true
    }
    function hideWindow() { windowRequested = false }

    // The window manager closed the window while we still wanted it: forget it, so
    // the next click on the bar button builds a new one.
    Connections {
        target: windowLoader.item
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (windowLoader.item && !windowLoader.item.visible && root.windowRequested)
                root.windowRequested = false
        }
    }

    // If the bar panel cannot be shown (Panel.qml failed to load, or the shell never
    // reported it open), show Omatune as its own window instead of doing nothing.
    // The reason goes to the shell log (`qs log`).
    property bool wantPanel: false
    function fallbackToWindow(reason) {
        console.warn("Omatune: " + reason + "; opening as a window instead")
        wantPanel = false
        panelCheck.stop()
        popped = true
        showWindow()
    }
    function openPanel() {
        if (panelLoader.status === Loader.Error || !panelLoader.item) {
            fallbackToWindow("Panel.qml is not loaded (status " + panelLoader.status + ")")
            return
        }
        injectPanel()
        wantPanel = true
        panelLoader.item.open()
        panelCheck.restart()
    }
    function closePanel() {
        wantPanel = false
        panelCheck.stop()
        if (panelLoader.item) panelLoader.item.close()
    }
    function open() {
        chooseMode()
        if (popped) showWindow()
        else openPanel()
    }
    function close() {
        closePanel()
        hideWindow()
    }
    function toggle() {
        chooseMode()
        if (popped) {
            if (windowShown) hideWindow()
            else showWindow()
        } else if (panelOpened) {
            closePanel()
        } else if (!(panelLoader.item && panelLoader.item.justClosedByGrab === true)) {
            openPanel()
        }
    }
    function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
    function popOut() {
        userPicked = true
        popped = true
        closePanel()
        showWindow()
    }
    function dock() {
        userPicked = true
        hideWindow()
        popped = false
        Qt.callLater(root.openPanel)
    }
    onPanelOpenedChanged: if (panelOpened) { wantPanel = false; panelCheck.stop() }
    Timer {
        id: panelCheck
        interval: 600
        repeat: false
        onTriggered: if (root.wantPanel && !root.panelOpened && !root.popped)
            root.fallbackToWindow("the panel did not open")
    }

    // Open on a tab (or keep it open and switch to it).
    function showTab(name) {
        ux.tabName = name
        open()
    }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
        panelLoader.item.ui = ux
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onBarChanged: injectPanel()

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("panel/Panel.qml")
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("Omatune: Panel.qml failed to load; run `qs log` for the QML error")
    }

    // A real, resizable, movable window. Only exists while popped out.
    Loader {
        id: windowLoader
        active: root.windowRequested
        source: Qt.resolvedUrl("panel/PopoutWindow.qml")
        onLoaded: {
            item.ui = ux
            item.visible = root.windowRequested
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("Omatune: PopoutWindow.qml failed to load; run `qs log` for the QML error")
    }

    // ---- the bar button --------------------------------------------------------------
    // While listening it always shows the countdown; otherwise Bar button shows decides.
    readonly property string buttonText: {
        const icon = Model.plain(cfg.barIcon)
        const busy = phase !== "idle"
        const label = Model.plain(barLabel)
        if (busy || cfg.barDisplay === "both") return label ? icon + " " + label : icon
        if (cfg.barDisplay === "song") return label || icon
        return icon
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.buttonText
        tooltipText: root.tooltip()
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton || buttonCode === "right") root.showTab("settings")
            else if (buttonCode === Qt.MiddleButton || buttonCode === "middle") {
                if (root.cfg.middleClick === "history") root.showTab("history")
                else if (root.cfg.middleClick === "listen") root.listen()
            } else {
                if (!root.opened && !root.windowShown) ux.tabName = "listen"
                root.toggle()
            }
        }
    }
}
