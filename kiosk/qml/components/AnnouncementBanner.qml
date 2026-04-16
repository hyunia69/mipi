import QtQuick
import ".."

Rectangle {
    id: root
    height: 40
    color: Qt.rgba(0, 0, 0, 0.5)
    radius: 8
    clip: true

    property string message: "운영시간 09:00 ~ 18:00   |   우천시 운영이 중단될 수 있습니다   |   문의: 02-1234-5678   |   안전한 관람을 위해 난간에 기대지 마세요"

    // Separator line top
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Text {
        id: scrollText
        anchors.verticalCenter: parent.verticalCenter
        text: root.message
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        font.letterSpacing: 1

        NumberAnimation on x {
            from: root.width
            to: -scrollText.width
            duration: scrollText.width * 18
            loops: Animation.Infinite
            running: true
        }
    }
}
