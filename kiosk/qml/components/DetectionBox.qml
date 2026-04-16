import QtQuick
import ".."

Item {
    id: root

    property string label: ""
    property real confidence: 0.95
    property bool selected: false

    signal tapped()

    // Outer glow border
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        color: "transparent"
        border.color: Qt.rgba(
            root.selected ? 0.96 : 0.23,
            root.selected ? 0.62 : 0.51,
            root.selected ? 0.07 : 0.96,
            0.25
        )
        border.width: 3
        radius: 6

        Behavior on border.color {
            ColorAnimation { duration: Theme.animNormal }
        }
    }

    // Main bounding box
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.selected ? Theme.accentColor : Theme.primaryColor
        border.width: 2
        radius: 4

        Behavior on border.color {
            ColorAnimation { duration: Theme.animNormal }
        }
    }

    // Corner accents (top-left)
    Rectangle { x: 0; y: 0; width: 16; height: 2; color: root.selected ? Theme.accentColor : Theme.primaryColor }
    Rectangle { x: 0; y: 0; width: 2; height: 16; color: root.selected ? Theme.accentColor : Theme.primaryColor }
    // Corner accents (top-right)
    Rectangle { x: parent.width - 16; y: 0; width: 16; height: 2; color: root.selected ? Theme.accentColor : Theme.primaryColor }
    Rectangle { x: parent.width - 2; y: 0; width: 2; height: 16; color: root.selected ? Theme.accentColor : Theme.primaryColor }
    // Corner accents (bottom-left)
    Rectangle { x: 0; y: parent.height - 2; width: 16; height: 2; color: root.selected ? Theme.accentColor : Theme.primaryColor }
    Rectangle { x: 0; y: parent.height - 16; width: 2; height: 16; color: root.selected ? Theme.accentColor : Theme.primaryColor }
    // Corner accents (bottom-right)
    Rectangle { x: parent.width - 16; y: parent.height - 2; width: 16; height: 2; color: root.selected ? Theme.accentColor : Theme.primaryColor }
    Rectangle { x: parent.width - 2; y: parent.height - 16; width: 2; height: 16; color: root.selected ? Theme.accentColor : Theme.primaryColor }

    // Label tag
    Rectangle {
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        anchors.left: parent.left
        width: labelRow.width + 16
        height: 30
        radius: 6
        color: root.selected ? Theme.accentColor : Theme.primaryColor

        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.label
                color: "#FFFFFF"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: Math.round(root.confidence * 100) + "%"
                color: Qt.rgba(1, 1, 1, 0.7)
                font.family: Theme.fontFamily
                font.pixelSize: 12
                visible: root.confidence > 0
            }
        }
    }

    // Scan line animation (subtle)
    Rectangle {
        id: scanLine
        width: parent.width - 8
        height: 1
        x: 4
        color: Qt.rgba(
            root.selected ? 0.96 : 0.23,
            root.selected ? 0.62 : 0.51,
            root.selected ? 0.07 : 0.96,
            0.3
        )
        opacity: 0.6

        SequentialAnimation on y {
            loops: Animation.Infinite
            PropertyAnimation { from: 4; to: root.height - 4; duration: 3000; easing.type: Easing.InOutSine }
            PropertyAnimation { from: root.height - 4; to: 4; duration: 3000; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        onClicked: root.tapped()
    }
}
