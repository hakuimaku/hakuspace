import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare

// Keep the empty Top host mapped so popup creation cannot raise it over fullscreen.
PanelWindow {
    id: root
    required property var modelData
    readonly property bool hasFullscreen: ToplevelManager.toplevels.values.some(w =>
        w.fullscreen && (w.activated || ToplevelManager.activeToplevel === w)
        && (!root.modelData || w.screens.length === 0 || w.screens.includes(root.modelData) || w.screens.some(s => s.name === root.modelData.name)))
    property var popup: null
    readonly property bool flareActive: !root.hasFullscreen && !!root.popup
    readonly property bool attachedMode: ShellSettingsStore.notificationPopupPosition === "anchor"
    readonly property bool leftAttachedMode: attachedMode && ChromeLayout.leftBarMode
    readonly property bool bottomAttachedMode: attachedMode && !leftAttachedMode && ScreenGeometry.bottomAttached
    readonly property real screenW: root.modelData ? root.modelData.width : 0
    readonly property real screenH: root.modelData ? root.modelData.height : 0
    readonly property real earMargin: Math.ceil(Math.max(Theme.largeRadius + 4, Theme.hugRadius) + 8)
    readonly property real maxPopupStackH: Math.ceil(3 * (Theme.fontSize * 13 + (Theme.cardPadding + Theme.spaceXs) * 2 + Theme.spaceSm * 2) + 2 * Theme.spaceSm + Theme.hugRadius + 8)
    readonly property real topOffset: ChromeLayout.topBarMode ? Theme.topBarHeight : ScreenGeometry.topBorderThickness
    readonly property real boundedCenterW: Math.min(screenW, Math.ceil(450 + earMargin * 2))
    readonly property real boundedLeftW: Math.min(screenW, Math.ceil(ScreenGeometry.contentLeftEdge + 450 + Theme.hugRadius + 8))
    readonly property real boundedTopH: Math.min(screenH, Math.ceil(topOffset + maxPopupStackH))
    readonly property real boundedBottomH: Math.min(screenH, Math.ceil(ScreenGeometry.taskbarHeight + maxPopupStackH))
    readonly property int windowOffsetX: !attachedMode && screenW > boundedCenterW ? Math.floor((screenW - boundedCenterW) / 2) : 0
    readonly property int windowOffsetY: bottomAttachedMode && screenH > boundedBottomH ? Math.floor(screenH - boundedBottomH) : 0
    screen: modelData
    anchors { top: true; left: true }
    margins.left: windowOffsetX
    margins.top: windowOffsetY
    // Keep a fixed bounded surface per chrome edge so popup open/close never triggers a Wayland resize.
    implicitWidth: Math.max(1, Math.ceil(leftAttachedMode ? boundedLeftW : !attachedMode ? boundedCenterW : screenW))
    implicitHeight: Math.max(1, Math.ceil(leftAttachedMode ? screenH : bottomAttachedMode ? boundedBottomH : boundedTopH))
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
        active: root.flareActive
        sourceComponent: Flare.FlareSurface {
            x: (root.popup && root.popup.leftAttached ? ScreenGeometry.contentLeftEdge : 0) - root.windowOffsetX
            y: (root.popup ? root.popup.attachmentY : 0) - root.windowOffsetY
            attach: root.popup ? root.popup.attachMode : Flare.FlareHost.Top
            transform: Matrix4x4 {
                matrix: root.popup && root.popup.leftAttached
                    ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    : Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
            start: root.popup ? root.popup.popupStart : 0
            end: root.popup ? root.popup.popupEnd : 0
            currentHeight: root.popup ? root.popup.revealHeight : 0
            bounds: root.popup ? root.popup.spanBounds : ScreenGeometry.horizontalBounds(root.modelData ? root.modelData.width : 0)
            r: Theme.largeRadius + 4
            rf: Theme.hugRadius
            bottomRadius: Theme.largeRadius + 4
            surfaceColor: Theme.surface
        }
    }
}
