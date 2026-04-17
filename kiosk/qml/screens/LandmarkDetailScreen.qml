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

    // === Hero image ===
    Item {
        id: heroArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: (Theme.isMinimal || Theme.isFuture) ? parent.height : parent.height * 0.58
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
            opacity: status === Image.Ready ? ((Theme.isMinimal || Theme.isFuture) ? 0.6 : 1.0) : 0.0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            transformOrigin: Item.Center

            SequentialAnimation on scale {
                running: heroImage.status === Image.Ready
                loops: Animation.Infinite
                NumberAnimation { from: 1.00; to: 1.05; duration: 20000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.05; to: 1.00; duration: 20000; easing.type: Easing.InOutSine }
            }
        }

        // Overlays
        Rectangle {
            anchors.fill: parent
            visible: Theme.isMinimal || Theme.isFuture
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.backgroundColor }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: (Theme.isMinimal || Theme.isFuture) ? 0 : 260
            visible: !Theme.isMinimal && !Theme.isFuture
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.backgroundColor }
            }
        }
    }

    // === Back button ===
    Rectangle {
        id: backBtn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Theme.spacingLG
        anchors.leftMargin: Theme.spacingLG
        width: 56; height: 56; radius: 28
        color: Qt.rgba(0, 0, 0, 0.4)
        border.color: Theme.glassBorder
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

    // === Content area ===
    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: (Theme.isMinimal || Theme.isFuture) ? parent.top : heroArea.bottom
        anchors.topMargin: (Theme.isMinimal || Theme.isFuture) ? 0 : -120
        anchors.leftMargin: Theme.spacingXL
        anchors.rightMargin: Theme.spacingXL
        anchors.bottomMargin: Theme.spacingLG
        z: 10

        // Left column: name, description, history
        Item {
            id: leftCol
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: (Theme.isMinimal || Theme.isFuture) ? 160 : 0
            anchors.bottom: parent.bottom
            anchors.right: rightCol.left
            anchors.rightMargin: Theme.spacingXL

            opacity: 0
            transform: [
                Translate { id: leftShift; y: 20 },
                Rotation { id: leftRot; axis.x: 0; axis.y: 1; axis.z: 0; angle: Theme.isFuture ? 15 : 0; origin.x: 0; origin.y: 200 }
            ]

            SequentialAnimation {
                running: true
                PauseAnimation { duration: 100 }
                ParallelAnimation {
                    NumberAnimation { target: leftCol; property: "opacity"; to: 1; duration: 600; easing.type: Easing.OutCubic }
                    NumberAnimation { target: leftShift; property: "y"; to: 0; duration: 600; easing.type: Easing.OutCubic }
                    NumberAnimation { target: leftRot; property: "angle"; to: 0; duration: 800; easing.type: Easing.OutBack }
                }
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
                    font.pixelSize: Theme.isFuture ? 56 : Theme.fontDisplay
                    font.weight: Font.Bold
                }

                Text {
                    text: root.landmark.nameEn || ""
                    color: Theme.isFuture ? Theme.futureCyan : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    font.letterSpacing: (Theme.isMinimal || Theme.isFuture) ? 1 : 3
                }

                Rectangle {
                    width: 60
                    height: 2
                    radius: 1
                    color: (Theme.isMinimal || Theme.isFuture) ? Theme.textPrimary : Theme.holoTeal
                    opacity: 0.6
                }

                Item { width: 1; height: Theme.spacingXS }

                Text {
                    width: parent.width
                    text: root.landmark.description || ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    wrapMode: Text.Wrap
                    lineHeight: 1.55
                }

                Item { width: 1; height: Theme.spacingMD }

                Row {
                    spacing: 8
                    visible: (root.landmark.history || "").length > 0
                    Icon { name: "info"; color: Theme.accentColor; size: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "DETAILS & HISTORY"
                        color: Theme.accentColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
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
                    opacity: 0.8
                }
            }
        }

        // Right column: stats card + HeroCTA
        Item {
            id: rightCol
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: (Theme.isMinimal || Theme.isFuture) ? 140 : 0
            anchors.bottom: parent.bottom
            width: (Theme.isMinimal || Theme.isFuture) ? 540 : 640

            opacity: 0
            transform: [
                Translate { id: rightShift; x: 40 },
                Rotation { id: rightRot; axis.x: 0; axis.y: 1; axis.z: 0; angle: Theme.isFuture ? -15 : 0; origin.x: 540; origin.y: 200 }
            ]

            SequentialAnimation {
                running: true
                PauseAnimation { duration: 200 }
                ParallelAnimation {
                    NumberAnimation { target: rightCol; property: "opacity"; to: 1; duration: 600; easing.type: Easing.OutCubic }
                    NumberAnimation { target: rightShift; property: "x"; to: 0; duration: 600; easing.type: Easing.OutCubic }
                    NumberAnimation { target: rightRot; property: "angle"; to: 0; duration: 800; easing.type: Easing.OutBack }
                }
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
                    primary: "BEGIN OBSERVATION"
                    caption: (Theme.isMinimal || Theme.isFuture) ? "Start Live View" : "Start 3-minute observation"
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
        opacity: 0.02
        spacing: 4
        visible: Theme.showScanlines
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
                width: 40; height: 40; radius: (Theme.isMinimal || Theme.isFuture) ? 8 : 20
                color: (Theme.isMinimal || Theme.isFuture) ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0.13, 0.83, 0.93, 0.10)
                border.color: (Theme.isMinimal || Theme.isFuture) ? Theme.glassBorder : Qt.rgba(0.13, 0.83, 0.93, 0.30)
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Icon {
                    anchors.centerIn: parent
                    name: iconName
                    color: (Theme.isMinimal || Theme.isFuture) ? Theme.textSecondary : Theme.holoTeal
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
                    font.letterSpacing: 1.5
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
