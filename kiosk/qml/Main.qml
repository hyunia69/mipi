import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "screens"
import "components"

ApplicationWindow {
    id: window
    width: 1920
    height: 1080
    visible: true
    title: "Digital Telescope Kiosk"
    color: Theme.backgroundColor

    Component.onCompleted: Theme.init(typeof PRIMARY_FONT !== "undefined" ? PRIMARY_FONT : "")

    StackView {
        id: nav
        anchors.fill: parent
        initialItem: homeComp

        pushEnter: Transition {
            ParallelAnimation {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                PropertyAnimation { property: "scale";   from: 0.94; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                PropertyAnimation { property: "x";       from: 60; to: 0; duration: 420; easing.type: Easing.OutCubic }
            }
        }
        pushExit: Transition {
            ParallelAnimation {
                PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 280; easing.type: Easing.InCubic }
                PropertyAnimation { property: "scale";   from: 1.0; to: 1.04; duration: 280; easing.type: Easing.InCubic }
            }
        }
        popEnter: Transition {
            ParallelAnimation {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 360; easing.type: Easing.OutCubic }
                PropertyAnimation { property: "scale";   from: 1.04; to: 1.0; duration: 360; easing.type: Easing.OutCubic }
            }
        }
        popExit: Transition {
            ParallelAnimation {
                PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 280; easing.type: Easing.InCubic }
                PropertyAnimation { property: "x";       from: 0; to: 80; duration: 280; easing.type: Easing.InCubic }
            }
        }
        replaceEnter: Transition {
            ParallelAnimation {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animSlow; easing.type: Easing.OutCubic }
                PropertyAnimation { property: "scale";   from: 0.96; to: 1.0; duration: Theme.animSlow; easing.type: Easing.OutCubic }
            }
        }
        replaceExit: Transition {
            PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animSlow; easing.type: Easing.InCubic }
        }
    }

    Component {
        id: homeComp
        HomeScreen {
            onStartViewing: nav.push(paymentComp)
        }
    }

    Component {
        id: paymentComp
        PaymentScreen {
            onPaymentCompleted: nav.replace(viewingComp)
            onCancelled: nav.pop()
        }
    }

    Component {
        id: viewingComp
        ViewingScreen {
            onSessionEnded: nav.replace(endComp)
        }
    }

    Component {
        id: endComp
        SessionEndScreen {
            onReturnHome: nav.replace(homeComp)
        }
    }
}
