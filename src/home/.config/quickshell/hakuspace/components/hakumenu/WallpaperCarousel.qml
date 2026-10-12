import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../../services"
import "../motion" as Motion

Item {
    id: root

    property var staticItems: []
    property var livelyItems: []
    property string loadError: ""
    property bool modelLoaded: false

    // W8/W12 keeps Static and Lively as distinct carousel modes. Both backend
    // models remain cached, and each mode remembers its own navigation index.
    property string activeKind: "static"
    property int staticSelectedIndex: -1
    property int livelySelectedIndex: -1
    property bool staticWarm: false
    property bool livelyWarm: false

    // W12.2 Search filter state
    property string searchQuery: ""
    property var visibleSourceIndices: []
    property int selectedVisiblePos: -1

    // W12.8 / W12.8.1 Single Motion Clock Architecture:
    // Only visualPosition is animated. targetVirtualIndex is the logical destination.
    property int targetVirtualIndex: 0
    property real visualPosition: 0.0
    property int lastRecycledCenter: 0
    property bool positionAnimationEnabled: true
    readonly property int maxTargetLead: 4

    readonly property var items: activeKind === "lively" ? livelyItems : staticItems
    readonly property int selectedIndex: activeKind === "lively" ? livelySelectedIndex : staticSelectedIndex
    readonly property var centerItem: recordForKindAt(activeKind, selectedIndex)
    readonly property real slotAspect: 16 / 9
    readonly property real headerHeight: Math.max(40, Theme.fontSize * 2.7)
    readonly property real headerSpacing: Theme.pad * 1.4 + 20
    readonly property real deckCenterY: root.height / 2 + (headerHeight + headerSpacing) / 2
    readonly property real maxSlotWidth: Math.max(0, width - Theme.pad * 4)
    readonly property real maxSlotHeight: Math.max(0, height - headerHeight - headerSpacing - Theme.pad * 4)
    readonly property real slotWidth: Math.min(maxSlotWidth, maxSlotHeight * slotAspect)
    readonly property real slotHeight: slotWidth / slotAspect
    readonly property Item modeSwitchHitRegion: headerControls
    readonly property bool searchFocused: searchInput.activeFocus

    // W12.4 / W12.8 Bounded delegate window. Max 11 active preview records total.
    readonly property int sideDepth: 3
    readonly property int prefetchDepth: sideDepth + 2
    readonly property int maxActivePreviews: 1 + prefetchDepth * 2
    readonly property real decodeOverscan: 1.12
    readonly property real sideScaleBase: 0.78
    readonly property real sideScaleStep: 0.09
    readonly property real sideOffsetBase: slotWidth * 0.44
    readonly property real sideOffsetStep: slotWidth * 0.22
    readonly property real sideOffsetOuterExtra: slotWidth * 0.06

    // Motion state & timing
    property string openPhase: "idle"   // idle | waiting | opening | ready | closing
    property real openOpacity: 1.0
    property real reelProgress: 1.0
    property real heroRevealProgress: 1.0
    property int navigationDirection: 0
    property bool navigationMotionActive: false
    property real closeGatherProgress: 0.0
    property real closeZoomProgress: 0.0
    property real closeOpacity: 1.0

    signal closeAnimationFinished()
    signal applyAccepted()
    signal requestFocusCarousel()

    function focusSearch() {
        searchInput.forceActiveFocus()
    }

    readonly property bool closing: openPhase === "closing"
    readonly property bool interactionReady: visible && openPhase === "ready"

    readonly property int navigationDuration: 145
    readonly property int closeGatherDuration: 200
    readonly property int closeZoomDuration: 260
    readonly property int openingDuration: 320
    readonly property int heroRevealDuration: 280
    readonly property real openingTravel: slotWidth * 1.35
    readonly property real reelScale: 0.62
    readonly property real reelSpacing: slotWidth * 0.34
    readonly property real reelSettleStart: 0.68

    // Single animation driver for visualPosition (W12.8.1 target-following Behavior)
    Behavior on visualPosition {
        enabled: root.positionAnimationEnabled && root.openPhase === "ready"
        SmoothedAnimation {
            id: positionSmoothedAnim
            velocity: -1
            duration: root.navigationDuration
            maximumEasingTime: 50
            reversingMode: SmoothedAnimation.Eased
            onRunningChanged: {
                if (running) {
                    root.navigationMotionActive = true
                    motionSettleTimer.stop()
                } else {
                    motionSettleTimer.restart()
                }
            }
        }
    }

    Timer {
        id: motionSettleTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (!positionSmoothedAnim.running || Math.abs(root.visualPosition - root.targetVirtualIndex) < 0.005) {
                if (root.visualPosition !== root.targetVirtualIndex) {
                    root.positionAnimationEnabled = false
                    root.visualPosition = root.targetVirtualIndex
                    root.positionAnimationEnabled = true
                }
                root.navigationMotionActive = false
                root.navigationDirection = 0
            } else {
                motionSettleTimer.restart()
            }
        }
    }

    // Paced ring recycling: as visualPosition crosses an integer boundary,
    // recycle only the card that has fallen off the trailing edge.
    onVisualPositionChanged: {
        var newCenter = Math.round(visualPosition)
        if (newCenter !== lastRecycledCenter) {
            lastRecycledCenter = newCenter
            recycleSlotWindow(newCenter)
        }
    }

    // Header controls bounce impulse when scrolling
    property real headerBounceY: 0.0
    property real headerBounceScale: 1.0

    function triggerHeaderBounce() {
        if (!interactionReady) return
        headerBounceAnim.restart()
    }

    SequentialAnimation {
        id: headerBounceAnim

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "headerBounceY"
                from: root.headerBounceY
                to: -4.2
                duration: 75
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "headerBounceScale"
                from: root.headerBounceScale
                to: 1.026
                duration: 75
                easing.type: Easing.OutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "headerBounceY"
                to: 1.4
                duration: 85
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: root
                property: "headerBounceScale"
                to: 0.994
                duration: 85
                easing.type: Easing.InOutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "headerBounceY"
                to: 0.0
                duration: 90
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "headerBounceScale"
                to: 1.0
                duration: 90
                easing.type: Easing.OutCubic
            }
        }
    }

    function exactBackendSelectedIndex(records) {
        if (!records) return -1
        for (var i = 0; i < records.length; ++i) {
            if (records[i] && records[i].selected)
                return i
        }
        return -1
    }

    function seededIndex(records) {
        if (!records || records.length === 0) return -1
        var backendIndex = exactBackendSelectedIndex(records)
        return backendIndex >= 0 ? backendIndex : 0
    }

    function resetSelectionsFromBackend() {
        staticSelectedIndex = seededIndex(staticItems)
        livelySelectedIndex = seededIndex(livelyItems)

        var staticCurrent = exactBackendSelectedIndex(staticItems)
        var livelyCurrent = exactBackendSelectedIndex(livelyItems)
        if (livelyCurrent >= 0)
            activeKind = "lively"
        else if (staticCurrent >= 0 || staticItems.length > 0)
            activeKind = "static"
        else if (livelyItems.length > 0)
            activeKind = "lively"

        warmKind(activeKind)
        updateVisibleIndices(true)
    }

    function warmKind(kind) {
        if (kind === "lively") livelyWarm = true
        else staticWarm = true
    }

    function switchKind(kind) {
        if (!interactionReady) return
        if (kind !== "static" && kind !== "lively") return
        if (kind === activeKind) {
            warmKind(kind)
            return
        }

        activeKind = kind
        if (kind === "static" && staticSelectedIndex < 0 && staticItems.length > 0)
            staticSelectedIndex = 0
        if (kind === "lively" && livelySelectedIndex < 0 && livelyItems.length > 0)
            livelySelectedIndex = 0
        warmKind(kind)
        updateVisibleIndices(true)
    }

    function setActiveSelectedIndex(index) {
        if (activeKind === "lively") livelySelectedIndex = index
        else staticSelectedIndex = index
    }

    function setSearchQuery(query) {
        searchQuery = query || ""
        updateVisibleIndices(true)
    }

    function clearSearch() {
        searchQuery = ""
        if (searchInput.text.length > 0)
            searchInput.text = ""
        searchInput.focus = false
        updateVisibleIndices(true)
    }

    function updateVisibleIndices(resetDeck) {
        var raw = activeKind === "lively" ? livelyItems : staticItems
        var q = (searchQuery || "").trim().toLowerCase()
        var matches = []
        if (raw && Array.isArray(raw)) {
            for (var i = 0; i < raw.length; ++i) {
                var rec = raw[i]
                if (!rec) continue
                if (q.length === 0) {
                    matches.push(i)
                } else {
                    var label = (rec.label || rec.id || "").toLowerCase()
                    if (label.indexOf(q) !== -1) {
                        matches.push(i)
                    }
                }
            }
        }
        visibleSourceIndices = matches

        var currSrcIdx = activeKind === "lively" ? livelySelectedIndex : staticSelectedIndex
        var pos = matches.indexOf(currSrcIdx)
        if (pos >= 0) {
            selectedVisiblePos = pos
        } else if (matches.length > 0) {
            selectedVisiblePos = 0
            setActiveSelectedIndex(matches[0])
        } else {
            selectedVisiblePos = -1
            setActiveSelectedIndex(-1)
        }

        if (resetDeck) {
            snapVisualPosition(Math.max(0, selectedVisiblePos))
        }
    }

    // Explicit snap/bypass path for initialization, search reset, and mode switching
    function snapVisualPosition(target) {
        positionAnimationEnabled = false
        targetVirtualIndex = target
        lastRecycledCenter = target
        visualPosition = target
        navigationMotionActive = false
        navigationDirection = 0
        motionSettleTimer.stop()
        initSlotWindow(target)
        positionAnimationEnabled = true
    }

    function getValidOffsetRange(N) {
        if (N <= 0) return { minK: 0, maxK: -1, count: 0 }
        var minK = -Math.min(root.prefetchDepth, Math.floor((N - 1) / 2))
        var maxK = Math.min(root.prefetchDepth, Math.floor(N / 2))
        return { minK: minK, maxK: maxK, count: maxK - minK + 1 }
    }

    // Initial setup of 11 slots around centerV without animating
    function initSlotWindow(centerV) {
        var N = visibleSourceIndices.length
        var range = getValidOffsetRange(N)
        var raw = activeKind === "lively" ? livelyItems : staticItems
        for (var i = 0; i < 11; ++i) {
            var slot = cardRepeater.itemAt(i)
            if (!slot) continue
            if (i < range.count && N > 0) {
                var v = centerV + range.minK + i
                var srcIdx = visibleSourceIndices[((v % N) + N) % N]
                var rec = raw && srcIdx >= 0 && srcIdx < raw.length ? raw[srcIdx] : null

                slot.virtualIndex = v
                slot.sourceIndex = srcIdx
                slot.record = rec
                slot.active = true
            } else {
                slot.active = false
                slot.record = null
                slot.virtualIndex = 999999
                slot.sourceIndex = -1
            }
        }
    }

    // Paced recycling: only recycle slots outside the window around centerV
    function recycleSlotWindow(centerV) {
        var N = visibleSourceIndices.length
        if (N <= 0) return
        var range = getValidOffsetRange(N)
        var raw = activeKind === "lively" ? livelyItems : staticItems

        var desiredMap = {}
        for (var k = range.minK; k <= range.maxK; ++k) {
            desiredMap[centerV + k] = true
        }

        var extraSlots = []
        var assignedMap = {}
        for (var i = 0; i < 11; ++i) {
            var slot = cardRepeater.itemAt(i)
            if (!slot || !slot.active) continue
            if (desiredMap[slot.virtualIndex]) {
                assignedMap[slot.virtualIndex] = true
            } else {
                extraSlots.push(slot)
            }
        }

        var missingV = []
        for (var k2 = range.minK; k2 <= range.maxK; ++k2) {
            var targetV = centerV + k2
            if (!assignedMap[targetV]) {
                missingV.push(targetV)
            }
        }

        for (var m = 0; m < missingV.length && m < extraSlots.length; ++m) {
            var recycledSlot = extraSlots[m]
            var v = missingV[m]
            var srcIdx = visibleSourceIndices[((v % N) + N) % N]
            var rec = raw && srcIdx >= 0 && srcIdx < raw.length ? raw[srcIdx] : null

            recycledSlot.virtualIndex = v
            recycledSlot.sourceIndex = srcIdx
            recycledSlot.record = rec
            recycledSlot.active = true
        }
    }

    // Input pipeline: advance targetVirtualIndex, retarget the single visualPosition animation
    function moveSelection(step) {
        if (!interactionReady || visibleSourceIndices.length <= 1 || step === 0) return
        var N = visibleSourceIndices.length

        // Trigger tactile bounce on header controls
        triggerHeaderBounce()

        // Retarget destination with lead bounding
        var nextTarget = targetVirtualIndex + step
        if (nextTarget > visualPosition + maxTargetLead)
            nextTarget = Math.round(visualPosition) + maxTargetLead
        else if (nextTarget < visualPosition - maxTargetLead)
            nextTarget = Math.round(visualPosition) - maxTargetLead

        targetVirtualIndex = nextTarget
        navigationDirection = step > 0 ? 1 : -1

        // Update logical selected position immediately
        selectedVisiblePos = ((targetVirtualIndex % N) + N) % N
        setActiveSelectedIndex(visibleSourceIndices[selectedVisiblePos])

        // Retarget single motion driver smoothly without restart()
        root.navigationMotionActive = true
        motionSettleTimer.stop()
        visualPosition = targetVirtualIndex
    }

    function selectPrevious() {
        moveSelection(-1)
    }

    function selectNext() {
        moveSelection(1)
    }

    function applySelected() {
        if (!interactionReady || applyProcess.running || centerItem === null) return false

        var command = centerItem.kind === "lively" ? "apply-lively" : "apply-static"
        var target = centerItem.path || centerItem.id || ""
        if (target.length === 0) return false

        applyProcess.errorOutput = ""
        applyProcess.command = [Env.binDir + "/wallpaper_ctl.sh", command, target]
        applyProcess.running = true
        return true
    }

    function acceptSelected() {
        if (!applySelected()) return false
        applyAccepted()
        return true
    }

    function recordForKindAt(kind, index) {
        var records = kind === "lively" ? livelyItems : staticItems
        return records && index >= 0 && index < records.length ? records[index] : null
    }

    function fileUrl(path) {
        if (!path || path.length === 0 || path[0] !== "/") return ""
        return "file://" + path
    }

    function refresh(force) {
        if (!force && modelLoaded) return
        loadError = ""
        staticSelectedIndex = -1
        livelySelectedIndex = -1
        staticWarm = false
        livelyWarm = false
        modelLoaded = false
        staticProcess.running = false
        livelyProcess.running = false
        staticProcess.command = [Env.binDir + "/wallpaper_ctl.sh", "list-static", "--json"]
        staticProcess.running = true
    }

    function beginOpenAnimation() {
        if (!visible) return
        closeSequence.stop()
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        if (!modelLoaded) {
            openSequence.stop()
            openPhase = "waiting"
            openOpacity = 0.0
            reelProgress = 0.0
            heroRevealProgress = 0.0
            return
        }

        navigationMotionActive = false
        navigationDirection = 0
        openSequence.stop()
        openPhase = "opening"
        openOpacity = 0.0
        reelProgress = 0.0
        heroRevealProgress = 0.0
        snapVisualPosition(Math.max(0, selectedVisiblePos))
        openSequence.start()
    }

    function beginCloseAnimation() {
        if (!visible || closing) return
        openSequence.stop()
        motionSettleTimer.stop()
        headerBounceAnim.stop()
        headerBounceY = 0.0
        headerBounceScale = 1.0
        navigationMotionActive = false
        navigationDirection = 0
        positionAnimationEnabled = false
        visualPosition = targetVirtualIndex
        lastRecycledCenter = targetVirtualIndex
        positionAnimationEnabled = true
        closeSequence.stop()

        openOpacity = Math.max(openOpacity, 0.001)
        reelProgress = 1.0
        heroRevealProgress = 1.0
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        openPhase = "closing"
        closeSequence.start()
    }

    function cancelCloseAnimation() {
        if (!closing) return
        closeSequence.stop()
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        openOpacity = 1.0
        reelProgress = 1.0
        heroRevealProgress = 1.0
        openPhase = "ready"
    }

    function resetOpenAnimation() {
        openSequence.stop()
        closeSequence.stop()
        motionSettleTimer.stop()
        headerBounceAnim.stop()
        headerBounceY = 0.0
        headerBounceScale = 1.0
        wheelDecayTimer.stop()
        wheelAccumulator = 0
        touchAccumulator = 0
        navigationMotionActive = false
        navigationDirection = 0
        openPhase = "idle"
        openOpacity = 1.0
        reelProgress = 1.0
        heroRevealProgress = 1.0
        closeGatherProgress = 0.0
        closeZoomProgress = 0.0
        closeOpacity = 1.0
        clearSearch()
    }

    function parseRecords(data, kind) {
        var line = (data || "").trim()
        if (line.length === 0) return []
        try {
            var parsed = JSON.parse(line)
            return Array.isArray(parsed) ? parsed : []
        } catch (e) {
            loadError = "Unable to read " + kind + " wallpapers"
            return []
        }
    }

    opacity: openOpacity * closeOpacity
    scale: closing ? (1.0 - closeZoomProgress * 0.28) : 1.0
    transformOrigin: Item.Center

    onVisibleChanged: {
        if (visible) {
            if (!modelLoaded) {
                beginOpenAnimation()
                refresh(false)
            } else {
                beginOpenAnimation()
            }
        } else {
            resetOpenAnimation()
        }
    }

    Component.onCompleted: {
        if (visible) {
            if (!modelLoaded) {
                beginOpenAnimation()
                refresh(false)
            } else {
                beginOpenAnimation()
            }
        }
    }

    ParallelAnimation {
        id: openSequence

        NumberAnimation {
            target: root
            property: "openOpacity"
            from: 0.0
            to: 1.0
            duration: 220
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "reelProgress"
            from: 0.0
            to: 1.0
            duration: root.openingDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "heroRevealProgress"
            from: 0.0
            to: 1.0
            duration: root.heroRevealDuration
            easing.type: Easing.OutQuart
        }

        onFinished: {
            root.openOpacity = 1.0
            root.reelProgress = 1.0
            root.heroRevealProgress = 1.0
            root.openPhase = "ready"
        }
    }

    SequentialAnimation {
        id: closeSequence

        NumberAnimation {
            target: root
            property: "closeGatherProgress"
            from: 0.0
            to: 1.0
            duration: root.closeGatherDuration
            easing.type: Easing.InOutCubic
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "closeZoomProgress"
                from: 0.0
                to: 1.0
                duration: root.closeZoomDuration
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "closeOpacity"
                from: 1.0
                to: 0.0
                duration: root.closeZoomDuration
                easing.type: Easing.InQuad
            }
        }

        onFinished: {
            root.closeGatherProgress = 1.0
            root.closeZoomProgress = 1.0
            root.closeOpacity = 0.0
            root.closeAnimationFinished()
        }
    }

    Process {
        id: staticProcess
        property string output: ""

        stdout: SplitParser {
            onRead: data => staticProcess.output += data
        }

        onRunningChanged: {
            if (running) output = ""
        }

        onExited: exitCode => {
            root.staticItems = exitCode === 0 ? root.parseRecords(output, "static") : []
            if (exitCode !== 0) root.loadError = "Unable to list static wallpapers"
            livelyProcess.command = [Env.binDir + "/wallpaper_ctl.sh", "list-lively", "--json"]
            livelyProcess.running = true
        }
    }

    Process {
        id: livelyProcess
        property string output: ""

        stdout: SplitParser {
            onRead: data => livelyProcess.output += data
        }

        onRunningChanged: {
            if (running) output = ""
        }

        onExited: exitCode => {
            root.livelyItems = exitCode === 0 ? root.parseRecords(output, "lively") : []
            if (exitCode !== 0 && root.loadError.length === 0)
                root.loadError = "Unable to list lively wallpapers"
            root.resetSelectionsFromBackend()
            root.modelLoaded = true
            if (root.visible) root.beginOpenAnimation()
        }
    }

    Process {
        id: applyProcess
        property string errorOutput: ""

        stderr: SplitParser {
            onRead: data => applyProcess.errorOutput += data
        }

        onRunningChanged: {
            if (running) errorOutput = ""
        }

        onExited: exitCode => {
            if (exitCode === 0) return
            var message = errorOutput.trim()
            console.warn("Wallpaper apply failed" + (message.length > 0 ? ": " + message : ""))
        }
    }

    // W12.8 Low-latency input pipeline: directly increments targetVirtualIndex
    property real wheelAccumulator: 0
    property real touchAccumulator: 0

    Timer {
        id: wheelDecayTimer
        interval: 180
        repeat: false
        onTriggered: {
            root.wheelAccumulator = 0
            root.touchAccumulator = 0
        }
    }

    WheelHandler {
        id: wheelNavigation
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!root.interactionReady) {
                event.accepted = true
                return
            }
            wheelDecayTimer.restart()

            var isTouchPad = event.device && (event.device.pointerType === PointerDevice.TouchPad
                             || (event.pixelDelta && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0)))

            if (isTouchPad && event.pixelDelta && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0)) {
                var pDelta = Math.abs(event.pixelDelta.y) >= Math.abs(event.pixelDelta.x)
                             ? event.pixelDelta.y
                             : event.pixelDelta.x
                root.touchAccumulator += pDelta
                var threshold = 45
                if (Math.abs(root.touchAccumulator) >= threshold) {
                    var tSteps = Math.trunc(root.touchAccumulator / threshold)
                    root.touchAccumulator -= tSteps * threshold
                    root.moveSelection(-tSteps)
                }
            } else {
                var aDelta = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x)
                             ? event.angleDelta.y
                             : event.angleDelta.x
                if (aDelta !== 0) {
                    root.wheelAccumulator += aDelta
                    var notch = 120
                    if (Math.abs(root.wheelAccumulator) >= notch) {
                        var wSteps = Math.trunc(root.wheelAccumulator / notch)
                        root.wheelAccumulator -= wSteps * notch
                        root.moveSelection(-wSteps)
                    }
                }
            }
            event.accepted = true
        }
    }

    // Background click absorber so clicks inside carousel do not leak to outside dismiss
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        onClicked: {}
    }

    Component {
        id: wallpaperCardDelegate

        Item {
            id: card

            required property int index

            property int virtualIndex: 999999
            property int sourceIndex: -1
            property var record: null
            property bool active: false

            readonly property string deckKind: record && record.kind === "lively" ? "lively" : "static"
            readonly property real relPos: card.virtualIndex - root.visualPosition
            readonly property real absDist: Math.abs(relPos)
            readonly property int sign: relPos < 0 ? -1 : (relPos > 0 ? 1 : 0)
            readonly property bool isCenter: absDist < 0.5
            readonly property string previewPath: record ? (record.thumbnail || record.path || "") : ""

            // Continuous Scale: 1.0 at center, sloping to sideScaleBase at dist 1.0, then sideScaleStep
            readonly property real calcScale: absDist <= 1.0
                ? 1.0 - absDist * (1.0 - root.sideScaleBase)
                : Math.max(0.40, root.sideScaleBase - (absDist - 1.0) * root.sideScaleStep)

            // Continuous Horizontal Offset (shifts outer layer outward so the last layer is nicely revealed)
            readonly property real distX: absDist <= 1.0
                ? absDist * root.sideOffsetBase
                : root.sideOffsetBase
                  + (absDist - 1.0) * root.sideOffsetStep
                  + Math.max(0.0, absDist - 1.8) * root.sideOffsetOuterExtra
            readonly property real calcTx: sign * distX

            // Continuous Vertical Offset
            readonly property real calcTy: absDist * Theme.gap * 0.35

            // Continuous Opacity: fades beyond sideDepth
            readonly property real calcOpacity: absDist <= 1.0
                ? 1.0 - absDist * (1.0 - 0.88)
                : (absDist <= root.sideDepth
                    ? Math.max(0.46, 0.88 - (absDist - 1.0) * 0.12)
                    : Math.max(0.0, Math.min(0.46, 0.46 * (1.0 - (absDist - root.sideDepth) / 0.75))))

            // Opening reel calculations
            readonly property real reelScrollProgress: root.openPhase === "opening"
                ? Math.min(1.0, root.reelProgress / root.reelSettleStart)
                : 1.0
            readonly property real reelSettleProgress: root.openPhase === "opening"
                ? Math.max(0.0, Math.min(1.0, (root.reelProgress - root.reelSettleStart) / (1.0 - root.reelSettleStart)))
                : 1.0
            readonly property real reelTravelX: relPos * root.reelSpacing + (1.0 - reelScrollProgress) * root.openingTravel

            // Closing gather calculations
            readonly property real closeGatherFactor: root.closing ? (1.0 - root.closeGatherProgress * 0.74) : 1.0
            readonly property real closeScaleFactor: root.closing ? (1.0 - root.closeGatherProgress * 0.08) : 1.0

            // Final Composite Transforms
            readonly property real finalTx: root.closing
                ? calcTx * closeGatherFactor
                : (root.openPhase === "opening" && !isCenter
                    ? reelTravelX + (calcTx - reelTravelX) * reelSettleProgress
                    : calcTx)

            readonly property real finalTy: root.closing
                ? calcTy * closeGatherFactor
                : (root.openPhase === "opening" && !isCenter
                    ? calcTy * reelSettleProgress
                    : calcTy)

            readonly property real finalScale: root.closing
                ? calcScale * closeScaleFactor
                : (root.openPhase === "opening" && !isCenter
                    ? root.reelScale + (calcScale - root.reelScale) * reelSettleProgress
                    : calcScale)

            readonly property real finalOpacity: root.closing
                ? calcOpacity * root.closeOpacity
                : (root.openPhase === "opening" && !isCenter
                    ? Math.min(calcOpacity, 0.30 + reelScrollProgress * 0.58)
                    : calcOpacity)

            readonly property bool heroRevealActive: isCenter
                && root.openPhase === "opening"
                && root.heroRevealProgress < 0.999
            readonly property real heroRevealDiameter: Math.sqrt(width * width + height * height)
                * root.heroRevealProgress

            // Fixed Geometry (No dynamic resize during navigation!)
            width: root.slotWidth
            height: root.slotHeight
            x: (root.width - root.slotWidth) / 2
            y: root.deckCenterY - root.slotHeight / 2
            z: absDist < 0.5 ? 100 : Math.max(0, Math.round(50 - absDist * 10))
            visible: active && record !== null && absDist <= (root.sideDepth + 1.2)
            opacity: finalOpacity
            transformOrigin: Item.Center

            transform: [
                Translate {
                    x: card.finalTx
                    y: card.finalTy
                },
                Scale {
                    origin.x: card.width / 2
                    origin.y: card.height / 2
                    xScale: card.finalScale
                    yScale: card.finalScale
                }
            ]

            Rectangle {
                id: shadowCaster
                anchors.fill: parent
                color: "#ff000000"
                radius: 0
                visible: false
            }

            MultiEffect {
                anchors.fill: shadowCaster
                source: shadowCaster
                autoPaddingEnabled: true
                shadowEnabled: !card.isCenter
                shadowColor: "#ff000000"
                shadowOpacity: card.isCenter ? 0.0 : Math.max(0.12, 0.22 - (card.absDist - 1) * 0.03)
                shadowBlur: 0.40
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 6
                shadowScale: 1.0
                blurMax: 32
                visible: root.openPhase === "ready"
                         && !root.navigationMotionActive
                         && !card.isCenter
            }

            Rectangle {
                id: cardSurface
                anchors.fill: parent
                radius: 0
                visible: !card.heroRevealActive
                color: Theme.surface
                border.width: 0
                clip: true

                Image {
                    id: preview
                    anchors.fill: parent
                    source: card.active && card.record ? root.fileUrl(card.previewPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize: Qt.size(
                        Math.max(1, Math.ceil(root.slotWidth * root.decodeOverscan)),
                        Math.max(1, Math.ceil(root.slotHeight * root.decodeOverscan))
                    )
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#24000000"
                    visible: !card.isCenter
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(Theme.fontSize * 2.2, Theme.pad * 2.2)
                    color: "#b0000000"
                    visible: card.isCenter && card.record !== null

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.pad
                        anchors.right: kindLabel.left
                        anchors.rightMargin: Theme.gap
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.record ? card.record.label : ""
                        color: Theme.fg
                        elide: Text.ElideMiddle
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                    }

                    Text {
                        id: kindLabel
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.pad
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.record ? (card.deckKind === "lively" ? "󰕧" : "󰋩") : ""
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                    }
                }
            }

            Item {
                id: heroMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(1, card.heroRevealDiameter)
                    height: width
                    radius: width / 2
                    color: "white"
                }
            }

            MultiEffect {
                id: heroRevealEffect
                anchors.fill: cardSurface
                source: cardSurface
                visible: card.heroRevealActive
                maskEnabled: true
                maskSource: heroMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.025
                maskThresholdMax: 1.0
                maskSpreadAtMax: 0.0
            }

            MouseArea {
                anchors.fill: parent
                z: 500
                enabled: root.interactionReady && card.active && card.record !== null
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (card.absDist < 0.5) {
                        root.acceptSelected()
                    } else {
                        var step = Math.round(card.relPos)
                        if (step === 0) step = (card.relPos > 0 ? 1 : -1)
                        root.moveSelection(step)
                    }
                }
            }
        }
    }

    // Bounded delegate pool of 11 items.
    Repeater {
        id: cardRepeater
        model: 11
        delegate: wallpaperCardDelegate
        Component.onCompleted: {
            root.initSlotWindow(root.targetVirtualIndex)
        }
    }

    // Top Controls: Mode Switcher (Static/Lively) + Search Box
    Item {
        id: headerControls
        z: 300
        readonly property real trackWidth: Math.max(190, Theme.fontSize * 13)
        readonly property real searchWidth: Math.max(230, Theme.fontSize * 15)
        readonly property real spacing: Theme.gap * 2

        width: trackWidth + spacing + searchWidth
        height: root.headerHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(Theme.pad, root.deckCenterY - root.slotHeight / 2 - height - root.headerSpacing)
        opacity: root.closing ? Math.max(0.0, 1.0 - root.closeGatherProgress * 1.4) : 1.0
        scale: root.closing ? Math.max(0.72, 1.0 - root.closeGatherProgress * 0.22) : 1.0
        transformOrigin: Item.Center

        transform: [
            Translate {
                y: root.headerBounceY
            },
            Scale {
                origin.x: headerControls.width / 2
                origin.y: headerControls.height / 2
                xScale: root.headerBounceScale
                yScale: root.headerBounceScale
            }
        ]

        // Mode Switcher (Static / Lively) using SelectionPill + MorphButton
        Rectangle {
            id: modeSwitcher
            width: headerControls.trackWidth
            height: headerControls.height
            radius: Theme.largeRadius
            color: "#b8000000"

            readonly property var modes: [
                { key: "static", label: "Static" },
                { key: "lively", label: "Lively" }
            ]
            readonly property int selectedIndex: root.activeKind === "lively" ? 1 : 0

            Item {
                id: tabLane
                anchors.fill: parent
                anchors.margins: Theme.gap
                readonly property real spacing: Theme.gap
                readonly property real slotWidth: (width - spacing) / 2

                Motion.SelectionPill {
                    z: 0
                    shown: modeSwitcher.selectedIndex >= 0
                    targetIndex: modeSwitcher.selectedIndex
                    slotCount: modeSwitcher.modes.length
                    slotSpacing: tabLane.spacing
                }

                Repeater {
                    model: modeSwitcher.modes

                    Motion.MorphButton {
                        required property var modelData
                        required property int index
                        z: 1
                        x: index * (tabLane.slotWidth + tabLane.spacing)
                        width: tabLane.slotWidth
                        height: tabLane.height
                        radius: Theme.radius
                        selected: root.activeKind === modelData.key
                        selectedOverridesHover: true
                        idleColor: "transparent"
                        hoverColor: "#22ffffff"
                        pressedColor: "#33ffffff"
                        selectedColor: "transparent"
                        foregroundColor: Theme.fg
                        hoverForegroundColor: Theme.fg
                        pressedForegroundColor: Theme.fg
                        selectedForegroundColor: Theme.onAccentColor
                        hoverScaleDelta: 0.004
                        pressScaleDelta: 0.018
                        text: modelData.label
                        fontSize: Theme.fontSize + 1
                        onClicked: root.switchKind(modelData.key)
                    }
                }
            }
        }

        // Search Box using MorphButton + TextInput
        Motion.MorphButton {
            id: searchBox
            x: modeSwitcher.width + headerControls.spacing
            width: headerControls.searchWidth
            height: headerControls.height
            radius: Theme.largeRadius
            interactive: false
            externalHovered: searchHover.hovered
            focused: searchInput.activeFocus
            idleColor: "#b8000000"
            hoverColor: "#cc000000"
            focusColor: "#cc000000"
            foregroundColor: Theme.fg
            hoverForegroundColor: Theme.fg
            focusForegroundColor: Theme.fg
            hoverScaleDelta: 0
            pressScaleDelta: 0

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.pad * 1.5
                anchors.verticalCenter: parent.verticalCenter
                text: "Search wallpaper…"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                visible: searchInput.text.length === 0
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: Theme.pad * 1.5
                anchors.rightMargin: Theme.pad * 1.5
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccentColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                clip: true
                focus: false
                text: root.searchQuery
                onTextEdited: root.setSearchQuery(text)

                Keys.onEscapePressed: event => {
                    UiState.closeWallpaper()
                    event.accepted = true
                }
                Keys.onTabPressed: event => {
                    searchInput.focus = false
                    root.requestFocusCarousel()
                    event.accepted = true
                }
                Keys.onDownPressed: event => {
                    root.selectNext()
                    event.accepted = true
                }
                Keys.onUpPressed: event => {
                    root.selectPrevious()
                    event.accepted = true
                }
                Keys.onReturnPressed: event => {
                    searchInput.focus = false
                    root.requestFocusCarousel()
                    event.accepted = true
                }
                Keys.onEnterPressed: event => {
                    searchInput.focus = false
                    root.requestFocusCarousel()
                    event.accepted = true
                }
                Keys.onLeftPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        root.switchKind("static")
                        event.accepted = true
                    }
                }
                Keys.onRightPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        root.switchKind("lively")
                        event.accepted = true
                    }
                }
            }

            HoverHandler {
                id: searchHover
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.deckCenterY - height / 2
        z: 200
        visible: root.visibleSourceIndices.length === 0
        text: root.loadError.length > 0
              ? root.loadError
              : (root.searchQuery.trim().length > 0
                 ? "No wallpapers match “" + root.searchQuery.trim() + "”"
                 : (root.activeKind === "lively" ? "No lively wallpapers" : "No static wallpapers"))
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
    }
}
