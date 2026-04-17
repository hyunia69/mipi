import QtQuick
import ".."

Item {
    id: root
    anchors.fill: parent
    z: 500
    enabled: open

    property bool open: false
    property string remainingTime: ""

    signal continueRequested()
    signal endRequested()

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.open ? 0.72 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.continueRequested()
        }
    }

    Item {
        id: dialogHost
        anchors.centerIn: parent
        width: Theme.isFuture ? 640 : 560
        height: Theme.isFuture ? 360 : 320
        opacity: root.open ? 1 : 0
        scale: root.open ? 1.0 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        Rectangle {
            id: shadowBacker
            anchors.fill: body
            anchors.margins: -6
            anchors.topMargin: Theme.isFuture ? -4 : 10
            color: Qt.rgba(0, 0, 0, Theme.isFuture ? 0.3 : 0.45)
            radius: Theme.panelRadius + 6
            visible: !Theme.isFuture
            z: -1
        }

        GlassPanel {
            id: body
            anchors.fill: parent
            radius: Theme.panelRadius

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingLG
                spacing: Theme.spacingMD

                Row {
                    spacing: 14

                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: Qt.rgba(0.98, 0.75, 0.14, 0.15)
                        border.color: Qt.rgba(0.98, 0.75, 0.14, 0.35)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Icon {
                            anchors.centerIn: parent
                            name: "info"
                            color: Theme.amberWarm
                            size: 20
                        }
                    }

                    Text {
                        text: "End session?"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: "Remaining time " + root.remainingTime + ".  You can continue observing or end the session now."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                    lineHeight: 1.5
                }

                Item { width: 1; height: Theme.spacingXS }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.isFuture ? Theme.spacingLG : Theme.spacingSM

                    TouchButton {
                        width: Theme.isFuture ? 220 : 200; height: 56
                        text: "CONTINUE"
                        fontSize: Theme.fontCaption
                        isGradient: false
                        onClicked: root.continueRequested()
                    }

                    TouchButton {
                        width: Theme.isFuture ? 220 : 200; height: 56
                        text: "END NOW"
                        fontSize: Theme.fontCaption
                        isGradient: false
                        onClicked: root.endRequested()
                    }
                }
            }
        }
    }
}
