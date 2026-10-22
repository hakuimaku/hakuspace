import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base" as Base
import "base/SafeZoneGeometry.js" as SafeZoneGeometry
import "flare" as Flare
import "sidebar" as Sidebar
import "dashboard" as Dashboard

Item {
    id: root
    required property var modelData

    readonly property bool panelOpen: UiState.activePanel === "navigation"
                                      && UiState.navigationMode !== "closed"
                                      && UiState.navigationScreenName === modelData.name
    readonly property bool dashboardExpanded: panelOpen && UiState.navigationMode === "handoff-dashboard"
    readonly property bool dashboardVisuallyActive: dashboardExpanded || dashboardMorphProgress > 0.001
    property real dashboardMorphProgress: 0.0

    onDashboardExpandedChanged: {
        dashboardMorphAnim.stop()
        if (dashboardExpanded) {
            dashboardMorphAnim.from = dashboardMorphProgress
            dashboardMorphAnim.to = 1.0
            dashboardMorphAnim.duration = HAnimation.dashboardOpenDuration
            dashboardMorphAnim.easing.bezierCurve = HAnimation.dashboardOpenCurve
            dashboardMorphAnim.start()
        } else {
            dashboardMorphAnim.from = dashboardMorphProgress
            dashboardMorphAnim.to = 0.0
            dashboardMorphAnim.duration = HAnimation.dashboardCloseDuration
            dashboardMorphAnim.easing.bezierCurve = HAnimation.dashboardCloseCurve
            dashboardMorphAnim.start()
            if (panelOpen) {
                selectedIndex = 0
                hoveredIndex = -1
                Qt.callLater(function() {
                    if (root.panelOpen)
                        keyHandler.forceActiveFocus()
                })
            }
        }
    }

    NumberAnimation {
        id: dashboardMorphAnim
        target: root
        property: "dashboardMorphProgress"
        onFinished: {
            if (root.closingFromDashboard) {
                UiState.finishNavigationVisual(root.modelData.name)
                Qt.callLater(function() {
                    root.closing = false
                    root.closingFromDashboard = false
                    root.closeCollapseProgress = 0.0
                    root.closeReturnProgress = 0.0
                    root.closeFlareProgress = 0.0
                    root.seedLogoGeometry()
                })
            }
        }
    }

    onDashboardVisuallyActiveChanged: {
        if (root.modelData && (UiState.navigationScreenName === root.modelData.name
                               || UiState.navigationVisualScreenName === root.modelData.name
                               || UiState.navigationScreenName === "")) {
            UiState.dashboardVisuallyActive = dashboardVisuallyActive
        }
    }
    property bool closing: false
    property bool closingFromDashboard: false
    property int selectedIndex: 0
    property int hoveredIndex: -1

    // Follow the active region angle for both selected and hovered wedges.
    readonly property int activeTargetIndex: hoveredIndex >= 0 ? hoveredIndex : selectedIndex
    property real morphAngle: 270.0

    function updateMorphTarget() {
        if (activeTargetIndex < 0 || activeTargetIndex >= regions.length) return
        var target = regions[activeTargetIndex].labelAngle
        var diff = (target - morphAngle) % 360.0
        if (diff > 180.0) diff -= 360.0
        else if (diff < -180.0) diff += 360.0
        morphAngle = morphAngle + diff
    }

    onActiveTargetIndexChanged: updateMorphTarget()

    Behavior on morphAngle {
        id: morphAngleBehavior
        enabled: root.panelOpen && !root.closing
        NumberAnimation {
            duration: HAnimation.buttonSelectDuration
            easing.bezierCurve: HAnimation.buttonSelectCurve
        }
    }

    // Close is two-phase: first fold the radial sectors into the Logo hub,
    // then return the Logo while the backing retracts into RoundedScreen.
    property real closeCollapseProgress: 0.0
    property real closeReturnProgress: 0.0
    property real closeFlareProgress: 0.0

    // Selection and hover are intentionally separate: selection owns accent;
    // hover uses a neutral gray and expands the sector/icon.
    readonly property color selectedColor: Theme.accent
    readonly property color hoverColor: Qt.lighter(Theme.hoverMuted, 1.35)
    readonly property color idleColor: Qt.darker(Theme.hoverMuted, 1.18)
    readonly property real hoverSliceScale: 1.20
    readonly property real hoverTextScale: 1.40
    readonly property real outerSectorRadius: circleRadius - 7
    readonly property real innerSectorRadius: Math.max(14, circleRadius * 0.18)
    readonly property real hubDiameter: Math.max(18, circleRadius * 0.28)
    readonly property real backingCurveRadius: circleRadius + shellPadding + 60

    // Navigation lives in one Overlay so exclusive zones cannot move it, while
    // the backing contour aligns to the shared RoundedScreen frame geometry.
    readonly property real sideInset: ScreenGeometry.leftInset
    readonly property real attachmentY: ScreenGeometry.chromeAttachmentY(modelData.height)
    // Map corner-relative Navigation coordinates around the active chrome seam.
    readonly property real logicalAttachmentY: ScreenGeometry.chromeBarHeight
    function mapY(logicalY, objectHeight) {
        return ScreenGeometry.attachedBodyY(modelData.height, objectHeight, logicalY - logicalAttachmentY)
    }
    function mappedRect(rect) {
        return {x: rect.x, y: mapY(rect.y, rect.height), width: rect.width, height: rect.height}
    }
    readonly property var horizontalBounds: ScreenGeometry.horizontalBounds(modelData.width)
    // Keep the steady-state backing tight around the radial controller.
    readonly property real shellPadding: 4
    readonly property real flareExtraBottom: 8
    readonly property real circleDiameter: Math.max(146, Theme.fontSize * 10.5)
    readonly property real circleRadius: circleDiameter / 2
    readonly property real circularShellDiameter: circleDiameter + shellPadding * 2
    readonly property real shellX: 0
    readonly property real shellY: 0
    readonly property real surfaceStart: sideInset
    readonly property real surfaceWidth: Math.max(0, surfaceEnd - surfaceStart)
    readonly property real surfaceHeight: circularShellDiameter + flareExtraBottom
    readonly property real surfaceEnd: Math.min(horizontalBounds.end, circularShellDiameter + flareExtraBottom)
    readonly property real flareTargetHeight: Math.max(1, surfaceHeight - logicalAttachmentY)
    readonly property real flareReach: ScreenGeometry.edgeHugRadius
    readonly property real hoverOverflow: Math.ceil(circleDiameter * 0.12)
    readonly property real controllerX: shellX + shellPadding
    readonly property real controllerY: shellY + shellPadding
    readonly property real dashboardWidthRatio: 0.50
    readonly property real dashboardHeightRatio: 0.50
    readonly property real dashboardVisualWidth: Math.round(modelData.width * dashboardWidthRatio)
    readonly property real dashboardVisualHeight: Math.round(modelData.height * dashboardHeightRatio)

    // Sidebar interaction geometry:
    readonly property bool sidebarExpanded: UiState.navigationMode === "handoff-sidebar"
    readonly property real sidebarControlDiameter: Math.max(50, Math.round(Theme.fontSize * 3.1))
    readonly property real sidebarBodyPadding: Math.max(10, Theme.pad)
    readonly property real sidebarBodyWidth: Math.max(70, sidebarControlDiameter + sidebarBodyPadding * 2)
    readonly property real sidebarBodyHeight: Math.max(1, Math.min(sidebarSurface.preferredBodyHeight,
        520, ScreenGeometry.availableAttachedHeight(modelData.height) + logicalAttachmentY - sidebarBodyY - flareReach - 16))
    readonly property real railHoverOverflow: 6
    readonly property real sidebarBodyX: 0
    readonly property real sidebarBodyY: Math.round(circularShellDiameter * 0.94)
    readonly property real sidebarEarWidth: Math.max(32, Math.round(flareReach * 1.5))
    readonly property real sidebarEarRadius: sidebarEarWidth + Theme.giantRadius * 2

    // Keep the ear tip inside Navigation's rounded contour as its width grows.
    readonly property real sidebarJoinRadius: Math.max(0, Math.min(backingCurveRadius,
        (surfaceEnd - surfaceStart) / 2, flareTargetHeight / 2))
    readonly property real sidebarJoinInset: Math.min(sidebarJoinRadius,
        Math.max(0, sidebarBodyWidth + sidebarEarWidth - surfaceEnd + sidebarJoinRadius))
    readonly property real sidebarTopFlareY: Math.max(0, surfaceHeight - sidebarBodyY - sidebarJoinRadius
        + Math.sqrt(Math.max(0, sidebarJoinRadius * sidebarJoinRadius - sidebarJoinInset * sidebarJoinInset)))

    // Bridge connects the lower-left radial sector to the sidebar body:
    readonly property real bridgeX: 0
    readonly property real bridgeY: Math.round(controllerY + circleRadius)
    readonly property real bridgeWidth: Math.max(sidebarBodyWidth, Math.round(circleRadius + shellPadding))
    readonly property real bridgeHeight: Math.max(1, (sidebarBodyY + Math.min(24, sidebarBodyHeight * 0.1)) - bridgeY)

    // One tool key owns the attached shell; rail selection remains independent.
    property string activeSidebarTool: ""
    property string renderedSidebarTool: ""
    property int sidebarSelectedIndex: 0
    property bool sidebarKeyboardMode: false
    property alias keyboardLease: lifetime.keyboardLease
    readonly property bool sidebarToolOpen: activeSidebarTool.length > 0
    readonly property bool sidebarToolVisible: sidebarToolOpen || (sidebarToolLayer && sidebarToolLayer.activeProgress > 0.001)
    readonly property bool sidebarInteractionVisible: sidebarExpanded || sidebarToolVisible
    readonly property real sidebarToolX: sidebarBodyWidth + 30
    readonly property real sidebarToolY: Math.max(0, Math.min(sidebarBodyY + 40,
        modelData.height - sidebarToolPreferredHeight - 12))
    readonly property real sidebarToolPreferredWidth: renderedSidebarTool === "quickActions" ? 540 : 460
    readonly property real sidebarToolPreferredHeight: renderedSidebarTool === "quickActions" ? 240 : 360
    readonly property real sidebarToolWidth: Math.max(1, Math.min(sidebarToolPreferredWidth,
        modelData.width - sidebarToolX - 12))
    readonly property real sidebarToolHeight: Math.max(1, Math.min(sidebarToolPreferredHeight,
        modelData.height - sidebarToolY - 12))
    readonly property var liveSafeZones: {
        var margin = Interaction.safeZoneMargin
        var empty = SafeZoneGeometry.rect(0, 0, 0, 0)
        var radial = SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(
            SafeZoneGeometry.rect(0, 0, circularShellDiameter, circularShellDiameter), margin),
            modelData.width, modelData.height)
        var anchor = SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(
            SafeZoneGeometry.rect(capturedAnchorRect.x, capturedAnchorRect.y,
                                  capturedAnchorRect.width, capturedAnchorRect.height),
            Interaction.safeZoneAnchorMargin), modelData.width, modelData.height)
        var bridge = sidebarInteractionVisible ? SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(
            SafeZoneGeometry.rect(bridgeX, bridgeY, bridgeWidth, bridgeHeight), margin / 2),
            modelData.width, modelData.height) : empty
        var railVisual = SafeZoneGeometry.rect(sidebarBodyX, sidebarBodyY,
            sidebarBodyWidth + railHoverOverflow, sidebarBodyHeight + flareReach)
        var rail = sidebarInteractionVisible ? SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(
            railVisual, margin),
            modelData.width, modelData.height) : empty
        var ear = sidebarInteractionVisible ? SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(
            SafeZoneGeometry.rect(sidebarBodyWidth, sidebarBodyY + sidebarTopFlareY,
                                  sidebarEarWidth, sidebarEarRadius), margin / 2),
            modelData.width, modelData.height) : empty
        var toolVisual = sidebarToolVisible ? SafeZoneGeometry.rect(sidebarToolX, sidebarToolY,
            sidebarToolLayer.interactionWidth, sidebarToolLayer.interactionHeight) : empty
        var tool = sidebarToolVisible ? SafeZoneGeometry.clampRect(
            SafeZoneGeometry.inflate(toolVisual, margin),
            modelData.width, modelData.height) : empty
        var toolBridge = tool.width ? SafeZoneGeometry.clampRect(
            SafeZoneGeometry.horizontalBridge(railVisual, toolVisual, Interaction.safeZoneCorridorWidth),
            modelData.width, modelData.height) : empty
        var dashboard = dashboardVisuallyActive ? SafeZoneGeometry.clampRect(
            SafeZoneGeometry.inflate(SafeZoneGeometry.rect(0,
                ScreenGeometry.bottomAttached ? dashboardSurface.contentOriginY : 0, dashboardVisualWidth,
                ScreenGeometry.bottomAttached ? dashboardSurface.currentBodyHeight : dashboardVisualHeight), margin), modelData.width, modelData.height) : empty
        return [radial, anchor, bridge, rail, ear, toolBridge, tool, dashboard].map(function(rect, index) {
            return index === 1 || index === 7 ? rect : root.mappedRect(rect)
        })
    }
    property var frozenSafeZones: []
    onLiveSafeZonesChanged: if (panelOpen && !closing) frozenSafeZones = liveSafeZones
    readonly property var safeZones: closing && !panelOpen ? frozenSafeZones : liveSafeZones
    function safeZone(index) { return safeZones[index] || SafeZoneGeometry.rect(0, 0, 0, 0) }
    function safeContains(x, y) { return SafeZoneGeometry.containsAny(safeZones, x, y) }

    Base.SafeZoneController {
        id: lifetime
        active: root.panelOpen
        closing: root.closing
        containsPoint: function(x, y) { return root.safeContains(x, y) }
        onCloseRequested: root.requestClose()
    }

    onSidebarExpandedChanged: {
        if (!sidebarExpanded) {
            if (sidebarToolOpen) closeSidebarTool()
            sidebarKeyboardMode = false
        }
    }

    // Return focus to the rail after a tool or radial handoff.
    function focusSidebarRail(fromKeyboard) {
        sidebarKeyboardMode = !!fromKeyboard
        keyboardLease = !!fromKeyboard
        if (panelOpen) keyHandler.forceActiveFocus()
        Qt.callLater(function() {
            if (root.panelOpen && root.sidebarKeyboardMode === !!fromKeyboard
                    && (!root.sidebarToolOpen || fromKeyboard))
                keyHandler.forceActiveFocus()
        })
    }

    // Give newly loaded content keyboard ownership.
    function focusActiveSidebarTool() {
        if (!panelOpen || !sidebarToolOpen || sidebarKeyboardMode) return
        sidebarToolLayer.forceFocus()
        Qt.callLater(function() {
            if (root.panelOpen && root.sidebarToolOpen && !root.sidebarKeyboardMode)
                sidebarToolLayer.forceFocus()
        })
    }

    // Replace content in the existing attached shell.
    function openSidebarTool(key, fromKeyboard) {
        var index = sidebarSurface.tools.findIndex(function(tool) { return tool.key === key })
        if (index < 0) return
        sidebarSelectedIndex = index
        if (!sidebarExpanded) UiState.beginNavigationHandoff("sidebar")
        renderedSidebarTool = key
        activeSidebarTool = key
        sidebarKeyboardMode = false
        keyboardLease = !!fromKeyboard
        lifetime.cancelClose()
        focusActiveSidebarTool()
    }

    // Close the attached utility before returning to rail navigation.
    function closeSidebarTool(fromKeyboard) {
        if (!sidebarToolOpen) return
        activeSidebarTool = ""
        focusSidebarRail(fromKeyboard)
    }

    // A second activation closes the current tool.
    function toggleSidebarTool(key, fromKeyboard) {
        if (key === "tempNote") {
            if (sidebarToolOpen) closeSidebarTool(fromKeyboard)
            sidebarSelectedIndex = sidebarSurface.tools.findIndex(tool => tool.key === key)
            UiState.toggleTempNote(modelData.name)
            focusSidebarRail(true)
            keyboardLease = !!fromKeyboard
            return
        }
        if (activeSidebarTool === key) closeSidebarTool(fromKeyboard)
        else openSidebarTool(key, fromKeyboard)
    }

    // Keep the rail cursor within the available utilities.
    function moveSidebarSelection(delta) {
        sidebarSelectedIndex = Math.max(0, Math.min(sidebarSurface.tools.length - 1, sidebarSelectedIndex + delta))
    }

    // Activate the rail cursor without changing hover state.
    function activateSidebarSelection() {
        toggleSidebarTool(sidebarSurface.tools[sidebarSelectedIndex].key, true)
    }

    // Keep dispatch in the parent so closing the tool cannot cancel its command.
    function runQuickAction(key) {
        if (key === "settings") {
            if (sidebarToolOpen) closeSidebarTool()
            if (sidebarExpanded) UiState.cancelNavigationHandoff()
            UiState.openSettings(modelData.name)
            return
        }
        if (key !== "screenshot" && key !== "lock" && key !== "wallpaper") return
        var script = key === "screenshot" ? "screenshot.sh"
                   : key === "lock" ? "lock.sh" : "wallpaper_select.sh"
        if (key === "screenshot") Quickshell.execDetached([Env.binDir + "/" + script])
        UiState.closeNavigation()
        if (key !== "screenshot")
            Qt.callLater(function() { Quickshell.execDetached([Env.binDir + "/" + script]) })
    }

    function requestClose() {
        if (!panelOpen) return
        if (sidebarToolOpen) closeSidebarTool()
        if (sidebarExpanded || dashboardExpanded) UiState.cancelNavigationHandoff()
        UiState.closeNavigation()
    }

    function insideSidebarSector(x, y) {
        var lx = x - controllerX
        var ly = y - mapY(controllerY, circleDiameter)
        var idx = indexAt(lx, ly, true)
        return idx >= 0 && regions[idx].key === "sidebar"
    }

    function evaluatePointer(x, y) {
        if (!panelOpen || closing) return
        lifetime.pointerMoved(x, y)
        if (dashboardExpanded) return

        if (insideSidebarSector(x, y) || (sidebarExpanded &&
                (SafeZoneGeometry.contains(safeZone(2), x, y)
                 || SafeZoneGeometry.contains(safeZone(3), x, y)
                 || SafeZoneGeometry.contains(safeZone(4), x, y)
                 || SafeZoneGeometry.contains(safeZone(5), x, y)
                 || SafeZoneGeometry.contains(safeZone(6), x, y)))) {
            root.selectedIndex = 1
            root.hoveredIndex = 1
            if (UiState.navigationMode !== "handoff-sidebar" && insideSidebarSector(x, y))
                UiState.beginNavigationHandoff("sidebar")
            return
        }

        if (SafeZoneGeometry.contains(safeZone(0), x, y)) {
            // Check if pointer deliberately hovered another sector (Dashboard or Settings)
            var lx = x - root.controllerX
            var ly = y - root.mapY(root.controllerY, root.circleDiameter)
            var idx = root.indexAt(lx, ly, true)
            if (idx >= 0 && root.regions[idx].key !== "sidebar") {
                root.selectedIndex = idx
                root.hoveredIndex = idx
                if (UiState.navigationMode === "handoff-sidebar") {
                    if (sidebarToolOpen) root.closeSidebarTool()
                    UiState.cancelNavigationHandoff()
                }
            }
            return
        }
    }

    // Logo geometry is captured when Navigation opens. Keeping this copy local
    // lets the Flare close back toward the Logo after UiState has already reset.
    property var capturedAnchorRect: ScreenGeometry.barAnchor(modelData.height, Theme.pad, Theme.fontSize * 1.8)

    readonly property real anchorStart: Math.max(0,
                                                   Math.min(modelData.width - 1, capturedAnchorRect.x))
    readonly property real anchorY: Math.max(0,
                                              Math.min(modelData.height - 1, capturedAnchorRect.y))
    readonly property real anchorEnd: Math.max(anchorStart + 1,
                                               Math.min(modelData.width,
                                                        anchorStart + capturedAnchorRect.width))
    // The Logo is clicked while hovered, so capturedAnchorRect.width can be wider
    // than the normal circular button. Opening keeps that exact footprint, but
    // closing must return to the stable circle size (the Logo height), never
    // to the hover-expanded pill width.
    readonly property real returnAnchorSize: Math.max(1, capturedAnchorRect.height)
    readonly property real anchorBodyHeight: Math.max(1, Math.min(surfaceHeight, capturedAnchorRect.height))

    property real flareStart: anchorStart
    property real flareEnd: anchorEnd
    property real flareHeight: anchorBodyHeight
    readonly property real morphProgress: {
        var span = Math.max(1, flareTargetHeight - anchorBodyHeight)
        return Math.max(0, Math.min(1, (flareHeight - anchorBodyHeight) / span))
    }
    readonly property real contentProgress: Math.max(0, Math.min(1,
        (morphProgress - 0.12) / 0.88))
    // The Logo proxy grows from the TopBar footprint into the radial hub;
    // sectors reveal after most of that travel has completed.
    readonly property real openLogoMorphProgress: {
        var t = Math.max(0, Math.min(1, contentProgress / 0.82))
        return t * t * (3 - 2 * t)
    }
    readonly property real openNavigationRevealProgress: Math.max(0, Math.min(1,
        (contentProgress - 0.18) / 0.82))
    readonly property real logoMorphProgress: closing
        ? Math.max(0, 1.0 - closeReturnProgress)
        : openLogoMorphProgress
    readonly property real navigationRevealProgress: closing
        ? Math.max(0, 1.0 - closeCollapseProgress)
        : openNavigationRevealProgress
    // The TopBar Logo becomes the Navigation hub and returns to its stable
    // circular footprint on close.
    readonly property real logoTargetSize: hubDiameter
    readonly property real logoTargetX: controllerX + circleRadius - logoTargetSize / 2
    readonly property real logoTargetY: controllerY + circleRadius - logoTargetSize / 2
    readonly property real logoProxyX: anchorStart + (logoTargetX - anchorStart) * logoMorphProgress
    readonly property real logoProxyY: anchorY + (mapY(logoTargetY, logoTargetSize) - anchorY) * logoMorphProgress
    readonly property real logoBaseWidth: (panelOpen && !closing) ? capturedAnchorRect.width : returnAnchorSize
    readonly property real logoBaseHeight: (panelOpen && !closing) ? capturedAnchorRect.height : returnAnchorSize
    readonly property real logoProxyWidth: logoBaseWidth
                                            + (logoTargetSize - logoBaseWidth) * logoMorphProgress
    readonly property real logoProxyHeight: logoBaseHeight
                                             + (logoTargetSize - logoBaseHeight) * logoMorphProgress

    function blendColor(c1, c2, t) {
        var a1 = Qt.color(c1)
        var a2 = Qt.color(c2)
        var clamped = Math.max(0.0, Math.min(1.0, t))
        return Qt.rgba(
            a1.r + (a2.r - a1.r) * clamped,
            a1.g + (a2.g - a1.g) * clamped,
            a1.b + (a2.b - a1.b) * clamped,
            a1.a + (a2.a - a1.a) * clamped
        )
    }
    // Sector angles use canvas coordinates: 0° right, 90° down.
    // Top layout uses three equal 120° sectors, reflected below for Full bar:
    // Sidebar: lower-left (90° -> 210°, center 150°);
    // Dashboard: top (210° -> 330°, center 270°);
    // Settings: lower-right (330° -> 450°, center 30°).
    readonly property var regions: [
        { key: "dashboard", icon: "", startDeg: 210, endDeg: 330,
          labelAngle: 270, labelRadius: 0.46, offsetX: -5, offsetY: 0 },
        { key: "sidebar", icon: "", startDeg: 90, endDeg: 210,
          labelAngle: 150, labelRadius: 0.50, offsetX: -4, offsetY: 0 },
        { key: "settings", icon: "", startDeg: 330, endDeg: 450,
          labelAngle: 30, labelRadius: 0.50, offsetX: 0, offsetY: 0 }
    ].map(function(region) {
        // Reflect sectors, labels and hit targets together without flipping glyphs.
        if (!ScreenGeometry.bottomAttached) return region
        var start = normalizeAngle(-region.endDeg)
        return Object.assign({}, region, {startDeg: start, endDeg: start + 120,
            labelAngle: normalizeAngle(-region.labelAngle), offsetY: -region.offsetY})
    })

    function normalizeAngle(deg) {
        var a = deg % 360
        return a < 0 ? a + 360 : a
    }

    function angleInSector(angle, startDeg, endDeg) {
        var a = normalizeAngle(angle)
        var s = normalizeAngle(startDeg)
        var e = normalizeAngle(endDeg)
        if (s <= e) {
            return a >= s && a < e
        } else {
            return a >= s || a < e
        }
    }

    // Tight bounds keep hover expansion centered on the active sector.
    function sectorBounds(startDeg, endDeg) {
        var r = outerSectorRadius
        var cx = circleRadius
        var cy = circleRadius
        var angles = [startDeg, endDeg]
        var cardinals = [0, 90, 180, 270, 360, 450]
        for (var i = 0; i < cardinals.length; ++i) {
            if (cardinals[i] >= startDeg && cardinals[i] <= endDeg)
                angles.push(cardinals[i])
        }

        var minX = cx
        var maxX = cx
        var minY = cy
        var maxY = cy
        for (var j = 0; j < angles.length; ++j) {
            var a = angles[j] * Math.PI / 180
            var px = cx + Math.cos(a) * r
            var py = cy + Math.sin(a) * r
            minX = Math.min(minX, px)
            maxX = Math.max(maxX, px)
            minY = Math.min(minY, py)
            maxY = Math.max(maxY, py)
        }

        var pad = 3
        return {
            x: minX - pad,
            y: minY - pad,
            width: Math.max(1, maxX - minX + pad * 2),
            height: Math.max(1, maxY - minY + pad * 2)
        }
    }

    function indexAt(localX, localY, allowHoverOverflow) {
        var dx = localX - circleRadius
        var dy = localY - circleRadius
        var hitRadius = circleRadius * (allowHoverOverflow ? 1.10 : 1.0)
        if (Math.sqrt(dx * dx + dy * dy) > hitRadius) return -1

        var angle = normalizeAngle(Math.atan2(dy, dx) * 180 / Math.PI)
        for (var i = 0; i < regions.length; ++i) {
            if (angleInSector(angle, regions[i].startDeg, regions[i].endDeg))
                return i
        }
        return -1
    }

    function selectIndex(index, updateHandoff) {
        if (index < 0 || index >= regions.length) return
        if (selectedIndex === index && regions[index].key === "sidebar" && sidebarExpanded) {
            UiState.cancelNavigationHandoff()
            return
        }
        selectedIndex = index
        if (regions[index].key === "sidebar") {
            if (updateHandoff) UiState.beginNavigationHandoff("sidebar")
        } else if (UiState.navigationMode === "handoff-sidebar") {
            UiState.cancelNavigationHandoff()
        }
    }

    function moveSelection(delta) {
        var count = regions.length
        selectIndex((selectedIndex + delta + count) % count, false)
    }

    function activateIndex(index, fromKeyboard) {
        if (index < 0 || index >= regions.length) return
        selectedIndex = index
        if (regions[index].key === "sidebar") {
            if (!sidebarExpanded) UiState.beginNavigationHandoff("sidebar")
            focusSidebarRail(fromKeyboard)
            return
        }
        if (regions[index].key === "dashboard") {
            if (sidebarExpanded) UiState.cancelNavigationHandoff()
            UiState.beginNavigationHandoff("dashboard")
            return
        }
        if (regions[index].key === "settings") {
            if (sidebarExpanded) UiState.cancelNavigationHandoff()
            UiState.openSettings(modelData.name)
            return
        }
        selectIndex(index, true)
    }

    function activateSelected() {
        activateIndex(selectedIndex, true)
    }

    function iconCenterX(index) {
        var angle = regions[index].labelAngle * Math.PI / 180
        return circleRadius + circleRadius * regions[index].labelRadius * Math.cos(angle)
    }

    function iconCenterY(index) {
        var angle = regions[index].labelAngle * Math.PI / 180
        return circleRadius + circleRadius * regions[index].labelRadius * Math.sin(angle)
    }

    function captureAnchor() {
        capturedAnchorRect = ScreenGeometry.localizeRect(UiState.navigationAnchorRect
            || ScreenGeometry.barAnchor(modelData.height, Theme.pad, Theme.fontSize * 1.8),
            {x: 0, y: 0, width: modelData.width, height: modelData.height})
    }

    function seedLogoGeometry() {
        flareStart = anchorStart
        flareEnd = anchorEnd
        flareHeight = Math.min(anchorBodyHeight, flareTargetHeight)
    }

    Connections {
        target: ChromeLayout
        // Drop an in-flight envelope instead of replaying it at the opposite edge.
        function onTaskbarModeChanged() {
            Qt.callLater(function() {
                if (root.panelOpen) return
                openMorph.stop()
                closeMorph.stop()
                dashboardMorphAnim.stop()
                root.closing = false
                root.closingFromDashboard = false
                root.dashboardMorphProgress = 0
                root.flareHeight = 0
                root.closeCollapseProgress = 0
                root.closeReturnProgress = 0
                root.closeFlareProgress = 0
                root.capturedAnchorRect = ScreenGeometry.barAnchor(root.modelData.height, Theme.pad, Theme.fontSize * 1.8)
                UiState.finishNavigationVisual(root.modelData.name)
            })
        }
    }

    Component.onDestruction: {
        UiState.closeNavigationIfScreen(modelData.name)
        UiState.finishNavigationVisual(modelData.name)
    }

    onPanelOpenChanged: {
        openMorph.stop()
        closeMorph.stop()

        if (panelOpen) {
            sidebarKeyboardMode = false
            closing = false
            closingFromDashboard = false
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            dashboardMorphAnim.stop()
            dashboardMorphProgress = 0.0
            captureAnchor()
            selectedIndex = UiState.navigationMode === "handoff-sidebar" ? 1
                            : UiState.navigationMode === "handoff-settings" ? 2 : 0
            hoveredIndex = -1
            morphAngle = regions[selectedIndex].labelAngle

            if (flareHeight <= anchorBodyHeight + 0.5)
                seedLogoGeometry()
            openMorph.start()
            Qt.callLater(function() {
                if (root.panelOpen) keyHandler.forceActiveFocus()
            })
            return
        }

        lifetime.cancelClose()
        if (root.sidebarToolOpen) root.closeSidebarTool()

        // Ownership moving to another monitor does not animate the stale output.
        if (UiState.activePanel === "navigation") {
            closing = false
            closingFromDashboard = false
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            dashboardMorphAnim.stop()
            dashboardMorphProgress = 0.0
            seedLogoGeometry()
            return
        }

        var wasInDashboard = root.dashboardVisuallyActive || root.dashboardMorphProgress > 0.05
        if (wasInDashboard) {
            root.closingFromDashboard = true
            root.closing = true
            root.hoveredIndex = -1
            return
        }

        if (flareHeight > anchorBodyHeight + 0.5) {
            closingFromDashboard = false
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            hoveredIndex = -1
            closing = true
            closeMorph.start()
        } else {
            closing = false
            closingFromDashboard = false
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            dashboardMorphAnim.stop()
            dashboardMorphProgress = 0.0
            seedLogoGeometry()
            UiState.finishNavigationVisual(modelData.name)
        }
    }

    ParallelAnimation {
        id: openMorph
        NumberAnimation {
            target: root; property: "flareStart"; to: root.surfaceStart
            duration: HAnimation.navigationOpenDuration; easing.bezierCurve: HAnimation.navigationOpenCurve
        }
        NumberAnimation {
            target: root; property: "flareEnd"; to: root.surfaceEnd
            duration: HAnimation.navigationOpenDuration; easing.bezierCurve: HAnimation.navigationOpenCurve
        }
        NumberAnimation {
            target: root; property: "flareHeight"; to: root.flareTargetHeight
            duration: HAnimation.navigationOpenDuration; easing.bezierCurve: HAnimation.navigationOpenCurve
        }
    }

    SequentialAnimation {
        id: closeMorph

        // Fold the navigation slices and outer ring into the hub first while keeping flare geometry stable.
        NumberAnimation {
            target: root
            property: "closeCollapseProgress"
            from: 0.0
            to: 1.0
            duration: HAnimation.navigationCollapseDuration
            easing.bezierCurve: HAnimation.navigationCloseCurve
        }

        // Once only the Logo hub remains, return it to the TopBar while the
        // flare retracts into the RoundedScreen seam without horizontal deformation.
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "closeReturnProgress"
                from: 0.0
                to: 1.0
                duration: HAnimation.navigationCloseDuration
                easing.bezierCurve: HAnimation.navigationCloseCurve
            }
            NumberAnimation {
                target: root
                property: "closeFlareProgress"
                from: 0.0
                to: 1.0
                duration: HAnimation.navigationCloseDuration
                easing.bezierCurve: HAnimation.navigationCloseCurve
            }
            NumberAnimation {
                target: root
                property: "flareHeight"
                to: 0.0
                duration: HAnimation.navigationCloseDuration
                easing.bezierCurve: HAnimation.navigationCloseCurve
            }
        }

        onFinished: {
            UiState.finishNavigationVisual(root.modelData.name)
            Qt.callLater(function() {
                root.closing = false
                root.closeCollapseProgress = 0.0
                root.closeReturnProgress = 0.0
                root.closeFlareProgress = 0.0
                if (typeof dashboardMorphAnim !== "undefined" && dashboardMorphAnim) {
                    dashboardMorphAnim.stop()
                }
                root.dashboardMorphProgress = 0.0
                root.seedLogoGeometry()
            })
        }
    }

    PanelWindow {
        id: navigationVisualLayer
        screen: root.modelData
        anchors { top: true; left: true; right: true; bottom: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-navigation-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        // Keep Top mapped so opening the panel does not raise it over fullscreen.
        visible: true
        mask: Region {}

        Flare.FlareSurface {
            id: navigationFlare
            attach: ScreenGeometry.bottomAttached ? Flare.FlareHost.Bottom : Flare.FlareHost.Top
            x: 0
            // Align the top-right attachment to RoundedScreen content.
            y: root.attachmentY
            width: navigationVisualLayer.width
            height: root.flareTargetHeight + root.flareReach
            start: root.flareStart
            end: root.flareEnd
            currentHeight: root.flareHeight
            bounds: root.horizontalBounds
            // Match the shared RoundedScreen corner language.
            r: Math.max(Theme.largeRadius + 8, ScreenGeometry.roundedRadius + 8)
            rf: root.flareReach
            bottomRadius: root.closing
                          ? root.backingCurveRadius * (1.0 - root.closeFlareProgress)
                          : root.backingCurveRadius
            surfaceColor: Theme.surface
            opacity: root.closingFromDashboard ? 0.0 : (root.closing
                     ? Math.max(0.0, 1.0 - Math.max(0.0, root.closeFlareProgress - 0.72) / 0.28)
                     : Math.max(0.0, 1.0 - root.dashboardMorphProgress / 0.35))
            visible: (root.panelOpen || root.closing) && opacity > 0.001
        }
        Sidebar.SidebarFlareSurface {
            x: root.sidebarBodyX
            y: root.mapY(root.sidebarBodyY, 0)
            transform: Scale { yScale: ScreenGeometry.bottomAttached ? -1 : 1 }
            visible: sidebarSurface.visible && (root.panelOpen || root.closing)
            bodyWidth: sidebarSurface.bodyWidth
            currentHeight: sidebarSurface.currentHeight
            morphProgress: sidebarSurface.morphProgress
            rf: sidebarSurface.rf
            sideInset: sidebarSurface.sideInset
            topFlareY: sidebarSurface.topFlareY
            earWidth: sidebarSurface.earWidth
            earRadius: sidebarSurface.earRadius
            cornerRadius: sidebarSurface.cornerRadius
            surfaceColor: sidebarSurface.surfaceColor
        }
    }

    PanelWindow {
        id: navigationLayer
        screen: root.modelData
        anchors { top: true; left: true; right: true; bottom: true }
        WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
        WlrLayershell.namespace: "hakuspace-navigation"
        WlrLayershell.keyboardFocus: !root.panelOpen ? WlrKeyboardFocus.None
            : root.sidebarKeyboardMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: root.panelOpen || root.closing
        mask: Region {
            Region {
                x: root.safeZone(0).x; y: root.safeZone(0).y
                width: root.panelOpen || root.closing ? root.safeZone(0).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(0).height : 0
            }
            Region {
                x: root.safeZone(1).x; y: root.safeZone(1).y
                width: root.panelOpen || root.closing ? root.safeZone(1).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(1).height : 0
            }
            Region {
                x: root.safeZone(2).x; y: root.safeZone(2).y
                width: root.panelOpen || root.closing ? root.safeZone(2).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(2).height : 0
            }
            Region {
                x: root.safeZone(3).x; y: root.safeZone(3).y
                width: root.panelOpen || root.closing ? root.safeZone(3).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(3).height : 0
            }
            Region {
                x: root.safeZone(4).x; y: root.safeZone(4).y
                width: root.panelOpen || root.closing ? root.safeZone(4).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(4).height : 0
            }
            Region {
                x: root.safeZone(5).x; y: root.safeZone(5).y
                width: root.panelOpen || root.closing ? root.safeZone(5).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(5).height : 0
            }
            Region {
                x: root.safeZone(6).x; y: root.safeZone(6).y
                width: root.panelOpen || root.closing ? root.safeZone(6).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(6).height : 0
            }
            Region {
                x: root.safeZone(7).x; y: root.safeZone(7).y
                width: root.panelOpen || root.closing ? root.safeZone(7).width : 0
                height: root.panelOpen || root.closing ? root.safeZone(7).height : 0
            }
        }

        HoverHandler {
            id: safeZoneHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (!hovered) lifetime.pointerExited()
                else {
                    lifetime.pointerEntered(point.position.x, point.position.y)
                    if (root.panelOpen) keyHandler.forceActiveFocus()
                }
            }
            onPointChanged: {
                if (!root.panelOpen || root.closing) return
                root.evaluatePointer(point.position.x, point.position.y)
            }
        }

        Base.SafeZoneDebugOverlay {
            anchors.fill: parent
            screenWidth: root.modelData.width
            screenHeight: root.modelData.height
            anchorRect: root.capturedAnchorRect
            localizedAnchorRect: root.capturedAnchorRect
            flareStart: root.flareStart
            flareEnd: root.flareEnd
            z: 999
            closePending: lifetime.closePending
            zones: root.safeZones.map(function(zone, index) {
                return { rect: zone, kind: index === 1 ? "anchor"
                    : index === 2 || index === 5 ? "corridor"
                    : index === 6 && sidebarToolLayer.activeProgress > 0.001
                        && sidebarToolLayer.activeProgress < 0.999 ? "animation" : "surface" }
            })
        }

        // Invisible interaction bridge connecting Sidebar sector to Sidebar body.
        MouseArea {
            id: bridgeHit
            x: root.bridgeX
            y: root.mapY(root.bridgeY, root.bridgeHeight)
            width: root.bridgeWidth
            height: root.bridgeHeight
            enabled: root.panelOpen && root.sidebarExpanded && !root.dashboardVisuallyActive
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            z: 24
            onEntered: {
                root.hoveredIndex = 1
                root.selectedIndex = 1
            }
            onPositionChanged: mouse => {
                root.hoveredIndex = 1
                root.selectedIndex = 1
                root.evaluatePointer(x + mouse.x, y + mouse.y)
            }
        }

        // Sidebar visual surface: attached flush to left edge with flare curve,
        // morph opening/closing animation, and circular option controls.
        Sidebar.SidebarSurface {
            id: sidebarSurface
            bottomAttached: ScreenGeometry.bottomAttached
            x: root.sidebarBodyX
            y: root.mapY(root.sidebarBodyY, root.sidebarBodyHeight)
            width: root.sidebarBodyWidth + root.sidebarEarWidth + 4
            height: root.sidebarBodyHeight + root.flareReach
            bodyWidth: root.sidebarBodyWidth
            bodyHeight: root.sidebarBodyHeight
            controlDiameter: root.sidebarControlDiameter
            tooltipHost: sidebarTooltipLayer
            expanded: root.panelOpen && root.sidebarExpanded && !root.closing && !root.dashboardVisuallyActive
            activeToolKey: root.activeSidebarTool
            selectedToolIndex: root.sidebarSelectedIndex
            keyboardSelected: root.sidebarKeyboardMode
            rf: root.flareReach
            sideInset: root.sideInset
            topFlareY: root.sidebarTopFlareY
            earWidth: root.sidebarEarWidth
            earRadius: root.sidebarEarRadius
            cornerRadius: Theme.largeRadius + 8
            surfaceColor: Theme.surface
            z: 5
            onToolRequested: key => {
                root.keyboardLease = false
                root.toggleSidebarTool(key, false)
            }
            onPointerMoved: (px, py) => {
                root.hoveredIndex = 1
                root.selectedIndex = 1
                root.evaluatePointer(sidebarSurface.x + px, sidebarSurface.y + py)
            }
        }

        // One attached shell hosts the active utility.
        Sidebar.SidebarToolLayer {
            id: sidebarToolLayer
            x: root.sidebarToolX
            y: root.mapY(root.sidebarToolY, sidebarToolLayer.height)
            targetWidth: root.sidebarToolWidth
            targetHeight: root.sidebarToolHeight
            title: root.renderedSidebarTool === "quickActions" ? "Quick Actions"
                : root.renderedSidebarTool === "clipboard" ? "Clipboard" : ""
            showHeader: root.renderedSidebarTool === "clipboard"
            icon: root.renderedSidebarTool === "quickActions" ? "󰀻"
                : root.renderedSidebarTool === "clipboard" ? "󰅌" : ""
            toolContent: root.renderedSidebarTool === "quickActions" ? quickActionsContent
                : root.renderedSidebarTool === "clipboard" ? clipboardContent : null
            focusContent: !root.sidebarKeyboardMode
            open: root.panelOpen && root.sidebarExpanded && root.sidebarToolOpen && !root.closing && !root.dashboardVisuallyActive
            z: 28
            onCloseRequested: {
                root.keyboardLease = false
                root.closeSidebarTool()
            }
            onClosed: {
                if (!root.sidebarToolOpen) root.renderedSidebarTool = ""
                if (root.panelOpen && root.sidebarExpanded && !root.sidebarToolOpen)
                    root.focusSidebarRail(root.sidebarKeyboardMode)
            }
            onPointerMoved: (px, py) => {
                root.hoveredIndex = 1
                root.selectedIndex = 1
                root.evaluatePointer(sidebarToolLayer.x + px, sidebarToolLayer.y + py)
            }
        }

        Item {
            id: sidebarTooltipLayer
            anchors.fill: parent
            z: 100
        }

        Component {
            id: quickActionsContent
            Sidebar.SidebarQuickActions {
                keyboardCursor: root.keyboardLease
                onRailFocusRequested: root.focusSidebarRail(true)
                onCloseRequested: keyboard => {
                    if (keyboard) UiState.closeNavigation()
                    else root.closeSidebarTool()
                }
                onActionRequested: key => root.runQuickAction(key)
            }
        }
        Component {
            id: clipboardContent
            Sidebar.SidebarClipboard {
                onRailFocusRequested: root.focusSidebarRail(true)
                onOpenFullRequested: {
                    UiState.closeNavigation()
                    UiState.openActionMenu(root.modelData.name, "clipboard")
                }
                onCloseRequested: keyboard => {
                    if (keyboard) UiState.closeNavigation()
                    else root.closeSidebarTool()
                }
            }
        }
        // Dashboard visual surface: fluid silhouette with avatar, profile rail,
        // and card layout inside the navigation overlay.
        Dashboard.DashboardSurface {
            id: dashboardSurface
            screenWidth: navigationLayer.width
            screenHeight: navigationLayer.height
            targetWidth: root.dashboardVisualWidth
            targetHeight: root.dashboardVisualHeight
            controllerX: root.controllerX
            controllerY: root.controllerY
            circleRadius: root.circleRadius
            circleDiameter: root.circleDiameter
            sideInset: root.sideInset
            attachmentY: root.logicalAttachmentY
            bottomAttached: ScreenGeometry.bottomAttached
            attachmentSeam: root.attachmentY
            expanded: root.panelOpen && root.dashboardExpanded && !root.closing
            morphProgress: root.dashboardMorphProgress
            // A full Dashboard -> closed transition reuses the Dashboard ->
            // Navigation morph path, whose zero-progress geometry is the
            // Navigation start envelope rather than 0x0. Fade only the tail
            // of the full-close path so that envelope never appears as a
            // detached black afterimage. Dashboard -> Navigation is unchanged.
            opacity: root.closingFromDashboard
                     ? Math.max(0.0, Math.min(1.0, root.dashboardMorphProgress / 0.20))
                     : 1.0
            z: 25
            onRequestReturnToNavigation: {
                UiState.cancelNavigationHandoff()
            }
            onFocusRequested: {
                if (root.panelOpen) {
                    keyHandler.forceActiveFocus()
                }
            }
        }

        // One background follows the Logo morph into the circular controller.
        Rectangle {
            id: circularShell
            x: root.anchorStart + (root.shellX - root.anchorStart) * root.logoMorphProgress
            y: root.anchorY + (root.mapY(root.shellY, root.circularShellDiameter) - root.anchorY) * root.logoMorphProgress
            width: root.logoBaseWidth
                   + (root.circularShellDiameter - root.logoBaseWidth) * root.logoMorphProgress
            height: root.logoBaseHeight
                    + (root.circularShellDiameter - root.logoBaseHeight) * root.logoMorphProgress
            radius: Math.min(width, height) / 2
            color: root.blendColor(Theme.accent, Theme.surface, root.logoMorphProgress)
            opacity: root.closingFromDashboard ? 0.0
                     : Math.max(0.0, 1.0 - root.dashboardMorphProgress / 0.35)
            visible: (root.panelOpen || root.closing) && opacity > 0.001
            z: 10
        }

        // Visual surrogate for the TopBar Logo while the radial surface owns it.
        Rectangle {
            id: logoMorphProxy
            x: root.logoProxyX
            y: root.logoProxyY
            width: root.logoProxyWidth
            height: root.logoProxyHeight
            radius: Math.min(width, height) / 2
            color: root.blendColor(Theme.accent, Theme.surface, root.logoMorphProgress)
            border.width: root.logoMorphProgress > 0.05 ? 2 : 0
            readonly property color baseBorderColor: Qt.lighter(Theme.hoverMuted, 1.55)
            border.color: Qt.rgba(baseBorderColor.r, baseBorderColor.g, baseBorderColor.b,
                                  baseBorderColor.a * Math.max(0.0, Math.min(1.0, (root.logoMorphProgress - 0.1) / 0.9)))
            z: 120
            opacity: root.closingFromDashboard ? 0.0 : Math.max(0.0, 1.0 - root.dashboardMorphProgress / 0.30)
            visible: (root.panelOpen || root.closing) && opacity > 0.001

            Text {
                anchors.centerIn: parent
                text: "󰮯"
                color: root.blendColor(Theme.onAccentColor, Theme.accent, root.logoMorphProgress)
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Math.max(Theme.fontSize,
                                         Theme.fontSize + root.logoMorphProgress * Theme.fontSize * 0.20)
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.panelOpen && root.navigationRevealProgress > 0.82 && root.dashboardMorphProgress <= 0.01
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.sidebarExpanded) UiState.cancelNavigationHandoff()
                    UiState.closeNavigation()
                }
            }
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: root.panelOpen

            Keys.onLeftPressed: event => {
                if (root.dashboardVisuallyActive || (root.sidebarToolOpen && !root.sidebarKeyboardMode)) return
                root.keyboardLease = true
                if (root.sidebarKeyboardMode) {
                    if (!root.sidebarToolOpen) root.moveSidebarSelection(-1)
                }
                else root.moveSelection(-1)
                event.accepted = true
            }
            Keys.onUpPressed: event => {
                if (root.dashboardVisuallyActive || (root.sidebarToolOpen && !root.sidebarKeyboardMode)) return
                root.keyboardLease = true
                if (root.sidebarKeyboardMode) root.moveSidebarSelection(-1)
                else root.moveSelection(-1)
                event.accepted = true
            }
            Keys.onRightPressed: event => {
                if (root.dashboardVisuallyActive || (root.sidebarToolOpen && !root.sidebarKeyboardMode)) return
                root.keyboardLease = true
                if (root.sidebarKeyboardMode && sidebarSurface.tools[root.sidebarSelectedIndex].key === "tempNote"
                        && UiState.tempNoteOpen && UiState.tempNoteScreenName === root.modelData.name) {
                    root.sidebarKeyboardMode = false
                    UiState.tempNoteFocusRequested(root.modelData.name)
                    root.keyboardLease = false
                } else if (root.sidebarKeyboardMode && root.sidebarToolOpen) {
                    root.sidebarKeyboardMode = false
                    root.focusActiveSidebarTool()
                } else if (root.sidebarKeyboardMode) root.moveSidebarSelection(1)
                else root.moveSelection(1)
                event.accepted = true
            }
            Keys.onDownPressed: event => {
                if (root.dashboardVisuallyActive || (root.sidebarToolOpen && !root.sidebarKeyboardMode)) return
                root.keyboardLease = true
                if (root.sidebarKeyboardMode) root.moveSidebarSelection(1)
                else root.moveSelection(1)
                event.accepted = true
            }
            Keys.onPressed: event => {
                if (!root.sidebarKeyboardMode) return
                if (event.key === Qt.Key_Home) root.sidebarSelectedIndex = 0
                else if (event.key === Qt.Key_End) root.sidebarSelectedIndex = sidebarSurface.tools.length - 1
                else return
                root.keyboardLease = true
                event.accepted = true
            }
            Keys.onReturnPressed: event => {
                if (root.dashboardVisuallyActive || (root.sidebarToolOpen && !root.sidebarKeyboardMode)) return
                root.keyboardLease = true
                if (root.sidebarKeyboardMode) root.activateSidebarSelection()
                else root.activateSelected()
                event.accepted = true
            }
            Keys.onEnterPressed: event => {
                if (root.dashboardVisuallyActive || (root.sidebarToolOpen && !root.sidebarKeyboardMode)) return
                root.keyboardLease = true
                if (root.sidebarKeyboardMode) root.activateSidebarSelection()
                else root.activateSelected()
                event.accepted = true
            }
            Keys.onSpacePressed: event => {
                if (root.sidebarKeyboardMode) {
                    root.activateSidebarSelection()
                    event.accepted = true
                }
            }
            Keys.onEscapePressed: event => {
                UiState.closeNavigation()
                event.accepted = true
            }
        }
        Item {
            id: controller
            x: root.controllerX
            y: root.mapY(root.controllerY, root.circleDiameter)
            width: root.circleDiameter
            height: root.circleDiameter
            readonly property real radialFadeProgress: Math.max(0.0, 1.0 - root.dashboardMorphProgress / 0.30)
            opacity: root.closingFromDashboard ? 0.0 : (root.navigationRevealProgress * radialFadeProgress)
            scale: (0.72 + root.navigationRevealProgress * 0.28) * (0.90 + 0.10 * radialFadeProgress)
            transformOrigin: Item.Center
            visible: opacity > 0.001
            z: 30

                // Static dark ring beneath the three independently animated slices.
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.surface
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 4
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.lighter(Theme.hoverMuted, 1.75)
                }

                Repeater {
                    id: sectorRepeater
                    model: root.regions

                    delegate: Item {
                        id: sector
                        required property int index
                        required property var modelData
                        readonly property bool hovered: root.hoveredIndex === index
                        readonly property bool selected: root.selectedIndex === index
                        readonly property var sectorBox: root.sectorBounds(modelData.startDeg, modelData.endDeg)
                        readonly property color fillColor: root.idleColor

                        x: sectorBox.x
                        y: sectorBox.y
                        width: sectorBox.width
                        height: sectorBox.height
                        scale: root.closing
                               ? Math.max(0.18, root.navigationRevealProgress)
                               : 1.0
                        transformOrigin: Item.Center
                        z: 10

                        Behavior on scale {
                            NumberAnimation {
                                duration: HAnimation.buttonHoverDuration
                                easing.bezierCurve: HAnimation.buttonHoverCurve
                            }
                        }

                        Canvas {
                            id: sectorCanvas
                            anchors.fill: parent
                            property color currentFill: sector.fillColor
                            property color separatorColor: Theme.surface

                            onCurrentFillChanged: requestPaint()
                            onSeparatorColorChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            function rad(deg) { return deg * Math.PI / 180 }

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cx = root.circleRadius - sector.sectorBox.x
                                var cy = root.circleRadius - sector.sectorBox.y
                                var outerR = root.outerSectorRadius
                                var innerR = root.innerSectorRadius
                                var start = rad(sector.modelData.startDeg)
                                var end = rad(sector.modelData.endDeg)

                                ctx.beginPath()
                                ctx.arc(cx, cy, outerR, start, end, false)
                                ctx.arc(cx, cy, innerR, end, start, true)
                                ctx.closePath()
                                ctx.fillStyle = currentFill
                                ctx.fill()

                                // Dark separators keep the three sectors visually
                                // segmented while rounded joins soften the wedge ends.
                                ctx.strokeStyle = separatorColor
                                ctx.lineWidth = 4
                                ctx.lineJoin = "round"
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }
                    }
                }

                Canvas {
                    id: activeWedgeCanvas
                    anchors.fill: parent
                    z: 35
                    visible: root.panelOpen && opacity > 0.001

                    property real morphAngle: root.morphAngle
                    property color activeColor: root.hoveredIndex >= 0 ? Qt.lighter(Theme.accent, 1.15) : Theme.accent
                    property color separatorColor: Theme.surface

                    onMorphAngleChanged: requestPaint()
                    onActiveColorChanged: requestPaint()
                    onSeparatorColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    scale: root.closing
                           ? Math.max(0.18, root.navigationRevealProgress)
                           : (root.hoveredIndex >= 0 ? 1.03 : 1.0)
                    transformOrigin: Item.Center

                    Behavior on scale {
                        NumberAnimation {
                            duration: HAnimation.buttonHoverDuration
                            easing.bezierCurve: HAnimation.buttonHoverCurve
                        }
                    }
                    Behavior on activeColor {
                        ColorAnimation {
                            duration: HAnimation.buttonHoverDuration
                        }
                    }

                    function rad(deg) { return deg * Math.PI / 180 }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (!root.panelOpen && !root.closing) return

                        var cx = width / 2
                        var cy = height / 2
                        var outerR = root.outerSectorRadius
                        var innerR = root.innerSectorRadius
                        var start = rad(morphAngle - 60.0)
                        var end = rad(morphAngle + 60.0)

                        ctx.beginPath()
                        ctx.arc(cx, cy, outerR, start, end, false)
                        ctx.arc(cx, cy, innerR, end, start, true)
                        ctx.closePath()
                        ctx.fillStyle = activeColor
                        ctx.fill()

                        ctx.strokeStyle = separatorColor
                        ctx.lineWidth = 4
                        ctx.lineJoin = "round"
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }

                Repeater {
                    model: root.regions

                    delegate: Text {
                        required property int index
                        required property var modelData
                        readonly property bool hovered: root.hoveredIndex === index
                        readonly property bool active: root.activeTargetIndex === index
                        readonly property real baseSize: Math.max(19, Theme.fontSize * 1.35)
                        readonly property real hoverShift: hovered ? root.circleRadius * 0.035 : 0
                        readonly property real angleRad: modelData.labelAngle * Math.PI / 180
                        readonly property real iconOffsetX: Number.isFinite(modelData.offsetX) ? modelData.offsetX : 0
                        readonly property real iconOffsetY: Number.isFinite(modelData.offsetY) ? modelData.offsetY : 0

                        width: Math.max(40, Theme.fontSize * 3.0)
                        height: width
                        x: root.iconCenterX(index) + Math.cos(angleRad) * hoverShift - width / 2 + iconOffsetX
                        y: root.iconCenterY(index) + Math.sin(angleRad) * hoverShift - height / 2 + iconOffsetY
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.icon
                        color: active ? Theme.onAccentColor : Theme.fg
                        scale: active ? 1.08 : 1.0
                        font.family: Theme.fontFamily
                        font.pixelSize: baseSize * (hovered ? root.hoverTextScale : 1.0)
                        font.weight: active ? Font.DemiBold : Font.Medium
                        z: 60

                        Behavior on x { NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.bezierCurve: HAnimation.buttonHoverCurve } }
                        Behavior on y { NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.bezierCurve: HAnimation.buttonHoverCurve } }
                        Behavior on color { ColorAnimation { duration: HAnimation.buttonSelectDuration } }
                        Behavior on scale { NumberAnimation { duration: HAnimation.buttonSelectDuration; easing.bezierCurve: HAnimation.buttonSelectCurve } }
                        Behavior on font.pixelSize {
                            NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.bezierCurve: HAnimation.buttonHoverCurve }
                        }
                    }
                }

                MouseArea {
                    id: radialHit
                    // Include sector overflow so expanded hover stays stable.
                    x: -root.shellPadding
                    y: -root.shellPadding
                    width: parent.width + root.shellPadding * 2
                    height: parent.height + root.shellPadding * 2
                    hoverEnabled: true
                    enabled: root.panelOpen && root.navigationRevealProgress > 0.82 && root.dashboardMorphProgress <= 0.01
                    acceptedButtons: Qt.LeftButton
                    cursorShape: root.hoveredIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    z: 80

                    function localCircleX(px) { return px + radialHit.x }
                    function localCircleY(py) { return py + radialHit.y }

                    function updateHover(px, py) {
                        var index = root.indexAt(localCircleX(px), localCircleY(py), true)
                        root.hoveredIndex = index
                        if (index >= 0) {
                            root.selectedIndex = index
                            if (root.regions[index].key === "sidebar") {
                                UiState.beginNavigationHandoff("sidebar")
                            } else if (UiState.navigationMode === "handoff-sidebar") {
                                UiState.cancelNavigationHandoff()
                            }
                        }
                    }

                    onEntered: updateHover(mouseX, mouseY)
                    onPositionChanged: mouse => updateHover(mouse.x, mouse.y)
                    onExited: {
                        if (UiState.navigationMode !== "handoff-sidebar") {
                            root.hoveredIndex = -1
                        }
                    }
                    onClicked: mouse => {
                        var index = root.indexAt(localCircleX(mouse.x), localCircleY(mouse.y), true)
                        if (index >= 0) {
                            root.keyboardLease = false
                            root.activateIndex(index, false)
                        }
                    }
                }
            }
    }
}
