import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base" as Base
import "appbar" as AppBar
import "base/SafeZoneGeometry.js" as Safe
import "dock" as Dock
import "dock/DockGeometry.js" as Geometry
import "hakumenu/HakuMenuGeometry.js" as MenuGeometry

Item {
    id: root
    required property var modelData
    // Release input and reservations immediately while preserving closing frames.
    readonly property bool enabledDock: !!modelData && ChromeLayout.dockbarActive
    readonly property bool always: ShellSettingsStore.dockVisibilityMode === "always"
    readonly property int iconSize: ShellSettingsStore.dockIconSize
    // Four pixels above the item; indicators keep two pixels below them.
    readonly property real targetHeight: ScreenGeometry.dockbarHeight
    // Follow frame reservations explicitly without consuming the Dock's own zone.
    readonly property real bottomInset: ScreenGeometry.bottomInset
    readonly property real sideInset: ScreenGeometry.leftInset
    readonly property real horizontalPadding: 24
    // A removed output becomes null before its Variants delegate is destroyed.
    readonly property real targetWidth: modelData
        ? Math.min(Math.max(0, modelData.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset - Theme.hugRadius * 2),
            appContent.contentWidth + horizontalPadding * 2) : 0
    // Ownership is per output; the Dock retains its return animation independently.
    readonly property bool menuOwned: enabledDock && UiState.activePanel === "hakumenu"
        && UiState.hakuMenuSource === "dockbar" && UiState.hakuMenuScreenName === modelData.name
    readonly property bool hakuMenuDockLease: menuOwned
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property real menuMorphProgress: 0
    property bool menuReturnLease: false
    property bool menuReturnKeepVisible: false
    property bool menuControlReady: false
    readonly property bool menuVisualActive: menuOwned || menuMorphProgress > 0.001 || menuReturnLease
    // Retain the outgoing profile while UiState clears the closed menu.
    property string menuTab: "hakumenu"
    property string menuMode: "drun"
    readonly property real menuWidth: modelData ? MenuGeometry.targetWidth(modelData.width, menuTab, menuMode,
        ScreenGeometry.leftInset, ScreenGeometry.rightInset) : 0
    readonly property bool visualMoving: morph.moving || menuMotion.running
    readonly property bool appMenuDockLease: !!modelData && UiState.activePanel === "appMenu"
        && UiState.appMenu && UiState.appMenu.screenName === modelData.name
    readonly property bool shown: enabledDock && (always || revealed || menuOwned || menuReturnLease || appMenuDockLease)
    property bool revealed: false
    property string registeredOutput: ""
    readonly property var triggerRect: Geometry.trigger(dockWindow.width, dockWindow.height)
    readonly property var safeRect: Geometry.envelope(dockWindow.width, dockWindow.height,
        (menuVisualActive ? Math.max(targetWidth, menuWidth) : targetWidth) + Theme.hugRadius * 2, targetHeight + bottomInset,
        surface.width + Theme.hugRadius * 2, morph.height + bottomInset, appContent.headroom)
    readonly property var safeZones: shown ? [triggerRect, safeRect] : []
    // Release compact input immediately while its closing frames finish.
    onEnabledDockChanged: {
        if (enabledDock) return
        menuMorphProgress = 0
        menuReturnLease = false
        menuReturnKeepVisible = false
        menuControlReady = false
        revealed = false
        appContent.cancelTermination()
        appContent.cancelReorder()
        appContent.clearPinFeedback()
        UiState.closeAppMenuIfScreen(modelData ? modelData.name : "")
    }
    Component.onCompleted: syncGeometry()
    Component.onDestruction: {
        menuReturnLease = false
        ScreenGeometry.setDockbarShown(registeredOutput, false)
    }
    onShownChanged: {
        syncGeometry()
        if (!shown) { appContent.cancelTermination(); appContent.cancelReorder(); appContent.clearPinFeedback(); UiState.closeAppMenuIfScreen(modelData ? modelData.name : "") }
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
    // Only the Close control adds an explicit keep-visible return intent.
    function closeMenuFromDock() {
        if (!menuOwned) return
        menuReturnKeepVisible = true
        UiState.closeHakuMenu()
    }
    // Release the visual lease only after the reverse morph has actually finished.
    function finishMenuReturn() {
        if (menuOwned || menuMotion.running || menuMorphProgress > 0.001 || !menuReturnLease) return
        var inside = lifetime.pointerInside && Safe.containsAny(safeZones, lifetime.lastPointerX, lifetime.lastPointerY)
        if (enabledDock && !always) revealed = menuReturnKeepVisible || inside
        menuReturnKeepVisible = false
        menuReturnLease = false
        lifetime.forcePointerMode()
        lifetime.pointerMoved(lifetime.lastPointerX, lifetime.lastPointerY)
        if (!inside) lifetime.pointerExited()
    }
    // Keep the final width in sync without retaining references to HakuMenu content.
    function syncMenuProfile() {
        if (!menuOwned) return
        menuTab = UiState.hakuPanelTab
        menuMode = UiState.hakuMenuMode
    }
    onMenuOwnedChanged: {
        menuControlReady = false
        if (menuOwned) {
            menuReturnLease = true
            menuReturnKeepVisible = false
            syncMenuProfile()
            TooltipManager.dismiss()
            appContent.cancelTermination()
            appContent.cancelReorder()
            appContent.clearPinFeedback()
            appContent.pendingPin = null
            Qt.callLater(function() {
                if (root && root.menuOwned) root.menuControlReady = true
            })
        }
        menuMorphProgress = menuOwned ? 1 : 0
        if (!menuOwned) Qt.callLater(finishMenuReturn)
    }
    onMenuMorphProgressChanged: if (menuMorphProgress <= 0.001) Qt.callLater(finishMenuReturn)
    onVisualMovingChanged: {
        if (visualMoving) lifetime.beginAnimationLease()
        else lifetime.endAnimationLease()
    }
    Connections {
        target: UiState
        function onHakuPanelTabChanged() { root.syncMenuProfile() }
        function onHakuMenuModeChanged() { root.syncMenuProfile() }
    }
    Behavior on menuMorphProgress {
        enabled: root.enabledDock
        NumberAnimation {
            id: menuMotion
            duration: root.reducedMotion ? 0 : root.menuOwned ? HAnimation.dockOpenDuration : HAnimation.dockCloseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.hakuMenuResizeCurve
            onRunningChanged: if (!running) root.finishMenuReturn()
        }
    }
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
        reducedMotion: root.reducedMotion
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
        Dock.DockMenuBridgeSurface {
            id: surface
            x: (dockWindow.width - width) / 2
            y: dockWindow.height - root.bottomInset - morph.height
            progress: root.menuMorphProgress
            normalWidth: morph.width
            bridgeWidth: root.menuWidth
            normalHeight: morph.height
            bottomInset: root.bottomInset
            reducedMotion: root.reducedMotion
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
            suppressTooltips: root.menuVisualActive || root.appMenuDockLease
            enabled: !root.menuVisualActive
            opacity: Math.max(0, 1 - root.menuMorphProgress / 0.3)
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
    PanelWindow {
        id: closeOverlay
        objectName: "dock-menu-close-overlay"
        screen: root.modelData
        anchors { bottom: true; left: true; right: true }
        margins.left: root.sideInset
        margins.right: root.sideInset
        implicitHeight: root.targetHeight + root.bottomInset
        visible: root.enabledDock && root.menuOwned && root.menuControlReady && closeContainer.opacity > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
        WlrLayershell.namespace: "hakuspace-dock-menu-close"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            x: closeContainer.x; y: closeContainer.y
            width: closeButton.enabled ? closeButton.width : 0
            height: closeButton.enabled ? closeButton.height : 0
        }
        TextMetrics {
            id: closeMetrics
            text: closeButton.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        // Parent opacity avoids the button's independent enabled-state fade.
        Item {
            id: closeContainer
            width: Math.min(closeMetrics.advanceWidth + 32, Math.max(0, root.menuWidth - 24))
            height: Math.min(36, root.targetHeight - 8)
            x: (closeOverlay.width - width) / 2
            y: (root.targetHeight - height) / 2
            opacity: Math.max(0, Math.min(1, (root.menuMorphProgress - 0.45) / 0.55))
            Base.HButton {
                id: closeButton
                anchors.fill: parent
                objectName: "dock-close-hakumenu"
                text: "Close HakuMenu"
                disabledOpacity: 1
                enabled: root.menuOwned && root.menuMorphProgress > 0.45
                Accessible.role: Accessible.Button
                Accessible.name: text
                Accessible.onPressAction: root.closeMenuFromDock()
                onClicked: root.closeMenuFromDock()
                HoverHandler {
                    onPointChanged: if (root.menuOwned) lifetime.pointerMoved(closeContainer.x + point.position.x,
                        dockWindow.height - closeOverlay.height + closeContainer.y + point.position.y)
                    onHoveredChanged: if (!hovered) lifetime.pointerExited()
                }
            }
        }
    }

}
