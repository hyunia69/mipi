import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root

    property string name: ""
    property color color: Theme.textPrimary
    property int size: 24

    implicitWidth: size
    implicitHeight: size

    Image {
        id: svg
        anchors.fill: parent
        source: typeof ASSETS_URL !== "undefined" && root.name.length > 0
            ? ASSETS_URL + "/icons/" + root.name + ".svg"
            : ""
        sourceSize.width: Math.max(2 * root.size, 48)
        sourceSize.height: Math.max(2 * root.size, 48)
        fillMode: Image.PreserveAspectFit
        smooth: true
        layer.enabled: true
        visible: false
    }

    MultiEffect {
        source: svg
        anchors.fill: svg
        colorizationColor: root.color
        colorization: 1.0
    }
}
