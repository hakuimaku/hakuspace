import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "actionmenu" as ActionMenu

PanelWindow {
    id: root
    required property var modelData

    readonly property bool panelOpen: UiState.activePanel === "actionMenu"
                                      && UiState.actionMenuScreenName === modelData.name
    readonly property bool panelClosing: panelOpen && UiState.actionMenuCloseRequested

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-actionmenu"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen

    // Fullscreen input mask while panel is open / closing animation is running
    mask: Region {
        width: (root.panelOpen && surface.phase !== "closed") ? root.modelData.width : 0
        height: (root.panelOpen && surface.phase !== "closed") ? root.modelData.height : 0
    }

    Component.onDestruction: UiState.forceCloseActionMenuIfScreen(modelData.name)

    onPanelClosingChanged: {
        if (!panelOpen) return
        if (panelClosing)
            surface.beginCloseAnimation()
        else if (surface.phase === "closing")
            surface.cancelCloseAnimation()
    }

    // Scrim overlay
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.35 * surface.openOpacity * surface.closeOpacity
    }

    property real _outsideWheelAccumulator: 0
    property real _outsideTouchAccumulator: 0

    Timer {
        id: outsideWheelDecayTimer
        interval: 180
        onTriggered: {
            root._outsideWheelAccumulator = 0;
            root._outsideTouchAccumulator = 0;
        }
    }

    // Outside-dismiss layer & outside input handling (middle-click to activate, wheel to scroll)
    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        enabled: root.panelOpen && !root.panelClosing && surface.phase === "ready"
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                UiState.closeActionMenu();
            } else if (mouse.button === Qt.MiddleButton) {
                surface.activateCurrent();
            }
        }
    }

    WheelHandler {
        id: outsideWheel
        enabled: root.panelOpen && !root.panelClosing && surface.phase === "ready"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            outsideWheelDecayTimer.restart();

            var isTouchPad = event.device && (event.device.pointerType === PointerDevice.TouchPad
                             || (event.pixelDelta && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0)));

            if (isTouchPad && event.pixelDelta && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0)) {
                var pDelta = Math.abs(event.pixelDelta.y) >= Math.abs(event.pixelDelta.x)
                             ? event.pixelDelta.y
                             : event.pixelDelta.x;
                root._outsideTouchAccumulator += pDelta;
                var threshold = 40;
                if (Math.abs(root._outsideTouchAccumulator) >= threshold) {
                    var tSteps = Math.trunc(root._outsideTouchAccumulator / threshold);
                    root._outsideTouchAccumulator -= tSteps * threshold;
                    if (tSteps > 0) surface.scrollPrevious();
                    else if (tSteps < 0) surface.scrollNext();
                }
            } else {
                var aDelta = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x)
                             ? event.angleDelta.y
                             : event.angleDelta.x;
                if (aDelta !== 0) {
                    root._outsideWheelAccumulator += aDelta;
                    var notch = 120;
                    if (Math.abs(root._outsideWheelAccumulator) >= notch) {
                        var wSteps = Math.trunc(root._outsideWheelAccumulator / notch);
                        root._outsideWheelAccumulator -= wSteps * notch;
                        if (wSteps > 0) surface.scrollPrevious();
                        else if (wSteps < 0) surface.scrollNext();
                    }
                }
            }
            event.accepted = true;
        }
    }

    ActionMenu.ActionMenuSurface {
        id: surface
        anchors.centerIn: parent
        screenWidth: root.modelData.width
        screenHeight: root.modelData.height
        flow: UiState.actionMenuFlow
        visible: root.panelOpen
        onRequestClose: UiState.closeActionMenu()
        onCloseAnimationFinished: UiState.finishCloseActionMenu(root.modelData.name)
    }

    Connections {
        target: UiState
        function onActionMenuScrollNextRequested() {
            if (root.panelOpen && surface.phase === "ready") surface.scrollNext();
        }
        function onActionMenuScrollPreviousRequested() {
            if (root.panelOpen && surface.phase === "ready") surface.scrollPrevious();
        }
        function onActionMenuActivateRequested() {
            if (root.panelOpen && surface.phase === "ready") surface.activateCurrent();
        }
    }
}
