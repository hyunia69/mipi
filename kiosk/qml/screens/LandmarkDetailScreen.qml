import QtQuick
import QtQuick.Effects
import ".."
import "../components"

Item {
    id: root

    property string landmarkKey: ""
    readonly property var landmark: landmarkKey.length > 0 ? (LandmarkData.get(landmarkKey) || {}) : {}

    signal backRequested()
    signal viewRequested()

    Rectangle { anchors.fill: parent; color: Theme.backgroundColor }

    // === Hero image (top 58%) ===
    Item {
        id: heroArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * 0.58
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.landmark.thumbColor || "#0D1117"
        }

        Image {
            id: heroImage
            anchors.fill: parent
            source: root.landmarkKey.length > 0 ? LandmarkData.heroImage(root.landmarkKey) : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1120
            opacity: status === Image.Ready ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            transformOrigin: Item.Center

            SequentialAnimation on scale {
                running: heroImage.status === Image.Ready
                loops: Animation.Infinite
                NumberAnimation { from: 1.00; to: 1.05; duration: 12000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.05; to: 1.00; duration: 12000; easing.type: Easing.InOutSine }
            }
        }

        // Bottom fade into background
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 260
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.backgroundColor }
            }
        }
    }

    // === Back button (top-left over hero) ===
    Rectangle {
        id: backBtn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Theme.spacingLG
        anchors.leftMargin: Theme.spacingLG
        width: 56; height: 56; radius: 28
        color: Qt.rgba(0, 0, 0, 0.55)
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1
        z: 20

        Icon {
            anchors.centerIn: parent
            name: "chevron-left"
            color: Theme.textPrimary
            size: 24
        }

        MouseArea {
            anchors.fill: parent
            onPressed: backBtn.scale = 0.92
            onReleased: backBtn.scale = 1.0
            onCanceled: backBtn.scale = 1.0
            onClicked: root.backRequested()
        }

        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }

    // === Status bar (top-right) ===
    StatusBar {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 380
        z: 20
        locationName: root.landmark.nameEn || root.landmark.name || ""
    }

    // === Content area (bottom 42%) ===
    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: heroArea.bottom
        anchors.topMargin: -120
        anchors.leftMargin: Theme.spacingXL
        anchors.rightMargin: Theme.spacingXL
        anchors.bottomMargin: Theme.spacingLG

        // Left column: name, description, history
        Item {
            id: leftCol
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: rightCol.left
            anchors.rightMargin: Theme.spacingXL

            opacity: 0
            transform: Translate { id: leftShift; y: 20 }

            ParallelAnimation {
                running: true
                NumberAnimation { target: leftCol;   property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
                NumberAnimation { target: leftShift; property: "y";       from: 20; to: 0; duration: 450; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Theme.spacingSM

                Text {
                    text: root.landmark.name || ""
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontDisplay
                    font.weight: Font.Bold
                }

                Text {
                    text: root.landmark.nameEn || ""
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    font.letterSpacing: 3
                }

                Rectangle {
                    width: 80
                    height: 2
                    radius: 1
                    color: Theme.holoTeal
                    opacity: 0.7
                }

                Item { width: 1; height: Theme.spacingXS }

                Text {
                    width: parent.width
                    text: root.landmark.description || ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                    lineHeight: 1.55
                }

                Item { width: 1; height: Theme.spacingXS }

                Row {
                    spacing: 8
                    visible: (root.landmark.history || "").length > 0
                    Icon { name: "info"; color: Theme.amberWarm; size: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "HISTORY"
                        color: Theme.amberWarm
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: root.landmark.history || ""
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    wrapMode: Text.Wrap
                    lineHeight: 1.5
                    visible: (root.landmark.history || "").length > 0
                }
            }
        }

        // Right column: stats card + HeroCTA
        Item {
            id: rightCol
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 640

            opacity: 0
            transform: Translate { id: rightShift; x: 40 }

            ParallelAnimation {
                running: true
                NumberAnimation { target: rightCol;   property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
                NumberAnimation { target: rightShift; property: "x";       from: 40; to: 0; duration: 450; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.fill: parent
                spacing: Theme.spacingMD

                GlassPanel {
                    width: parent.width
                    height: statsColumn.height + Theme.spacingLG * 2

                    Column {
                        id: statsColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingLG
                        spacing: Theme.spacingMD

                        StatRow {
                            iconName: "map-pin"
                            label: "DISTANCE"
                            value: root.landmark.distance || "—"
                        }
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                        StatRow {
                            iconName: "compass"
                            label: "DIRECTION"
                            value: root.landmark.direction || "—"
                        }
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06); visible: (root.landmark.altitude || "").length > 0 }
                        StatRow {
                            iconName: "mountain"
                            label: "ALTITUDE"
                            value: root.landmark.altitude || ""
                            visible: (root.landmark.altitude || "").length > 0
                        }
                    }
                }

                HeroCTA {
                    width: parent.width
                    primary: "VIEW THIS LANDMARK"
                    caption: "Start 3-minute observation"
                    leadingIcon: "eye"
                    trailingIcon: "chevron-right"
                    onClicked: root.viewRequested()
                }
            }
        }
    }

    ScanlineOverlay {
        anchors.fill: parent
        z: 60
        opacity: 0.025
        spacing: 4
    }

    // Inline stat row component
    component StatRow : Item {
        property string iconName: ""
        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        height: 52

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSM

            Rectangle {
                width: 40; height: 40; radius: 20
                color: Qt.rgba(0.13, 0.83, 0.93, 0.10)
                border.color: Qt.rgba(0.13, 0.83, 0.93, 0.30)
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Icon {
                    anchors.centerIn: parent
                    name: iconName
                    color: Theme.holoTeal
                    size: 18
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: label
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }
                Text {
                    text: value
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeading
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
