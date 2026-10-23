import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare

// Keep the empty Top host mapped so popup creation cannot raise it over fullscreen.
PanelWindow {
    id: root
    required property var modelData
    property var popup: null
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-notification-popup-flare"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: true
    mask: Region {}

    Loader {
        anchors.fill: parent
        active: !!root.popup
        sourceComponent: Flare.FlareSurface {
            y: root.popup ? root.popup.topOffset : 0
            attach: Flare.FlareHost.Top
            start: root.popup ? root.popup.popupStart : 0
            end: root.popup ? root.popup.popupEnd : 0
            currentHeight: root.popup ? root.popup.revealHeight : 0
            bounds: ScreenGeometry.horizontalBounds(root.modelData ? root.modelData.width : 0)
            r: Theme.largeRadius + 4
            rf: Theme.hugRadius
            bottomRadius: Theme.largeRadius + 4
            surfaceColor: Theme.surface
        }
    }
}
