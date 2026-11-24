import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../services"
import "glassgrid" as Glass
import "TaskManagerLogic.js" as Logic
import "TaskManagerGridGeometry.js" as GridGeometry
import "../../config/UiCatalog.js" as Catalog

FocusScope {
    id: root

    property var snapshot: ({})
    property var pinnedProcesses: TaskManagerPins.pinnedProcesses
    property bool reducedMotion: false

    signal openFullRequested()

    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpu: (snapshot.gpus || [])[0] || ({})

    implicitHeight: Math.max(180, Math.round(Theme.fontSize * 13.5))

    property real waterWavePhase: 0
    NumberAnimation on waterWavePhase {
        from: 0
        to: Math.PI * 2
        duration: 3400
        loops: Animation.Infinite
        running: root.visible && !root.reducedMotion
    }

    readonly property var carouselIds: TaskManagerOverlayState.carouselMetrics
    property int committedIndex: TaskManagerOverlayState.activeMetricIndex
    property int pendingIndex: -1
    property int transitionDirection: 0
    property bool transitioning: false
    property real transitionProgress: 0.0
    readonly property real slideDistance: Math.max(40, Theme.spaceXl * 2.5)

    Connections {
        target: TaskManagerOverlayState
        function onActiveMetricIndexChanged() {
            if (!root.transitioning && root.committedIndex !== TaskManagerOverlayState.activeMetricIndex) {
                root.committedIndex = TaskManagerOverlayState.activeMetricIndex
            }
        }
    }

    function switchCarousel(direction) {
        var count = carouselIds.length
        if (count <= 1) return

        var step = direction < 0 ? -1 : 1
        if (root.reducedMotion) {
            carouselAnim.stop()
            var directNext = ((TaskManagerOverlayState.activeMetricIndex + step) % count + count) % count
            TaskManagerOverlayState.setActiveMetricIndex(directNext)
            root.committedIndex = directNext
            root.pendingIndex = -1
            root.transitionDirection = 0
            root.transitioning = false
            root.transitionProgress = 0.0
            return
        }

        if (root.transitioning && root.pendingIndex >= 0) {
            var candidateFromPending = ((root.pendingIndex + step) % count + count) % count
            carouselAnim.stop()
            if (candidateFromPending === root.committedIndex) {
                // Reverse mid-flight without snapping to an intermediate frame.
                var oldCommitted = root.committedIndex
                root.committedIndex = root.pendingIndex
                root.pendingIndex = oldCommitted
                root.transitionDirection = step
                root.transitionProgress = Math.max(0.0, Math.min(1.0, 1.0 - root.transitionProgress))
                TaskManagerOverlayState.setActiveMetricIndex(root.pendingIndex)
                carouselAnim.from = root.transitionProgress
                carouselAnim.to = 1.0
                carouselAnim.duration = Math.max(60, Math.round(HAnimation.dashboardWidgetSwitchDuration * (1.0 - root.transitionProgress)))
                carouselAnim.start()
                return
            }
            root.committedIndex = root.pendingIndex
        }

        var nextIdx = ((root.committedIndex + step) % count + count) % count
        if (nextIdx === root.committedIndex) return

        root.transitionDirection = step
        root.pendingIndex = nextIdx
        root.transitioning = true
        root.transitionProgress = 0.0
        TaskManagerOverlayState.setActiveMetricIndex(nextIdx)
        carouselAnim.from = 0.0
        carouselAnim.to = 1.0
        carouselAnim.duration = HAnimation.dashboardWidgetSwitchDuration
        carouselAnim.start()
    }

    NumberAnimation {
        id: carouselAnim
        target: root
        property: "transitionProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.dashboardWidgetSwitchCurve
        onFinished: {
            if (root.pendingIndex >= 0) root.committedIndex = root.pendingIndex
            root.pendingIndex = -1
            root.transitionDirection = 0
            root.transitioning = false
            root.transitionProgress = 0.0
        }
    }

    function metricValueNumber(metricId) {
        if (metricId === "ram") return Number.isFinite(root.memory.percent) ? root.memory.percent : NaN
        if (metricId === "cpu") return Number.isFinite(root.cpu.usage) ? root.cpu.usage : NaN
        var g = root.gpu
        return Number.isFinite(g.usage) ? g.usage : NaN
    }

    function metricDisplayLabel(metricId) {
        if (metricId === "ram") return "RAM"
        if (metricId === "cpu") return "CPU"
        return "GPU"
    }

    function metricIconGlyph(metricId) {
        if (metricId === "ram") return Catalog.taskManagerIcons.memory
        if (metricId === "cpu") return Catalog.taskManagerIcons.cpu
        return Catalog.taskManagerIcons.gpu
    }

    function detailRowsForMetric(metricId) {
        if (metricId === "ram") {
            var m = root.memory
            var usedVal = (Number.isFinite(m.used) && Number.isFinite(m.total))
                ? (Logic.bytes(m.used) + " / " + Logic.bytes(m.total)) : "—"
            var availVal = Number.isFinite(m.availableBytes) ? Logic.bytes(m.availableBytes) : "—"
            var cacheVal = Number.isFinite(m.cache) ? Logic.bytes(m.cache) : "—"
            var swapVal = (Number.isFinite(m.swapTotal) && m.swapTotal > 0)
                ? (Logic.bytes(m.swapUsed || 0) + " / " + Logic.bytes(m.swapTotal)) : "—"
            return [
                { label: "Used", value: usedVal },
                { label: "Available", value: availVal },
                { label: "Cache", value: cacheVal },
                { label: "Swap", value: swapVal }
            ]
        }
        if (metricId === "cpu") {
            var c = root.cpu
            var tempVal = Number.isFinite(c.temperatureC) ? (Math.round(c.temperatureC) + " °C") : "—"
            var freqRaw = c.frequencyHighestMHz !== undefined && c.frequencyHighestMHz !== null
                ? c.frequencyHighestMHz
                : (c.frequencyMHz !== undefined && c.frequencyMHz !== null ? c.frequencyMHz : c.frequencyAverageMHz)
            var freqVal = Number.isFinite(freqRaw) ? (Math.round(freqRaw) + " MHz") : "—"
            var loadVal = Array.isArray(c.load) && c.load.length > 0
                ? c.load.slice(0, 3).map(function(v) { return Number.isFinite(v) ? v.toFixed(2) : "—" }).join(" / ")
                : "—"
            var coresVal = Array.isArray(c.cores) && c.cores.length > 0 ? (c.cores.length + " threads") : "—"
            return [
                { label: "Temp", value: tempVal },
                { label: "Freq", value: freqVal },
                { label: "Load", value: loadVal },
                { label: "Cores", value: coresVal }
            ]
        }
        var g = root.gpu
        var devVal = g.name || (TaskManagerService.ready ? "Unsupported" : "—")
        var gTempVal = Number.isFinite(g.temperatureC) ? (Math.round(g.temperatureC) + " °C") : "—"
        var vramVal = g.memoryType === "shared"
            ? "Shared"
            : (Number.isFinite(g.memoryUsed)
                ? (Logic.bytes(g.memoryUsed) + (Number.isFinite(g.memoryTotal) && g.memoryTotal > 0 ? " / " + Logic.bytes(g.memoryTotal) : ""))
                : "—")
        var cpParts = []
        if (Number.isFinite(g.clockMHz)) cpParts.push(Math.round(g.clockMHz) + " MHz")
        if (Number.isFinite(g.powerW)) cpParts.push(g.powerW.toFixed(1) + " W")
        var cpVal = cpParts.length > 0 ? cpParts.join(" · ") : (Number.isFinite(g.usage) ? "—" : Logic.gpuUsage(g))
        return [
            { label: "Device", value: devVal },
            { label: "Temp", value: gTempVal },
            { label: "VRAM", value: vramVal },
            { label: "Clock / Power", value: cpVal }
        ]
    }

    function resolvedScreen() {
        var targetName = UiState.hakuMenuScreenName
        for (var s of Quickshell.screens) {
            if (s.name === targetName) return s
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    function screenUsableArea(screenObj) {
        var w = screenObj ? screenObj.width : 1920
        var h = screenObj ? screenObj.height : 1080
        return GridGeometry.usableArea(w, h, { padding: 0 })
    }

    function forcePrimaryFocus() {
        pinsPane.forceActiveFocus()
    }

    function clearPrimaryFocus() {
        focus = false
    }

    RowLayout {
        id: mainGrid
        objectName: "taskManagerMiniTwoColumnGrid"
        anchors.fill: parent
        spacing: Theme.spaceLg

        Item {
            id: leftColumnHost
            objectName: "taskManagerMiniLeftColumn"
            Layout.preferredWidth: Math.round(mainGrid.width * Theme.taskManagerMiniLeftColumnRatio)
            Layout.minimumWidth: Math.round(Theme.fontSize * 10.5)
            Layout.fillHeight: true

            readonly property int slotSpacing: Theme.spaceMd
            readonly property real pillHeight: Math.max(36, (height - slotSpacing * 3) / 4)

            Text {
                id: leftHeaderLabel
                objectName: "taskManagerMiniLeftLabel"
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: leftColumnHost.pillHeight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "--- Performance ---"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Item {
                id: leftStack
                anchors {
                    top: leftHeaderLabel.bottom
                    topMargin: leftColumnHost.slotSpacing
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                Repeater {
                    id: leftSlotRepeater
                    model: 3

                    Item {
                        id: slotContainer
                        required property int index
                        objectName: "taskManagerMiniLeftSlot_" + index
                        x: 0
                        y: index * (leftColumnHost.pillHeight + leftColumnHost.slotSpacing)
                        width: leftStack.width
                        height: leftColumnHost.pillHeight
                        // Keep detached recall controls above leftDragArea so hover and click work directly.
                        z: showMissingRecall && !TaskManagerOverlayState.dragActive ? 15 : 1

                        readonly property string slotMetricId: TaskManagerOverlayState.leftSlotOrder[index] || "cpu"
                        readonly property bool isDetached: TaskManagerOverlayState.isDetached(slotMetricId)
                        readonly property bool isDraggedFromMenu: TaskManagerOverlayState.dragActive
                            && TaskManagerOverlayState.dragOrigin === "menu"
                            && TaskManagerOverlayState.dragMetricId === slotMetricId
                        readonly property bool showMissingRecall: isDetached || (isDraggedFromMenu && TaskManagerOverlayState.dragOutsideMenu)
                        readonly property var missingMetrics: TaskManagerOverlayState.detachedMetrics
                        readonly property bool multiMissing: missingMetrics.length >= 2

                        Rectangle {
                            id: missingCapsule
                            objectName: "taskManagerMiniMissingSlot_" + slotContainer.index
                            anchors.fill: parent
                            visible: slotContainer.showMissingRecall || slotContainer.isDraggedFromMenu
                            radius: height / 2
                            border.width: 0
                            color: Theme.surfaceSubtle(1.55)
                            scale: (slotContainer.showMissingRecall && missingHover.hovered && !slotContainer.multiMissing && !TaskManagerOverlayState.dragActive && !root.reducedMotion)
                                ? 1.05 : 1.0

                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: HAnimation.buttonHoverDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: HAnimation.buttonHoverCurve
                                }
                            }

                            HoverHandler {
                                id: missingHover
                                enabled: slotContainer.showMissingRecall && !TaskManagerOverlayState.dragActive
                            }

                            Row {
                                id: idleRecallContent
                                anchors.centerIn: parent
                                spacing: Theme.spaceSm
                                visible: slotContainer.showMissingRecall && opacity > 0.001
                                opacity: (missingHover.hovered && !TaskManagerOverlayState.dragActive && slotContainer.missingMetrics.length > 0)
                                    ? (slotContainer.multiMissing ? 0.0 : 1.0)
                                    : 1.0

                                Behavior on opacity {
                                    enabled: !root.reducedMotion
                                    NumberAnimation { duration: HAnimation.fast }
                                }

                                Text {
                                    objectName: "taskManagerMiniMissingIcon_" + slotContainer.index
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (missingHover.hovered && !slotContainer.multiMissing && slotContainer.missingMetrics.length === 1)
                                        ? root.metricIconGlyph(slotContainer.missingMetrics[0])
                                        : Catalog.taskManagerIcons.recall
                                    color: (missingHover.hovered && !slotContainer.multiMissing)
                                        ? Theme.accent
                                        : Qt.alpha(Theme.fgMuted, 0.55)
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Math.max(20, Math.round(Theme.fontSize * 1.75))
                                    Accessible.ignored: true
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: missingHover.hovered && !slotContainer.multiMissing && slotContainer.missingMetrics.length === 1
                                    text: slotContainer.missingMetrics.length === 1
                                        ? root.metricDisplayLabel(slotContainer.missingMetrics[0])
                                        : ""
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                objectName: "taskManagerMiniSingleRecallMouse_" + slotContainer.index
                                anchors.fill: parent
                                enabled: slotContainer.showMissingRecall
                                    && !TaskManagerOverlayState.dragActive
                                    && slotContainer.missingMetrics.length === 1
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (slotContainer.missingMetrics.length === 1) {
                                        TaskManagerOverlayState.recallOverlayToSlot(slotContainer.missingMetrics[0], slotContainer.index)
                                    }
                                }
                            }

                            RowLayout {
                                id: multiRecallRow
                                objectName: "taskManagerMiniMultiRecallRow_" + slotContainer.index
                                anchors {
                                    fill: parent
                                    leftMargin: Theme.spaceMd
                                    rightMargin: Theme.spaceMd
                                    topMargin: Theme.spaceSm
                                    bottomMargin: Theme.spaceSm
                                }
                                spacing: Theme.spaceSm
                                visible: slotContainer.showMissingRecall
                                    && slotContainer.multiMissing
                                    && !TaskManagerOverlayState.dragActive
                                    && opacity > 0.001
                                opacity: (missingHover.hovered && slotContainer.multiMissing && !TaskManagerOverlayState.dragActive) ? 1.0 : 0.0

                                Behavior on opacity {
                                    enabled: !root.reducedMotion
                                    NumberAnimation { duration: HAnimation.fast }
                                }

                                Repeater {
                                    model: slotContainer.multiMissing ? slotContainer.missingMetrics : []

                                    Rectangle {
                                        id: recallChip
                                        required property string modelData
                                        objectName: "taskManagerMiniRecallChip_" + slotContainer.index + "_" + modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: height / 2
                                        border.width: 0
                                        color: Theme.surfaceSubtle(1.25)
                                        scale: (chipMouse.containsMouse && !root.reducedMotion) ? 1.05 : 1.0

                                        Behavior on scale {
                                            enabled: !root.reducedMotion
                                            NumberAnimation {
                                                duration: HAnimation.buttonHoverDuration
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: HAnimation.buttonHoverCurve
                                            }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Theme.spaceXs

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.metricIconGlyph(recallChip.modelData)
                                                color: Theme.accent
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Math.max(18, Math.round(Theme.fontSize * 1.65))
                                                Accessible.ignored: true
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: slotContainer.missingMetrics.length <= 2
                                                text: root.metricDisplayLabel(recallChip.modelData)
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                font.bold: true
                                            }
                                        }

                                        MouseArea {
                                            id: chipMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton
                                            onClicked: TaskManagerOverlayState.recallOverlayToSlot(recallChip.modelData, slotContainer.index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Repeater {
                    id: dockedPillRepeater
                    model: TaskManagerOverlayState.validMetrics

                    TaskManagerMetricPill {
                        id: dockedPill
                        required property string modelData
                        objectName: "taskManagerMiniDockedPill_" + modelData

                        readonly property int slotIdx: Math.max(0, TaskManagerOverlayState.leftSlotOrder.indexOf(modelData))
                        readonly property bool isDetached: TaskManagerOverlayState.isDetached(modelData)
                        readonly property bool isDraggedFromMenu: TaskManagerOverlayState.dragActive
                            && TaskManagerOverlayState.dragOrigin === "menu"
                            && TaskManagerOverlayState.dragMetricId === modelData

                        x: 0
                        y: slotIdx * (leftColumnHost.pillHeight + leftColumnHost.slotSpacing)
                        width: leftStack.width
                        height: leftColumnHost.pillHeight
                        z: 2
                        visible: !isDetached && !isDraggedFromMenu && leftColumnHost.pillHeight > 0
                        metricId: modelData
                        snapshot: root.snapshot
                        inOverlay: false
                        hovered: leftDragArea.hoveredSlot === slotIdx && !leftDragArea.dragging
                        pressed: leftDragArea.pressedSlot === slotIdx && !leftDragArea.dragging
                        reducedMotion: root.reducedMotion

                        property bool layoutReady: false
                        Component.onCompleted: Qt.callLater(function() { if (dockedPill) dockedPill.layoutReady = true })

                        Behavior on y {
                            enabled: dockedPill.layoutReady && !root.reducedMotion
                            NumberAnimation {
                                duration: HAnimation.fast
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: HAnimation.moduleCurve
                            }
                        }
                    }
                }

                // Keep one stationary MouseArea so slot reordering and menu exit never drop the pointer grab.
                MouseArea {
                    id: leftDragArea
                    objectName: "taskManagerMiniLeftDragArea"
                    anchors.fill: parent
                    z: 10
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton

                    property int hoveredSlot: -1
                    property int pressedSlot: -1
                    property string pressMetricId: ""
                    property real pressX: 0
                    property real pressY: 0
                    property real grabOffsetX: 0
                    property real grabOffsetY: 0
                    property real grabPillW: 0
                    property real grabPillH: 0
                    property bool dragging: false

                    cursorShape: {
                        if (dragging) return Qt.ClosedHandCursor
                        if (hoveredSlot >= 0) {
                            var mId = TaskManagerOverlayState.leftSlotOrder[hoveredSlot]
                            if (mId && !TaskManagerOverlayState.isDetached(mId)) return Qt.OpenHandCursor
                        }
                        return Qt.ArrowCursor
                    }

                    onExited: if (!pressed) hoveredSlot = -1

                    onPressed: mouse => {
                        var idx = GridGeometry.slotIndexAtY(mouse.y, leftStack.height, 3, leftColumnHost.slotSpacing)
                        var mId = TaskManagerOverlayState.leftSlotOrder[idx]
                        if (!mId || TaskManagerOverlayState.isDetached(mId)) {
                            mouse.accepted = false
                            return
                        }
                        var slotItem = leftSlotRepeater.itemAt(idx)
                        pressedSlot = idx
                        pressMetricId = mId
                        pressX = mouse.x
                        pressY = mouse.y
                        grabPillW = slotItem ? slotItem.width : leftStack.width
                        grabPillH = slotItem ? slotItem.height : leftColumnHost.pillHeight
                        grabOffsetX = slotItem ? (mouse.x - slotItem.x) : grabPillW / 2
                        grabOffsetY = slotItem ? (mouse.y - slotItem.y) : grabPillH / 2
                        dragging = false
                    }

                    onPositionChanged: mouse => {
                        if (!pressed) {
                            hoveredSlot = GridGeometry.slotIndexAtY(mouse.y, leftStack.height, 3, leftColumnHost.slotSpacing)
                            return
                        }
                        if (!pressMetricId) return
                        var screenObj = root.resolvedScreen()
                        if (!screenObj) return

                        if (!dragging) {
                            if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < 5) return
                            var initPt = leftDragArea.mapToItem(null, mouse.x, mouse.y)
                            dragging = TaskManagerOverlayState.beginMenuDrag(
                                pressMetricId,
                                screenObj.name,
                                initPt.x,
                                initPt.y,
                                grabPillW,
                                grabPillH,
                                grabOffsetX,
                                grabOffsetY,
                                pressedSlot
                            )
                        }

                        if (!dragging) return

                        var pt = leftDragArea.mapToItem(null, mouse.x, mouse.y)
                        var menuRect = TaskManagerOverlayState.activeMenuRect
                        var insideMenu = menuRect.open
                            && pt.x >= menuRect.x && pt.x <= menuRect.x + menuRect.width
                            && pt.y >= menuRect.y && pt.y <= menuRect.y + menuRect.height

                        if (insideMenu) {
                            var targetSlot = GridGeometry.slotIndexAtY(mouse.y, leftStack.height, 3, leftColumnHost.slotSpacing)
                            TaskManagerOverlayState.updateDrag(pt.x, pt.y, false, null, targetSlot)
                        } else {
                            var usable = root.screenUsableArea(screenObj)
                            var pSpec = GridGeometry.pillDimensions(Theme.fontSize, Theme.spaceSm, Theme.spaceLg)
                            var rawX = pt.x - Math.max(0, Math.min(pSpec.width, grabOffsetX))
                            var rawY = pt.y - Math.max(0, Math.min(pSpec.height, grabOffsetY))
                            var resolved = GridGeometry.resolveMagneticPosition(
                                rawX,
                                rawY,
                                pSpec,
                                usable,
                                TaskManagerOverlayState.otherOverlaysForScreen(screenObj.name, pressMetricId, pSpec),
                                { gap: Theme.spaceSm }
                            )
                            TaskManagerOverlayState.updateDrag(pt.x, pt.y, true, resolved, -1)
                        }
                    }

                    onReleased: {
                        if (dragging) TaskManagerOverlayState.commitMenuDrag()
                        dragging = false
                        pressedSlot = -1
                        pressMetricId = ""
                    }

                    onCanceled: {
                        if (dragging) TaskManagerOverlayState.cancelDrag()
                        dragging = false
                        pressedSlot = -1
                        pressMetricId = ""
                    }
                }
            }
        }

        ColumnLayout {
            id: rightColumn
            objectName: "taskManagerMiniRightColumn"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            Rectangle {
                id: waterCarouselCard
                objectName: "taskManagerMiniWaterCarousel"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(138, Math.round(rightColumn.height * 0.58))
                radius: Theme.largeRadius
                color: Theme.surfaceSubtle(1.6)
                border.width: 0
                z: cardHovered ? 2 : 0
                readonly property bool cardHovered: cardHover.hovered || prevCarouselMouse.containsMouse || nextCarouselMouse.containsMouse
                scale: (cardHovered && !root.reducedMotion) ? 1.05 : 1.0

                HoverHandler { id: cardHover }

                Behavior on scale {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: waterCarouselCard.cardHovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: waterCarouselCard.cardHovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceMd
                    anchors.rightMargin: Theme.spaceMd
                    spacing: Theme.spaceSm

                    Rectangle {
                        id: prevCarouselBtn
                        objectName: "taskManagerMiniCarouselPrev"
                        Layout.preferredWidth: Theme.controlHeight - 4
                        Layout.preferredHeight: Theme.controlHeight - 4
                        Layout.alignment: Qt.AlignVCenter
                        radius: height / 2
                        border.width: 0
                        color: Theme.surfaceSubtle(1.3)
                        scale: prevCarouselMouse.pressed && !root.reducedMotion ? 0.92
                            : (prevCarouselMouse.containsMouse && !root.reducedMotion ? 1.05 : 1.0)
                        activeFocusOnTab: true

                        Behavior on scale {
                            enabled: !root.reducedMotion
                            NumberAnimation {
                                duration: prevCarouselMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: prevCarouselMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                            }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: "Previous metric"
                        Keys.onReturnPressed: event => { root.switchCarousel(-1); event.accepted = true }
                        Keys.onSpacePressed: event => { root.switchCarousel(-1); event.accepted = true }

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSize * 1.4)
                            font.bold: true
                            Accessible.ignored: true
                        }

                        MouseArea {
                            id: prevCarouselMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: root.switchCarousel(-1)
                        }
                    }

                    Item {
                        id: carouselViewport
                        objectName: "taskManagerMiniCarouselViewport"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Repeater {
                            model: root.carouselIds

                            Item {
                                id: slideSlot
                                required property int index
                                required property string modelData
                                objectName: "taskManagerMiniCarouselSlide_" + modelData

                                width: carouselViewport.width
                                height: carouselViewport.height

                                readonly property bool isCurrent: !root.transitioning && root.committedIndex === index
                                readonly property bool isOutgoing: root.transitioning && root.committedIndex === index
                                readonly property bool isIncoming: root.transitioning && root.pendingIndex === index

                                visible: isCurrent || isOutgoing || isIncoming

                                x: isOutgoing
                                    ? (-root.transitionDirection * root.slideDistance * root.transitionProgress)
                                    : (isIncoming
                                        ? (root.transitionDirection * root.slideDistance * (1.0 - root.transitionProgress))
                                        : 0)

                                opacity: isOutgoing
                                    ? (1.0 - root.transitionProgress)
                                    : (isIncoming
                                        ? root.transitionProgress
                                        : (isCurrent ? 1.0 : 0.0))

                                readonly property real metricVal: root.metricValueNumber(modelData)
                                readonly property bool metricAvail: Number.isFinite(metricVal)
                                readonly property real gaugeSize: Math.max(64, Math.min(118,
                                    carouselViewport.height - Theme.spaceMd * 2,
                                    Math.round(carouselViewport.width * 0.36)))
                                readonly property var detailRows: root.detailRowsForMetric(modelData)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spaceMd
                                    anchors.rightMargin: Theme.spaceMd
                                    anchors.topMargin: Theme.spaceSm
                                    anchors.bottomMargin: Theme.spaceSm
                                    spacing: Theme.spaceXl + Theme.spaceSm

                                    Item {
                                        id: gaugeHoverSlot
                                        Layout.preferredWidth: waterGauge.diameter
                                        Layout.preferredHeight: waterGauge.diameter
                                        Layout.alignment: Qt.AlignVCenter

                                        HoverHandler { id: gaugeHover }

                                        Glass.TaskWaterGauge {
                                            id: waterGauge
                                            objectName: "taskManagerMiniWaterGauge_" + slideSlot.modelData
                                            anchors.centerIn: parent
                                            diameter: slideSlot.gaugeSize
                                            borderless: true
                                            interactive: false
                                            emphasized: gaugeHover.hovered
                                            scale: (gaugeHover.hovered && !root.reducedMotion) ? 1.05 : 1.0
                                            metricId: slideSlot.modelData
                                            available: slideSlot.metricAvail
                                            value: slideSlot.metricAvail ? slideSlot.metricVal : 0
                                            wavePhase: root.waterWavePhase
                                            reducedMotion: root.reducedMotion || !slideSlot.visible
                                            Accessible.ignored: true

                                            Behavior on scale {
                                                enabled: !root.reducedMotion
                                                NumberAnimation {
                                                    duration: gaugeHover.hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: gaugeHover.hovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        objectName: "taskManagerMiniWaterDetails_" + slideSlot.modelData
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 3

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spaceMd

                                            Text {
                                                text: root.metricIconGlyph(slideSlot.modelData)
                                                color: Theme.accent
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fontSize + 1
                                                Accessible.ignored: true
                                            }

                                            Text {
                                                objectName: "taskManagerMiniWaterLabel_" + slideSlot.modelData
                                                text: root.metricDisplayLabel(slideSlot.modelData)
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                                font.bold: true
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                objectName: "taskManagerMiniWaterPercent_" + slideSlot.modelData
                                                text: waterGauge.percentText
                                                color: Theme.accent
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Math.round(Theme.fontSize * 1.35)
                                                font.bold: true
                                            }
                                        }

                                        Repeater {
                                            model: slideSlot.detailRows

                                            RowLayout {
                                                required property var modelData
                                                required property int index
                                                objectName: "taskManagerMiniWaterDetailRow_" + slideSlot.modelData + "_" + index
                                                Layout.fillWidth: true
                                                spacing: Theme.spaceSm

                                                Text {
                                                    text: modelData.label
                                                    color: Theme.fgMuted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Math.max(11, Theme.fontSize - 2)
                                                }

                                                Text {
                                                    objectName: "taskManagerMiniWaterDetailValue_" + slideSlot.modelData + "_" + index
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    horizontalAlignment: Text.AlignRight
                                                    text: modelData.value
                                                    color: Theme.fg
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Math.max(11, Theme.fontSize - 2)
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: nextCarouselBtn
                        objectName: "taskManagerMiniCarouselNext"
                        Layout.preferredWidth: Theme.controlHeight - 4
                        Layout.preferredHeight: Theme.controlHeight - 4
                        Layout.alignment: Qt.AlignVCenter
                        radius: height / 2
                        border.width: 0
                        color: Theme.surfaceSubtle(1.3)
                        scale: nextCarouselMouse.pressed && !root.reducedMotion ? 0.92
                            : (nextCarouselMouse.containsMouse && !root.reducedMotion ? 1.05 : 1.0)
                        activeFocusOnTab: true

                        Behavior on scale {
                            enabled: !root.reducedMotion
                            NumberAnimation {
                                duration: nextCarouselMouse.containsMouse ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: nextCarouselMouse.containsMouse ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                            }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: "Next metric"
                        Keys.onReturnPressed: event => { root.switchCarousel(1); event.accepted = true }
                        Keys.onSpacePressed: event => { root.switchCarousel(1); event.accepted = true }

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSize * 1.4)
                            font.bold: true
                            Accessible.ignored: true
                        }

                        MouseArea {
                            id: nextCarouselMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: root.switchCarousel(1)
                        }
                    }
                }
            }

            Rectangle {
                id: pinsPane
                objectName: "taskManagerMiniPinsPane"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.largeRadius
                border.width: 0
                clip: true
                activeFocusOnTab: true
                color: Theme.surfaceSubtle(1.6)

                Accessible.role: Accessible.Button
                Accessible.name: "Open Task Manager"
                Keys.onReturnPressed: event => { root.openFullRequested(); event.accepted = true }
                Keys.onEnterPressed: event => { root.openFullRequested(); event.accepted = true }
                Keys.onSpacePressed: event => { root.openFullRequested(); event.accepted = true }

                MouseArea {
                    id: pinsBgMouse
                    objectName: "taskManagerMiniPinsClickArea"
                    anchors.fill: parent
                    z: 0
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.openFullRequested()
                }

                Item {
                    id: emptyPinsState
                    objectName: "taskManagerMiniEmptyPins"
                    anchors.fill: parent
                    anchors.margins: Theme.spaceMd
                    z: 2

                    Row {
                        id: emptyIdleRow
                        objectName: "taskManagerMiniEmptyPinsIdle"
                        anchors.centerIn: parent
                        spacing: Theme.spaceSm
                        visible: root.pinnedProcesses.length === 0 && TaskManagerService.error.length === 0
                        opacity: 0.72

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Catalog.taskManagerIcons.pin
                            color: Theme.fgMuted
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Math.round(Theme.fontSize * 1.25)
                            Accessible.ignored: true
                        }

                        Text {
                            objectName: "taskManagerMiniEmptyPinsLabel"
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Pin Process"
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.Medium
                        }
                    }
                }

                Text {
                    visible: root.pinnedProcesses.length === 0 && TaskManagerService.error.length > 0
                    anchors.centerIn: parent
                    width: parent.width - Theme.spaceLg * 2
                    horizontalAlignment: Text.AlignHCenter
                    text: TaskManagerService.error
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }

                ScriptModel {
                    id: pinnedModel
                    values: root.pinnedProcesses
                    objectProp: "key"
                    comparisonMode: ObjectComparison.Structure
                }

                ListView {
                    id: pinnedListView
                    objectName: "taskManagerMiniPinnedList"
                    anchors.fill: parent
                    topMargin: Theme.spaceSm
                    bottomMargin: Theme.spaceSm
                    z: 1
                    spacing: Theme.spaceXs
                    visible: root.pinnedProcesses.length > 0
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    model: pinnedModel

                    delegate: Item {
                        id: pinRowWrapper
                        required property var modelData
                        width: pinnedListView.width
                        height: Theme.comfortableControlHeight

                        Rectangle {
                            id: pinRow
                            objectName: "taskManagerMiniPinnedRow"
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(0, parent.width - Theme.spaceMd * 2)
                            height: parent.height
                            radius: height / 2
                            border.width: 0
                            color: Theme.surfaceSubtle(1.4)

                            readonly property bool rowHovered: rowClickMouse.containsMouse || unpinMouse.containsMouse
                            scale: (rowHovered && !root.reducedMotion) ? 1.05 : 1.0

                            Behavior on scale {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: pinRow.rowHovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: pinRow.rowHovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                                }
                            }

                            MouseArea {
                                id: rowClickMouse
                                objectName: "taskManagerMiniPinnedRowClick_" + pinRowWrapper.modelData.key
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                    right: parent.right
                                    rightMargin: unpinBtn.width + Theme.spaceSm * 2
                                }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: root.openFullRequested()
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spaceLg
                                anchors.rightMargin: Theme.spaceSm
                                spacing: Theme.spaceSm

                                Text {
                                    objectName: "taskManagerMiniPinnedName"
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: pinRowWrapper.modelData.name
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    objectName: "taskManagerMiniPinnedCpu"
                                    Layout.preferredWidth: Theme.fontSize * 3.6
                                    horizontalAlignment: Text.AlignRight
                                    text: Logic.metric(pinRowWrapper.modelData.cpuTotalPercent, "%", 0)
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                }

                                Text {
                                    objectName: "taskManagerMiniPinnedRam"
                                    Layout.preferredWidth: Theme.fontSize * 5.2
                                    horizontalAlignment: Text.AlignRight
                                    text: Logic.bytes(pinRowWrapper.modelData.rss)
                                    color: Theme.fgMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                }

                                Rectangle {
                                    id: unpinBtn
                                    objectName: "taskManagerMiniUnpinButton"
                                    z: 2
                                    Layout.preferredWidth: Theme.controlHeight - 8
                                    Layout.preferredHeight: Theme.controlHeight - 8
                                    radius: height / 2
                                    border.width: 0
                                    color: "transparent"
                                    opacity: (rowClickMouse.containsMouse || unpinMouse.containsMouse || unpinBtn.activeFocus) ? 1.0 : 0.0
                                    scale: (unpinMouse.containsMouse && !root.reducedMotion) ? 1.15 : 1.0
                                    activeFocusOnTab: true

                                    Behavior on opacity {
                                        enabled: !root.reducedMotion
                                        NumberAnimation { duration: HAnimation.fast }
                                    }

                                    Behavior on scale {
                                        enabled: !root.reducedMotion
                                        NumberAnimation { duration: HAnimation.fast }
                                    }

                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Unpin " + pinRowWrapper.modelData.name
                                    Keys.onReturnPressed: event => { TaskManagerPins.unpin(pinRowWrapper.modelData); event.accepted = true }
                                    Keys.onSpacePressed: event => { TaskManagerPins.unpin(pinRowWrapper.modelData); event.accepted = true }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: unpinMouse.containsMouse ? Theme.danger : Theme.fgMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize + 3
                                        font.bold: true
                                        Accessible.ignored: true
                                    }

                                    MouseArea {
                                        id: unpinMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: TaskManagerPins.unpin(pinRowWrapper.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
