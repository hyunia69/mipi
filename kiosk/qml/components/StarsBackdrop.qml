import QtQuick
import ".."

Item {
    id: root

    property int count: 50
    property real topFraction: 0.55
    property color starColor: Theme.isFuture ? Theme.futureCyan : Theme.holoTeal

    // Stars
    Repeater {
        model: root.count
        Rectangle {
            readonly property real seed: Math.random()
            readonly property real size: (Theme.isFuture ? 1.5 : 1) + Math.random() * 2.5
            x: Math.random() * root.width
            y: Math.random() * (root.height * root.topFraction)
            width: size
            height: size
            radius: size / 2
            color: Theme.isFuture ? (seed > 0.5 ? Theme.futureCyan : Theme.futureMagenta) : root.starColor
            opacity: 0.35 + Math.random() * 0.45

            SequentialAnimation on opacity {
                running: Theme.enableParticles
                loops: Animation.Infinite
                PauseAnimation { duration: Math.floor(Math.random() * 3500) }
                NumberAnimation { to: 0.15; duration: 1400 + Math.floor(Math.random() * 1800); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.9; duration: 1400 + Math.floor(Math.random() * 1800); easing.type: Easing.InOutSine }
            }

            // Future theme slow drift
            NumberAnimation on x {
                running: Theme.isFuture && Theme.enableParticles
                from: x; to: x + 100; duration: 30000; loops: Animation.Infinite
            }
        }
    }

    // Future Theme Data Streams
    Repeater {
        model: Theme.isFuture ? 8 : 0
        Rectangle {
            x: Math.random() * root.width
            y: 0
            width: 1
            height: root.height * 0.6
            opacity: 0.1
            color: index % 2 === 0 ? Theme.futureCyan : Theme.futureMagenta
            
            Rectangle {
                width: 2
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                color: parent.color
                opacity: 0.8
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    NumberAnimation { from: -40; to: root.height * 0.6; duration: 2000 + Math.random() * 3000 }
                }
            }
        }
    }

    // Faint shooting-star streak
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
