import QtQuick
import ".."

Column {
    id: root
    spacing: Theme.spacingXS

    signal zoomInPressed()
    signal zoomInReleased()
    signal zoomOutPressed()
    signal zoomOutReleased()

    Rectangle {
        id: zoomInBtn
        width: 60; height: 60; radius: 30
        color: Qt.rgba(0, 0, 0, 0.5)
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1

        Icon {
            anchors.centerIn: parent
            name: "plus"
            color: Theme.textPrimary
            size: 26
        }

        MouseArea {
            anchors.fill: parent
            onPressed: {
                zoomInBtn.scale = 0.9
                root.zoomInPressed()
            }
            onReleased: {
                zoomInBtn.scale = 1.0
                root.zoomInReleased()
            }
            onCanceled: {
                zoomInBtn.scale = 1.0
                root.zoomInReleased()
            }
        }

        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    Item {
        width: 60; height: 100
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            anchors.centerIn: parent
            width: 3; height: 80; radius: 2
            color: Qt.rgba(1, 1, 1, 0.15)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 50
            width: 14; height: 14; radius: 7
            color: Theme.holoTeal

            Rectangle {
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: "#FFFFFF"
            }
        }
    }

    Rectangle {
        id: zoomOutBtn
        width: 60; height: 60; radius: 30
        color: Qt.rgba(0, 0, 0, 0.5)
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1

        Icon {
            anchors.centerIn: parent
            name: "minus"
            color: Theme.textPrimary
            size: 26
        }

        MouseArea {
            anchors.fill: parent
            onPressed: {
                zoomOutBtn.scale = 0.9
                root.zoomOutPressed()
            }
            onReleased: {
                zoomOutBtn.scale = 1.0
                root.zoomOutReleased()
            }
            onCanceled: {
                zoomOutBtn.scale = 1.0
                root.zoomOutReleased()
            }
        }

        Behavior on scale { NumberAnimation { duration: 100 } }
    }
}
