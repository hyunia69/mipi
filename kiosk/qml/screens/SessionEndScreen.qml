import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root
    signal returnHome()

    Rectangle { anchors.fill: parent; color: Theme.backgroundColor }

    Rectangle {
        anchors.centerIn: parent
        width: 720; height: 720; radius: 360
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.13, 0.83, 0.93, 0.07) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Column {
        id: centerContent
        anchors.centerIn: parent
        spacing: Theme.spacingMD
        opacity: 0

        Item {
            id: telescopeIconHost
            width: 140; height: 140
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                id: telescopeIcon
                anchors.fill: parent
                layer.enabled: Theme.enableEffects

                Rectangle {
                    anchors.centerIn: parent
                    width: 92; height: 92; radius: 46
                    color: "transparent"
                    border.color: Theme.holoTeal
                    border.width: 2
                    opacity: 0.7
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 58; height: 58; radius: 29
                    color: "transparent"
                    border.color: Theme.holoTeal
                    border.width: 1.5
                    opacity: 0.5
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 22; height: 22; radius: 11
                    color: Theme.holoTeal
                    opacity: 0.35
                }

                Rectangle { anchors.centerIn: parent; width: 1;  height: 108; color: Qt.rgba(0.13, 0.83, 0.93, 0.35) }
                Rectangle { anchors.centerIn: parent; width: 108; height: 1;  color: Qt.rgba(0.13, 0.83, 0.93, 0.35) }

                RotationAnimation on rotation {
                    running: Theme.enableEffects
                    from: 0; to: 360
                    duration: 20000
                    loops: Animation.Infinite
                }
            }

            MultiEffect {
                source: telescopeIcon
                anchors.fill: telescopeIcon
                enabled: Theme.enableEffects
                visible: enabled
                shadowEnabled: true
                shadowBlur: Theme.glowRadiusLg
                shadowColor: Theme.holoTeal
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0

                SequentialAnimation on shadowOpacity {
                    running: Theme.enableEffects
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.55; duration: 1600; easing.type: Easing.InOutSine }
                }
            }
        }

        Item { width: 1; height: Theme.spacingSM }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Thank you for viewing"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontDisplay
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Returning to home screen shortly"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            topPadding: Theme.spacingMD

            Repeater {
                model: 4
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Theme.holoTeal
                    opacity: 0.2

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 400 }
                        NumberAnimation { to: 0.9; duration: 400 }
                        NumberAnimation { to: 0.2; duration: 400 }
                        PauseAnimation { duration: (3 - index) * 400 }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: fadeIn
        target: centerContent; property: "opacity"
        from: 0; to: 1; duration: 800
        easing.type: Easing.OutCubic
    }
    Component.onCompleted: fadeIn.start()

    Timer {
        interval: 5000
        running: true
        onTriggered: root.returnHome()
    }
}
