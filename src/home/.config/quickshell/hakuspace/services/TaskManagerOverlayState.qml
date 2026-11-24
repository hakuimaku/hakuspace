pragma Singleton
import QtQuick
import Quickshell
import "../components/taskmanager/TaskManagerGridGeometry.js" as GridGeometry

QtObject {
    id: root

    // Runtime-only layout and overlay state; never persisted across sessions.
    readonly property var validMetrics: ["cpu", "gpu", "ram"]
    readonly property var carouselMetrics: ["ram", "cpu", "gpu"]

    property var leftSlotOrder: ["cpu", "gpu", "ram"]
    property int activeMetricIndex: 0

    // Map of metricId -> { active, metricId, screenName, x, y }
    property var detachedOverlays: ({})
    readonly property var detachedMetrics: validMetrics.filter(function(id) { return !!detachedOverlays[id] })
    readonly property int detachedCount: detachedMetrics.length
    readonly property bool hasActiveOverlays: detachedCount > 0

    // Published HakuMenu body bounds so overlays avoid conflicting with open menu bounds.
    property var activeMenuRect: ({ screenName: "", open: false, x: 0, y: 0, width: 0, height: 0 })

    // Active drag session coordinates in output-local space.
    property bool dragActive: false
    property string dragMetricId: ""
    property string dragOrigin: ""
    property string dragScreenName: ""
    property real dragPointerX: 0
    property real dragPointerY: 0
    property real dragGrabOffsetX: 0
    property real dragGrabOffsetY: 0
    property real dragPillWidth: 0
    property real dragPillHeight: 0
    property bool dragOutsideMenu: false
    property real dragTargetX: 0
    property real dragTargetY: 0
    property int dragHoveredMenuSlot: -1

    readonly property var dragSession: ({
        active: dragActive,
        metricId: dragMetricId,
        origin: dragOrigin,
        screenName: dragScreenName,
        pointerX: dragPointerX,
        pointerY: dragPointerY,
        outsideMenu: dragOutsideMenu,
        targetPos: { x: dragTargetX, y: dragTargetY },
        hoveredMenuSlot: dragHoveredMenuSlot
    })

    // Hold exactly one telemetry lease while any gaming monitor pill or drag session exists.
    readonly property bool needsServiceLease: AppState.shellBackend === "hikai" && (hasActiveOverlays || dragActive)
    property bool _serviceLeaseHeld: false
    property var snapshot: ({})

    function syncServiceLease() {
        if (needsServiceLease && !_serviceLeaseHeld) {
            _serviceLeaseHeld = true
            TaskManagerService.acquire()
            if (TaskManagerService.ready) snapshot = TaskManagerService.snapshot
        } else if (!needsServiceLease && _serviceLeaseHeld) {
            _serviceLeaseHeld = false
            TaskManagerService.release()
        }
    }

    onNeedsServiceLeaseChanged: syncServiceLease()
    Component.onCompleted: syncServiceLease()
    Component.onDestruction: if (_serviceLeaseHeld) TaskManagerService.release()

    property Connections serviceConnections: Connections {
        target: TaskManagerService
        function onSnapshotChanged() {
            if (TaskManagerService.ready) root.snapshot = TaskManagerService.snapshot
        }
        function onReadyChanged() {
            if (TaskManagerService.ready) root.snapshot = TaskManagerService.snapshot
        }
    }

    property Connections backendConnections: Connections {
        target: AppState
        function onShellBackendChanged() {
            if (AppState.shellBackend !== "hikai") root.resetAll()
        }
    }

    property Connections screenConnections: Connections {
        target: Quickshell
        function onScreensChanged() {
            var liveNames = {}
            for (var s of Quickshell.screens) liveNames[s.name] = true
            var changed = false
            var next = {}
            for (var key in root.detachedOverlays) {
                var entry = root.detachedOverlays[key]
                if (entry && liveNames[entry.screenName]) next[key] = entry
                else changed = true
            }
            if (changed) root.detachedOverlays = next
            if (root.dragActive && !liveNames[root.dragScreenName]) root.cancelDrag()
        }
    }

    function isValidMetric(metricId) {
        return validMetrics.indexOf(metricId) >= 0
    }

    function isDetached(metricId) {
        return !!detachedOverlays[metricId]
    }

    function overlayFor(metricId) {
        return detachedOverlays[metricId] || null
    }

    function overlaysForScreen(screenName) {
        if (!screenName) return []
        var list = []
        for (var i = 0; i < validMetrics.length; i++) {
            var id = validMetrics[i]
            var item = detachedOverlays[id]
            if (item && item.active && item.screenName === screenName) list.push(item)
        }
        return list
    }

    function otherOverlaysForScreen(screenName, excludeMetricId, pillSpec) {
        var pw = pillSpec && pillSpec.width > 0 ? pillSpec.width : 180
        var ph = pillSpec && pillSpec.height > 0 ? pillSpec.height : 46
        var items = overlaysForScreen(screenName)
        var result = []
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            if (excludeMetricId && item.metricId === excludeMetricId) continue
            result.push({
                metricId: item.metricId,
                x: item.x,
                y: item.y,
                width: pw,
                height: ph
            })
        }
        return result
    }

    function screenHasOverlayOrDrag(screenName) {
        if (!screenName) return false
        if (dragActive && dragScreenName === screenName) return true
        for (var key in detachedOverlays) {
            var entry = detachedOverlays[key]
            if (entry && entry.active && entry.screenName === screenName) return true
        }
        return false
    }

    function isDraggingFromMenuOnScreen(screenName) {
        return dragActive && dragOrigin === "menu" && dragScreenName === screenName
    }

    function isDraggingFromOverlayOnScreen(screenName) {
        return dragActive && dragOrigin === "overlay" && dragScreenName === screenName
    }

    function setActiveMetricIndex(index) {
        var count = carouselMetrics.length
        activeMetricIndex = ((index % count) + count) % count
    }

    function reorderLeftSlot(metricId, targetSlotIndex) {
        if (!isValidMetric(metricId)) return
        var next = GridGeometry.reorderSlots(leftSlotOrder, metricId, targetSlotIndex)
        var same = next.length === leftSlotOrder.length && next.every(function(v, idx) { return v === leftSlotOrder[idx] })
        if (!same) leftSlotOrder = next
    }

    function setMenuRect(screenName, open, x, y, width, height) {
        activeMenuRect = {
            screenName: screenName || "",
            open: !!open,
            x: x || 0,
            y: y || 0,
            width: Math.max(0, width || 0),
            height: Math.max(0, height || 0)
        }
    }

    function beginMenuDrag(metricId, screenName, pointerX, pointerY, pillWidth, pillHeight, grabOffsetX, grabOffsetY, initialSlot) {
        if (!isValidMetric(metricId) || !screenName || isDetached(metricId)) return false
        dragMetricId = metricId
        dragOrigin = "menu"
        dragScreenName = screenName
        dragPointerX = pointerX
        dragPointerY = pointerY
        dragPillWidth = pillWidth
        dragPillHeight = pillHeight
        dragGrabOffsetX = grabOffsetX
        dragGrabOffsetY = grabOffsetY
        dragOutsideMenu = false
        dragTargetX = pointerX - grabOffsetX
        dragTargetY = pointerY - grabOffsetY
        dragHoveredMenuSlot = initialSlot !== undefined ? initialSlot : leftSlotOrder.indexOf(metricId)
        dragActive = true
        return true
    }

    function beginOverlayDrag(metricId, screenName, pointerX, pointerY, pillWidth, pillHeight, grabOffsetX, grabOffsetY) {
        var existing = detachedOverlays[metricId]
        if (!existing || !screenName) return false
        dragMetricId = metricId
        dragOrigin = "overlay"
        dragScreenName = screenName
        dragPointerX = pointerX
        dragPointerY = pointerY
        dragPillWidth = pillWidth
        dragPillHeight = pillHeight
        dragGrabOffsetX = grabOffsetX
        dragGrabOffsetY = grabOffsetY
        dragOutsideMenu = true
        dragTargetX = existing.x
        dragTargetY = existing.y
        dragHoveredMenuSlot = -1
        dragActive = true
        return true
    }

    function updateDrag(pointerX, pointerY, outsideMenu, snappedPos, menuSlot) {
        if (!dragActive) return
        dragPointerX = pointerX
        dragPointerY = pointerY
        dragOutsideMenu = !!outsideMenu
        if (outsideMenu && snappedPos) {
            dragTargetX = snappedPos.x
            dragTargetY = snappedPos.y
            dragHoveredMenuSlot = -1
        } else {
            if (menuSlot !== undefined && menuSlot >= 0) {
                dragHoveredMenuSlot = menuSlot
                reorderLeftSlot(dragMetricId, menuSlot)
            }
        }
    }

    function _clearDragFields() {
        dragActive = false
        dragMetricId = ""
        dragOrigin = ""
        dragScreenName = ""
        dragOutsideMenu = false
        dragTargetX = 0
        dragTargetY = 0
        dragHoveredMenuSlot = -1
    }

    function commitMenuDrag() {
        if (!dragActive || dragOrigin !== "menu") return false
        var detached = false
        if (dragOutsideMenu && dragScreenName && Number.isFinite(dragTargetX) && Number.isFinite(dragTargetY)) {
            var next = Object.assign({}, detachedOverlays)
            next[dragMetricId] = {
                active: true,
                metricId: dragMetricId,
                screenName: dragScreenName,
                x: Math.round(dragTargetX),
                y: Math.round(dragTargetY)
            }
            detachedOverlays = next
            detached = true
        }
        _clearDragFields()
        return detached
    }

    function commitOverlayDrag() {
        if (!dragActive || dragOrigin !== "overlay") return false
        var existing = detachedOverlays[dragMetricId]
        if (existing && Number.isFinite(dragTargetX) && Number.isFinite(dragTargetY)) {
            var next = Object.assign({}, detachedOverlays)
            next[dragMetricId] = {
                active: true,
                metricId: existing.metricId,
                screenName: existing.screenName,
                x: Math.round(dragTargetX),
                y: Math.round(dragTargetY)
            }
            detachedOverlays = next
        }
        _clearDragFields()
        return true
    }

    function cancelDrag() {
        if (!dragActive) return
        _clearDragFields()
    }

    function dismissOverlay(metricId) {
        if (!detachedOverlays[metricId]) return false
        if (dragActive && dragMetricId === metricId) _clearDragFields()
        var next = Object.assign({}, detachedOverlays)
        delete next[metricId]
        detachedOverlays = next
        return true
    }

    function recallOverlayToSlot(metricId, targetSlotIndex) {
        if (!detachedOverlays[metricId]) return false
        dismissOverlay(metricId)
        if (targetSlotIndex !== undefined && targetSlotIndex >= 0 && targetSlotIndex < leftSlotOrder.length) {
            var fromIdx = leftSlotOrder.indexOf(metricId)
            if (fromIdx >= 0 && fromIdx !== targetSlotIndex) {
                var nextOrder = leftSlotOrder.slice()
                var displaced = nextOrder[targetSlotIndex]
                nextOrder[targetSlotIndex] = metricId
                nextOrder[fromIdx] = displaced
                leftSlotOrder = nextOrder
            }
        }
        return true
    }

    function resetAll() {
        _clearDragFields()
        detachedOverlays = ({})
        leftSlotOrder = ["cpu", "gpu", "ram"]
        activeMetricIndex = 0
    }
}
