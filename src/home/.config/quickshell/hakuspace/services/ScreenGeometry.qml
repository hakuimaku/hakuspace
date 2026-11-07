pragma Singleton
import QtQuick
import Quickshell
import "ScreenGeometry.js" as Geometry

QtObject {
    // Physical display geometry is independent from component styling radii.
    readonly property real roundedRadius: ShellSettingsStore.roundedScreenRadius
    readonly property real borderThickness: ShellSettingsStore.roundedScreenBorderThickness
    readonly property real topBorderThickness: ChromeLayout.taskbarMode || ChromeLayout.leftBarMode ? borderThickness : 0
    // Top-only overlays keep their physical edge in every status layout.
    readonly property real topChromeHeight: ChromeLayout.topBarMode ? Theme.topBarHeight : topBorderThickness
    readonly property real leftInset: borderThickness
    // Work-area chrome never changes the physical frame inset contract.
    // Vertical paint sits inside transparent touch slots with symmetric exterior gutters.
    readonly property var leftMetrics: Geometry.leftMetrics(Theme.fontSize)
    readonly property real leftVisualSize: leftMetrics.visual
    readonly property real leftVisualGutter: leftMetrics.gutter
    readonly property real leftTouchSize: leftMetrics.touch
    readonly property real leftControlSlotHeight: leftMetrics.slot
    readonly property real leftControlGap: leftMetrics.controlGap
    readonly property real leftIconSize: leftMetrics.icon
    readonly property real leftModuleTouchSize: leftTouchSize
    readonly property real leftModuleHorizontalInset: 4
    readonly property real leftModuleGap: leftMetrics.gap
    readonly property real leftModuleInset: Math.max(6, Theme.gap - 2)
    readonly property real leftModuleHoverExtent: leftMetrics.hover
    readonly property real leftBarWidth: leftMetrics.rail
    readonly property real leftChromeWidth: ChromeLayout.leftBarMode ? leftBarWidth : 0
    readonly property real reservedLeft: Math.max(leftInset, leftChromeWidth)
    readonly property real contentLeftEdge: reservedLeft
    readonly property real rightInset: borderThickness
    readonly property real bottomInset: ChromeLayout.taskbarMode ? 0 : borderThickness
    // Reserve the rail opposite the active status bar.
    readonly property real frameBottomReservation: ChromeLayout.topBarMode ? bottomInset : 0
    // App artwork shares a baseline; status modules may require a taller Taskbar.
    readonly property real appBarHeight: Math.ceil(ShellSettingsStore.dockIconSize + 17)
    readonly property real taskbarHeight: Math.ceil(Math.max(appBarHeight, Theme.fontSize * 1.8))
    readonly property real dockbarHeight: appBarHeight
    // A hidden Dock leaves bottom panels attached directly to the screen rail.
    readonly property bool bottomHostAvailable: ChromeLayout.taskbarMode || ChromeLayout.dockbarActive
    readonly property real bottomHostOppositeInset: ChromeLayout.topBarMode ? Theme.topBarHeight : topBorderThickness
    // The return control occupies the panel's footer while its Dock is hidden.
    readonly property real bottomHostControlHeight: ChromeLayout.dockbarActive && !ChromeLayout.taskbarMode ? dockbarHeight : 0
    function bottomHostReservation() {
        return bottomInset + (ChromeLayout.taskbarMode ? taskbarHeight : 0)
    }
    function bottomHostTop(screenHeight) { return screenHeight - bottomHostReservation() }
    // Taskbar owners publish and revoke physical center lanes independently per output.
    property var taskbarCenterRects: ({})
    function setTaskbarCenterRect(name, rect) {
        if (!name) return
        var previous = taskbarCenterRects[name]
        if ((!previous && !rect) || (previous && rect && previous.x === rect.x && previous.y === rect.y
            && previous.width === rect.width && previous.height === rect.height)) return
        var next = Object.assign({}, taskbarCenterRects)
        if (rect) next[name] = rect
        else delete next[name]
        taskbarCenterRects = next
    }
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
        return ChromeLayout.dockbarActive && shownDockbars[name] && ShellSettingsStore.dockExclusiveSpace ? dockbarHeight + bottomInset : 0
    }
    // Overlay clearance includes the painted bottom frame; native zones are owned separately.
    function bottomReservation(name) { return Math.max(bottomInset, dockbarReservation(name)) }
    function leftbarUsableBottom(name) { return screenHeight(name) - bottomReservation(name) }
    // Keep the Dock centered while applying equal clearance on both sides.
    function dockWidthLimit(screenWidth) { return Math.max(0, screenWidth - 2 * (Math.max(reservedLeft, rightInset) + Theme.hugRadius)) }
    function taskbarReservation() { return ChromeLayout.taskbarMode ? taskbarHeight : 0 }
    // Measure attachment distances from the active status edge.
    readonly property bool bottomAttached: ChromeLayout.taskbarMode
    readonly property real chromeBarHeight: bottomAttached ? taskbarHeight : topChromeHeight
    function chromeAttachmentY(screenHeight) { return bottomAttached ? screenHeight - taskbarHeight : topChromeHeight }
    function attachedBodyY(screenHeight, contentHeight, distance) {
        return Geometry.attachedY(chromeAttachmentY(screenHeight), contentHeight, distance || 0, bottomAttached)
    }
    function attachedPointY(screenHeight, distance) { return attachedBodyY(screenHeight, 0, distance) }
    function attachedBodyRect(screenHeight, x, width, contentHeight, distance) {
        return {x: x, y: attachedBodyY(screenHeight, contentHeight, distance), width: width, height: contentHeight}
    }
    function availableAttachedHeight(screenHeight) { return Math.max(0, screenHeight - chromeBarHeight - bottomInset - (bottomAttached ? topBorderThickness : 0)) }
    // Resolve keyboard callers against the requested output rather than a primary-screen guess.
    function screenHeight(name) {
        for (var output of Quickshell.screens) if (output.name === name) return output.height
        return 0
    }
    function barAnchor(screenHeight, x, width) {
        var height = Theme.fontSize * 1.8
        if (ChromeLayout.leftBarMode) return {x: (leftBarWidth - height) / 2,
            y: x > leftBarWidth ? Math.max(height, screenHeight - height * 2 - bottomInset) : Theme.pad,
            width: height, height: height}
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
