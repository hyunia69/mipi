import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root

    property string text: ""
    property bool isGradient: false
    property int fontSize: Theme.fontBody
    property bool active: true

    signal clicked()

    width: 200
    height: Theme.buttonHeight
    opacity: active ? 1.0 : 0.4

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.buttonRadius
        color: root.isGradient ? "transparent" : (Theme.isMinimal ? Theme.surfaceColor : (Theme.isFuture ? Qt.rgba(0.1, 0.2, 0.4, 0.3) : Theme.surfaceColor))
        border.color: root.isGradient ? "transparent" : (Theme.isFuture ? Theme.futureCyan : Theme.glassBorder)
        border.width: root.isGradient ? 0 : (Theme.isFuture ? 2 : 1)
        clip: true
        layer.enabled: Theme.isFuture // Ensures rounded clipping for internal effects

        // Gradient background for Holo or Gradient buttons
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.isGradient || (Theme.isFuture && !root.isGradient)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.isFuture ? Theme.futureViolet : Theme.ctaStart }
                GradientStop { position: 0.5; color: Theme.isFuture ? Theme.futureMagenta : (root.isGradient ? Theme.ctaStart : Theme.ctaEnd) }
                GradientStop { position: 1.0; color: Theme.isFuture ? Theme.futureCyan : Theme.ctaEnd }
            }
        }

        // Animated chrome/liquid highlight for Future
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: Theme.isFuture
            opacity: 0.4
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.6) }
                GradientStop { position: 0.2; color: "transparent" }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 0.8; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.2) }
            }
        }

        Rectangle {
            id: liquidWave
            width: parent.width * 2
            height: parent.height
            x: -parent.width
            visible: Theme.isFuture
            opacity: 0.3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: "white" }
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on x {
                running: Theme.isFuture
                from: -root.width * 2; to: root.width * 2; duration: 3000; loops: Animation.Infinite
            }
        }

        // Top highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, Theme.isMinimal ? 0.08 : 0.15)
        }

        Text {
            anchors.centerIn: parent
            text: root.text
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            font.weight: (Theme.isMinimal || Theme.isFuture) ? Font.Bold : Font.DemiBold
            font.letterSpacing: root.isGradient ? (Theme.isMinimal ? 2 : 4) : (Theme.isFuture ? 3 : (Theme.isMinimal ? 0 : 1))
        }

        Rectangle {
            id: ripple
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.1)
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    MultiEffect {
        source: body
        anchors.fill: body
        anchors.margins: Theme.isFuture ? -32 : 0 // Prevents glow clipping
        enabled: Theme.enableEffects && (root.isGradient || Theme.isMinimal || Theme.isFuture)
        visible: enabled
        shadowEnabled: true
        shadowBlur: Theme.isMinimal ? 0.4 : (Theme.isFuture ? 0.8 : Theme.shadowBlurSoft)
        shadowColor: Theme.isFuture ? Qt.rgba(255/255, 0/255, 229/255, 0.6) : (root.isGradient ? Qt.rgba(0.55, 0.44, 0.98, 0.4) : Qt.rgba(0, 0, 0, 0.3))
        shadowVerticalOffset: Theme.isMinimal ? 4 : (Theme.isFuture ? 8 : Theme.shadowOffsetMd)
        shadowHorizontalOffset: 0
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active
        onPressed: {
            root.scale = 0.97
            ripple.opacity = 1
        }
        onReleased: {
            root.scale = 1.0
            ripple.opacity = 0
        }
        onCanceled: {
            root.scale = 1.0
            ripple.opacity = 0
        }
        onClicked: root.clicked()
    }

    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
}
