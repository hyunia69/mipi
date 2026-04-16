import QtQuick
import ".."

Item {
    id: root
    signal returnHome()

    Rectangle { anchors.fill: parent; color: Theme.backgroundColor }

    // Decorative radial gradient
    Rectangle {
        anchors.centerIn: parent
        width: 600; height: 600; radius: 300
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(59, 130, 246, 0.06) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Column {
        id: centerContent
        anchors.centerIn: parent
        spacing: Theme.spacingMD
        opacity: 0

        // Telescope icon (abstract geometric)
        Item {
            width: 120; height: 120
            anchors.horizontalCenter: parent.horizontalCenter

            // Lens circles
            Rectangle {
                anchors.centerIn: parent
                width: 80; height: 80; radius: 40
                color: "transparent"
                border.color: Theme.primaryColor
                border.width: 2
                opacity: 0.6
            }
            Rectangle {
                anchors.centerIn: parent
                width: 50; height: 50; radius: 25
                color: "transparent"
                border.color: Theme.primaryColor
                border.width: 1.5
                opacity: 0.4
            }
            Rectangle {
                anchors.centerIn: parent
                width: 20; height: 20; radius: 10
                color: Theme.primaryColor
                opacity: 0.3
            }

            // Crosshair
            Rectangle { anchors.centerIn: parent; width: 1; height: 90; color: Qt.rgba(59, 130, 246, 0.2) }
            Rectangle { anchors.centerIn: parent; width: 90; height: 1; color: Qt.rgba(59, 130, 246, 0.2) }

            // Subtle rotate animation
            RotationAnimation on rotation {
                from: 0; to: 360
                duration: 20000
                loops: Animation.Infinite
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

        // Progress dots
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            topPadding: Theme.spacingMD

            Repeater {
                model: 4
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Theme.primaryColor
                    opacity: 0.2

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 400 }
                        NumberAnimation { to: 0.8; duration: 400 }
                        NumberAnimation { to: 0.2; duration: 400 }
                        PauseAnimation { duration: (3 - index) * 400 }
                    }
                }
            }
        }
    }

    // Fade-in animation
    NumberAnimation {
        id: fadeIn
        target: centerContent; property: "opacity"
        from: 0; to: 1; duration: 800
        easing.type: Easing.OutCubic
    }
    Component.onCompleted: fadeIn.start()

    // Auto-return timer
    Timer {
        interval: 5000
        running: true
        onTriggered: root.returnHome()
    }
}
