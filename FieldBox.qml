import QtQuick

// Minimal themed text input (no dependency on QtQuick.Controls or shell styles).
Rectangle {
    id: box

    property alias text: input.text
    property string placeholderText: ""
    property color foreground: "#e8dcc8"
    property color accent: "#d4a35a"
    property string fontFamily: ""
    property int pixelSize: 12
    readonly property bool focused: input.activeFocus

    signal accepted()

    function forceFocus() { input.forceActiveFocus() }
    function clear() { input.text = "" }

    implicitHeight: 34
    radius: 8
    color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
    border.width: 1
    border.color: focused ? accent : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        color: box.foreground
        selectionColor: box.accent
        selectedTextColor: "#101010"
        font.pixelSize: box.pixelSize
        font.family: box.fontFamily
        clip: true
        selectByMouse: true
        onAccepted: box.accepted()
    }

    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text.length === 0 && !input.activeFocus
        text: box.placeholderText
        color: Qt.rgba(box.foreground.r, box.foreground.g, box.foreground.b, 0.45)
        font.pixelSize: box.pixelSize
        font.family: box.fontFamily
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }
}
