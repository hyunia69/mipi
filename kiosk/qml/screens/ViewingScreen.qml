import QtQuick
import ".."
import "../components"

Item {
    id: root
    signal sessionEnded()

    // === Mock Camera Feed (landscape scene) ===
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#0C1445" }
            GradientStop { position: 0.25; color: "#1D3461" }
            GradientStop { position: 0.50; color: "#376996" }
            GradientStop { position: 0.65; color: "#2D6A4F" }
            GradientStop { position: 0.80; color: "#1B4332" }
            GradientStop { position: 1.00; color: "#0D1117" }
        }
    }

    // Scenic details canvas
    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            var w = width, h = height;

            // Clouds
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.04);
            ctx.beginPath(); ctx.arc(w * 0.2, h * 0.12, 60, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.arc(w * 0.25, h * 0.1, 45, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.arc(w * 0.7, h * 0.18, 55, 0, Math.PI * 2); ctx.fill();

            // Distant mountains
            ctx.fillStyle = "#264653";
            ctx.beginPath();
            ctx.moveTo(0, h * 0.55);
            ctx.quadraticCurveTo(w * 0.1, h * 0.38, w * 0.2, h * 0.45);
            ctx.quadraticCurveTo(w * 0.32, h * 0.3, w * 0.42, h * 0.42);
            ctx.quadraticCurveTo(w * 0.52, h * 0.28, w * 0.62, h * 0.38);
            ctx.quadraticCurveTo(w * 0.75, h * 0.25, w * 0.85, h * 0.35);
            ctx.quadraticCurveTo(w * 0.92, h * 0.4, w, h * 0.45);
            ctx.lineTo(w, h); ctx.lineTo(0, h);
            ctx.closePath(); ctx.fill();

            // Near hills
            ctx.fillStyle = "#1B4332";
            ctx.beginPath();
            ctx.moveTo(0, h * 0.7);
            ctx.quadraticCurveTo(w * 0.15, h * 0.58, w * 0.3, h * 0.65);
            ctx.quadraticCurveTo(w * 0.45, h * 0.55, w * 0.6, h * 0.62);
            ctx.quadraticCurveTo(w * 0.75, h * 0.52, w * 0.88, h * 0.6);
            ctx.lineTo(w, h * 0.58); ctx.lineTo(w, h); ctx.lineTo(0, h);
            ctx.closePath(); ctx.fill();

            // Tower structure (Namsan-like)
            var towerX = w * 0.33;
            ctx.fillStyle = "#6B7280";
            ctx.fillRect(towerX - 3, h * 0.15, 6, h * 0.3);
            ctx.fillRect(towerX - 14, h * 0.15, 28, 6);
            ctx.fillRect(towerX - 10, h * 0.17, 20, 18);
            ctx.fillRect(towerX - 6, h * 0.32, 12, 8);
            // Antenna
            ctx.fillRect(towerX - 1, h * 0.08, 2, h * 0.07);

            // Skyscraper cluster (right side)
            ctx.fillStyle = "#4B5563";
            ctx.fillRect(w * 0.66, h * 0.3, 20, h * 0.32);
            ctx.fillRect(w * 0.685, h * 0.25, 14, h * 0.37);
            ctx.fillRect(w * 0.705, h * 0.28, 18, h * 0.34);

            // Tall tower (Lotte-like)
            ctx.fillStyle = "#6B7280";
            ctx.fillRect(w * 0.695, h * 0.12, 8, h * 0.5);
            ctx.fillRect(w * 0.692, h * 0.11, 14, 4);

            // Bridge in foreground
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12);
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(w * 0.02, h * 0.73);
            ctx.quadraticCurveTo(w * 0.15, h * 0.71, w * 0.3, h * 0.73);
            ctx.stroke();

            // Bridge supports
            for (var i = 0; i < 5; i++) {
                var bx = w * 0.05 + i * w * 0.055;
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.08);
                ctx.fillRect(bx, h * 0.71, 2, h * 0.05);
            }

            // Water reflection shimmer
            for (var j = 0; j < 20; j++) {
                var rx = Math.random() * w;
                var ry = h * 0.78 + Math.random() * h * 0.15;
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.02 + Math.random() * 0.03);
                ctx.fillRect(rx, ry, 20 + Math.random() * 40, 1);
            }

            // Small window lights on buildings
            ctx.fillStyle = Qt.rgba(1, 1, 0.8, 0.3);
            for (var k = 0; k < 12; k++) {
                var wx = w * 0.66 + Math.random() * 50;
                var wy = h * 0.3 + Math.random() * (h * 0.25);
                ctx.fillRect(wx, wy, 3, 2);
            }
        }
    }

    // === Crosshair (center) ===
    Item {
        anchors.centerIn: parent
        width: 60; height: 60
        opacity: 0.2

        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: 1; height: 20; color: "white" }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 40; width: 1; height: 20; color: "white" }
        Rectangle { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 1; color: "white" }
        Rectangle { x: 40; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 1; color: "white" }
    }

    // === AI Detection Overlays ===
    DetectionBox {
        x: parent.width * 0.27; y: parent.height * 0.08
        width: parent.width * 0.14; height: parent.height * 0.48
        label: "Namsan Tower"
        confidence: 0.97
        selected: infoPanel.isOpen && infoPanel.landmarkName === "Namsan Tower"
        onTapped: openLandmark(
            "Namsan Tower", "N Seoul Tower",
            "Seoul's iconic landmark offering panoramic views of the city. The tower sits atop Namsan Mountain at 236m elevation, serving as both a broadcasting tower and major tourist attraction.",
            "Built in 1969 as a broadcasting tower, it was opened to the public in 1980 and has since become one of Seoul's most visited landmarks.",
            "2.3km", "Northeast", "236m", "#1B4332"
        )
    }

    DetectionBox {
        x: parent.width * 0.64; y: parent.height * 0.06
        width: parent.width * 0.08; height: parent.height * 0.55
        label: "Lotte World Tower"
        confidence: 0.94
        selected: infoPanel.isOpen && infoPanel.landmarkName === "Lotte World Tower"
        onTapped: openLandmark(
            "Lotte World Tower", "Lotte World Tower",
            "Standing at 555m, this supertall skyscraper is the tallest building in South Korea and the fifth tallest in the world. It houses an observation deck, hotel, offices, and shopping complex.",
            "Construction began in 2011 and was completed in 2017. The Seoul Sky observation deck on floors 117-123 offers breathtaking views.",
            "8.1km", "East", "555m", "#14213D"
        )
    }

    DetectionBox {
        x: parent.width * 0.02; y: parent.height * 0.67
        width: parent.width * 0.3; height: parent.height * 0.1
        label: "Hangang Bridge"
        confidence: 0.91
        selected: infoPanel.isOpen && infoPanel.landmarkName === "Hangang Bridge"
        onTapped: openLandmark(
            "Hangang Bridge", "Hangang Bridge",
            "A major bridge crossing the Han River, connecting Yongsan-gu and Dongjak-gu districts. It holds historical significance as the first pedestrian bridge over the Han River.",
            "Originally opened in 1917 as a pedestrian bridge, it was destroyed during the Korean War and rebuilt in 1958.",
            "1.5km", "South", "", "#023E8A"
        )
    }

    // === Countdown Timer ===
    CountdownTimer {
        id: timer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.spacingLG
        anchors.rightMargin: Theme.spacingLG + (infoPanel.isOpen ? infoPanel.width : 0)
        totalSeconds: 180
        remainingSeconds: 180
        isRunning: true
        onExpired: root.sessionEnded()

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
    }

    // === Zoom Controls ===
    ZoomControls {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spacingLG + (infoPanel.isOpen ? infoPanel.width + Theme.spacingSM : 0)

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
    }

    // === Time Warning Overlay ===
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.errorColor
        border.width: timer.isWarning ? 3 : 0
        visible: timer.isWarning

        property real pulseOpacity: 0.5
        opacity: pulseOpacity

        SequentialAnimation on pulseOpacity {
            running: timer.isWarning
            loops: Animation.Infinite
            NumberAnimation { to: 0.15; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
        }
    }

    // Warning banner
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingLG
        anchors.horizontalCenter: parent.horizontalCenter
        width: warningLabel.width + 48
        height: 48
        radius: 24
        color: Qt.rgba(0, 0, 0, 0.75)
        border.color: Qt.rgba(239, 68, 68, 0.5)
        border.width: 1
        visible: timer.isWarning
        opacity: timer.isWarning ? 1 : 0

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

    // === Recording indicator (top-left) ===
    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.spacingLG
        spacing: 10

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
            text: "LIVE  40x"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // === Landmark Info Panel ===
    LandmarkInfoPanel {
        id: infoPanel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onCloseRequested: infoPanel.isOpen = false
    }

    function openLandmark(name, nameEn, desc, hist, dist, dir, alt, clr) {
        infoPanel.landmarkName = name;
        infoPanel.landmarkNameEn = nameEn;
        infoPanel.description = desc;
        infoPanel.history = hist;
        infoPanel.distance = dist;
        infoPanel.direction = dir;
        infoPanel.altitude = alt;
        infoPanel.thumbColor = clr;
        infoPanel.isOpen = true;
    }
}
