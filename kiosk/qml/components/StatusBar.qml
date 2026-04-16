import QtQuick
import ".."

Rectangle {
    id: root
    height: 56
    color: Qt.rgba(0, 0, 0, 0.4)

    property string locationName: "Seoul Namsan Observatory"

    // Left: location
    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingLG
        anchors.verticalCenter: parent.verticalCenter
        text: root.locationName
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
        font.weight: Font.Medium
        font.letterSpacing: 1
    }

    // Right: date and time
    Text {
        id: clockLabel
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingLG
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "yyyy. MM. dd    HH:mm")
        }
    }

    // Bottom separator
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }
}
