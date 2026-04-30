import QtQuick
import ".."
import "../components"

Item {
    id: root

    signal startViewing()
    signal landmarkSelected(string key)

    ImageSlideshow {
        anchors.fill: parent
        interval: 8000
        opacity: Theme.isFuture ? 0.7 : 1.0
    }

    // Spatial Grid for Future Theme
    Item {
        anchors.fill: parent
        visible: Theme.isFuture
        z: 1
        opacity: 0.2

        transform: Rotation {
            axis.x: 1; axis.y: 0; axis.z: 0
            angle: 45
            origin.x: root.width / 2
            origin.y: root.height
        }

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.strokeStyle = Theme.futureCyan;
                ctx.lineWidth = 1;
                for(var i=-width; i<width*2; i+=60) {
                    ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, height); ctx.stroke();
                }
                for(var j=0; j<height; j+=60) {
                    ctx.beginPath(); ctx.moveTo(-width, j); ctx.lineTo(width*2, j); ctx.stroke();
                }
            }
        }
        
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 60; duration: 2000; easing.type: Easing.Linear }
        }
    }

    StarsBackdrop {
        anchors.fill: parent
        z: 1
        count: Theme.isMinimal ? 0 : (Theme.isFuture ? 80 : 55)
        visible: Theme.enableParticles
        topFraction: 0.55
    }

    Rectangle {
        anchors.fill: parent
        z: 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.40; color: "transparent" }
            GradientStop { position: 0.70; color: Theme.isMinimal ? Qt.rgba(0, 0, 0, 0.5) : (Theme.isFuture ? Qt.rgba(5, 5, 16, 0.7) : Qt.rgba(13/255, 17/255, 23/255, 0.6)) }
            GradientStop { position: 1.0; color: Theme.backgroundColor }
        }
    }

    StatusBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 10
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingXL
        anchors.rightMargin: Theme.spacingXL
        anchors.bottomMargin: Theme.spacingLG
        spacing: Theme.spacingMD
        z: 5

        Column {
            spacing: 8

            Text {
                text: "DIGITAL TELESCOPE"
                color: Theme.isMinimal ? Theme.textSecondary : (Theme.isFuture ? Theme.futureCyan : Theme.holoTeal)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Theme.isMinimal ? Font.Normal : Font.Medium
                font.letterSpacing: Theme.isMinimal ? 4 : (Theme.isFuture ? 10 : 6)
                opacity: 0.85
            }

            Text {
                text: "40x Zoom Viewing Experience"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHero
                font.weight: Font.Bold
                
                // Future theme neon glow effect via scale/opacity pulse
                SequentialAnimation on opacity {
                    running: Theme.isFuture
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.8; duration: 2000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                }
            }
        }

        ListView {
            id: cardList
            width: parent.width
            height: Theme.isFuture ? 260 : 220
            orientation: ListView.Horizontal
            spacing: Theme.spacingMD
            clip: false
            boundsBehavior: Flickable.StopAtBounds
            interactive: true

            model: ListModel { id: landmarkModel }
            Component.onCompleted: {
                for (var i = 0; i < LandmarkData.items.length; i++) {
                    var item = LandmarkData.items[i];
                    landmarkModel.append({
                        key: item.key,
                        name: item.name,
                        dist: item.distance,
                        dir: item.direction,
                        clr: item.thumbColor
                    });
                }
            }

            delegate: LocationCard {
                id: card
                property string landmarkKey: model.key
                name: model.name
                distance: model.dist
                direction: model.dir
                thumbColor: model.clr
                thumbSource: Theme.assetsUrl.length > 0
                    ? Theme.assetsUrl + "/landmarks/" + model.key + "/thumb.jpg"
                    : ""

                opacity: 0
                transform: [
                    Translate { id: cardShift; x: -36 },
                    Scale { id: cardScale; xScale: 0.9; yScale: 0.9; origin.x: 120; origin.y: 100 }
                ]

                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: 250 + index * 90 }
                    ParallelAnimation {
                        NumberAnimation { target: card;      property: "opacity"; to: 1;  duration: 600; easing.type: Easing.OutCubic }
                        NumberAnimation { target: cardShift; property: "x";       to: 0;  duration: 600; easing.type: Easing.OutCubic }
                        NumberAnimation { target: cardScale; property: "xScale";  to: 1;  duration: 600; easing.type: Easing.OutBack }
                        NumberAnimation { target: cardScale; property: "yScale";  to: 1;  duration: 600; easing.type: Easing.OutBack }
                    }
                }

                onClicked: root.landmarkSelected(card.landmarkKey)
            }
        }

        HeroCTA {
            width: parent.width
            primary: "START VIEWING"
            caption: "1,000 KRW · 3 MIN · Live 40x Optical Zoom"
            leadingIcon: "telescope"
            trailingIcon: "chevron-right"
            onClicked: root.startViewing()
        }

        AnnouncementBanner {
            width: parent.width
            message: "Operating Hours 09:00 - 18:00   |   Service may be suspended during rain   |   Contact: 02-1234-5678"
        }
    }

    AvatarWidget {
        id: homeAvatar
        visible: typeof AVATAR_ENABLED !== "undefined" ? AVATAR_ENABLED : false
        gloss: "CASA"
        repeatIntervalMs: typeof AVATAR_REPEAT_MS !== "undefined" ? AVATAR_REPEAT_MS : 8000
        width: 280
        height: 360
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 32
        anchors.bottomMargin: 32
        z: 20
    }

    opacity: 0
    Component.onCompleted: fadeIn.start()
    NumberAnimation {
        id: fadeIn
        target: root; property: "opacity"
        from: 0; to: 1; duration: 800
        easing.type: Easing.OutCubic
    }
}
