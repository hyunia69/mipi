import QtQuick
import ".."

Canvas {
    id: root
    opacity: Theme.showScanlines ? 0.05 : 0.0
    visible: opacity > 0
    z: 50

    property int spacing: 3
    property color lineColor: Theme.holoTeal

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onSpacingChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.strokeStyle = root.lineColor;
        ctx.lineWidth = 1;
        for (var y = 0; y < height; y += root.spacing) {
            ctx.beginPath();
            ctx.moveTo(0, y + 0.5);
            ctx.lineTo(width, y + 0.5);
            ctx.stroke();
        }
    }

    SequentialAnimation on opacity {
        running: Theme.enableEffects
        loops: Animation.Infinite
        NumberAnimation { to: 0.07; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.035; duration: 2200; easing.type: Easing.InOutSine }
    }
}
