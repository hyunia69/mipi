import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root
    width: 240
    height: Theme.isMinimal ? 220 : (Theme.isFuture ? 240 : 200)

    property string name: ""
    property string distance: ""
    property string direction: ""
    property color thumbColor: "#2D6A4F"
    property url thumbSource

    signal clicked()

    // 3D Tilt calculation
    readonly property real maxTilt: 12
    property real tiltX: 0
    property real tiltY: 0

    transform: [
        Rotation {
            id: rotX
            axis.x: 1; axis.y: 0; axis.z: 0
            angle: root.tiltX
            origin.x: root.width / 2
            origin.y: root.height / 2
        },
        Rotation {
            id: rotY
            axis.x: 0; axis.y: 1; axis.z: 0
            angle: root.tiltY
            origin.x: root.width / 2
            origin.y: root.height / 2
        }
    ]

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.surfaceColor
        border.color: mouseArea.containsMouse
            ? (Theme.isMinimal ? Theme.textPrimary : (Theme.isFuture ? Theme.futureMagenta : Qt.rgba(0.13, 0.83, 0.93, 0.55)))
            : Theme.glassBorder
        border.width: Theme.isFuture ? (mouseArea.containsMouse ? 2 : 1) : 1
        clip: true
        layer.enabled: Theme.enableEffects

        // Future background pattern
        Rectangle {
            anchors.fill: parent
            visible: Theme.isFuture
            color: "transparent"
            opacity: 0.1
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.strokeStyle = Theme.futureCyan;
                    ctx.lineWidth = 0.5;
                    for(var i=0; i<width; i+=20) {
                        ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, height); ctx.stroke();
                    }
                    for(var j=0; j<height; j+=20) {
                        ctx.beginPath(); ctx.moveTo(0, j); ctx.lineTo(width, j); ctx.stroke();
                    }
                }
            }
        }

        Rectangle {
            id: thumb
            width: parent.width
            height: Theme.isMinimal ? 140 : (Theme.isFuture ? 150 : 120)
            color: root.thumbColor

            Image {
                id: thumbImage
                anchors.fill: parent
                source: root.thumbSource
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 480
                sourceSize.height: 320
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, Theme.isMinimal ? 0.6 : 0.4) }
                }
            }
            
            // Future accent line
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2
                color: Theme.futureMagenta
                visible: Theme.isFuture
                opacity: 0.8
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingSM
            spacing: 2

            Text {
                text: root.name
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.isFuture ? 20 : 18
                font.weight: Theme.isMinimal ? Font.Medium : Font.Bold
            }

            Row {
                spacing: 6
                Text { text: root.distance; color: Theme.isFuture ? Theme.futureCyan : Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSmall }
                Text { text: "|"; color: Qt.rgba(1, 1, 1, 0.15); font.pixelSize: Theme.fontSmall }
                Text { text: root.direction; color: Theme.isFuture ? Theme.futureCyan : Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSmall }
            }
        }

        Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
    }

    MultiEffect {
        source: body
        anchors.fill: body
        anchors.margins: -32 // Prevents shadow clipping
        enabled: Theme.enableEffects && (mouseArea.containsMouse || Theme.isFuture)
        visible: enabled
        shadowEnabled: true
        shadowBlur: mouseArea.containsMouse ? Theme.glowRadiusLg : Theme.glowRadiusSm
        shadowColor: Theme.isMinimal ? Qt.rgba(0, 0, 0, 0.5) : (Theme.isFuture ? Qt.rgba(168/255, 85/255, 247/255, 0.4) : Qt.rgba(0.13, 0.83, 0.93, 0.45))
        shadowVerticalOffset: Theme.isMinimal ? 8 : (Theme.isFuture ? 12 : Theme.shadowOffsetMd)
        shadowHorizontalOffset: 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: (mouse) => {
            if (Theme.enable3D) {
                var cx = width / 2;
                var cy = height / 2;
                var dx = mouse.x - cx;
                var dy = mouse.y - cy;
                root.tiltY = (dx / cx) * root.maxTilt;
                root.tiltX = -(dy / cy) * root.maxTilt;
            }
        }
        onExited: {
            root.tiltX = 0;
            root.tiltY = 0;
        }
        onPressed: root.scale = 0.96
        onReleased: root.scale = 1.0
        onCanceled: root.scale = 1.0
        onClicked: root.clicked()
    }

    Behavior on tiltX { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on tiltY { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
}
