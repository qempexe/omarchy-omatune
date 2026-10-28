import QtQuick
import QtQuick.Layouts
import "../controls"

// The History tab: every song found, or only the saved ones.
Item {
    id: root

    property var ui: null
    readonly property var tune: ui ? ui.service : null
    readonly property bool favs: ui.historyView === "fav"

    ColumnLayout {
        anchors.fill: parent
        spacing: ui.px(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: ui.px(6)
            Chip {
                ui: root.ui
                label: "All"
                count: root.tune ? root.tune.history.length : 0
                on: !root.favs
                onClicked: ui.historyView = "all"
            }
            Chip {
                ui: root.ui
                label: "♥ Favourites"
                count: root.tune ? root.tune.favourites.length : 0
                on: root.favs
                onClicked: ui.historyView = "fav"
            }
            Item { Layout.fillWidth: true }
            Btn {
                ui: root.ui
                visible: !root.favs && !!root.tune && root.tune.history.length > 0
                kind: confirm ? "danger" : "normal"
                property bool confirm: false
                text: confirm ? "Really clear?" : "Clear"
                onClicked: {
                    if (!confirm) { confirm = true; clearTimer.restart(); return }
                    confirm = false
                    root.tune.clearHistory()
                }
                Timer { id: clearTimer; interval: 2500; onTriggered: parent.confirm = false }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: ui.px(6)
            boundsBehavior: Flickable.StopAtBounds
            model: !root.tune ? [] : (root.favs ? root.tune.favourites : root.tune.history)

            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width
                height: ui.px(54)
                radius: ui.r(2)
                color: ui.cardFill(rowArea.containsMouse)
                border.width: ui.cardBorder
                border.color: ui.tint(0.12)

                Column {
                    anchors.left: parent.left
                    anchors.right: heart.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: ui.px(12)
                    anchors.rightMargin: ui.px(8)
                    spacing: ui.px(3)
                    Txt {
                        ui: root.ui
                        width: parent.width
                        text: row.modelData.title
                        font.pixelSize: ui.fs(12)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Txt {
                        ui: root.ui
                        width: parent.width
                        text: row.modelData.artist + (row.modelData.url ? "  ·  open ↗" : "")
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (row.modelData.url && root.tune) root.tune.openLink(row.modelData.url)
                }
                // save or unsave this song (above the row's click area)
                Btn {
                    id: heart
                    ui: root.ui
                    anchors.right: parent.right
                    anchors.rightMargin: ui.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: ui.px(30)
                    implicitHeight: ui.px(28)
                    readonly property bool saved: !!root.tune && root.tune.isFavourite(row.modelData)
                    active: saved
                    text: saved ? "♥" : "♡"
                    onClicked: root.tune.toggleFavourite(row.modelData)
                }
            }

            Txt {
                ui: root.ui
                anchors.centerIn: parent
                width: parent.width - ui.px(40)
                visible: list.count === 0
                text: root.favs ? "No favourites yet. Press ♡ next to a song to save it." : "No songs yet."
                opacity: 0.55
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
