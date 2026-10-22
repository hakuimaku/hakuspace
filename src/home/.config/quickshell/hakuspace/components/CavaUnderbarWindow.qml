import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "cava"

Item {
    id: rootItem
    required property var modelData

    readonly property bool isTop: AppState.cavaTopState
    readonly property bool shouldBeVisible: CavaService.enabled && CavaService.available

    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors {
            top: rootItem.isTop
            bottom: !rootItem.isTop
            left: true
            right: true
        }
        margins {
            left: ScreenGeometry.leftInset
            right: ScreenGeometry.rightInset
            bottom: rootItem.isTop ? 0 : (ChromeLayout.taskbarMode ? ScreenGeometry.taskbarReservation() : ScreenGeometry.bottomInset)
            top: rootItem.isTop ? (ChromeLayout.taskbarMode ? ScreenGeometry.topBorderThickness : Theme.topBarHeight) : 0
        }
        implicitHeight: CavaService.height
        color: "transparent"
        visible: rootItem.shouldBeVisible

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "hakuspace-cava-underbar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        // Completely pass-through input clicks to desktop or windows
        mask: Region {}

        CavaUnderbar {
            anchors.fill: parent
            screen: rootItem.modelData
        }
    }
}
