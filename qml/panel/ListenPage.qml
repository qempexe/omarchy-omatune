import QtQuick
import QtQuick.Layouts
import "../controls"

// The Listen tab: the Listen button, what Omatune is doing, and the last song.
Flickable {
    id: root

    property var ui: null
    readonly property var tune: ui ? ui.service : null
    readonly property var cfg: ui.cfgSafe
    readonly property var last: tune ? tune.last : null
    readonly property string sourceName: cfg.source === "microphone" ? "the microphone" : "this computer"

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: col.implicitHeight + ui.px(8)

    ColumnLayout {
        id: col
        width: root.width
        spacing: ui.px(12)

        // first run: SongRec is a separate package the user installs themselves
        Rectangle {
            Layout.fillWidth: true
            visible: !!root.tune && root.tune.recognizerMissing
            implicitHeight: setupCol.implicitHeight + ui.px(24)
            radius: ui.r(2)
            color: ui.accentTint(0.12)
            border.width: 1
            border.color: ui.accent
            ColumnLayout {
                id: setupCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ui.px(12)
                spacing: ui.px(8)
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    text: "Omatune needs SongRec to recognise songs."
                    font.pixelSize: ui.fs(12)
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    text: "Install the songrec package from your distribution's repositories, then press Recheck."
                    opacity: 0.7
                    wrapMode: Text.Wrap
                }
                Btn {
                    ui: root.ui
                    kind: "primary"
                    text: "Recheck"
                    implicitHeight: ui.px(28)
                    onClicked: root.tune.recheckRecognizer()
                }
            }
        }

        Btn {
            ui: root.ui
            Layout.fillWidth: true
            implicitHeight: ui.px(38)
            kind: "primary"
            enabled: !!root.tune && !root.tune.continuous && !root.tune.recognizerMissing
                     && (root.tune.phase === "idle" || root.tune.phase === "error")
            text: !root.tune ? ""
                : root.tune.phase === "listening" ? "Listening…  " + root.tune.secondsLeft + " s"
                : root.tune.phase === "identifying" ? "Identifying…"
                : "Listen for " + root.cfg.duration + " s"
            onClicked: root.tune.listen()
        }

        Txt {
            ui: root.ui
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            readonly property bool failed: !!root.tune && root.tune.phase === "error"
            color: failed ? ui.bad : ui.fg
            opacity: failed ? 1 : 0.6
            text: !root.tune ? ""
                : failed ? root.tune.errorText
                : root.tune.continuous
                  ? "Continuous: " + (root.tune.phase === "identifying" ? "identifying…" : "listening to " + root.sourceName + "…")
                  : "Listening to " + root.sourceName + ". Turn on the switch above for continuous listening: songs are identified one after another, and a repeat is not logged twice."
        }

        // the last song
        Rectangle {
            Layout.fillWidth: true
            visible: !!root.last
            implicitHeight: resultCol.implicitHeight + ui.px(24)
            radius: ui.r(2.5)
            color: ui.cardFill(false)
            border.width: ui.cardBorder
            border.color: ui.tint(0.12)

            ColumnLayout {
                id: resultCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ui.px(12)
                spacing: ui.px(12)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(14)

                    Rectangle {
                        visible: root.cfg.showCover
                        Layout.preferredWidth: ui.px(96)
                        Layout.preferredHeight: ui.px(96)
                        Layout.alignment: Qt.AlignTop
                        radius: ui.r(2)
                        color: ui.tint(0.08)
                        clip: true

                        Image {
                            id: thumb
                            anchors.fill: parent
                            // only the clean local copy of the cover, never the address itself
                            source: {
                                const t = root.tune
                                const p = t && root.last && root.last.cover ? t.covers.pathFor(root.last.cover) : ""
                                return p ? "file://" + p : ""
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 192
                            sourceSize.height: 192
                        }
                        Txt {
                            ui: root.ui
                            anchors.centerIn: parent
                            visible: thumb.status !== Image.Ready
                            text: root.cfg.barIcon
                            opacity: 0.5
                            font.pixelSize: ui.fs(34)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: ui.px(4)
                        Txt {
                            ui: root.ui
                            Layout.fillWidth: true
                            text: root.last ? root.last.title : ""
                            font.pixelSize: ui.fs(15)
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Txt {
                            ui: root.ui
                            Layout.fillWidth: true
                            text: root.last ? root.last.artist : ""
                            font.pixelSize: ui.fs(12)
                            wrapMode: Text.Wrap
                        }
                        Txt {
                            ui: root.ui
                            Layout.fillWidth: true
                            visible: !!root.last && root.last.album !== ""
                            text: root.last ? root.last.album : ""
                            opacity: 0.6
                            wrapMode: Text.Wrap
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(8)
                    Btn {
                        ui: root.ui
                        visible: !!root.last && root.last.url !== ""
                        implicitHeight: ui.px(28)
                        text: "Open on Shazam ↗"
                        onClicked: root.tune.openLink(root.last.url)
                    }
                    Btn {
                        ui: root.ui
                        implicitHeight: ui.px(28)
                        readonly property bool saved: !!root.last && !!root.tune && root.tune.isFavourite(root.last)
                        active: saved
                        text: saved ? "♥ Saved" : "♡ Save"
                        onClicked: root.tune.toggleFavourite(root.last)
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Txt {
            ui: root.ui
            Layout.fillWidth: true
            Layout.topMargin: ui.px(16)
            visible: !root.last
            text: "Play a song, then press Listen. The result shows here, in the bar and as a notification."
            opacity: 0.55
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
