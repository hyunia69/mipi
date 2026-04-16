import QtQuick
import ".."

Column {
    id: root
    spacing: Theme.spacingXS

    signal zoomIn()
    signal zoomOut()

    // Zoom In button
    Rectangle {
        id: zoomInBtn
        width: 60; height: 60; radius: 30
        color: Qt.rgba(0, 0, 0, 0.5)
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "+"
            color: Theme.textPrimary
            font.pixelSize: 28
            font.weight: Font.Light
        }

        MouseArea {
            anchors.fill: parent
            onPressed: zoomInBtn.scale = 0.9
            onReleased: zoomInBtn.scale = 1.0
            onCanceled: zoomInBtn.scale = 1.0
            onClicked: root.zoomIn()
        }

        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    // Track indicator
    Item {
        width: 60; height: 100
        anchors.horizontalCenter: parent.horizontalCenter

        // Track bar
        Rectangle {
            anchors.centerIn: parent
            width: 3; height: 80; radius: 2
            color: Qt.rgba(1, 1, 1, 0.15)
        }

        // Level indicator (static for demo)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 50
            width: 14; height: 14; radius: 7
            color: Theme.primaryColor

            Rectangle {
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: "#FFFFFF"
            }
        }
    }

    // Zoom Out button
    Rectangle {
        id: zoomOutBtn
        width: 60; height: 60; radius: 30
        color: Qt.rgba(0, 0, 0, 0.5)
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1

        // Minus line
        Rectangle {
            anchors.centerIn: parent
            width: 18; height: 2; radius: 1
            color: Theme.textPrimary
        }

        MouseArea {
            anchors.fill: parent
            onPressed: zoomOutBtn.scale = 0.9
            onReleased: zoomOutBtn.scale = 1.0
            onCanceled: zoomOutBtn.scale = 1.0
            onClicked: root.zoomOut()
        }

        Behavior on scale { NumberAnimation { duration: 100 } }
    }
}
