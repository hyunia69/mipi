import QtQuick
import ".."

Rectangle {
    id: root

    property string text: ""
    property bool isGradient: false
    property int fontSize: Theme.fontBody
    property bool active: true

    signal clicked()

    width: 200
    height: Theme.buttonHeight
    radius: Theme.buttonRadius
    color: isGradient ? "transparent" : Theme.surfaceColor
    border.color: isGradient ? "transparent" : Theme.glassBorder
    border.width: isGradient ? 0 : 1
    opacity: active ? 1.0 : 0.4
    clip: true

    // Gradient fill for CTA
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.isGradient
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.ctaStart }
            GradientStop { position: 1.0; color: Theme.ctaEnd }
        }
    }

    // Subtle top highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.15)
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: root.fontSize
        font.weight: Font.DemiBold
        font.letterSpacing: root.isGradient ? 4 : 1
    }

    // Ripple overlay on press
    Rectangle {
        id: ripple
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.08)
        opacity: 0
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

    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: Theme.animFast }
    }
}
