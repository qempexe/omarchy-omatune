pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Settings.js" as Settings

// Popup with three tabs: Listen (the last song), History, Settings (built from Settings.js).
Panel {
    id: root
    moduleName: "io.github.qempexe.omatune"
    manageIpc: false

    // injected by BarWidget
    property var anchorItem: null
    property var hostWidget: null
    property var widget: null

    // the shell's bar colour, so the widget can match the installed Omarchy theme to it (as Omatravel does)
    // The shell's live bar colours. `bar.background` / `bar.foreground` are the documented ones;
    // `barBackground` / `barForeground` on the base Panel are a second source when they exist.
    readonly property var shellBgColor: (root.bar && root.bar.background !== undefined) ? root.bar.background
                                       : root.barBackground
    readonly property var shellFgColor: (root.bar && root.bar.foreground !== undefined) ? root.bar.foreground
                                       : root.barForeground
    Binding { target: root.widget; property: "shellBg"; value: root.shellBgColor; when: !!root.widget && root.shellBgColor !== undefined }

    property string currentTab: "listen"
    // History filter: "all" or "fav" (favourites only)
    property string historyView: "all"
    readonly property var cfg: widget ? widget.cfg : ({})
    // Colours. "Follow Omarchy" uses the shell's own bar colours, so a light Omarchy theme comes out
    // light and a dark one dark, with no guessing. The parsed Omarchy theme only supplies the accent.
    // Custom and Monochrome use the widget's own colours.
    readonly property bool useBarColors: !!widget && widget.cfg.theme === "follow"
        && root.shellBgColor !== undefined && root.shellFgColor !== undefined
    readonly property color fg: useBarColors ? root.shellFgColor : (widget ? widget.colors.text : "#e0e0e0")
    readonly property color panelBg: {
        if (useBarColors) { var c = root.shellBgColor; return Qt.rgba(c.r, c.g, c.b, 1) }   // never translucent
        return widget ? widget.colors.background : "#141414"
    }
    readonly property color accent: {
        if (useBarColors) {
            var o = widget.omarchy
            return (o && Model.isHex(o.accent)) ? Qt.color(o.accent) : root.shellFgColor
        }
        return widget ? widget.colors.accent : "#aaaaaa"
    }
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.56)
    readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.14)
    readonly property color selectedFill: Qt.rgba(accent.r, accent.g, accent.b, 0.12)
    readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    readonly property int fsMain: Math.max(10, Math.round(Style.font.body * 0.9))
    readonly property int fsSub: Math.max(9, Math.round(Style.font.body * 0.8))

    readonly property var optionLabels: ({
        follow: "Follow Omarchy", custom: "Custom", brown: "Brown", mono: "Monochrome",
        system: "This computer", microphone: "Microphone", listen: "Listen", panel: "Open panel"
    })

    function open() { root.controller.show() }
    function close() { root.controller.hide() }
    function toggle() { if (root.opened) root.close(); else root.open() }
    function openTab(tab) { root.currentTab = tab; root.open() }

    // Which colour role the custom picker edits (a panel-local choice, not a setting).
    property string colorRole: "customBackground"
    readonly property var colorRoles: [
        { key: "customBackground", label: "Background" },
        { key: "customText", label: "Text" },
        { key: "customAccent", label: "Accent" }
    ]

    // Shown option label for an enum value.
    function labelFor(d, value) {
        var i = d.options.indexOf(value)
        return i >= 0 && d.labels ? d.labels[i] : String(value)
    }

    // Rows of the Settings tab: a header per group, then each visible setting.
    // Built from the theme choice only, so typing in a field never rebuilds the list.
    readonly property string themeChoice: root.widget ? root.widget.themeChoice : "follow"
    readonly property var settingRows: buildRows(themeChoice)
    function buildRows(theme) {
        var rows = [], lastGroup = ""
        var schema = Settings.SCHEMA
        for (var i = 0; i < schema.length; i++) {
            var d = schema[i]
            if (d.ui === "hidden") continue
            if (d.showWhen && d.showWhen !== theme) continue
            if (d.group !== lastGroup) { rows.push({ type: "header", label: d.group }); lastGroup = d.group }
            rows.push(d)
        }
        return rows
    }


    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(460))
        contentHeight: panel.fittedContentHeight(Style.space(640))

        // The popup surface is transparent. This fills the whole surface with the
        // theme background, so the whole layout is the same colour (no wallpaper or
        // border showing through, and no gaps at the edges).
        Rectangle {
            anchors.fill: parent
            color: root.panelBg
        }

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
        }

        Rectangle {
            id: card
            x: 0; y: 0
            width: parent ? parent.width : 0
            height: parent ? parent.height : 0
            // square corners: the background fills the whole layout, with no see-through corner cut-outs
            radius: 0
            color: root.panelBg

            // ── header ──
            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Style.space(52)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(18)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "OMATUNE"
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: root.fsMain + 4
                    font.bold: true
                    font.letterSpacing: 1
                    textFormat: Text.PlainText
                }
                FlatButton {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    hPad: Style.space(10)
                    foreground: root.fg
                    accent: root.accent
                    fontFamily: root.fontFamily
                    pixelSize: root.fsMain
                    onClicked: root.close()
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: root.faint
                }
            }

            // tabs
            Item {
                id: tabs
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                height: Style.space(50)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(14)
                    anchors.rightMargin: Style.space(14)
                    anchors.topMargin: Style.space(10)
                    anchors.bottomMargin: Style.space(10)
                    spacing: Style.space(6)

                    Repeater {
                        model: [
                            { key: "listen", label: "Listen" },
                            { key: "history", label: "History" },
                            { key: "settings", label: "Settings" }
                        ]
                        delegate: FlatButton {
                            id: tabBtn
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            outlined: true
                            hPad: Style.space(4)
                            text: tabBtn.modelData.label
                            selected: root.currentTab === tabBtn.modelData.key
                            foreground: root.fg
                            accent: root.accent
                            fontFamily: root.fontFamily
                            pixelSize: root.fsSub
                            onClicked: root.currentTab = tabBtn.modelData.key
                        }
                    }
                }
            }

            // pages
            StackLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tabs.bottom
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(16)
                currentIndex: ["listen", "history", "settings"].indexOf(root.currentTab)

                // LISTEN
                ColumnLayout {
                    spacing: Style.space(14)

                    // first-run setup: SongRec is a separate package the user installs themselves.
                    Rectangle {
                        Layout.fillWidth: true
                        visible: !!root.widget && root.widget.recognizerMissing
                        Layout.preferredHeight: visible ? setupCol.implicitHeight + Style.space(24) : 0
                        radius: Style.cornerRadius
                        color: root.selectedFill
                        border.width: 1
                        border.color: root.accent
                        ColumnLayout {
                            id: setupCol
                            anchors.fill: parent
                            anchors.margins: Style.space(12)
                            spacing: Style.space(8)
                            Text {
                                Layout.fillWidth: true
                                text: "Omatune needs SongRec to recognise songs."
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: root.fsMain
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Install the songrec package from your distribution's repositories, then press Recheck."
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: root.fsSub
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                            FlatButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(36)
                                outlined: true
                                selected: true
                                text: "Recheck"
                                foreground: root.fg
                                accent: root.accent
                                fontFamily: root.fontFamily
                                pixelSize: root.fsMain
                                onClicked: root.widget.recheckRecognizer()
                            }
                        }
                    }

                    // continuous listening: identify songs one after another, no clicking
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(10)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(2)
                            Text {
                                Layout.fillWidth: true
                                text: "Continuous listening"
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: root.fsMain
                                textFormat: Text.PlainText
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Keeps identifying songs one after another. A song that repeats is not logged twice."
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: root.fsSub
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }
                        FlatButton {
                            text: "Off"
                            outlined: true
                            selected: !root.widget || !root.widget.continuous
                            implicitHeight: Style.space(30)
                            foreground: root.fg
                            accent: root.accent
                            fontFamily: root.fontFamily
                            pixelSize: root.fsSub
                            onClicked: root.widget.setContinuous(false)
                        }
                        FlatButton {
                            text: "On"
                            outlined: true
                            selected: !!root.widget && root.widget.continuous
                            implicitHeight: Style.space(30)
                            foreground: root.fg
                            accent: root.accent
                            fontFamily: root.fontFamily
                            pixelSize: root.fsSub
                            onClicked: root.widget.setContinuous(true)
                        }
                    }

                    FlatButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(44)
                        outlined: true
                        selected: true
                        enabled: root.widget && !root.widget.continuous && (root.widget.phase === "idle" || root.widget.phase === "error")
                        text: !root.widget ? "" :
                              root.widget.phase === "listening" ? "Listening… " + root.widget.secondsLeft + " s" :
                              root.widget.phase === "identifying" ? "Identifying…" :
                              "Listen for " + root.cfg.duration + " s"
                        foreground: root.fg
                        accent: root.accent
                        fontFamily: root.fontFamily
                        pixelSize: root.fsMain
                        onClicked: root.widget.listen()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.widget && root.widget.phase === "error"
                              ? root.widget.errorText
                              : root.widget && root.widget.continuous
                                ? "Continuous: " + (root.widget.phase === "identifying" ? "identifying…" : "listening to " + (root.optionLabels[root.cfg.source] || "this computer") + "…")
                                : "Listening to " + (root.optionLabels[root.cfg.source] || "this computer") + "."
                        color: root.widget && root.widget.phase === "error" ? root.accent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: root.fsSub
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }

                    // last result
                    Rectangle {
                        id: resultCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: resultCol.implicitHeight + Style.space(28)
                        visible: !!root.widget && !!root.widget.last
                        radius: Style.space(12)
                        color: root.selectedFill
                        border.width: 1
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5)

                        ColumnLayout {
                            id: resultCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Style.space(14)
                            spacing: Style.space(12)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.space(14)

                                Rectangle {
                                    Layout.preferredWidth: Style.space(96)
                                    Layout.preferredHeight: Style.space(96)
                                    radius: Style.space(8)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                                    clip: true

                                    Image {
                                        id: thumb
                                        anchors.fill: parent
                                        source: root.widget && root.widget.last && root.widget.last.cover ? root.widget.last.cover : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize.width: 192
                                        sourceSize.height: 192
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: thumb.status !== Image.Ready
                                        text: root.cfg.barIcon
                                        color: root.dim
                                        font.pixelSize: Style.space(30)
                                        textFormat: Text.PlainText
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(4)
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.widget && root.widget.last ? root.widget.last.title : ""
                                        color: root.fg
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fsMain + 2
                                        font.bold: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.widget && root.widget.last ? root.widget.last.artist : ""
                                        color: root.fg
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fsMain
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: !!root.widget && !!root.widget.last && root.widget.last.album !== ""
                                        text: root.widget && root.widget.last ? root.widget.last.album : ""
                                        color: root.dim
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fsSub
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.space(8)

                                FlatButton {
                                    visible: !!root.widget && !!root.widget.last && root.widget.last.url !== ""
                                    text: "Open on Shazam"
                                    outlined: true
                                    implicitHeight: Style.space(30)
                                    foreground: root.fg
                                    accent: root.accent
                                    fontFamily: root.fontFamily
                                    pixelSize: root.fsSub
                                    onClicked: root.widget.openLink(root.widget.last.url)
                                }

                                FlatButton {
                                    visible: !!root.widget && !!root.widget.last
                                    selected: !!root.widget && !!root.widget.last && root.widget.isFavourite(root.widget.last)
                                    text: selected ? "♥ Saved" : "♡ Save"
                                    outlined: true
                                    implicitHeight: Style.space(30)
                                    foreground: root.fg
                                    accent: root.accent
                                    fontFamily: root.fontFamily
                                    pixelSize: root.fsSub
                                    onClicked: root.widget.toggleFavourite(root.widget.last)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: !root.widget || !root.widget.last
                        text: "Play a song, then press Listen. The result shows here, in the bar and as a notification."
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: root.fsSub
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                    }

                    Item { Layout.fillHeight: true }
                }

                // HISTORY
                ColumnLayout {
                    spacing: Style.space(10)

                    // filter: all songs, or favourites only
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Repeater {
                            model: [
                                { key: "all", label: "All" },
                                { key: "fav", label: "♥ Favourites" }
                            ]
                            delegate: FlatButton {
                                id: viewBtn
                                required property var modelData
                                Layout.fillWidth: true
                                outlined: true
                                implicitHeight: Style.space(30)
                                hPad: Style.space(4)
                                selected: root.historyView === viewBtn.modelData.key
                                text: viewBtn.modelData.key === "fav" && root.widget
                                      ? viewBtn.modelData.label + " (" + root.widget.favourites.length + ")"
                                      : viewBtn.modelData.label
                                foreground: root.fg
                                accent: root.accent
                                fontFamily: root.fontFamily
                                pixelSize: root.fsSub
                                onClicked: root.historyView = viewBtn.modelData.key
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: root.widget
                                  ? (root.historyView === "fav" ? root.widget.favourites.length : root.widget.history.length)
                                    + (root.historyView === "fav" ? " saved" : " songs")
                                  : ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: root.fsSub
                            textFormat: Text.PlainText
                        }
                        FlatButton {
                            visible: !!root.widget && root.historyView === "all" && root.widget.history.length > 0
                            text: "Clear"
                            outlined: true
                            implicitHeight: Style.space(28)
                            foreground: root.fg
                            accent: root.accent
                            fontFamily: root.fontFamily
                            pixelSize: root.fsSub
                            onClicked: root.widget.clearHistory()
                        }
                    }

                    ListView {
                        id: historyList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Style.space(6)
                        model: !root.widget ? []
                               : root.historyView === "fav" ? root.widget.favourites
                               : root.widget.history
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: histRow
                            required property var modelData
                            width: historyList.width
                            height: Style.space(56)
                            radius: Style.space(10)
                            color: histMouse.containsMouse ? root.selectedFill : "transparent"
                            border.width: 1
                            border.color: root.faint

                            Column {
                                anchors.left: parent.left
                                anchors.right: heartBtn.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Style.space(14)
                                anchors.rightMargin: Style.space(8)
                                spacing: Style.space(3)
                                Text {
                                    width: parent.width
                                    text: histRow.modelData.title
                                    color: root.fg
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fsMain
                                    font.bold: true
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    width: parent.width
                                    text: histRow.modelData.artist + (histRow.modelData.url ? "  ·  open ↗" : "")
                                    color: root.dim
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fsSub
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                            }
                            MouseArea {
                                id: histMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: histRow.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (histRow.modelData.url && root.widget) root.widget.openLink(histRow.modelData.url)
                            }

                            // save / unsave this song (on top of the row's click area)
                            FlatButton {
                                id: heartBtn
                                anchors.right: parent.right
                                anchors.rightMargin: Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                hPad: Style.space(8)
                                implicitHeight: Style.space(30)
                                text: !!root.widget && root.widget.isFavourite(histRow.modelData) ? "♥" : "♡"
                                selected: !!root.widget && root.widget.isFavourite(histRow.modelData)
                                foreground: root.fg
                                accent: root.accent
                                fontFamily: root.fontFamily
                                pixelSize: root.fsMain
                                onClicked: root.widget.toggleFavourite(histRow.modelData)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: historyList.count === 0
                            width: parent.width - Style.space(40)
                            text: root.historyView === "fav"
                                  ? "No favourites yet. Press ♡ next to a song to save it."
                                  : "No songs yet."
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: root.fsMain
                            horizontalAlignment: Text.AlignHCenter
                            textFormat: Text.PlainText
                        }
                    }
                }

                // SETTINGS (built from Settings.js: grouped, every option visible, applied at once)
                Flickable {
                    id: settingsFlick
                    contentHeight: settingsCol.implicitHeight + Style.space(24)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: settingsCol
                        width: settingsFlick.width
                        spacing: Style.space(8)

                        Text {
                            Layout.fillWidth: true
                            Layout.bottomMargin: Style.space(4)
                            text: root.cfg.theme === "follow" && root.widget && root.widget.omarchyNote
                                  ? "Changes apply straight away. " + root.widget.omarchyNote
                                  : "Changes apply straight away."
                            wrapMode: Text.Wrap
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: root.fsSub
                            textFormat: Text.PlainText
                        }

                        Repeater {
                            // built only while the panel is open (as Omatravel does), so no text field keeps focus after it closes
                            model: root.opened ? root.settingRows : []
                            delegate: Item {
                                id: row
                                required property var modelData
                                Layout.fillWidth: true
                                readonly property bool isHeader: modelData.type === "header"
                                readonly property int pad: Style.space(12)
                                readonly property real innerWidth: width - (isHeader ? 0 : pad * 2)
                                implicitHeight: content.implicitHeight + (isHeader ? 0 : pad * 2)

                                // a soft card behind each setting (group headers stay bare)
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !row.isHeader
                                    radius: Style.space(12)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                                    border.width: 1
                                    border.color: root.faint
                                }

                                // Each row kind is a component, chosen below.
                                Component {
                                    id: headerC
                                    Item {
                                        width: row.innerWidth
                                        height: Style.space(40)
                                        Text {
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: Style.space(4)
                                            text: row.modelData.label.toUpperCase()
                                            color: root.accent
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fsSub
                                            font.bold: true
                                            font.letterSpacing: 1
                                            textFormat: Text.PlainText
                                        }
                                    }
                                }

                                Component {
                                    id: labelsC
                                    // label and description, with room on the right for a control
                                    Column {
                                        width: row.innerWidth
                                        spacing: Style.space(2)
                                        Text {
                                            width: parent.width
                                            text: row.modelData.label
                                            color: root.fg
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fsMain
                                            wrapMode: Text.Wrap
                                            textFormat: Text.PlainText
                                        }
                                        Text {
                                            width: parent.width
                                            text: row.modelData.description
                                            color: root.dim
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fsSub
                                            wrapMode: Text.Wrap
                                            textFormat: Text.PlainText
                                        }
                                    }
                                }

                                // on / off: both options visible, the active one filled
                                Component {
                                    id: boolC
                                    Item {
                                        width: row.innerWidth
                                        height: Math.max(labelBlock.height, Style.space(34)) + Style.space(12)
                                        Loader { id: labelBlock; sourceComponent: labelsC; width: parent.width - Style.space(150); anchors.verticalCenter: parent.verticalCenter }
                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Style.space(6)
                                            Repeater {
                                                model: [{ v: false, t: "Off" }, { v: true, t: "On" }]
                                                delegate: FlatButton {
                                                    id: onOff
                                                    required property var modelData
                                                    outlined: true
                                                    selected: (root.cfg[row.modelData.key] === true) === onOff.modelData.v
                                                    implicitHeight: Style.space(30)
                                                    width: Style.space(64)
                                                    text: onOff.modelData.t
                                                    foreground: root.fg
                                                    accent: root.accent
                                                    fontFamily: root.fontFamily
                                                    pixelSize: root.fsSub
                                                    onClicked: root.widget.setValue(row.modelData.key, onOff.modelData.v)
                                                }
                                            }
                                        }
                                    }
                                }

                                // a number with − and +, and its unit
                                Component {
                                    id: intC
                                    Item {
                                        width: row.innerWidth
                                        height: Math.max(labelBlock2.height, Style.space(34)) + Style.space(12)
                                        Loader { id: labelBlock2; sourceComponent: labelsC; width: parent.width - Style.space(190); anchors.verticalCenter: parent.verticalCenter }
                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Style.space(6)
                                            FlatButton {
                                                text: "−"
                                                outlined: true
                                                implicitHeight: Style.space(30)
                                                hPad: Style.space(12)
                                                foreground: root.fg
                                                accent: root.accent
                                                fontFamily: root.fontFamily
                                                pixelSize: root.fsMain
                                                onClicked: root.widget.setValue(row.modelData.key,
                                                    root.cfg[row.modelData.key] - (row.modelData.step || 1))
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Style.space(60)
                                                horizontalAlignment: Text.AlignHCenter
                                                text: String(root.cfg[row.modelData.key]) + (row.modelData.unit ? " " + row.modelData.unit : "")
                                                color: root.fg
                                                font.family: root.fontFamily
                                                font.pixelSize: root.fsMain
                                                textFormat: Text.PlainText
                                            }
                                            FlatButton {
                                                text: "+"
                                                outlined: true
                                                implicitHeight: Style.space(30)
                                                hPad: Style.space(12)
                                                foreground: root.fg
                                                accent: root.accent
                                                fontFamily: root.fontFamily
                                                pixelSize: root.fsMain
                                                onClicked: root.widget.setValue(row.modelData.key,
                                                    root.cfg[row.modelData.key] + (row.modelData.step || 1))
                                            }
                                        }
                                    }
                                }

                                // a choice: every option is a button, the current one is filled
                                Component {
                                    id: enumC
                                    Column {
                                        width: row.innerWidth
                                        spacing: Style.space(8)
                                        Loader { sourceComponent: labelsC; width: parent.width }
                                        Flow {
                                            width: parent.width
                                            spacing: Style.space(6)
                                            Repeater {
                                                model: row.modelData.options
                                                delegate: FlatButton {
                                                    id: choice
                                                    required property string modelData
                                                    outlined: true
                                                    selected: root.cfg[row.modelData.key] === choice.modelData
                                                    implicitHeight: Style.space(30)
                                                    text: root.labelFor(row.modelData, choice.modelData)
                                                    foreground: root.fg
                                                    accent: root.accent
                                                    fontFamily: root.fontFamily
                                                    pixelSize: root.fsSub
                                                    onClicked: root.widget.setValue(row.modelData.key, choice.modelData)
                                                }
                                            }
                                        }
                                    }
                                }

                                // the bar icon: typed text, saved as you type
                                Component {
                                    id: textC
                                    Column {
                                        width: row.innerWidth
                                        spacing: Style.space(8)
                                        Loader { sourceComponent: labelsC; width: parent.width }
                                        FieldBox {
                                            id: iconBox
                                            width: Style.space(160)
                                            height: Style.space(32)
                                            placeholderText: row.modelData.defaultValue
                                            foreground: root.fg
                                            accent: root.accent
                                            fontFamily: root.fontFamily
                                            pixelSize: root.fsMain
                                            text: String(root.cfg[row.modelData.key] !== undefined ? root.cfg[row.modelData.key] : "")
                                            // Only react to real typing. The field's binding also
                                            // updates when `cfg` changes for unrelated reasons, and
                                            // saving those values back would loop.
                                            onTextChanged: if (focused) root.widget.setValue(row.modelData.key, text)
                                        }
                                    }
                                }

                                // custom colours: pick a role, then a swatch or a hex code
                                Component {
                                    id: paletteC
                                    Column {
                                        width: row.innerWidth
                                        spacing: Style.space(10)
                                        Loader { sourceComponent: labelsC; width: parent.width }

                                        Flow {
                                            width: parent.width
                                            spacing: Style.space(6)
                                            Repeater {
                                                model: root.colorRoles
                                                delegate: FlatButton {
                                                    id: roleBtn
                                                    required property var modelData
                                                    outlined: true
                                                    selected: root.colorRole === roleBtn.modelData.key
                                                    implicitHeight: Style.space(30)
                                                    text: roleBtn.modelData.label
                                                    dotColor: String(root.cfg[roleBtn.modelData.key])
                                                    foreground: root.fg
                                                    accent: root.accent
                                                    fontFamily: root.fontFamily
                                                    pixelSize: root.fsSub
                                                    // No need to touch hexField: its text binding
                                                    // depends on root.colorRole and re-evaluates.
                                                    onClicked: root.colorRole = roleBtn.modelData.key
                                                }
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            spacing: Style.space(8)
                                            Rectangle {
                                                width: Style.space(32)
                                                height: Style.space(32)
                                                radius: Style.space(6)
                                                color: String(root.cfg[root.colorRole])
                                                border.width: 1
                                                border.color: root.faint
                                            }
                                            FieldBox {
                                                id: hexField
                                                width: parent.width - Style.space(40)
                                                height: Style.space(32)
                                                placeholderText: "#rrggbb"
                                                foreground: root.fg
                                                accent: root.accent
                                                fontFamily: root.fontFamily
                                                pixelSize: root.fsMain
                                                text: String(root.cfg[root.colorRole] !== undefined ? root.cfg[root.colorRole] : "")
                                                // Only save real typing. The binding above also
                                                // updates the text whenever `cfg` changes, which
                                                // happens on every setValue; without this guard, the
                                                // field would re-save the same value on each update,
                                                // rebuilding `cfg` and re-colouring the whole panel.
                                                onTextChanged: {
                                                    if (!focused) return
                                                    var v = text.trim()
                                                    if (/^#[0-9a-fA-F]{6}$/.test(v)) root.widget.setValue(root.colorRole, v.toLowerCase())
                                                }
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: Style.space(5)
                                            Repeater {
                                                model: Settings.PALETTE
                                                delegate: Rectangle {
                                                    id: swatch
                                                    required property string modelData
                                                    width: Style.space(26)
                                                    height: Style.space(26)
                                                    radius: Style.space(6)
                                                    color: swatch.modelData
                                                    border.width: String(root.cfg[root.colorRole]).toLowerCase() === swatch.modelData ? 2 : 1
                                                    border.color: String(root.cfg[root.colorRole]).toLowerCase() === swatch.modelData
                                                        ? root.accent : root.faint
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        // setValue updates cfg; the hex field's
                                                        // text binding follows on its own, so no
                                                        // imperative write here.
                                                        onClicked: root.widget.setValue(root.colorRole, swatch.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Component {
                                    id: unknownC
                                    Item { width: row.innerWidth; height: 0 }
                                }

                                Loader {
                                    id: content
                                    width: row.innerWidth
                                    x: row.isHeader ? 0 : row.pad
                                    y: row.isHeader ? 0 : row.pad
                                    sourceComponent: row.modelData.type === "header" ? headerC
                                                   : row.modelData.type === "palette" ? paletteC
                                                   : row.modelData.type === "boolean" ? boolC
                                                   : row.modelData.type === "integer" ? intC
                                                   : row.modelData.type === "enum" ? enumC
                                                   : row.modelData.type === "string" ? textC
                                                   : unknownC
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // keep the popup in sync with the controller, and vice versa
    //
    // The popup used to be driven by a plain binding (`open: root.opened`).
    // That binding is broken the moment the compositor dismisses the popup on
    // a click outside: the compositor sets `open` imperatively, and from then
    // on `controller.show()` no longer reaches the popup, so the panel never
    // comes back until the shell is restarted.
    //
    // Driving `open` from `opened` through a signal, and telling the
    // controller when the popup closes on its own, survives that.

    // 1) When the controller's `opened` changes, push it to the popup.
    Connections {
        target: root
        function onOpenedChanged() { panel.open = root.opened }
    }

    // 2) When the popup closes itself (compositor click-outside), let the
    //    controller know, so `opened` and the controller's internal state
    //    go back to false and the next `show()` is a real transition.
    Connections {
        target: panel
        function onOpenChanged() {
            if (!panel.open && root.opened)
                root.controller.hide()
        }
    }
}
