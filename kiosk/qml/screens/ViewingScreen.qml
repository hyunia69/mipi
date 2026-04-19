import QtQuick
import QtQuick.Effects
import ".."
import "../components"

Item {
    id: root
    signal sessionEnded()

    readonly property bool isLive: typeof appMode !== "undefined" && appMode === "live"

    property int currentView: 0
    property int viewInterval: 18000

    readonly property var views: [
        {
            name: "Seoul Panorama",
            image: "slideshow/seoul-04.jpg",
            boxes: [
                { key: "namsan",  x: 0.38, y: 0.22, w: 0.06, h: 0.32, conf: 0.92 },
                { key: "lotte",   x: 0.72, y: 0.20, w: 0.05, h: 0.42, conf: 0.94 },
                { key: "hangang", x: 0.15, y: 0.70, w: 0.35, h: 0.08, conf: 0.87 }
            ]
        },
        {
            name: "Skyline Overview",
            image: "slideshow/seoul-01.jpg",
            boxes: [
                { key: "namsan", x: 0.32, y: 0.22, w: 0.07, h: 0.30, conf: 0.89 },
                { key: "lotte",  x: 0.70, y: 0.20, w: 0.05, h: 0.38, conf: 0.91 }
            ]
        },
        {
            name: "Namsan Tower",
            image: "landmarks/namsan/hero.jpg",
            boxes: [
                { key: "namsan", x: 0.38, y: 0.18, w: 0.22, h: 0.70, conf: 0.97 }
            ]
        },
        {
            name: "Lotte World Tower",
            image: "landmarks/lotte/hero.jpg",
            boxes: [
                { key: "lotte", x: 0.42, y: 0.18, w: 0.18, h: 0.70, conf: 0.96 }
            ]
        },
        {
            name: "Hangang Bridge",
            image: "landmarks/hangang/hero.jpg",
            boxes: [
                { key: "hangang", x: 0.10, y: 0.48, w: 0.78, h: 0.18, conf: 0.93 }
            ]
        },
        {
            name: "Bukhansan",
            image: "landmarks/bukhan/hero.jpg",
            boxes: [
                { key: "bukhan", x: 0.22, y: 0.22, w: 0.55, h: 0.60, conf: 0.94 }
            ]
        }
    ]

    readonly property var activeView: views[currentView]

    // ===== Background fallback =====
    Rectangle { anchors.fill: parent; color: Theme.backgroundColor }

    // ===== Background Loader: demo slideshow vs live camera =====
    Loader {
        id: bgLoader
        anchors.fill: parent
        z: 0
        sourceComponent: root.isLive ? liveBgComp : demoBgComp
    }

    // --- Demo: crossfading real photographs (Ken Burns pan) ---
    Component {
        id: demoBgComp

        Item {
            anchors.fill: parent

            Repeater {
                model: root.views.length

                Item {
                    anchors.fill: parent
                    opacity: index === root.currentView ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 1400; easing.type: Easing.InOutQuad } }

                    Image {
                        id: bgImage
                        anchors.fill: parent
                        source: Theme.assetsUrl.length > 0
                            ? Theme.assetsUrl + "/" + root.views[index].image
                            : ""
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 1920
                        sourceSize.height: 1080
                        transformOrigin: Item.Center

                        SequentialAnimation on scale {
                            running: bgImage.status === Image.Ready && index === root.currentView
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.00; to: 1.04; duration: 16000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.04; to: 1.00; duration: 16000; easing.type: Easing.InOutSine }
                        }

                        SequentialAnimation on x {
                            running: bgImage.status === Image.Ready && index === root.currentView
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: -24; duration: 16000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: -24; to: 0; duration: 16000; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }

    // --- Live: real camera feed ---
    Component {
        id: liveBgComp

        CameraView {
            id: cameraView
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            onSignalLost: (reason) => {
                liveStatus.message = "Camera signal lost — " + reason
                liveStatus.isError = true
                liveStatus.visible = true
            }
            onSignalRestored: {
                liveStatus.message = ""
                liveStatus.isError = false
                liveStatus.visible = false
            }
        }
    }

    // ===== Vignette over background =====
    Rectangle {
        anchors.fill: parent
        z: 1
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.22) }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.00; color: Qt.rgba(13/255, 17/255, 23/255, 0.60) }
        }
    }

    // ===== View transition timer (demo only; pauses while info panel is open) =====
    Timer {
        interval: root.viewInterval
        running: !root.isLive && !infoPanel.isOpen && !exitDialog.open
        repeat: true
        onTriggered: root.currentView = (root.currentView + 1) % root.views.length
    }

    // ===== View indicator (top center) — demo only =====
    Row {
        id: viewIndicator
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingLG
        spacing: 14
        z: 15
        visible: !root.isLive

        Icon {
            name: "navigation"
            color: Theme.holoTeal
            size: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "VIEW  ·  " + (root.activeView.name).toUpperCase()
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 3
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { width: 14; height: 1 }

        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: root.views.length
                Rectangle {
                    width: index === root.currentView ? 22 : 6
                    height: 4
                    radius: 2
                    color: index === root.currentView ? Theme.holoTeal : Qt.rgba(1, 1, 1, 0.22)
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
            }
        }
    }

    // ===== Live mode status line (top center) =====
    Row {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingLG
        spacing: 12
        z: 15
        visible: root.isLive

        Icon {
            name: "navigation"
            color: Theme.holoTeal
            size: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "LIVE CAMERA  ·  " + (typeof cameraWidth !== "undefined" ? cameraWidth : 1920)
                  + "×" + (typeof cameraHeight !== "undefined" ? cameraHeight : 1080)
                  + "  ·  " + (typeof cameraFps !== "undefined" ? cameraFps : 60) + " fps"
                  + "  ·  " + (typeof cameraBackend !== "undefined" ? cameraBackend.toUpperCase() : "QT")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 3
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ===== Holographic crosshair (center) =====
    Item {
        id: crosshair
        anchors.centerIn: parent
        width: 80; height: 80
        z: 30
        visible: !Theme.isMinimal

        Item {
            id: crosshairVisuals
            anchors.fill: parent
            layer.enabled: Theme.enableEffects

            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0;  width: 1; height: 26; color: Theme.holoTeal; opacity: 0.55 }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 54; width: 1; height: 26; color: Theme.holoTeal; opacity: 0.55 }
            Rectangle { x: 0;  anchors.verticalCenter: parent.verticalCenter; width: 26; height: 1; color: Theme.holoTeal; opacity: 0.55 }
            Rectangle { x: 54; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 1; color: Theme.holoTeal; opacity: 0.55 }

            Rectangle {
                anchors.centerIn: parent
                width: 18; height: 18; radius: 9
                color: "transparent"
                border.color: Theme.holoTeal
                border.width: 1
                opacity: 0.55
            }
            Rectangle {
                anchors.centerIn: parent
                width: 2; height: 2; radius: 1
                color: Theme.holoTeal
            }
        }

        MultiEffect {
            source: crosshairVisuals
            anchors.fill: crosshairVisuals
            enabled: Theme.enableEffects
            visible: enabled
            shadowEnabled: true
            shadowBlur: Theme.glowRadiusMd
            shadowColor: Theme.holoTeal
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
        }

        RotationAnimation on rotation {
            running: Theme.enableEffects
            from: 0; to: 360
            duration: 120000
            loops: Animation.Infinite
        }
    }

    // ===== AI Detection overlays — demo only =====
    Repeater {
        model: root.isLive ? 0 : root.views.length

        Item {
            anchors.fill: parent
            z: 25
            opacity: index === root.currentView ? 1.0 : 0.0
            enabled: index === root.currentView
            Behavior on opacity { NumberAnimation { duration: 1400; easing.type: Easing.InOutQuad } }

            Repeater {
                model: root.views[index].boxes

                DetectionBox {
                    readonly property var entry: LandmarkData.get(modelData.key) || ({ name: modelData.key })

                    x: root.width * modelData.x
                    y: root.height * modelData.y
                    width: root.width * modelData.w
                    height: root.height * modelData.h
                    label: entry.name
                    confidence: modelData.conf
                    selected: infoPanel.isOpen && infoPanel.landmarkName === entry.name
                    onTapped: openLandmark(modelData.key)
                }
            }
        }
    }

    // ===== Countdown Timer =====
    CountdownTimer {
        id: timer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.spacingLG
        anchors.rightMargin: Theme.spacingLG + (infoPanel.isOpen ? infoPanel.width : 0)
        totalSeconds: 180
        remainingSeconds: 180
        isRunning: true
        z: 20
        onExpired: root.sessionEnded()

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
    }

    // ===== Zoom Controls =====
    ZoomControls {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spacingLG + (infoPanel.isOpen ? infoPanel.width + Theme.spacingSM : 0)
        z: 20

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
    }

    // ===== Time warning overlays =====
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.errorColor
        border.width: timer.isWarning ? 3 : 0
        visible: timer.isWarning
        z: 40

        property real pulseOpacity: 0.5
        opacity: pulseOpacity

        SequentialAnimation on pulseOpacity {
            running: timer.isWarning
            loops: Animation.Infinite
            NumberAnimation { to: 0.15; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingLG
        anchors.horizontalCenter: parent.horizontalCenter
        width: warningLabel.width + 48
        height: 48
        radius: 24
        color: Qt.rgba(0, 0, 0, 0.75)
        border.color: Qt.rgba(239/255, 68/255, 68/255, 0.5)
        border.width: 1
        visible: timer.isWarning
        opacity: timer.isWarning ? 1 : 0
        z: 40

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

        Text {
            id: warningLabel
            anchors.centerIn: parent
            text: "Session ending soon"
            color: Theme.errorColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
        }
    }

    // ===== LIVE indicator (top left) =====
    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.spacingLG
        spacing: 10
        z: 15

        Rectangle {
            width: 10; height: 10; radius: 5
            color: "#EF4444"
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 1000 }
                NumberAnimation { to: 1.0; duration: 1000 }
            }
        }

        Text {
            text: root.isLive ? "LIVE" : "LIVE  40x"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ===== Camera error banner (live mode only) =====
    Rectangle {
        id: liveStatus
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingLG * 2 + 28
        width: Math.min(parent.width - 2 * Theme.spacingLG, statusLabel.width + 48)
        height: 44
        radius: 22
        color: Qt.rgba(0, 0, 0, 0.80)
        border.color: Qt.rgba(239/255, 68/255, 68/255, 0.55)
        border.width: 1
        visible: false
        z: 50
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        property string message: ""
        property bool isError: false

        Text {
            id: statusLabel
            anchors.centerIn: parent
            text: liveStatus.message
            color: liveStatus.isError ? Theme.errorColor : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }
    }

    // ===== EXIT button (bottom left) =====
    Rectangle {
        id: exitBtn
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingLG
        width: 200; height: 56
        radius: 28
        color: Qt.rgba(0, 0, 0, 0.55)
        border.color: Qt.rgba(1, 1, 1, 0.20)
        border.width: 1
        z: 30

        Row {
            anchors.centerIn: parent
            spacing: 10

            Icon {
                name: "x"
                color: Theme.textSecondary
                size: 18
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "END SESSION"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: exitBtn.scale = 0.96
            onReleased: exitBtn.scale = 1.0
            onCanceled: exitBtn.scale = 1.0
            onClicked: exitDialog.open = true
        }

        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }

    // ===== Landmark Info Panel =====
    LandmarkInfoPanel {
        id: infoPanel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        z: 100
        onCloseRequested: infoPanel.isOpen = false
    }

    // ===== CRT Scanline Overlay =====
    ScanlineOverlay {
        anchors.fill: parent
        z: 45
    }

    // ===== Exit confirmation dialog =====
    ExitConfirmDialog {
        id: exitDialog
        remainingTime: timer.formattedTime
        onContinueRequested: exitDialog.open = false
        onEndRequested: {
            exitDialog.open = false;
            root.sessionEnded();
        }
    }

    function openLandmark(key) {
        var d = LandmarkData.get(key);
        if (!d) return;
        infoPanel.landmarkName = d.name;
        infoPanel.landmarkNameEn = d.nameEn;
        infoPanel.description = d.description;
        infoPanel.history = d.history;
        infoPanel.distance = d.distance;
        infoPanel.direction = d.direction;
        infoPanel.altitude = d.altitude;
        infoPanel.thumbColor = d.thumbColor;
        infoPanel.heroSource = LandmarkData.heroImage(key);
        infoPanel.isOpen = true;
    }
}
