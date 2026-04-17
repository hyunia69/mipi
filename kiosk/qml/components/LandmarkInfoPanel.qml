import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root
    width: Theme.isMinimal ? 480 : 440

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
        NumberAnimation { 
            duration: Theme.isMinimal ? 600 : Theme.animNormal
            easing.type: Easing.OutCubic 
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        color: Theme.isMinimal ? Qt.rgba(0, 0, 0, 0.85) : Qt.rgba(13/255, 17/255, 23/255, 0.95)
        border.color: Theme.glassBorder
        border.width: 1

        layer.enabled: Theme.enableEffects
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: Theme.isMinimal ? 0.8 : Theme.shadowBlurDeep
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowHorizontalOffset: -10
            shadowVerticalOffset: 0
            autoPaddingEnabled: true
        }

        // Left accent border for Holo
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: Theme.holoTeal
            visible: !Theme.isMinimal
            opacity: 0.4
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
                    height: Theme.isMinimal ? 280 : 240
                    color: root.thumbColor
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.heroSource
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 960
                        sourceSize.height: 560
                        visible: status === Image.Ready
                        opacity: status === Image.Ready ? (Theme.isMinimal ? 0.8 : 1.0) : 0.0
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 120
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Theme.isMinimal ? Qt.rgba(0, 0, 0, 0.9) : Qt.rgba(13/255, 17/255, 23/255, 0.98) }
                        }
                    }

                    // Close button
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingSM
                        width: 44; height: 44; radius: 22
                        color: Qt.rgba(0, 0, 0, 0.5)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            name: "x"
                            color: Theme.textSecondary
                            size: 20
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.closeRequested()
                        }
                    }
                }

                Column {
                    width: parent.width - Theme.spacingLG * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingSM
                    topPadding: Theme.spacingXS

                    Text {
                        text: root.landmarkName
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.isMinimal ? 36 : Theme.fontTitle
                        font.weight: Font.Bold
                    }

                    Text {
                        text: root.landmarkNameEn
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.letterSpacing: Theme.isMinimal ? 1 : 2
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    Text {
                        width: parent.width
                        text: root.description
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        wrapMode: Text.Wrap
                        lineHeight: 1.6
                    }

                    Item { width: 1; height: Theme.spacingXS }

                    Row {
                        spacing: Theme.spacingLG
                        topPadding: Theme.spacingXS

                        Column {
                            spacing: 6
                            Row {
                                spacing: 6
                                Icon { name: "map-pin"; color: Theme.textMuted; size: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "DISTANCE"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.5; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { text: root.distance; color: Theme.primaryColor; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        }
                        
                        Column {
                            spacing: 6
                            Row {
                                spacing: 6
                                Icon { name: "compass"; color: Theme.textMuted; size: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "DIRECTION"; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.5; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { text: root.direction; color: Theme.primaryColor; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 10
                        topPadding: Theme.spacingSM
                        visible: root.history !== ""

                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

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
                            lineHeight: 1.55
                            opacity: 0.9
                        }
                    }

                    Item { width: 1; height: Theme.spacingXL }
                }
            }
        }
    }
}
