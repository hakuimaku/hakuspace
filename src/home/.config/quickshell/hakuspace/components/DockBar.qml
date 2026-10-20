import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base" as Base
import "appbar" as AppBar
import "base/SafeZoneGeometry.js" as Safe
import "dock" as Dock
import "dock/DockGeometry.js" as Geometry

Item {
    id: root
    required property var modelData
    // Release input and reservations immediately while preserving closing frames.
    readonly property bool enabledDock: !!modelData && ChromeLayout.dockbarActive
    readonly property bool always: ShellSettingsStore.dockVisibilityMode === "always"
    readonly property int iconSize: ShellSettingsStore.dockIconSize
    // Four pixels above the item; indicators meet the surface's bottom edge.
    readonly property real targetHeight: ScreenGeometry.dockbarHeight
    // Follow frame reservations explicitly without consuming the Dock's own zone.
    readonly property real bottomInset: ScreenGeometry.bottomInset
    readonly property real sideInset: ScreenGeometry.leftInset
    readonly property real horizontalPadding: 24
    // A removed output becomes null before its Variants delegate is destroyed.
    readonly property real targetWidth: modelData
        ? Math.min(Math.max(0, modelData.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset - Theme.hugRadius * 2),
            appContent.contentWidth + horizontalPadding * 2) : 0
    // Only the Dock presentation keeps its owning output's autohide surface alive.
    readonly property bool hakuMenuDockLease: !!modelData && UiState.activePanel === "hakumenu"
        && UiState.hakuMenuStyle === "dockFloating" && UiState.hakuMenuScreenName === modelData.name
    readonly property bool shown: enabledDock && (always || revealed || hakuMenuDockLease)
    property bool revealed: false
    property string registeredOutput: ""
    readonly property var triggerRect: Geometry.trigger(dockWindow.width, dockWindow.height)
    readonly property var safeRect: Geometry.envelope(dockWindow.width, dockWindow.height,
        targetWidth + Theme.hugRadius * 2, targetHeight + bottomInset,
        morph.width + Theme.hugRadius * 2, morph.height + bottomInset, appContent.headroom)
    readonly property var safeZones: shown ? [triggerRect, safeRect] : []
    // Release compact input immediately while its closing frames finish.
    onEnabledDockChanged: {
        if (!enabledDock) { revealed = false; appContent.cancelTermination(); appContent.cancelReorder(); appContent.clearPinFeedback() }
    }
    Component.onCompleted: syncGeometry()
    Component.onDestruction: {
        ScreenGeometry.setDockbarShown(registeredOutput, false)
    }
    onShownChanged: {
        syncGeometry()
        if (!shown) { appContent.cancelTermination(); appContent.cancelReorder(); appContent.clearPinFeedback() }
        else Qt.callLater(function() {
            lifetime.forcePointerMode()
            if (hover.hovered) lifetime.pointerEntered(hover.point.position.x, hover.point.position.y)
        })
    }
    onAlwaysChanged: {
        appContent.cancelTermination()
        revealed = !always && hover.hovered
    }

    // Revealing persistent chrome does not change UiState's transient panel ownership.
    function reveal() { if (enabledDock && !always) revealed = true }
    function close() { appContent.cancelTermination(); revealed = false }
    // Remove stale output entries before publishing the current visible state.
    function syncGeometry() {
        var name = modelData ? modelData.name : ""
        if (registeredOutput && registeredOutput !== name) ScreenGeometry.setDockbarShown(registeredOutput, false)
        registeredOutput = name
        ScreenGeometry.setDockbarShown(name, shown)
    }
    Base.SafeZoneController {
        id: lifetime
        active: root.shown
        closeOnPointerExit: true
        containsPoint: function(x, y) { return Safe.containsAny(root.safeZones, x, y) }
        onCloseRequested: {
            if (root.always) appContent.cancelTermination()
            else root.close()
        }
    }
    Dock.DockMorph {
        id: morph
        shown: root.shown
        targetWidth: root.targetWidth
        targetHeight: root.targetHeight
        onMovingChanged: {
            if (moving) lifetime.beginAnimationLease()
            else lifetime.endAnimationLease()
        }
    }

    // Reserve once per reveal; visual animation never changes the zone's height.
    PanelWindow {
        screen: root.modelData
        anchors { bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "hakuspace-dock-reservation"
        visible: root.shown && ShellSettingsStore.dockExclusiveSpace
        color: "transparent"
        implicitHeight: root.targetHeight
        exclusiveZone: root.targetHeight
        mask: Region {}
    }
    PanelWindow {
        id: dockWindow
        // ScreenGeometry captures anchors relative to this bounded bottom window.
        readonly property bool bottomChromeHost: true
        screen: root.modelData
        anchors { bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-dock"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        margins.left: root.sideInset
        margins.right: root.sideInset
        visible: ChromeLayout.topBarMode && (root.enabledDock || morph.height > 0)
        color: "transparent"
        implicitHeight: root.targetHeight + 180
        // Keyboard navigation ends when an application or another panel takes focus.
        Connections {
            target: dockWindow.contentItem.Window.window
            function onActiveChanged() {
                if (!dockWindow.contentItem.Window.active) lifetime.releaseKeyboardLease()
            }
        }
        mask: Region {
            x: root.triggerRect.x; y: root.triggerRect.y
            width: root.enabledDock ? root.triggerRect.width : 0
            height: root.enabledDock ? root.triggerRect.height : 0
            Region {
                x: root.shown ? root.safeRect.x : (dockWindow.width - morph.width) / 2
                y: root.shown ? root.safeRect.y : dockWindow.height - root.bottomInset - morph.height
                width: !root.enabledDock ? 0 : root.shown ? root.safeRect.width : morph.width
                height: !root.enabledDock ? 0 : root.shown ? root.safeRect.height : morph.height
            }

        }
        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (!hovered) lifetime.pointerExited()
                else {
                    root.reveal()
                    lifetime.pointerEntered(point.position.x, point.position.y)
                }
            }
            onPointChanged: {
                if (hovered && Safe.contains(root.triggerRect, point.position.x, point.position.y)) root.reveal()
                lifetime.pointerMoved(point.position.x, point.position.y)
            }
        }
        Dock.DockFlareSurface {
            id: surface
            x: (dockWindow.width - width) / 2
            y: dockWindow.height - root.bottomInset - height
            width: morph.width
            height: morph.height
            visible: height > 0.1
        }
        AppBar.AppBarContent {
            id: appContent
            anchors.fill: parent
            modelData: root.modelData
            hostWindow: dockWindow
            inputLifetime: lifetime
            activationSource: "dockbar"
            active: root.enabledDock
            shown: root.shown
            suppressTooltips: root.hakuMenuDockLease
            bottomInset: root.bottomInset
            sideInset: root.sideInset
            targetHeight: root.targetHeight
            safeRect: root.safeRect
            visualHeight: morph.height
            viewportLimit: Math.max(0, morph.width - root.horizontalPadding * 2) + hoverPadding * 2
            pointerX: hover.hovered ? hover.point.position.x : NaN
            pointerY: hover.hovered ? hover.point.position.y : NaN
        }
    }
}
