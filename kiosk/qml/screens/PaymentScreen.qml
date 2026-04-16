import QtQuick
import ".."
import "../components"

Item {
    id: root

    signal paymentCompleted()
    signal cancelled()

    Rectangle { anchors.fill: parent; color: Theme.backgroundColor }

    // Decorative background circles
    Rectangle {
        x: -120; y: -120; width: 400; height: 400; radius: 200
        color: Qt.rgba(59, 130, 246, 0.04)
    }
    Rectangle {
        x: parent.width - 200; y: parent.height - 280; width: 500; height: 500; radius: 250
        color: Qt.rgba(139, 92, 246, 0.04)
    }

    // Center glass panel
    GlassPanel {
        id: panel
        width: 520
        height: contentColumn.height + Theme.spacingXL * 2
        anchors.centerIn: parent
        radius: Theme.panelRadius

        Column {
            id: contentColumn
            width: parent.width - Theme.spacingXL * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingXL
            spacing: Theme.spacingMD

            // Title
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "VIEWING FEE"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
                font.letterSpacing: 4
            }

            // Price
            Item {
                width: parent.width
                height: 80
                Text {
                    id: priceNum
                    anchors.centerIn: parent
                    text: "1,000"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 72
                    font.weight: Font.Bold
                }
                Text {
                    anchors.left: priceNum.right
                    anchors.leftMargin: 6
                    anchors.baseline: priceNum.baseline
                    text: "KRW"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeading
                    font.letterSpacing: 2
                }
            }

            // Duration badge
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: durationText.width + 32
                height: 36
                radius: 18
                color: Qt.rgba(245, 158, 11, 0.15)
                border.color: Qt.rgba(245, 158, 11, 0.3)
                border.width: 1

                Text {
                    id: durationText
                    anchors.centerIn: parent
                    text: "3 MIN"
                    color: Theme.accentColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                }
            }

            // Divider
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

            // Card illustration
            Item {
                width: parent.width
                height: 180

                Rectangle {
                    id: cardIllust
                    width: 220; height: 140; radius: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#667eea" }
                        GradientStop { position: 1.0; color: "#764ba2" }
                    }

                    // EMV chip
                    Rectangle {
                        x: 28; y: 32; width: 42; height: 32; radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#F59E0B" }
                            GradientStop { position: 1.0; color: "#D97706" }
                        }
                        // Chip lines
                        Rectangle { x: 0; y: 10; width: parent.width; height: 1; color: Qt.rgba(0,0,0,0.15) }
                        Rectangle { x: 0; y: 21; width: parent.width; height: 1; color: Qt.rgba(0,0,0,0.15) }
                        Rectangle { x: 14; y: 0; width: 1; height: parent.height; color: Qt.rgba(0,0,0,0.1) }
                        Rectangle { x: 28; y: 0; width: 1; height: parent.height; color: Qt.rgba(0,0,0,0.1) }
                    }

                    // Card details
                    Rectangle { x: 28; y: 86; width: 90; height: 2; radius: 1; color: Qt.rgba(1,1,1,0.25) }
                    Rectangle { x: 28; y: 96; width: 140; height: 2; radius: 1; color: Qt.rgba(1,1,1,0.15) }
                    Rectangle { x: 28; y: 106; width: 60; height: 2; radius: 1; color: Qt.rgba(1,1,1,0.1) }

                    // Contactless icon
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        spacing: 3
                        Repeater {
                            model: 3
                            Rectangle {
                                width: 12 + index * 6
                                height: 2
                                radius: 1
                                color: Qt.rgba(1, 1, 1, 0.3 - index * 0.08)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // Floating animation
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        NumberAnimation { to: 12; duration: 2200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 28; duration: 2200; easing.type: Easing.InOutSine }
                    }

                    // Subtle shadow
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                        width: parent.width * 0.7
                        height: 6
                        radius: 3
                        color: Qt.rgba(0, 0, 0, 0.3)
                        opacity: 0.5
                    }
                }
            }

            // Instruction text
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Tap your card on the reader"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
            }

            Item { width: 1; height: Theme.spacingXS }

            // Action buttons
            TouchButton {
                width: parent.width
                text: "PAY NOW"
                isGradient: true
                fontSize: Theme.fontBody
                onClicked: root.paymentCompleted()
            }

            TouchButton {
                width: parent.width
                text: "CANCEL"
                fontSize: Theme.fontBody
                onClicked: root.cancelled()
            }
        }
    }

    // Fade-in
    opacity: 0
    NumberAnimation {
        id: fadeIn
        target: root; property: "opacity"
        from: 0; to: 1; duration: 400
        easing.type: Easing.OutCubic
    }
    Component.onCompleted: fadeIn.start()
}
