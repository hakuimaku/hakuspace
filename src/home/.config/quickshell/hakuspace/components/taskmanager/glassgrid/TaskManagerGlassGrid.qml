import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../services"
import "TaskManagerMotion.js" as Motion

FocusScope {
    id: root

    // Reuse two focus cards across metric changes.
    property string focusedMetric: "memory"
    property string currentFocusMetric: "memory"
    property string incomingMetric: ""
    property string pendingMetric: ""

    // Keep aliases used by lifecycle probes.
    readonly property alias displayMetric: root.currentFocusMetric
    property string morphFromMetric: "memory"
    property string morphToMetric: "memory"

    property int frontCardIndex: 0  // 0 -> focusCardA, 1 -> focusCardB
    readonly property int backCardIndex: frontCardIndex === 0 ? 1 : 0
    property real focusMorphProgress: 1.0
    property bool _manualMorphActive: false
    property bool _suppressFocusSignal: false
    readonly property bool transitionActive: focusMorphAnim.running || root._manualMorphActive
    readonly property alias focusMorphActive: root.transitionActive

    property rect incomingStartRect: Qt.rect(0, 0, 140, 92)
    property rect incomingTargetRect: Qt.rect(0, 0, 298, 160)
    readonly property alias morphFocusRect: root.focusSlotRect

    readonly property var frontFocusCard: frontCardIndex === 0 ? focusCardA : focusCardB
    readonly property var backFocusCard: frontCardIndex === 0 ? focusCardB : focusCardA
    readonly property alias focusCard: root.frontFocusCard
    readonly property alias incomingCard: root.backFocusCard
    readonly property alias incomingMorphCard: root.incomingCard

    property string interfaceName: ""
    property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    property real sharedWaterWavePhase: 0.0
    NumberAnimation on sharedWaterWavePhase {
        from: 0.0
        to: Math.PI * 2
        duration: 3400
        loops: Animation.Infinite
        running: !root.reducedMotion && root.visible
    }

    // Telemetry inputs default to TaskManagerService, overridable by standalone style harnesses.
    property var cpuData: TaskManagerService.cpu
    property var memoryData: TaskManagerService.memory
    property var gpusData: TaskManagerService.gpus
    property var disksData: TaskManagerService.disks
    property var networkData: TaskManagerService.network
    property var processesData: TaskManagerService.processes
    property var historyData: TaskManagerService.history
    property bool serviceReady: TaskManagerService.ready
    property bool warmingUp: TaskManagerService.warmingUp
    property string statusError: TaskManagerService.error
    property string actionError: TaskManagerService.actionError
    property string actionStatus: TaskManagerService.actionStatus
    property bool actionBusy: TaskManagerService.actionBusy

    // Process table state exposed for existing lifecycle/input contracts.
    property alias query: processPane.query
    property alias sortKey: processPane.sortKey
    property alias descending: processPane.descending
    readonly property alias rows: processPane.rows
    property alias selectedKey: processPane.selectedKey
    readonly property alias selectedProcess: processPane.selectedProcess
    property alias detailsOpen: processPane.detailsOpen
    property alias killKey: processPane.killKey
    readonly property alias selectedIndex: processPane.selectedIndex
    property bool interactionOwned: false

    signal closeRequested()

    readonly property bool compactWidth: width > 0 && width < 840
    readonly property bool compactHeight: height > 0 && height < 540
    readonly property bool ultraCompactHeight: height > 0 && height < 450
    readonly property int leftWidth: visuals.leftPaneWidth(width)
    readonly property int rowGap: visuals.gridGap(height)
    readonly property int cpuHeight: visuals.cpuCardHeight(height)
    readonly property int compactCardHeight: visuals.compactCardHeight(height)
    readonly property int focusHeight: visuals.focusCardHeight(height)

    readonly property var primaryGpu: (Array.isArray(gpusData) && gpusData.length > 0) ? gpusData[0] : null
    readonly property var diskMounts: (disksData && Array.isArray(disksData.mounts)) ? disksData.mounts : []
    readonly property var mainMount: diskMounts.find(m => m && m.mount === "/") || diskMounts[0] || null
    readonly property var netInterfaces: ((networkData && Array.isArray(networkData.interfaces)) ? networkData.interfaces : []).filter(row => !row.loopback)
    readonly property var netNames: ["All"].concat(netInterfaces.map(row => row.name))
    readonly property string effectiveInterface: netNames.includes(interfaceName) ? interfaceName : ((networkData && networkData.defaultInterface) || "All")
    readonly property var netTraffic: effectiveInterface === "All"
        ? ((networkData && networkData.all) || {})
        : (netInterfaces.find(row => row.name === effectiveInterface) || {})

    TaskManagerVisuals { id: visuals }

    NumberAnimation {
        id: focusMorphAnim
        target: root
        property: "focusMorphProgress"
        from: 0.0
        to: 1.0
        duration: HAnimation.taskManagerFocusMorphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.taskManagerFocusMorphCurve
        onFinished: {
            if (root.focusMorphProgress >= 0.999) {
                root._finishStackedMorph()
            }
        }
    }

    onFocusMorphProgressChanged: {
        if (root.transitionActive && root.backFocusCard) {
            root.backFocusCard.progress = root.focusMorphProgress
            root.backFocusCard.roleProgress = root.focusMorphProgress
        }
    }

    function _metricCardItem(metricId) {
        if (metricId === "gpu") return gpuCompactCard
        if (metricId === "disk") return diskCompactCard
        if (metricId === "network") return networkCompactCard
        return memoryCompactCard
    }

    function _itemRectInFocusLayer(item) {
        if (!item || !focusLayer) return Qt.rect(0, 0, 0, 0)
        var pt = item.mapToItem(focusLayer, 0, 0)
        return Qt.rect(pt.x, pt.y, item.width, item.height)
    }

    readonly property rect focusSlotRect: {
        if (!focusSlot || !focusLayer || focusSlot.width <= 0) return Qt.rect(0, 0, 298, 160)
        var pt = focusSlot.mapToItem(focusLayer, 0, 0)
        return Qt.rect(pt.x, pt.y, focusSlot.width, focusSlot.height)
    }

    function _beginStackedFocusMorph(targetMetric) {
        if (!targetMetric || targetMetric === root.currentFocusMetric) {
            root.pendingMetric = ""
            return
        }

        if (root.reducedMotion || root.width <= 0 || root.height <= 0 || !focusSlot || focusSlot.width <= 0) {
            focusMorphAnim.stop()
            root._manualMorphActive = false
            root.pendingMetric = ""
            var nextCard = root.backFocusCard
            nextCard.metricId = targetMetric
            nextCard.progress = 1.0
            nextCard.roleProgress = 1.0
            nextCard.isFront = true
            nextCard.isAnimating = false
            nextCard.interactive = true
            nextCard.z = 10
            nextCard.visible = true

            var prevCard = root.frontFocusCard
            prevCard.isFront = false
            prevCard.isAnimating = false
            prevCard.interactive = false
            prevCard.z = 5
            prevCard.visible = false

            root.frontCardIndex = root.backCardIndex
            root.currentFocusMetric = targetMetric
            root.morphFromMetric = targetMetric
            root.morphToMetric = targetMetric
            root.incomingMetric = ""
            root.focusMorphProgress = 1.0
            return
        }

        var srcCard = _metricCardItem(targetMetric)
        var startR = _itemRectInFocusLayer(srcCard)
        var endR = root.focusSlotRect

        root.morphFromMetric = root.currentFocusMetric
        root.morphToMetric = targetMetric
        root.incomingMetric = targetMetric
        root.incomingStartRect = startR
        root.incomingTargetRect = endR

        var incoming = root.backFocusCard
        var oldFront = root.frontFocusCard

        // Keep the outgoing card visible until the incoming card arrives.
        oldFront.isAnimating = false
        oldFront.interactive = false
        oldFront.z = 10
        oldFront.visible = true

        incoming.metricId = targetMetric
        incoming.startRect = startR
        incoming.targetRect = endR
        incoming.progress = 0.0
        incoming.roleProgress = 0.0
        incoming.isFront = true
        incoming.isAnimating = true
        incoming.interactive = false
        incoming.z = 20
        incoming.visible = true

        root._manualMorphActive = false
        root.focusMorphProgress = 0.0
        focusMorphAnim.duration = HAnimation.taskManagerFocusMorphDuration
        focusMorphAnim.start()
    }

    function _finishStackedMorph() {
        focusMorphAnim.stop()
        root._manualMorphActive = false
        root.focusMorphProgress = 1.0

        var newlyFocused = root.incomingMetric !== "" ? root.incomingMetric : root.currentFocusMetric
        var newFront = root.backFocusCard
        var oldFront = root.frontFocusCard

        // Promote the incoming card without recreating its content.
        newFront.isAnimating = false
        newFront.progress = 1.0
        newFront.roleProgress = 1.0
        newFront.isFront = true
        newFront.interactive = true
        newFront.z = 10
        newFront.visible = true

        oldFront.isAnimating = false
        oldFront.isFront = false
        oldFront.interactive = false
        oldFront.z = 5
        oldFront.visible = false

        root.frontCardIndex = root.backCardIndex
        root.currentFocusMetric = newlyFocused
        root.focusedMetric = newlyFocused
        root.morphFromMetric = newlyFocused
        root.morphToMetric = newlyFocused
        root.incomingMetric = ""

        if (root.pendingMetric !== "" && root.pendingMetric !== root.currentFocusMetric) {
            var nextTarget = root.pendingMetric
            root.pendingMetric = ""
            root._beginStackedFocusMorph(nextTarget)
        } else {
            root.pendingMetric = ""
        }
    }

    function finishFocusMorphImmediately() {
        if (!focusMorphAnim.running && !root._manualMorphActive) return
        _finishStackedMorph()
    }

    function setFocusMorphState(fromMetric, toMetric, progress) {
        focusMorphAnim.stop()
        root.pendingMetric = ""
        var p = Motion.clamp01(progress)

        if (p >= 0.999 || fromMetric === toMetric) {
            root._manualMorphActive = false
            root.focusedMetric = toMetric
            if (root.currentFocusMetric !== toMetric) {
                var nextCard = root.backFocusCard
                var prevCard = root.frontFocusCard
                nextCard.metricId = toMetric
                nextCard.progress = 1.0
                nextCard.roleProgress = 1.0
                nextCard.isFront = true
                nextCard.isAnimating = false
                nextCard.interactive = true
                nextCard.z = 10
                nextCard.visible = true

                prevCard.isFront = false
                prevCard.isAnimating = false
                prevCard.interactive = false
                prevCard.z = 5
                prevCard.visible = false

                root.frontCardIndex = root.backCardIndex
                root.currentFocusMetric = toMetric
                root.morphFromMetric = toMetric
                root.morphToMetric = toMetric
            }
            root.incomingMetric = ""
            root.focusMorphProgress = 1.0
        } else {
            root.focusedMetric = toMetric
            if (root.currentFocusMetric !== fromMetric) {
                root.frontFocusCard.metricId = fromMetric
                root.frontFocusCard.progress = 1.0
                root.frontFocusCard.roleProgress = 1.0
                root.frontFocusCard.isFront = true
                root.frontFocusCard.isAnimating = false
                root.frontFocusCard.interactive = false
                root.frontFocusCard.z = 10
                root.frontFocusCard.visible = true
                root.currentFocusMetric = fromMetric
                root.morphFromMetric = fromMetric
            }

            var srcCard = _metricCardItem(toMetric)
            var startR = _itemRectInFocusLayer(srcCard)
            var endR = root.focusSlotRect

            root.morphToMetric = toMetric
            root.incomingMetric = toMetric
            root.incomingStartRect = startR
            root.incomingTargetRect = endR

            var incoming = root.backFocusCard
            incoming.metricId = toMetric
            incoming.startRect = startR
            incoming.targetRect = endR
            incoming.progress = p
            incoming.roleProgress = p
            incoming.isFront = true
            incoming.isAnimating = true
            incoming.interactive = false
            incoming.z = 20
            incoming.visible = true

            root.frontFocusCard.isAnimating = false
            root.frontFocusCard.interactive = false
            root.frontFocusCard.z = 10
            root.frontFocusCard.visible = true

            root.focusMorphProgress = p
            root._manualMorphActive = true
        }
    }

    onWidthChanged: if (root.transitionActive) root.finishFocusMorphImmediately()
    onHeightChanged: if (root.transitionActive) root.finishFocusMorphImmediately()

    // Discard stale selection and confirmation as soon as a process disappears.
    onProcessesDataChanged: {
        if (root.selectedKey && !(root.processesData || []).some(row => row.key === root.selectedKey)) {
            root.selectedKey = ""
            root.killKey = ""
            root.detailsOpen = false
        }
    }

    function resetVisualState() {
        focusMorphAnim.stop()
        root.pendingMetric = ""
        root._manualMorphActive = false
        root.incomingMetric = ""
        root.focusMorphProgress = 1.0

        root.frontCardIndex = 0
        if (typeof focusCardA !== "undefined" && focusCardA) {
            focusCardA.metricId = "memory"
            focusCardA.progress = 1.0
            focusCardA.roleProgress = 1.0
            focusCardA.isFront = true
            focusCardA.isAnimating = false
            focusCardA.interactive = true
            focusCardA.z = 10
            focusCardA.visible = true
            if (typeof focusCardA.resetState === "function") focusCardA.resetState("memory")
        }

        if (typeof focusCardB !== "undefined" && focusCardB) {
            focusCardB.metricId = "memory"
            focusCardB.progress = 1.0
            focusCardB.roleProgress = 1.0
            focusCardB.isFront = false
            focusCardB.isAnimating = false
            focusCardB.interactive = false
            focusCardB.z = 5
            focusCardB.visible = false
            if (typeof focusCardB.resetState === "function") focusCardB.resetState("memory")
        }

        root._suppressFocusSignal = true
        root.focusedMetric = "memory"
        root.currentFocusMetric = "memory"
        root.morphFromMetric = "memory"
        root.morphToMetric = "memory"
        root._suppressFocusSignal = false
    }

    Component.onCompleted: {
        resetVisualState()
    }

    function selectMetric(metricId) {
        if (metricId === "memory" || metricId === "gpu" || metricId === "disk" || metricId === "network") {
            if (metricId === root.focusedMetric && !root.transitionActive) return
            root.focusedMetric = metricId
            if (root.transitionActive) {
                root.pendingMetric = (metricId !== root.incomingMetric) ? metricId : ""
                return
            }
            root._beginStackedFocusMorph(metricId)
        }
    }

    function forceFocus() {
        processPane.forceFocus()
    }

    function moveSelection(delta) {
        processPane.moveSelection(delta)
    }

    function handleEscape() {
        processPane.handleEscape()
    }

    function handleKey(event) {
        processPane.handleKey(event)
    }

    Keys.onPressed: event => handleKey(event)

    RowLayout {
        anchors.fill: parent
        spacing: visuals.paneGap(root.width)

        Item {
            id: leftPane
            objectName: "taskTelemetryPane"
            Layout.preferredWidth: root.leftWidth
            Layout.minimumWidth: root.leftWidth
            Layout.maximumWidth: root.leftWidth
            Layout.fillHeight: true

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: telemetryGrid.implicitHeight
                interactive: contentHeight > height + 2
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                GridLayout {
                    id: telemetryGrid
                    width: parent.width
                    columns: 2
                    rowSpacing: root.rowGap
                    columnSpacing: root.rowGap

                    TaskCpuCard {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.cpuHeight
                        Layout.minimumHeight: root.cpuHeight
                        Layout.maximumHeight: root.cpuHeight
                        cpu: root.cpuData
                        visuals: visuals
                        compact: root.compactWidth || root.compactHeight
                        ultraCompact: root.ultraCompactHeight
                        reducedMotion: root.reducedMotion
                    }

                    // Reserve focus geometry while cards animate above the grid.
                    Item {
                        id: focusSlot
                        objectName: "taskFocusSlot"
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.focusHeight
                        Layout.minimumHeight: root.focusHeight
                        Layout.maximumHeight: root.focusHeight
                    }

                    TaskMetricCard {
                        id: memoryCompactCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.compactCardHeight
                        Layout.minimumHeight: root.compactCardHeight
                        Layout.maximumHeight: root.compactCardHeight
                        metricId: "memory"
                        title: "Memory"
                        selected: root.focusedMetric === "memory"
                        visualSuppressed: root.transitionActive && root.incomingMetric === "memory"
                        primaryValue: visuals.dashMetric(root.memoryData.percent, "%")
                        secondaryValue: visuals.dashPairBytes(root.memoryData.used, root.memoryData.total)
                        barValue: visuals.clampPercent(root.memoryData.percent)
                        barAvailable: Number.isFinite(root.memoryData.percent)
                        waterWavePhase: root.sharedWaterWavePhase
                        memory: root.memoryData
                        gpus: root.gpusData
                        disks: root.disksData
                        network: root.networkData
                        compact: root.compactWidth || root.compactHeight
                        ultraCompact: root.ultraCompactHeight
                        reducedMotion: root.reducedMotion
                        visuals: visuals
                        onActivated: id => root.selectMetric(id)
                    }

                    TaskMetricCard {
                        id: gpuCompactCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.compactCardHeight
                        Layout.minimumHeight: root.compactCardHeight
                        Layout.maximumHeight: root.compactCardHeight
                        metricId: "gpu"
                        title: "GPU"
                        selected: root.focusedMetric === "gpu"
                        visualSuppressed: root.transitionActive && root.incomingMetric === "gpu"
                        primaryValue: visuals.gpuHeroText(root.primaryGpu, root.serviceReady)
                        secondaryValue: root.primaryGpu && root.primaryGpu.name ? root.primaryGpu.name : "—"
                        barValue: root.primaryGpu ? visuals.clampPercent(root.primaryGpu.usage) : 0
                        barAvailable: !!(root.primaryGpu && Number.isFinite(root.primaryGpu.usage))
                        waterWavePhase: root.sharedWaterWavePhase
                        memory: root.memoryData
                        gpus: root.gpusData
                        disks: root.disksData
                        network: root.networkData
                        compact: root.compactWidth || root.compactHeight
                        ultraCompact: root.ultraCompactHeight
                        reducedMotion: root.reducedMotion
                        visuals: visuals
                        onActivated: id => root.selectMetric(id)
                    }

                    TaskMetricCard {
                        id: diskCompactCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.compactCardHeight
                        Layout.minimumHeight: root.compactCardHeight
                        Layout.maximumHeight: root.compactCardHeight
                        metricId: "disk"
                        title: "Disk"
                        selected: root.focusedMetric === "disk"
                        visualSuppressed: root.transitionActive && root.incomingMetric === "disk"
                        primaryValue: root.mainMount ? visuals.dashMetric(root.mainMount.percent, "%") : "—"
                        secondaryValue: "R " + visuals.dashRate(root.disksData ? root.disksData.readBps : null)
                            + " · W " + visuals.dashRate(root.disksData ? root.disksData.writeBps : null)
                        barValue: root.mainMount ? visuals.clampPercent(root.mainMount.percent) : 0
                        barAvailable: !!(root.mainMount && Number.isFinite(root.mainMount.percent))
                        waterWavePhase: root.sharedWaterWavePhase
                        memory: root.memoryData
                        gpus: root.gpusData
                        disks: root.disksData
                        network: root.networkData
                        compact: root.compactWidth || root.compactHeight
                        ultraCompact: root.ultraCompactHeight
                        reducedMotion: root.reducedMotion
                        visuals: visuals
                        onActivated: id => root.selectMetric(id)
                    }

                    TaskMetricCard {
                        id: networkCompactCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.compactCardHeight
                        Layout.minimumHeight: root.compactCardHeight
                        Layout.maximumHeight: root.compactCardHeight
                        metricId: "network"
                        title: "Network"
                        selected: root.focusedMetric === "network"
                        visualSuppressed: root.transitionActive && root.incomingMetric === "network"
                        primaryValue: "↓ " + visuals.dashRate(root.netTraffic.rxBps)
                        secondaryValue: "↑ " + visuals.dashRate(root.netTraffic.txBps)
                        waterWavePhase: root.sharedWaterWavePhase
                        memory: root.memoryData
                        gpus: root.gpusData
                        disks: root.disksData
                        network: root.networkData
                        compact: root.compactWidth || root.compactHeight
                        ultraCompact: root.ultraCompactHeight
                        reducedMotion: root.reducedMotion
                        visuals: visuals
                        onActivated: id => root.selectMetric(id)
                    }
                }
            }

            Item {
                id: focusLayer
                objectName: "taskFocusLayer"
                anchors.fill: parent
                z: 20

                TaskFocusLayerCard {
                    id: focusCardA
                    instanceId: 0
                    idleRect: root.focusSlotRect
                    compact: root.compactWidth || root.compactHeight
                    ultraCompact: root.ultraCompactHeight
                    reducedMotion: root.reducedMotion
                    waterWavePhase: root.sharedWaterWavePhase
                    memory: root.memoryData
                    gpus: root.gpusData
                    disks: root.disksData
                    network: root.networkData
                    history: root.historyData
                    serviceReady: root.serviceReady
                    interfaceName: root.interfaceName
                    visuals: visuals
                    onInterfaceSelected: name => root.interfaceName = name
                }

                TaskFocusLayerCard {
                    id: focusCardB
                    instanceId: 1
                    idleRect: root.focusSlotRect
                    compact: root.compactWidth || root.compactHeight
                    ultraCompact: root.ultraCompactHeight
                    reducedMotion: root.reducedMotion
                    waterWavePhase: root.sharedWaterWavePhase
                    memory: root.memoryData
                    gpus: root.gpusData
                    disks: root.disksData
                    network: root.networkData
                    history: root.historyData
                    serviceReady: root.serviceReady
                    interfaceName: root.interfaceName
                    visuals: visuals
                    onInterfaceSelected: name => root.interfaceName = name
                }
            }
        }

        TaskProcessPane {
            id: processPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            processes: root.processesData
            statusError: root.statusError
            warmingUp: root.warmingUp
            actionError: root.actionError
            actionStatus: root.actionStatus
            actionBusy: root.actionBusy
            interactionOwned: root.interactionOwned
            visuals: visuals
            compact: root.compactWidth || root.compactHeight
            ultraCompact: root.ultraCompactHeight
            reducedMotion: root.reducedMotion
            onCloseRequested: root.closeRequested()
            onSignalRequested: (proc, sig) => TaskManagerService.sendSignal(proc, sig)
        }
    }
}
