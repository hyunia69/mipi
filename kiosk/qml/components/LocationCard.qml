import QtQuick
import ".."

Rectangle {
    id: root
    width: 240
    height: 200
    radius: Theme.cardRadius
    color: Theme.surfaceColor
    border.color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Theme.glassBorder
    border.width: 1
    clip: true

    property string name: ""
    property string distance: ""
    property string direction: ""
    property color thumbColor: "#2D6A4F"

    signal clicked()

    // Thumbnail
    Rectangle {
        id: thumb
        width: parent.width
        height: 120
        color: root.thumbColor

        // Subtle gradient overlay
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.8; color: Qt.rgba(0, 0, 0, 0.3) }
            }
        }

        // Small decorative dots (stars/lights)
        Repeater {
            model: 5
            Rectangle {
                x: Math.random() * (thumb.width - 4)
                y: Math.random() * (thumb.height * 0.5)
                width: 2; height: 2; radius: 1
                color: Qt.rgba(1, 1, 1, 0.4 + Math.random() * 0.3)
            }
        }
    }

    // Info section
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingSM
        spacing: 4

        Text {
            text: root.name
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Row {
            spacing: 6
            Text {
                text: root.distance
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
            Text {
                text: "|"
                color: Qt.rgba(1, 1, 1, 0.15)
                font.pixelSize: Theme.fontSmall
            }
            Text {
                text: root.direction
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onPressed: root.scale = 0.96
        onReleased: root.scale = 1.0
        onCanceled: root.scale = 1.0
        onClicked: root.clicked()
    }

    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.animNormal }
    }
}
