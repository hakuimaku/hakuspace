pragma Singleton
import QtQuick
import Quickshell
import "ScreenGeometry.js" as Geometry

QtObject {
    // Physical display geometry is independent from component styling radii.
    readonly property real roundedRadius: ShellSettingsStore.roundedScreenRadius
    readonly property real borderThickness: ShellSettingsStore.roundedScreenBorderThickness
    readonly property real topBorderThickness: ChromeLayout.taskbarMode ? borderThickness : 0
    readonly property real leftInset: borderThickness
    readonly property real rightInset: borderThickness
    readonly property real bottomInset: ChromeLayout.taskbarMode ? 0 : borderThickness
    // Reserve the rail opposite the active status bar.
    readonly property real frameBottomReservation: bottomInset
    // App artwork shares a baseline; status modules may require a taller Taskbar.
    readonly property real appBarHeight: Math.ceil(ShellSettingsStore.dockIconSize + 17)
    readonly property real taskbarHeight: Math.ceil(Math.max(appBarHeight, Theme.fontSize * 1.8))
    readonly property real dockbarHeight: appBarHeight
    property var shownDockbars: ({})
    function setDockbarShown(name, shown) {
        if (!name || !!shownDockbars[name] === shown) return
        var next = Object.assign({}, shownDockbars)
        if (shown) next[name] = true
        else delete next[name]
        shownDockbars = next
    }
    // Compact reservations never stand in for the fixed Taskbar zone.
    function dockbarReservation(name) {
        return ChromeLayout.dockbarActive && shownDockbars[name] && ShellSettingsStore.dockExclusiveSpace ? dockbarHeight : 0
    }
    function taskbarReservation() { return ChromeLayout.taskbarMode ? taskbarHeight : 0 }
    // Measure attachment distances from the active status edge.
    readonly property bool bottomAttached: ChromeLayout.taskbarMode
    readonly property real chromeBarHeight: bottomAttached ? taskbarHeight : Theme.topBarHeight
    function chromeAttachmentY(screenHeight) { return bottomAttached ? screenHeight - taskbarHeight : Theme.topBarHeight }
    function attachedBodyY(screenHeight, contentHeight, distance) {
        return Geometry.attachedY(chromeAttachmentY(screenHeight), contentHeight, distance || 0, bottomAttached)
    }
    function attachedPointY(screenHeight, distance) { return attachedBodyY(screenHeight, 0, distance) }
    function attachedBodyRect(screenHeight, x, width, contentHeight, distance) {
        return {x: x, y: attachedBodyY(screenHeight, contentHeight, distance), width: width, height: contentHeight}
    }
    function availableAttachedHeight(screenHeight) { return Math.max(0, screenHeight - chromeBarHeight - bottomInset - topBorderThickness) }
    // Resolve keyboard callers against the requested output rather than a primary-screen guess.
    function screenHeight(name) {
        for (var output of Quickshell.screens) if (output.name === name) return output.height
        return 0
    }
    function barAnchor(screenHeight, x, width) {
        var height = Theme.fontSize * 1.8
        return {x: x, y: bottomAttached ? screenHeight - taskbarHeight + (taskbarHeight - height) / 2
            : (Theme.topBarContentHeight - height) / 2 + Theme.topBarTopPadding / 2, width: width, height: height}
    }
    function fallbackModuleAnchor(name, x, width) { return barAnchor(screenHeight(name), x, width) }
    // Preserve the top-only API for existing top-layout fixtures.
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
    // Capture the real module footprint in output coordinates for either owning window.
    function itemRect(item) {
        var point = item.mapToItem(null, 0, 0)
        var lane = item
        while (lane && lane.screenOffsetY === undefined) lane = lane.parent
        return {x: point.x, y: point.y + (lane ? lane.screenOffsetY : 0), width: item.width, height: item.height}
    }
    // Keyboard/IPC entries have no live Item, so use the unchanged module lane.
    function topBarAnchor(x, width) {
        var height = Theme.fontSize * 1.8
        return {x: x, y: (Theme.topBarContentHeight - height) / 2 + Theme.topBarTopPadding / 2,
            width: width, height: height}
    }
}
