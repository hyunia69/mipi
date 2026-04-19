import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root

    property string primary: ""
    property string caption: ""
    property string leadingIcon: "telescope"
    property string trailingIcon: "chevron-right"
    property bool active: true

    signal clicked()

    implicitHeight: 96
    opacity: active ? 1.0 : 0.4

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.surfaceColor
        border.color: mouseArea.containsMouse
            ? (Theme.isFuture ? Theme.futureCyan : Qt.rgba(0.13, 0.83, 0.93, 0.55))
            : Theme.glassBorder
        border.width: 1

        layer.enabled: Theme.enableEffects && mouseArea.containsMouse
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: Theme.shadowBlurSoft
            shadowColor: Theme.isFuture ? Qt.rgba(168/255, 85/255, 247/255, 0.4) : Qt.rgba(0.55, 0.44, 0.98, 0.5)
            shadowVerticalOffset: Theme.shadowOffsetMd
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }

        Item {
            anchors.fill: parent
            clip: true
            
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                radius: body.radius
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Rectangle {
                anchors.fill: parent
                radius: body.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0.55, 0.44, 0.98, 0.10) }
                    GradientStop { position: 0.6; color: "transparent" }
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20

            Rectangle {
                id: iconHost
                width: 56; height: 56; radius: 28
                anchors.verticalCenter: parent.verticalCenter
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.ctaStart }
                    GradientStop { position: 1.0; color: Theme.cosmicPurple }
                }

                Icon {
                    anchors.centerIn: parent
                    name: root.leadingIcon
                    color: "#FFFFFF"
                    size: 26
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: root.primary
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeading
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                }

                Text {
                    text: root.caption
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.letterSpacing: 1
                    visible: root.caption.length > 0
                }
            }
        }

        Item {
            id: chevronHost
            width: 28; height: 28
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                id: chevron
                anchors.fill: parent
                name: root.trailingIcon
                color: Theme.holoTeal
                size: 28
            }

            SequentialAnimation on x {
                running: Theme.enableEffects && root.active
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 6; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 6; to: 0; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.active
        onPressed: root.scale = 0.98
        onReleased: root.scale = 1.0
        onCanceled: root.scale = 1.0
        onClicked: root.clicked()
    }

    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
}
