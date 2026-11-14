import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-bar-transition"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    // Stay mapped so step transitions only toggle barRect visibility inside the existing Wayland surface.
    visible: true
    mask: Region {}

    readonly property string fromEdge: BarTransitionState.fromEdge
    readonly property string toEdge: BarTransitionState.toEdge
    readonly property real progress: BarTransitionState.moveProgress
    readonly property real topH: Theme.topBarHeight
    readonly property real leftW: ScreenGeometry.leftBarWidth
    readonly property real taskH: ScreenGeometry.taskbarHeight

    readonly property bool isSlide: (fromEdge === "top" && toEdge === "bottom") || (fromEdge === "bottom" && toEdge === "top")
    readonly property bool isTopLeft: (fromEdge === "top" && toEdge === "left") || (fromEdge === "left" && toEdge === "top")
    readonly property bool isBottomLeft: (fromEdge === "bottom" && toEdge === "left") || (fromEdge === "left" && toEdge === "bottom")

    readonly property real startThickness: fromEdge === "left" ? leftW : (fromEdge === "bottom" ? taskH : topH)
    readonly property real endThickness: toEdge === "left" ? leftW : (toEdge === "bottom" ? taskH : topH)
    readonly property real startLength: fromEdge === "left" ? height : width
    readonly property real endLength: toEdge === "left" ? height : width

    function clamp01(value) { return Math.max(0, Math.min(1, value)) }
    function thicknessAt(p) { return Math.max(4, startThickness + (endThickness - startThickness) * p) }
    function lengthAt(p) { return isSlide ? width : Math.max(0, startLength + (endLength - startLength) * p) }
    function barYAt(p) {
        if (isSlide) return fromEdge === "top" ? (height - taskH) * p : (height - taskH) * (1 - p)
        return isBottomLeft ? height - thicknessAt(p) : 0
    }
    function barAngleAt(p) {
        if (isTopLeft) return fromEdge === "top" ? 90 * p : 90 * (1 - p)
        if (isBottomLeft) return fromEdge === "bottom" ? -90 * p : -90 * (1 - p)
        return 0
    }
    function barRadiusAt(p) {
        var c = clamp01(p)
        var swell = Math.min(1, Math.sin(Math.PI * c) * 2.4)
        var maxR = Math.min(thicknessAt(p) / 2, Math.max(Theme.radius, 14))
        return maxR * swell
    }

    readonly property real barAngle: barAngleAt(progress)
    readonly property real barY: barYAt(progress)
    readonly property real currentThickness: thicknessAt(progress)
    readonly property real currentLength: lengthAt(progress)
    readonly property real trailEnvelope: Math.sin(Math.PI * clamp01(progress))

    // Cartoon motion-smear ghosts trailing behind the active bar.
    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            readonly property int trailStep: 4 - index
            readonly property real p: Math.max(0, root.progress - trailStep * 0.055 * root.trailEnvelope)
            readonly property real baseThickness: root.thicknessAt(p)
            readonly property real shrink: Math.max(0.65, 1 - trailStep * 0.06)
            visible: BarTransitionState.overlayVisible && root.trailEnvelope > 0.01
            x: 0
            y: root.barYAt(p) + (baseThickness * (1 - shrink)) / 2
            width: root.lengthAt(p)
            height: baseThickness * shrink
            radius: root.barRadiusAt(p) * shrink
            color: trailStep >= 3 ? Theme.accent : Theme.surface
            opacity: (trailStep === 4 ? 0.16 : trailStep === 3 ? 0.28 : trailStep === 2 ? 0.42 : 0.6) * root.trailEnvelope
            transform: Rotation {
                origin.x: baseThickness / 2
                origin.y: (baseThickness * shrink) / 2
                angle: root.barAngleAt(p)
            }
        }
    }

    Rectangle {
        id: barRect
        visible: BarTransitionState.overlayVisible
        x: 0
        y: root.barY
        width: root.currentLength
        height: root.currentThickness
        radius: root.barRadiusAt(root.progress)
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, Math.min(1, Math.sin(Math.PI * root.clamp01(root.progress)) * 2.4))
        transform: Rotation {
            origin.x: root.currentThickness / 2
            origin.y: root.currentThickness / 2
            angle: root.barAngle
        }
    }
}
