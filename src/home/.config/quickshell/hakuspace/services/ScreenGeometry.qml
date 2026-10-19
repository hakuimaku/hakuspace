pragma Singleton
import QtQuick
import "ScreenGeometry.js" as Geometry

QtObject {
    // Physical display geometry is independent from component styling radii.
    readonly property real roundedRadius: ShellSettingsStore.roundedScreenRadius
    readonly property real borderThickness: ShellSettingsStore.roundedScreenBorderThickness
    readonly property real topBorderThickness: 0
    readonly property real leftInset: borderThickness
    readonly property real rightInset: borderThickness
    readonly property real bottomInset: borderThickness
    // Share the Dock's fixed zone so frame visuals can cancel its inward offset.
    readonly property real dockHeight: ShellSettingsStore.dockIconSize + 17
    readonly property real dockReservedHeight: AppState.taskbarManualState && ShellSettingsStore.dockExclusiveSpace ? dockHeight : 0
    readonly property real flareTopY: Theme.topBarHeight
    readonly property real edgeHugRadius: Math.max(Theme.hugRadius, roundedRadius)

    // Optionally express physical screen bounds inside a partial-width host.
    function horizontalBounds(width, hostRect) {
        var bounds = Geometry.horizontalBounds(width, borderThickness)
        if (!hostRect) return bounds
        var local = localizeRect({x: bounds.start, y: hostRect.y,
            width: bounds.end - bounds.start, height: hostRect.height}, hostRect)
        return {start: local.x, end: local.x + local.width}
    }
    // Localize captured screen coordinates for both visual targets and safe zones.
    function localizeRect(anchorRect, hostRect) { return Geometry.localizeRect(anchorRect, hostRect) }
    // Keep corner paths valid when an output is smaller than the requested envelope.
    function maskRadius(width, height) { return Geometry.maskRadius(width, height, roundedRadius, borderThickness) }
    // Capture the real item footprint in its screen-local TopBar window.
    function itemRect(item) {
        var point = item.mapToItem(null, 0, 0)
        return {x: point.x, y: point.y, width: item.width, height: item.height}
    }
    // Keyboard/IPC entries have no live Item, so use the unchanged module lane.
    function topBarAnchor(x, width) {
        var height = Theme.fontSize * 1.8
        return {x: x, y: (Theme.topBarContentHeight - height) / 2 + Theme.topBarTopPadding / 2,
            width: width, height: height}
    }
}
