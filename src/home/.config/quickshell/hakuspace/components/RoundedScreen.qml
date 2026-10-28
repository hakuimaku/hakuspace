import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services"

Item {
    id: rootItem
    required property var modelData

    // Keep the drawing plane fixed while Settings changes the active bar.
    readonly property bool settingsPlane: UiState.activePanel === "settings"

    // Physical corner masks and reservations share the independent screen preferences.
    readonly property real sideInset: ScreenGeometry.borderThickness
    readonly property real cornerRadius: ScreenGeometry.roundedRadius
    readonly property color frameColor: Theme.surface
    // Place the lower corners above each output's visible full bar.
    readonly property real taskbarInset: ScreenGeometry.taskbarReservation()

    // Render corner masks and rails opposite the status bar without intercepting input.
    PanelWindow {
        id: visualWindow
        screen: rootItem.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: rootItem.cornerRadius > 0 || rootItem.sideInset > 0

        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: rootItem.settingsPlane || ChromeLayout.taskbarMode ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: 0
        // Taskbar uses physical bounds so its bottom reservation is counted once.
        margins {
            left: rootItem.settingsPlane || ChromeLayout.taskbarMode ? 0 : -ScreenGeometry.leftInset
            right: rootItem.settingsPlane || ChromeLayout.taskbarMode ? 0 : -ScreenGeometry.rightInset
            bottom: rootItem.settingsPlane ? 0 : ChromeLayout.taskbarMode ? rootItem.taskbarInset
                : -ScreenGeometry.frameBottomReservation
                    - ScreenGeometry.dockbarReservation(rootItem.modelData ? rootItem.modelData.name : "")
        }
        mask: Region {}

        // Draw only the small corner masks and rails instead of repainting an output-sized image.
        Item {
            id: frame
            width: parent.width
            y: rootItem.settingsPlane && ChromeLayout.topBarMode ? Math.round(Theme.topBarHeight) : 0
            height: Math.max(0, parent.height - y - (rootItem.settingsPlane && ChromeLayout.taskbarMode ? rootItem.taskbarInset : 0))
            readonly property real t: rootItem.sideInset
            readonly property real topInset: ScreenGeometry.topBorderThickness
            readonly property real bottomInset: ScreenGeometry.bottomInset
            readonly property real r: ScreenGeometry.maskRadius(width, height)
            Repeater {
                model: 4
                delegate: Shape {
                    required property int index
                    width: frame.r; height: frame.r
                    x: index === 1 || index === 2 ? frame.width - frame.t - width : frame.t
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
            Rectangle { width: frame.t; height: parent.height; color: rootItem.frameColor }
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
        anchors { top: ChromeLayout.taskbarMode; bottom: !ChromeLayout.taskbarMode; left: true; right: true }
        exclusiveZone: rootItem.sideInset
        implicitHeight: rootItem.sideInset
        mask: Region {}
        visible: rootItem.sideInset > 0
    }

    PanelWindow {
        id: leftReservation
        screen: rootItem.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; bottom: true; left: true }
        exclusiveZone: ScreenGeometry.leftInset
        implicitWidth: ScreenGeometry.leftInset
        mask: Region {}
        visible: rootItem.sideInset > 0
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
