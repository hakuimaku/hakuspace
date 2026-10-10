import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare

Item {
    id: root
    required property var modelData

    readonly property bool panelOpen: UiState.activePanel === "navigation"
                                      && UiState.navigationMode !== "closed"
                                      && UiState.navigationScreenName === modelData.name
    property bool closing: false
    property int selectedIndex: 0
    property int hoveredIndex: -1
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
    readonly property real backingCurveRadius: circleRadius + shellPadding + Math.max(Theme.radiusSm, 12)

    // Navigation lives in one Overlay so exclusive zones cannot move it, while
    // the backing contour aligns to the shared RoundedScreen frame geometry.
    readonly property real frameThickness: FlareEdges.thickness
    readonly property real frameTop: FlareEdges.topOriginY
    readonly property var frameBounds: FlareEdges.getBounds(modelData.width)
    // Keep the steady-state backing tight around the radial controller.
    readonly property real shellPadding: 4
    readonly property real flareExtraRight: 8
    readonly property real flareExtraBottom: 8
    readonly property real circleDiameter: Math.max(146, Theme.fontSize * 10.5)
    readonly property real circleRadius: circleDiameter / 2
    readonly property real circularShellDiameter: circleDiameter + shellPadding * 2
    readonly property real shellX: 0
    readonly property real shellY: 0
    readonly property real surfaceStart: frameThickness
    readonly property real surfaceWidth: circularShellDiameter + flareExtraRight
    readonly property real surfaceHeight: circularShellDiameter + flareExtraBottom
    readonly property real surfaceEnd: Math.min(modelData.width - frameThickness,
                                                surfaceStart + surfaceWidth)
    readonly property real flareTargetHeight: Math.max(1, surfaceHeight - frameTop)
    readonly property real flareReach: Math.max(Theme.tipHugRadius, AppState.roundedScreenRadius)
    readonly property real hoverOverflow: Math.ceil(circleDiameter * 0.12)
    readonly property real controllerX: shellX + shellPadding
    readonly property real controllerY: shellY + shellPadding
    readonly property real safeRadius: circularShellDiameter + 100

    function insideSafeZone(x, y) {
        return x >= 0 && y >= 0 && (x * x + y * y <= safeRadius * safeRadius)
    }

    // Logo geometry is captured when Navigation opens. Keeping this copy local
    // lets the Flare close back toward the Logo after UiState has already reset.
    property real capturedAnchorX: frameThickness
    property real capturedAnchorY: Theme.topBarTopPadding
    property real capturedAnchorWidth: Theme.topBarHeight
    property real capturedAnchorHeight: Theme.topBarHeight

    readonly property real anchorStart: Math.max(0,
                                                   Math.min(modelData.width - 1, capturedAnchorX))
    readonly property real anchorY: Math.max(0,
                                              Math.min(modelData.height - 1, capturedAnchorY))
    readonly property real anchorEnd: Math.max(anchorStart + 1,
                                               Math.min(modelData.width,
                                                        anchorStart + capturedAnchorWidth))
    // The Logo is clicked while hovered, so capturedAnchorWidth can be wider
    // than the normal circular button. Opening keeps that exact footprint, but
    // closing must return to the stable circle size (the Logo height), never
    // to the hover-expanded pill width.
    readonly property real returnAnchorSize: Math.max(1, capturedAnchorHeight)
    readonly property real anchorBodyHeight: Math.max(1, Math.min(surfaceHeight, capturedAnchorHeight))

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
    readonly property real logoProxyY: anchorY + (logoTargetY - anchorY) * logoMorphProgress
    readonly property real logoBaseWidth: closing ? returnAnchorSize : capturedAnchorWidth
    readonly property real logoBaseHeight: closing ? returnAnchorSize : capturedAnchorHeight
    readonly property real logoProxyWidth: logoBaseWidth
                                            + (logoTargetSize - logoBaseWidth) * logoMorphProgress
    readonly property real logoProxyHeight: logoBaseHeight
                                             + (logoTargetSize - logoBaseHeight) * logoMorphProgress
    // Sector angles use canvas coordinates: 0° right, 90° down.
    // Dashboard: top; Sidebar: lower-left; Settings: lower-right.
    readonly property var regions: [
        { key: "dashboard", icon: "", startDeg: 215, endDeg: 320,
          labelAngle: 270, labelRadius: 0.46, offsetX: -2, offsetY: 0 },
        { key: "sidebar", icon: "", startDeg: 90, endDeg: 215,
          labelAngle: 150, labelRadius: 0.50, offsetX: 0, offsetY: 0 },
        { key: "settings", icon: "", startDeg: 320, endDeg: 450,
          labelAngle: 30, labelRadius: 0.50, offsetX: 0, offsetY: 0 }
    ]

    function normalizeAngle(deg) {
        var a = deg % 360
        return a < 0 ? a + 360 : a
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
        if (angle >= 215 && angle < 320) return 0
        if (angle >= 90 && angle < 215) return 1
        return 2
    }

    function selectIndex(index, updateHandoff) {
        if (index < 0 || index >= regions.length) return
        selectedIndex = index
        if (updateHandoff) UiState.beginNavigationHandoff(regions[index].key)
    }

    function moveSelection(delta) {
        var count = regions.length
        selectIndex((selectedIndex + delta + count) % count, true)
    }

    function activateIndex(index) {
        selectIndex(index, true)
    }

    function activateSelected() {
        activateIndex(selectedIndex)
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
        capturedAnchorX = Number.isFinite(UiState.navigationAnchorX)
                          ? UiState.navigationAnchorX : surfaceStart
        capturedAnchorY = Number.isFinite(UiState.navigationAnchorY)
                          ? UiState.navigationAnchorY : Theme.topBarTopPadding
        capturedAnchorWidth = Math.max(1, Number.isFinite(UiState.navigationAnchorWidth)
                                          ? UiState.navigationAnchorWidth : Theme.topBarHeight)
        capturedAnchorHeight = Math.max(1, Number.isFinite(UiState.navigationAnchorHeight)
                                           ? UiState.navigationAnchorHeight : capturedAnchorWidth)
    }

    function seedLogoGeometry() {
        flareStart = anchorStart
        flareEnd = anchorEnd
        flareHeight = Math.min(anchorBodyHeight, flareTargetHeight)
    }

    Component.onDestruction: {
        UiState.closeNavigationIfScreen(modelData.name)
        UiState.finishNavigationVisual(modelData.name)
    }

    onPanelOpenChanged: {
        openMorph.stop()
        closeMorph.stop()

        if (panelOpen) {
            closing = false
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            captureAnchor()
            selectedIndex = UiState.navigationMode === "handoff-sidebar" ? 1
                            : UiState.navigationMode === "handoff-settings" ? 2 : 0
            hoveredIndex = -1

            if (flareHeight <= anchorBodyHeight + 0.5)
                seedLogoGeometry()
            openMorph.start()
            Qt.callLater(function() {
                if (root.panelOpen) keyHandler.forceActiveFocus()
            })
            return
        }

        // Ownership moving to another monitor does not animate the stale output.
        if (UiState.activePanel === "navigation") {
            closing = false
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            seedLogoGeometry()
            return
        }

        if (flareHeight > anchorBodyHeight + 0.5) {
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            hoveredIndex = -1
            closing = true
            closeMorph.start()
        } else {
            closing = false
            closeCollapseProgress = 0.0
            closeReturnProgress = 0.0
            closeFlareProgress = 0.0
            seedLogoGeometry()
            UiState.finishNavigationVisual(modelData.name)
        }
    }

    ParallelAnimation {
        id: openMorph
        NumberAnimation {
            target: root; property: "flareStart"; to: root.surfaceStart
            duration: HAnimation.spatial; easing.bezierCurve: HAnimation.spatialCurve
        }
        NumberAnimation {
            target: root; property: "flareEnd"; to: root.surfaceEnd
            duration: HAnimation.spatial; easing.bezierCurve: HAnimation.spatialCurve
        }
        NumberAnimation {
            target: root; property: "flareHeight"; to: root.flareTargetHeight
            duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve
        }
    }

    SequentialAnimation {
        id: closeMorph

        // Fold the pizza slices/ring into the hub first. Keeping flare geometry
        // fixed here removes the abrupt "menu disappears, then blob travels"
        // seen in the runtime recording.
        NumberAnimation {
            target: root
            property: "closeCollapseProgress"
            from: 0.0
            to: 1.0
            duration: Math.max(HAnimation.fast, 150)
            easing.type: Easing.InOutCubic
        }

        // Once only the Logo hub remains, return it to the TopBar while the
        // flare retracts into the RoundedScreen seam. Do not collapse the flare
        // horizontally toward the Logo: its visual origin lives at frameTop,
        // so doing that creates the detached black blob seen in runtime.
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "closeReturnProgress"
                from: 0.0
                to: 1.0
                duration: HAnimation.normal
                easing.bezierCurve: HAnimation.shellCurve
            }
            NumberAnimation {
                target: root
                property: "closeFlareProgress"
                from: 0.0
                to: 1.0
                duration: HAnimation.normal
                easing.bezierCurve: HAnimation.shellCurve
            }
            NumberAnimation {
                target: root
                property: "flareHeight"
                to: 0.0
                duration: HAnimation.normal
                easing.type: Easing.InOutCubic
            }
        }

        onFinished: {
            root.closing = false
            root.closeCollapseProgress = 0.0
            root.closeReturnProgress = 0.0
            root.closeFlareProgress = 0.0
            UiState.finishNavigationVisual(root.modelData.name)
        }
    }

    // One Overlay surface owns both the backing and radial content. The compact
    // input mask keeps the rest of the desktop directly interactive.
    PanelWindow {
        id: navigationLayer
        screen: root.modelData
        anchors { top: true; left: true; right: true; bottom: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hakuspace-navigation"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        visible: root.panelOpen || root.closing

        mask: Region {
            Region {
                x: 0
                y: 0
                width: Math.min(navigationLayer.width, root.safeRadius)
                height: Math.min(navigationLayer.height, root.safeRadius)
                bottomRightRadius: Math.min(width, height)
            }
        }

        // Pointer-lifetime safe zone: pointer leaves the top-left quarter circle
        // -> closes Navigation via existing animated close path.
        HoverHandler {
            id: safeZoneHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (!hovered && root.panelOpen && !root.closing) {
                    UiState.closeNavigation()
                }
            }
            onPointChanged: {
                if (!root.panelOpen || root.closing) return
                if (!root.insideSafeZone(point.position.x, point.position.y)) {
                    UiState.closeNavigation()
                }
            }
        }

        // Persistent backing participates in the Logo morph and remains visible
        // at rest around the circular controller.
        Flare.FlareSurface {
            id: navigationFlare
            x: 0
            // Align the top-right attachment to RoundedScreen content.
            y: root.frameTop
            width: navigationLayer.width
            height: root.flareTargetHeight + root.flareReach
            start: root.flareStart
            end: root.flareEnd
            currentHeight: root.flareHeight
            bounds: root.frameBounds
            // Match the shared RoundedScreen corner language.
            r: Math.max(Theme.tipRadius, AppState.roundedScreenRadius + 8)
            rf: root.flareReach
            bottomRadius: root.closing
                          ? root.backingCurveRadius * (1.0 - root.closeFlareProgress)
                          : root.backingCurveRadius
            surfaceColor: Theme.barColor
            opacity: root.closing
                     ? Math.max(0.0, 1.0 - Math.max(0.0, root.closeFlareProgress - 0.72) / 0.28)
                     : 1.0
            visible: root.panelOpen || root.closing
        }

        // Circular bulb is flush with the physical top-left corner. The
        // RoundedScreen border underneath provides the outer 4 px frame, while
        // navigationFlare joins from frameTop on the right/bottom.
        Rectangle {
            id: circularShell
            x: root.shellX
            y: root.shellY
            width: root.circularShellDiameter
            height: root.circularShellDiameter
            radius: width / 2
            color: Theme.barColor
            opacity: root.navigationRevealProgress
            scale: 0.92 + root.navigationRevealProgress * 0.08
            transformOrigin: Item.Center
        }

        // Visual surrogate for the TopBar Logo while the radial surface owns it.
        Rectangle {
            id: logoMorphProxy
            x: root.logoProxyX
            y: root.logoProxyY
            width: root.logoProxyWidth
            height: root.logoProxyHeight
            radius: Math.min(width, height) / 2
            color: root.logoMorphProgress < 0.52 ? Theme.accent : Theme.surface
            border.width: root.logoMorphProgress > 0.45 ? 2 : 0
            border.color: Qt.lighter(Theme.hoverMuted, 1.55)
            z: 120
            visible: root.panelOpen || root.closing

            Behavior on color { ColorAnimation { duration: HAnimation.fast } }
            Behavior on border.width { NumberAnimation { duration: HAnimation.fast } }

            Text {
                anchors.centerIn: parent
                text: "󰮯"
                color: root.logoMorphProgress < 0.52 ? Theme.onAccentColor : Theme.accent
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Math.max(Theme.fontSize,
                                         Theme.fontSize + root.logoMorphProgress * Theme.fontSize * 0.20)
                Behavior on color { ColorAnimation { duration: HAnimation.fast } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.panelOpen && root.navigationRevealProgress > 0.82
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: root.panelOpen

            Keys.onLeftPressed: event => { root.moveSelection(-1); event.accepted = true }
            Keys.onUpPressed: event => { root.moveSelection(-1); event.accepted = true }
            Keys.onRightPressed: event => { root.moveSelection(1); event.accepted = true }
            Keys.onDownPressed: event => { root.moveSelection(1); event.accepted = true }
            Keys.onReturnPressed: event => { root.activateSelected(); event.accepted = true }
            Keys.onEnterPressed: event => { root.activateSelected(); event.accepted = true }
            Keys.onEscapePressed: event => { UiState.closeNavigation(); event.accepted = true }
        }
        Item {
            id: controller
            x: root.controllerX
            y: root.controllerY
            width: root.circleDiameter
            height: root.circleDiameter
            opacity: root.navigationRevealProgress
            scale: 0.72 + root.navigationRevealProgress * 0.28
            transformOrigin: Item.Center

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
                        readonly property color fillColor: selected
                            ? root.selectedColor
                            : (hovered ? root.hoverColor : root.idleColor)

                        x: sectorBox.x
                        y: sectorBox.y
                        width: sectorBox.width
                        height: sectorBox.height
                        scale: root.closing
                               ? Math.max(0.18, root.navigationRevealProgress)
                               : (hovered ? root.hoverSliceScale : 1.0)
                        transformOrigin: Item.Center
                        z: hovered ? 30 : (selected ? 20 : 10)

                        Behavior on scale {
                            NumberAnimation {
                                duration: HAnimation.buttonHoverDuration
                                easing.type: Easing.OutCubic
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

                Repeater {
                    model: root.regions

                    delegate: Text {
                        required property int index
                        required property var modelData
                        readonly property bool hovered: root.hoveredIndex === index
                        readonly property bool selected: root.selectedIndex === index
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
                        color: selected ? Theme.onAccentColor : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: baseSize * (hovered ? root.hoverTextScale : 1.0)
                        font.weight: hovered || selected ? Font.DemiBold : Font.Medium
                        z: 60

                        Behavior on x { NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
                        Behavior on font.pixelSize {
                            NumberAnimation { duration: HAnimation.buttonHoverDuration; easing.type: Easing.OutCubic }
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
                    enabled: root.panelOpen && root.navigationRevealProgress > 0.82
                    acceptedButtons: Qt.LeftButton
                    cursorShape: root.hoveredIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    z: 80

                    function localCircleX(px) { return px + radialHit.x }
                    function localCircleY(py) { return py + radialHit.y }

                    function updateHover(px, py) {
                        var index = root.indexAt(localCircleX(px), localCircleY(py), true)
                        root.hoveredIndex = index
                        if (index >= 0 && root.regions[index].key === "sidebar") {
                            UiState.beginNavigationHandoff("sidebar")
                        } else if (UiState.navigationMode === "handoff-sidebar") {
                            UiState.cancelNavigationHandoff()
                        }
                    }

                    onEntered: updateHover(mouseX, mouseY)
                    onPositionChanged: mouse => updateHover(mouse.x, mouse.y)
                    onExited: {
                        root.hoveredIndex = -1
                        if (UiState.navigationMode === "handoff-sidebar") {
                            UiState.cancelNavigationHandoff()
                        }
                    }
                    onClicked: mouse => {
                        var index = root.indexAt(localCircleX(mouse.x), localCircleY(mouse.y), true)
                        if (index >= 0) root.activateIndex(index)
                    }
                }
            }
    }
}
