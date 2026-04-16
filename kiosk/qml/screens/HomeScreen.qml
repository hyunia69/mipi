import QtQuick
import ".."
import "../components"

Item {
    id: root

    signal startViewing()

    // === Background Slideshow ===
    ImageSlideshow {
        anchors.fill: parent
        interval: 6000
    }

    // === Gradient overlay (bottom heavy) ===
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 0.65; color: Qt.rgba(13, 17, 23, 0.6) }
            GradientStop { position: 1.0; color: Theme.backgroundColor }
        }
    }

    // === Top Status Bar ===
    StatusBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 10
    }

    // === Bottom Content ===
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingXL
        anchors.rightMargin: Theme.spacingXL
        anchors.bottomMargin: Theme.spacingLG
        spacing: Theme.spacingMD

        // Hero text
        Column {
            spacing: 8

            Text {
                text: "DIGITAL TELESCOPE"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Medium
                font.letterSpacing: 6
            }

            Text {
                text: "40x Zoom Viewing Experience"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHero
                font.weight: Font.Bold
            }

            Text {
                text: "40                                       ."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeading
                visible: false
            }
        }

        // Landmark cards scroll
        ListView {
            id: cardList
            width: parent.width
            height: 200
            orientation: ListView.Horizontal
            spacing: Theme.spacingSM
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: ListModel {
                ListElement { name: "Namsan Tower";     dist: "2.3km"; dir: "NE"; clr: "#1B4332" }
                ListElement { name: "Lotte World Tower"; dist: "8.1km"; dir: "E";  clr: "#14213D" }
                ListElement { name: "Hangang Bridge";   dist: "1.5km"; dir: "S";  clr: "#023E8A" }
                ListElement { name: "Gyeongbokgung";    dist: "4.2km"; dir: "N";  clr: "#3D405B" }
                ListElement { name: "63 Building";      dist: "5.7km"; dir: "SW"; clr: "#1A1A2E" }
                ListElement { name: "Bukhansan";        dist: "9.3km"; dir: "N";  clr: "#264653" }
            }

            delegate: LocationCard {
                name: model.name
                distance: model.dist
                direction: model.dir
                thumbColor: model.clr
            }
        }

        // CTA Button
        TouchButton {
            width: parent.width
            height: 88
            text: "START   VIEWING"
            fontSize: Theme.fontHeading
            isGradient: true
            onClicked: root.startViewing()
        }

        // Announcement banner
        AnnouncementBanner {
            width: parent.width
            message: "Operating Hours 09:00 - 18:00   |   Service may be suspended during rain   |   Contact: 02-1234-5678   |   Please do not lean on the railings"
        }
    }

    // Fade-in on load
    opacity: 0
    Component.onCompleted: fadeIn.start()
    NumberAnimation {
        id: fadeIn
        target: root; property: "opacity"
        from: 0; to: 1; duration: 600
        easing.type: Easing.OutCubic
    }
}
