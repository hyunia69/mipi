import QtQuick
import ".."

Rectangle {
    id: root
    color: Qt.rgba(1, 1, 1, 0.06)
    border.color: Theme.glassBorder
    border.width: 1
    radius: Theme.panelRadius

    // Top edge highlight for depth
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
        radius: parent.radius
    }

    // Inner subtle gradient for glass depth
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
