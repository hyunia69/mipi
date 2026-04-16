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

    StackView {
        id: nav
        anchors.fill: parent
        initialItem: homeComp

        pushEnter: Transition {
            ParallelAnimation {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
                PropertyAnimation { property: "x"; from: 80; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }
        }
        pushExit: Transition {
            PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
        popEnter: Transition {
            PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
        popExit: Transition {
            ParallelAnimation {
                PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
                PropertyAnimation { property: "x"; from: 0; to: 80; duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }
        }
        replaceEnter: Transition {
            PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animSlow; easing.type: Easing.OutCubic }
        }
        replaceExit: Transition {
            PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animSlow; easing.type: Easing.OutCubic }
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
