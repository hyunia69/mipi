import QtQuick
import ".."

Rectangle {
    id: root
    height: 40
    color: Qt.rgba(0, 0, 0, 0.5)
    radius: 8
    clip: true

    property string message: "운영시간 09:00 ~ 18:00   |   우천시 운영이 중단될 수 있습니다   |   문의: 02-1234-5678   |   안전한 관람을 위해 난간에 기대지 마세요"

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Icon {
        id: megaphoneIcon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        name: "megaphone"
        color: Theme.holoTeal
        size: 18
        z: 5
    }

    Rectangle {
        anchors.left: megaphoneIcon.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "transparent"
        clip: true

        Text {
            id: scrollText
            anchors.verticalCenter: parent.verticalCenter
            text: root.message
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 1

            NumberAnimation on x {
                from: parent.width
                to: -scrollText.width
                duration: scrollText.width * 18
                loops: Animation.Infinite
                running: true
            }
        }
    }
}
