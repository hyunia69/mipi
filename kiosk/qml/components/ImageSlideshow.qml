import QtQuick
import ".."

Item {
    id: root

    property int interval: 6000
    property int currentIndex: 0

    // Abstract landscape palettes [sky, mountain, valley]
    readonly property var palettes: [
        ["#0F2027", "#203A43", "#2C5364"],
        ["#141E30", "#243B55", "#4B79A1"],
        ["#1A1A2E", "#16213E", "#0F3460"],
        ["#0D1B2A", "#1B263B", "#415A77"],
        ["#10002B", "#240046", "#3C096C"]
    ]

    // Slides rendered as gradient rectangles
    Repeater {
        model: root.palettes.length

        Rectangle {
            anchors.fill: parent
            opacity: index === root.currentIndex ? 1.0 : 0.0
            z: index === root.currentIndex ? 1 : 0

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.palettes[index][0] }
                GradientStop { position: 0.5; color: root.palettes[index][1] }
                GradientStop { position: 1.0; color: root.palettes[index][2] }
            }

            Behavior on opacity {
                NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad }
            }
        }
    }

    // Decorative mountain silhouette
    Canvas {
        anchors.fill: parent
        z: 2
        onPaint: {
            var ctx = getContext("2d");
            var w = width, h = height;

            // Distant peaks
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.2);
            ctx.beginPath();
            ctx.moveTo(0, h);
            ctx.lineTo(0, h * 0.6);
            ctx.lineTo(w * 0.12, h * 0.42);
            ctx.lineTo(w * 0.22, h * 0.55);
            ctx.lineTo(w * 0.35, h * 0.35);
            ctx.lineTo(w * 0.48, h * 0.45);
            ctx.lineTo(w * 0.58, h * 0.32);
            ctx.lineTo(w * 0.72, h * 0.48);
            ctx.lineTo(w * 0.82, h * 0.38);
            ctx.lineTo(w * 0.92, h * 0.5);
            ctx.lineTo(w, h * 0.42);
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fill();

            // Near ridge
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.35);
            ctx.beginPath();
            ctx.moveTo(0, h);
            ctx.lineTo(0, h * 0.72);
            ctx.lineTo(w * 0.08, h * 0.62);
            ctx.lineTo(w * 0.2, h * 0.68);
            ctx.lineTo(w * 0.35, h * 0.58);
            ctx.lineTo(w * 0.5, h * 0.65);
            ctx.lineTo(w * 0.65, h * 0.55);
            ctx.lineTo(w * 0.78, h * 0.62);
            ctx.lineTo(w * 0.9, h * 0.58);
            ctx.lineTo(w, h * 0.64);
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fill();
        }
    }

    // Animated shimmer (subtle light sweep)
    Rectangle {
        id: shimmer
        width: parent.width * 0.4
        height: parent.height
        z: 3
        rotation: -20
        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on x {
            loops: Animation.Infinite
            PropertyAnimation { from: -shimmer.width; to: root.width + shimmer.width; duration: 8000; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 4000 }
        }

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            PropertyAnimation { from: 0; to: 1; duration: 2000 }
            PropertyAnimation { from: 1; to: 1; duration: 4000 }
            PropertyAnimation { from: 1; to: 0; duration: 2000 }
            PauseAnimation { duration: 4000 }
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        onTriggered: root.currentIndex = (root.currentIndex + 1) % root.palettes.length
    }
}
