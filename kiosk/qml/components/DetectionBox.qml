import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root

    property string label: ""
    property real confidence: 0.95
    property bool selected: false

    signal tapped()

    Item {
        id: visualGroup
        anchors.fill: parent
        layer.enabled: Theme.enableEffects

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            color: "transparent"
            border.color: Qt.rgba(
                root.selected ? 0.98 : 0.13,
                root.selected ? 0.75 : 0.83,
                root.selected ? 0.14 : 0.93,
                0.30
            )
            border.width: 3
            radius: 6

            Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: root.selected ? Theme.amberWarm : Theme.holoTeal
            border.width: 2
            radius: 4

            Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
        }

        // Corner accents
        Rectangle { x: 0; y: 0; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal }
        Rectangle { x: 0; y: 0; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal }
        Rectangle { x: parent.width - 16; y: 0; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal }
        Rectangle { x: parent.width - 2; y: 0; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal }
        Rectangle { x: 0; y: parent.height - 2; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal }
        Rectangle { x: 0; y: parent.height - 16; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal }
        Rectangle { x: parent.width - 16; y: parent.height - 2; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal }
        Rectangle { x: parent.width - 2; y: parent.height - 16; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal }

        Rectangle {
            id: scanLine
            width: parent.width - 8
            height: 1
            x: 4
            color: Qt.rgba(
                root.selected ? 0.98 : 0.13,
                root.selected ? 0.75 : 0.83,
                root.selected ? 0.14 : 0.93,
                0.35
            )
            opacity: 0.7

            SequentialAnimation on y {
                loops: Animation.Infinite
                PropertyAnimation { from: 4; to: root.height - 4; duration: 3000; easing.type: Easing.InOutSine }
                PropertyAnimation { from: root.height - 4; to: 4; duration: 3000; easing.type: Easing.InOutSine }
            }
        }
    }

    MultiEffect {
        source: visualGroup
        anchors.fill: visualGroup
        enabled: Theme.enableEffects
        visible: enabled
        shadowEnabled: true
        shadowBlur: root.selected ? Theme.glowRadiusLg : Theme.glowRadiusSm
        shadowColor: root.selected ? Theme.amberWarm : Theme.holoTeal
        shadowVerticalOffset: 0
        shadowHorizontalOffset: 0
    }

    // Label tag (outside visualGroup, so glow doesn't blur it)
    Rectangle {
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        anchors.left: parent.left
        width: labelRow.width + 16
        height: 30
        radius: 6
        color: root.selected ? Theme.amberWarm : Theme.holoTeal

        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.label
                color: "#0B1220"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: Math.round(root.confidence * 100) + "%"
                color: Qt.rgba(0, 0, 0, 0.6)
                font.family: Theme.fontFamily
                font.pixelSize: 12
                visible: root.confidence > 0
            }
        }
    }

    SequentialAnimation on scale {
        running: root.selected
        loops: Animation.Infinite
        NumberAnimation { to: 1.03; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.00; duration: 900; easing.type: Easing.InOutSine }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        onClicked: root.tapped()
    }
}
