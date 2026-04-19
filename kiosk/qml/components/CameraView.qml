import QtQuick
import QtQuick.Effects
import QtMultimedia
import ".."

Item {
    id: root

    signal signalLost(string reason)
    signal signalRestored()

    property alias fillMode: videoOut.fillMode
    property alias videoSink: videoOut.videoSink
    property string lastError: ""
    property bool isStreaming: camera.active && camera.error === Camera.NoError

    readonly property string deviceHint: typeof cameraDevicePath !== "undefined" ? cameraDevicePath : "/dev/video0"
    readonly property int requestedWidth: typeof cameraWidth !== "undefined" ? cameraWidth : 1920
    readonly property int requestedHeight: typeof cameraHeight !== "undefined" ? cameraHeight : 1080
    readonly property int requestedFps: typeof cameraFps !== "undefined" ? cameraFps : 60

    function pickDevice() {
        const inputs = mediaDevs.videoInputs
        for (let i = 0; i < inputs.length; i++) {
            const idStr = inputs[i].id.toString()
            if (idStr === root.deviceHint || idStr.indexOf(root.deviceHint) !== -1)
                return inputs[i]
        }
        return mediaDevs.defaultVideoInput
    }

    function pickFormat(dev) {
        if (!dev) return null
        const formats = dev.videoFormats
        let best = null
        let bestScore = -1
        for (let i = 0; i < formats.length; i++) {
            const f = formats[i]
            const w = f.resolution.width
            const h = f.resolution.height
            const fps = f.maxFrameRate
            // score: exact resolution match + fps match
            let score = 0
            if (w === root.requestedWidth && h === root.requestedHeight) score += 100
            score -= Math.abs(w * h - root.requestedWidth * root.requestedHeight) / 100000
            score -= Math.abs(fps - root.requestedFps) * 0.5
            if (score > bestScore) { bestScore = score; best = f }
        }
        return best
    }

    MediaDevices { id: mediaDevs }

    CaptureSession {
        id: capture
        videoOutput: videoOut
        camera: Camera {
            id: camera
            active: false
            onErrorOccurred: (err, str) => {
                root.lastError = str
                root.signalLost(str + " (" + err + ")")
                retryTimer.restart()
            }
            onActiveChanged: {
                if (active) {
                    root.lastError = ""
                    root.signalRestored()
                }
            }
        }
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    Timer {
        id: retryTimer
        interval: 2500
        repeat: false
        onTriggered: root.activate()
    }

    function activate() {
        const dev = pickDevice()
        if (!dev) {
            root.lastError = "no video device"
            root.signalLost("no video device")
            retryTimer.restart()
            return
        }
        camera.cameraDevice = dev
        const fmt = pickFormat(dev)
        if (fmt) camera.cameraFormat = fmt
        camera.active = true
    }

    function deactivate() {
        retryTimer.stop()
        camera.active = false
    }

    Component.onCompleted: activate()
    Component.onDestruction: deactivate()

    // ===== No-signal overlay (visible while camera is not streaming) =====
    Rectangle {
        anchors.fill: parent
        visible: !root.isStreaming
        color: Theme.backgroundColor
        z: 1

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingMD

            Rectangle {
                width: 64; height: 64; radius: 32
                color: Qt.rgba(239/255, 68/255, 68/255, 0.15)
                border.color: Theme.errorColor
                border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: Theme.errorColor
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    font.family: Theme.fontFamily
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "NO CAMERA SIGNAL"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeading
                font.letterSpacing: 4
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.lastError.length > 0
                    ? root.lastError
                    : "Connecting to " + root.deviceHint
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
