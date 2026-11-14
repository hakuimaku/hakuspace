import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services"

Item {
    id: rootItem
    required property var modelData

    // Physical corner masks and reservations share the independent screen preferences.
    readonly property real sideInset: ScreenGeometry.borderThickness
    readonly property real cornerRadius: ScreenGeometry.roundedRadius
    readonly property color frameColor: Theme.surface
    // Place the lower corners above each output's visible full bar.
    readonly property real taskbarInset: ScreenGeometry.taskbarReservation()
    readonly property Item frameItem: frame
    property alias horizontalReservationWindow: horizontalReservation
    property alias leftReservationWindow: leftReservation

    // Render corner masks and rails opposite the status bar without intercepting input.
    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: rootItem.cornerRadius > 0 || rootItem.sideInset > 0

        WlrLayershell.layer: WlrLayer.Top
        // Keep compositor geometry fixed when Settings opens or switches layouts.
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        // Draw only the small corner masks and rails instead of repainting an output-sized image.
        Item {
            id: frame
            readonly property bool transitionDriven: BarTransitionState.hostActive && BarTransitionState.armed
            readonly property string activeEdge: BarTransitionState.phase === "hiding" ? BarTransitionState.fromEdge
                : BarTransitionState.active ? BarTransitionState.toEdge
                : BarTransitionState.settledEdge
            function edgeX(edge) { return edge === "left" ? ScreenGeometry.leftBarWidth : 0 }
            function edgeY(edge) { return edge === "top" ? Math.round(Theme.topBarHeight) : 0 }
            function edgeBottomReserve(edge) { return edge === "bottom" ? ScreenGeometry.taskbarHeight : 0 }
            function edgeLeftRail(edge) { return edge === "left" ? 0 : t }
            function edgeTopInset(edge) { return edge === "top" ? 0 : t }
            function edgeBottomInset(edge) { return edge === "bottom" ? 0 : t }

            opacity: transitionDriven ? BarTransitionState.modulesOpacity : 1
            x: transitionDriven ? edgeX(activeEdge) : ScreenGeometry.leftChromeWidth
            width: parent.width - x
            y: transitionDriven ? edgeY(activeEdge) : (ChromeLayout.topBarMode ? Math.round(Theme.topBarHeight) : 0)
            height: transitionDriven
                ? Math.max(0, parent.height - y - edgeBottomReserve(activeEdge))
                : Math.max(0, parent.height - y - rootItem.taskbarInset)
            readonly property real t: rootItem.sideInset
            readonly property real leftRail: transitionDriven ? edgeLeftRail(activeEdge) : (ChromeLayout.leftBarMode ? 0 : t)
            readonly property real topInset: transitionDriven ? edgeTopInset(activeEdge) : ScreenGeometry.topBorderThickness
            readonly property real bottomInset: transitionDriven ? edgeBottomInset(activeEdge) : ScreenGeometry.bottomInset
            readonly property real r: ScreenGeometry.maskRadius(width, height)
            Repeater {
                model: 4
                delegate: Shape {
                    required property int index
                    width: frame.r; height: frame.r
                    x: index === 1 || index === 2 ? frame.width - frame.t - width : frame.leftRail
                    y: index >= 2 ? frame.height - frame.bottomInset - height : frame.topInset
                    rotation: index * 90
                    transformOrigin: Item.Center
                    visible: frame.r > 0
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: rootItem.frameColor; strokeColor: "transparent"
                        startX: 0; startY: 0
                        PathLine { x: frame.r; y: 0 }
                        PathArc { x: 0; y: frame.r; radiusX: frame.r; radiusY: frame.r; direction: PathArc.Counterclockwise }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }
            Rectangle { width: frame.leftRail; height: parent.height; color: rootItem.frameColor }
            Rectangle { x: parent.width - width; width: frame.t; height: parent.height; color: rootItem.frameColor }
            Rectangle { width: parent.width; height: frame.topInset; color: rootItem.frameColor }
            Rectangle { y: parent.height - height; width: parent.width; height: frame.bottomInset; color: rootItem.frameColor }
        }
    }

    // Reserve the horizontal rail opposite the active bar and both side rails.
    PanelWindow {
        id: horizontalReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { top: !ChromeLayout.topBarMode; bottom: ChromeLayout.topBarMode; left: true; right: true }
        exclusiveZone: rootItem.sideInset
        implicitHeight: rootItem.sideInset
        mask: Region {}
        visible: rootItem.sideInset > 0 && (!ChromeLayout.topBarMode || ScreenGeometry.dockbarReservation(rootItem.modelData.name) === 0)
    }

    PanelWindow {
        id: leftReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; bottom: true; left: true }
        exclusiveZone: ScreenGeometry.reservedLeft
        implicitWidth: ScreenGeometry.reservedLeft
        mask: Region {}
        visible: ScreenGeometry.reservedLeft > 0
    }

    PanelWindow {
        id: rightReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; bottom: true; right: true }
        exclusiveZone: ScreenGeometry.rightInset
        implicitWidth: ScreenGeometry.rightInset
        mask: Region {}
        visible: rootItem.sideInset > 0
    }
}
