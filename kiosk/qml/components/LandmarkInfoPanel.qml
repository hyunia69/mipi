import QtQuick
import ".."

Rectangle {
    id: root
    width: 440
    color: Qt.rgba(13, 17, 23, 0.95)
    border.color: Theme.glassBorder
    border.width: 1

    property bool isOpen: false
    property string landmarkName: ""
    property string landmarkNameEn: ""
    property string description: ""
    property string history: ""
    property string distance: ""
    property string direction: ""
    property string altitude: ""
    property color thumbColor: "#2D6A4F"

    signal closeRequested()

    // Slide in/out animation
    x: isOpen ? parent.width - width : parent.width
    Behavior on x {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // Left edge highlight
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width

            // Header image area
            Rectangle {
                width: parent.width
                height: 240
                color: root.thumbColor

                // Gradient overlay
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 100
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(13, 17, 23, 0.95) }
                    }
                }

                // Close X button
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingSM
                    width: 40; height: 40; radius: 20
                    color: Qt.rgba(0, 0, 0, 0.5)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        color: Theme.textSecondary
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.closeRequested()
                    }
                }
            }

            // Content padding wrapper
            Column {
                width: parent.width - Theme.spacingMD * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSM
                topPadding: Theme.spacingXS

                // Name
                Text {
                    text: root.landmarkName
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.Bold
                }

                Text {
                    text: root.landmarkNameEn
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    font.letterSpacing: 1
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Description
                Text {
                    width: parent.width
                    text: root.description
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    wrapMode: Text.Wrap
                    lineHeight: 1.6
                }

                // Stats row
                Row {
                    spacing: Theme.spacingMD
                    topPadding: Theme.spacingXS

                    // Distance
                    Column {
                        spacing: 4
                        Text { text: "DISTANCE"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2 }
                        Text { text: root.distance; color: Theme.primaryColor; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                    }

                    // Separator
                    Rectangle { width: 1; height: 40; color: Qt.rgba(1,1,1,0.08); anchors.verticalCenter: parent.verticalCenter }

                    // Direction
                    Column {
                        spacing: 4
                        Text { text: "DIRECTION"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2 }
                        Text { text: root.direction; color: Theme.primaryColor; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                    }

                    // Separator
                    Rectangle { width: 1; height: 40; color: Qt.rgba(1,1,1,0.08); anchors.verticalCenter: parent.verticalCenter; visible: root.altitude !== "" }

                    // Altitude
                    Column {
                        spacing: 4
                        visible: root.altitude !== ""
                        Text { text: "ALTITUDE"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2 }
                        Text { text: root.altitude; color: Theme.primaryColor; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                    }
                }

                // History section
                Column {
                    width: parent.width
                    spacing: 8
                    topPadding: Theme.spacingSM
                    visible: root.history !== ""

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    Text {
                        text: "HISTORY"
                        color: Theme.accentColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                    }

                    Text {
                        width: parent.width
                        text: root.history
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        wrapMode: Text.Wrap
                        lineHeight: 1.5
                    }
                }

                // Bottom spacing
                Item { width: 1; height: Theme.spacingLG }
            }
        }
    }
}
