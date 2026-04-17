import QtQuick
import ".."
import "../components"

Item {
    id: root

    signal startViewing()
    signal landmarkSelected(string key)

    ImageSlideshow {
        anchors.fill: parent
        interval: 6000
    }

    StarsBackdrop {
        anchors.fill: parent
        z: 1
        count: 55
        topFraction: 0.55
    }

    Rectangle {
        anchors.fill: parent
        z: 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 0.65; color: Qt.rgba(13/255, 17/255, 23/255, 0.6) }
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
                color: Theme.holoTeal
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Medium
                font.letterSpacing: 6
                opacity: 0.85
            }

            Text {
                text: "40x Zoom Viewing Experience"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHero
                font.weight: Font.Bold
            }
        }

        ListView {
            id: cardList
            width: parent.width
            height: 200
            orientation: ListView.Horizontal
            spacing: Theme.spacingSM
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: true

            model: ListModel {
                ListElement { key: "namsan";    name: "Namsan Tower";      dist: "2.3km"; dir: "NE"; clr: "#1B4332" }
                ListElement { key: "lotte";     name: "Lotte World Tower"; dist: "8.1km"; dir: "E";  clr: "#14213D" }
                ListElement { key: "hangang";   name: "Hangang Bridge";    dist: "1.5km"; dir: "S";  clr: "#023E8A" }
                ListElement { key: "gyeongbok"; name: "Gyeongbokgung";     dist: "4.2km"; dir: "N";  clr: "#3D405B" }
                ListElement { key: "sixty3";    name: "63 Building";       dist: "5.7km"; dir: "SW"; clr: "#1A1A2E" }
                ListElement { key: "bukhan";    name: "Bukhansan";         dist: "9.3km"; dir: "N";  clr: "#264653" }
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
                transform: Translate { id: cardShift; x: -36 }

                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: 250 + index * 90 }
                    ParallelAnimation {
                        NumberAnimation { target: card;      property: "opacity"; from: 0; to: 1;  duration: 500; easing.type: Easing.OutCubic }
                        NumberAnimation { target: cardShift; property: "x";       to: 0;            duration: 500; easing.type: Easing.OutCubic }
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
            message: "Operating Hours 09:00 - 18:00   |   Service may be suspended during rain   |   Contact: 02-1234-5678   |   Please do not lean on the railings"
        }
    }

    opacity: 0
    Component.onCompleted: fadeIn.start()
    NumberAnimation {
        id: fadeIn
        target: root; property: "opacity"
        from: 0; to: 1; duration: 600
        easing.type: Easing.OutCubic
    }
}
