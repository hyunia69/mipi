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
        
        layer.enabled: Theme.enableEffects && !Theme.isMinimal
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: root.selected ? Theme.glowRadiusLg : Theme.glowRadiusSm
            shadowColor: root.selected ? Theme.amberWarm : Theme.holoTeal
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.isMinimal ? 0 : -3
            color: "transparent"
            border.color: Theme.isMinimal 
                ? (root.selected ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.4))
                : Qt.rgba(root.selected ? 0.98 : 0.13, root.selected ? 0.75 : 0.83, root.selected ? 0.14 : 0.93, 0.30)
            border.width: Theme.isMinimal ? 1 : 3
            radius: Theme.isMinimal ? 2 : 6

            Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: root.selected ? Theme.amberWarm : Theme.holoTeal
            border.width: Theme.isMinimal ? 0 : 2
            radius: 4
            visible: !Theme.isMinimal

            Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
        }

        // Corner accents - Hidden in Minimal
        Rectangle { x: 0; y: 0; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }
        Rectangle { x: 0; y: 0; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }
        Rectangle { x: parent.width - 16; y: 0; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }
        Rectangle { x: parent.width - 2; y: 0; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }
        Rectangle { x: 0; y: parent.height - 2; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }
        Rectangle { x: 0; y: parent.height - 16; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }
        Rectangle { x: parent.width - 16; y: parent.height - 2; width: 16; height: 2; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }
        Rectangle { x: parent.width - 2; y: parent.height - 16; width: 2; height: 16; color: root.selected ? Theme.amberWarm : Theme.holoTeal; visible: !Theme.isMinimal }

        Rectangle {
            id: scanLine
            width: parent.width - 8
            height: 1
            x: 4
            color: Qt.rgba(root.selected ? 0.98 : 0.13, root.selected ? 0.75 : 0.83, root.selected ? 0.14 : 0.93, 0.35)
            opacity: 0.7
            visible: !Theme.isMinimal

            SequentialAnimation on y {
                running: !Theme.isMinimal
                loops: Animation.Infinite
                PropertyAnimation { from: 4; to: root.height - 4; duration: 3000; easing.type: Easing.InOutSine }
                PropertyAnimation { from: root.height - 4; to: 4; duration: 3000; easing.type: Easing.InOutSine }
            }
        }
    }

    // Label tag
    Rectangle {
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.isMinimal ? 4 : 6
        anchors.left: parent.left
        width: labelRow.width + 12
        height: Theme.isMinimal ? 24 : 30
        radius: Theme.isMinimal ? 2 : 6
        color: Theme.isMinimal 
            ? (root.selected ? Theme.textPrimary : Qt.rgba(0, 0, 0, 0.7))
            : (root.selected ? Theme.amberWarm : Theme.holoTeal)
        
        border.color: Theme.isMinimal ? Theme.glassBorder : "transparent"
        border.width: Theme.isMinimal ? 1 : 0

        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.label
                color: Theme.isMinimal ? (root.selected ? "#000000" : "#FFFFFF") : "#0B1220"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.isMinimal ? 12 : 14
                font.weight: Theme.isMinimal ? Font.Medium : Font.DemiBold
            }

            Text {
                text: Math.round(root.confidence * 100) + "%"
                color: Theme.isMinimal ? (root.selected ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.5)) : Qt.rgba(0, 0, 0, 0.6)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.isMinimal ? 10 : 12
                visible: root.confidence > 0 && !Theme.isMinimal
            }
        }
    }

    SequentialAnimation on scale {
        running: root.selected
        loops: Animation.Infinite
        NumberAnimation { to: 1.02; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.00; duration: 1200; easing.type: Easing.InOutSine }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        onClicked: root.tapped()
    }
}
