import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root
    width: 150
    height: 150

    property int totalSeconds: 180
    property int remainingSeconds: 180
    property bool isRunning: false
    property bool isWarning: remainingSeconds <= 30
    property real progress: totalSeconds > 0 ? remainingSeconds / totalSeconds : 0

    readonly property string formattedTime: {
        var m = Math.floor(remainingSeconds / 60);
        var s = remainingSeconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    signal expired()

    Item {
        id: visualGroup
        anchors.fill: parent
        layer.enabled: Theme.enableEffects && root.isWarning

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.6)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
        }

        Canvas {
            id: arc
            anchors.fill: parent
            anchors.margins: 10

            onPaint: {
                var ctx = getContext("2d");
                var cx = width / 2, cy = height / 2;
                var r = Math.min(cx, cy) - 6;

                ctx.clearRect(0, 0, width, height);

                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08);
                ctx.lineWidth = 5;
                ctx.stroke();

                if (root.progress > 0) {
                    var start = -Math.PI / 2;
                    var end = start + (2 * Math.PI * root.progress);

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, end);
                    ctx.strokeStyle = root.isWarning ? Theme.errorColor : Theme.holoTeal;
                    ctx.lineWidth = 5;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                if (root.progress > 0 && root.progress < 1) {
                    var angle = -Math.PI / 2 + (2 * Math.PI * root.progress);
                    var dx = cx + r * Math.cos(angle);
                    var dy = cy + r * Math.sin(angle);

                    ctx.beginPath();
                    ctx.arc(dx, dy, 4, 0, 2 * Math.PI);
                    ctx.fillStyle = root.isWarning ? Theme.errorColor : Theme.holoTeal;
                    ctx.fill();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.formattedTime
            color: root.isWarning ? Theme.errorColor : Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 34
            font.weight: Font.Bold

            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28
            text: "remaining"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1
            visible: !root.isWarning
        }
    }

    MultiEffect {
        source: visualGroup
        anchors.fill: visualGroup
        enabled: Theme.enableEffects && root.isWarning
        visible: enabled
        shadowEnabled: true
        shadowBlur: Theme.glowRadiusLg
        shadowColor: Theme.errorColor
        shadowVerticalOffset: 0
        shadowHorizontalOffset: 0
    }

    SequentialAnimation {
        running: root.isWarning && root.isRunning
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "scale"; to: 1.05; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "scale"; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
    }

    Timer {
        interval: 1000
        running: root.isRunning && root.remainingSeconds > 0
        repeat: true
        onTriggered: {
            root.remainingSeconds--;
            arc.requestPaint();
            if (root.remainingSeconds <= 0) {
                root.expired();
            }
        }
    }

    onProgressChanged: arc.requestPaint()
    Component.onCompleted: arc.requestPaint()
}
