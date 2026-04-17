import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root
    width: 440

    property bool isOpen: false
    property string landmarkName: ""
    property string landmarkNameEn: ""
    property string description: ""
    property string history: ""
    property string distance: ""
    property string direction: ""
    property string altitude: ""
    property color thumbColor: "#2D6A4F"
    property url heroSource

    signal closeRequested()

    x: isOpen ? parent.width - width : parent.width
    Behavior on x {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        color: Qt.rgba(13/255, 17/255, 23/255, 0.95)
        border.color: Theme.glassBorder
        border.width: 1
        layer.enabled: Theme.enableEffects

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(0.13, 0.83, 0.93, 0.18)
        }

        Flickable {
            anchors.fill: parent
            contentHeight: content.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: parent.width

                Rectangle {
                    id: heroBox
                    width: parent.width
                    height: 240
                    color: root.thumbColor
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.heroSource
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 880
                        sourceSize.height: 480
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 110
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(13/255, 17/255, 23/255, 0.98) }
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingSM
                        width: 40; height: 40; radius: 20
                        color: Qt.rgba(0, 0, 0, 0.5)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            name: "x"
                            color: Theme.textSecondary
                            size: 18
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.closeRequested()
                        }
                    }
                }

                Column {
                    width: parent.width - Theme.spacingMD * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingSM
                    topPadding: Theme.spacingXS

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

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    Text {
                        width: parent.width
                        text: root.description
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        wrapMode: Text.Wrap
                        lineHeight: 1.6
                    }

                    Row {
                        spacing: Theme.spacingMD
                        topPadding: Theme.spacingXS

                        Column {
                            spacing: 4
                            Row {
                                spacing: 6
                                Icon { name: "map-pin"; color: Theme.textMuted; size: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "DISTANCE"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { text: root.distance; color: Theme.holoTeal; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                        }
                        Rectangle { width: 1; height: 40; color: Qt.rgba(1,1,1,0.08); anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 4
                            Row {
                                spacing: 6
                                Icon { name: "compass"; color: Theme.textMuted; size: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "DIRECTION"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { text: root.direction; color: Theme.holoTeal; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                        }
                        Rectangle { width: 1; height: 40; color: Qt.rgba(1,1,1,0.08); anchors.verticalCenter: parent.verticalCenter; visible: root.altitude !== "" }
                        Column {
                            spacing: 4
                            visible: root.altitude !== ""
                            Row {
                                spacing: 6
                                Icon { name: "mountain"; color: Theme.textMuted; size: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "ALTITUDE"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { text: root.altitude; color: Theme.holoTeal; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        topPadding: Theme.spacingSM
                        visible: root.history !== ""

                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                        Text {
                            text: "HISTORY"
                            color: Theme.amberWarm
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

                    Item { width: 1; height: Theme.spacingLG }
                }
            }
        }
    }

    MultiEffect {
        source: body
        anchors.fill: body
        enabled: Theme.enableEffects
        visible: enabled
        shadowEnabled: true
        shadowBlur: Theme.shadowBlurDeep
        shadowColor: Qt.rgba(0, 0, 0, 0.75)
        shadowHorizontalOffset: -Theme.shadowOffsetLg
        shadowVerticalOffset: 0
    }
}
