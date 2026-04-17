import QtQuick
import ".."

Item {
    id: root

    property int count: 50
    property real topFraction: 0.55
    property color starColor: Theme.holoTeal

    Repeater {
        model: root.count
        Rectangle {
            readonly property real seed: Math.random()
            readonly property real size: 1 + Math.random() * 2.5
            x: Math.random() * root.width
            y: Math.random() * (root.height * root.topFraction)
            width: size
            height: size
            radius: size / 2
            color: Qt.rgba(
                root.starColor.r,
                root.starColor.g,
                root.starColor.b,
                0.35 + Math.random() * 0.45
            )

            SequentialAnimation on opacity {
                running: Theme.enableParticles
                loops: Animation.Infinite
                PauseAnimation { duration: Math.floor(Math.random() * 3500) }
                NumberAnimation { from: 1.0; to: 0.15; duration: 1400 + Math.floor(Math.random() * 1800); easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.15; to: 1.0; duration: 1400 + Math.floor(Math.random() * 1800); easing.type: Easing.InOutSine }
            }
        }
    }

    // Faint shooting-star streak across the upper band
    Rectangle {
        id: streak
        width: 120
        height: 1
        rotation: -18
        opacity: 0
        y: root.height * 0.2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: root.starColor }
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation {
            running: Theme.enableParticles
            loops: Animation.Infinite

            PauseAnimation { duration: 9000 + Math.floor(Math.random() * 6000) }
            ParallelAnimation {
                NumberAnimation { target: streak; property: "x"; from: -streak.width; to: root.width + streak.width; duration: 1400; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    NumberAnimation { target: streak; property: "opacity"; to: 0.7; duration: 300 }
                    PauseAnimation { duration: 700 }
                    NumberAnimation { target: streak; property: "opacity"; to: 0; duration: 400 }
                }
            }
        }
    }
}
