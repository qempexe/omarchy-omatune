import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// The About tab: the logo, the name and version, who made it, and where to find more
// plugins by the same author.
Item {
    id: root

    property color fg: "#e0e0e0"
    property color accent: "#aaaaaa"
    property string fontFamily: ""
    property bool lightSurface: false
    property string version: ""
    // the author's plugins, in one place. a fixed address, opened with xdg-open
    readonly property string moreUrl: "https://github.com/qempexe?tab=repositories&q=omarchy"

    function tint(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }
    function accentTint(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }

    // the version, read from the plugin's own manifest
    FileView {
        path: decodeURIComponent(Qt.resolvedUrl("manifest.json").toString().replace(/^file:\/\//, ""))
        onLoaded: {
            let v = ""
            try { v = String(JSON.parse(text()).version || "") } catch (e) { v = "" }
            root.version = /^[0-9A-Za-z.+-]{1,32}$/.test(v) ? v : ""
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -16
        spacing: 6

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            // the light logo on a dark panel, the dark one on a light panel
            source: Qt.resolvedUrl(root.lightSurface ? "assets/logo-dark.png" : "assets/logo.png")
            sourceSize.width: 192
            sourceSize.height: 192
            smooth: true
            mipmap: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            text: "OMATUNE"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 19
            font.weight: Font.DemiBold
            font.letterSpacing: 4
            textFormat: Text.PlainText
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.version !== ""
            text: "Version " + root.version
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1.5
            textFormat: Text.PlainText
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            Text { text: "made with "; color: root.fg; opacity: 0.75; font.family: root.fontFamily; font.pixelSize: 12; textFormat: Text.PlainText }
            Text {   // the system font: some fonts draw the heart as an outline
                textFormat: Text.PlainText
                text: "♥"
                color: root.accent
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text { text: " by qempexe"; color: root.fg; opacity: 0.75; font.family: root.fontFamily; font.pixelSize: 12; textFormat: Text.PlainText }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            implicitWidth: moreText.implicitWidth + 28
            implicitHeight: 30
            radius: 6
            color: moreArea.containsMouse ? root.accentTint(0.22) : root.tint(0.07)
            border.width: 1
            border.color: root.accentTint(moreArea.containsMouse ? 0.8 : 0.35)
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                id: moreText
                anchors.centerIn: parent
                text: "Check out my other plugins ↗"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: 11
                textFormat: Text.PlainText
            }
            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["xdg-open", root.moreUrl])
            }
        }
    }
}
