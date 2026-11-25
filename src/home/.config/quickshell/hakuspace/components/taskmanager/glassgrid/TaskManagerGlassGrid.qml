import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../services"
import "../../../config/UiCatalog.js" as Catalog
import ".." as TaskManager
import "../TaskManagerLogic.js" as Logic

FocusScope {
    id: root

    readonly property var metricOrder: ["cpu", "ram", "gpu", "disk", "network"]
    property string focusedMetric: "cpu"
    property int committedIndex: 0
    property int pendingIndex: -1
    property int transitionDirection: 0
    property bool transitioning: false
    property real transitionProgress: 0.0
    readonly property real slideDistance: Math.max(40, Theme.spaceXl * 2.5)

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

    readonly property var telemetrySnapshot: ({
        cpu: root.cpuData || ({}),
        memory: root.memoryData || ({}),
        gpus: root.gpusData || [],
        disks: root.disksData || ({}),
        network: root.networkData || ({})
    })

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

    readonly property var primaryGpu: (Array.isArray(gpusData) && gpusData.length > 0) ? gpusData[0] : null
    readonly property var diskMounts: (disksData && Array.isArray(disksData.mounts)) ? disksData.mounts : []
    readonly property var mainMount: diskMounts.find(function(m) { return m && m.mount === "/" }) || diskMounts[0] || null
    readonly property var netInterfaces: ((networkData && Array.isArray(networkData.interfaces)) ? networkData.interfaces : []).filter(function(row) { return !row.loopback })
    readonly property var netNames: ["All"].concat(netInterfaces.map(function(row) { return row.name }))
    readonly property string effectiveInterface: netNames.includes(interfaceName) ? interfaceName : ((networkData && networkData.defaultInterface) || "All")
    readonly property var netTraffic: effectiveInterface === "All"
        ? ((networkData && networkData.all) || ({}))
        : (netInterfaces.find(function(row) { return row.name === effectiveInterface }) || ({}))

    NumberAnimation {
        id: carouselAnim
        target: root
        property: "transitionProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.dashboardWidgetSwitchCurve
        onFinished: {
            if (root.pendingIndex >= 0) {
                root.committedIndex = root.pendingIndex
                root.focusedMetric = root.metricOrder[root.committedIndex] || "cpu"
            }
            root.pendingIndex = -1
            root.transitionDirection = 0
            root.transitioning = false
            root.transitionProgress = 0.0
        }
    }

    function selectMetric(metricId) {
        var nextIdx = metricOrder.indexOf(metricId)
        if (nextIdx < 0) return

        if (root.reducedMotion || root.width <= 0 || root.height <= 0) {
            carouselAnim.stop()
            root.committedIndex = nextIdx
            root.pendingIndex = -1
            root.transitionDirection = 0
            root.transitioning = false
            root.transitionProgress = 0.0
            root.focusedMetric = metricId
            return
        }

        if (root.transitioning && root.pendingIndex >= 0) {
            if (nextIdx === root.pendingIndex) return
            carouselAnim.stop()
            if (nextIdx === root.committedIndex) {
                var oldCommitted = root.committedIndex
                root.committedIndex = root.pendingIndex
                root.pendingIndex = oldCommitted
                root.transitionDirection = nextIdx >= root.committedIndex ? 1 : -1
                root.transitionProgress = Math.max(0.0, Math.min(1.0, 1.0 - root.transitionProgress))
                root.focusedMetric = metricId
                carouselAnim.from = root.transitionProgress
                carouselAnim.to = 1.0
                carouselAnim.duration = Math.max(60, Math.round(HAnimation.dashboardWidgetSwitchDuration * (1.0 - root.transitionProgress)))
                carouselAnim.start()
                return
            }
            root.committedIndex = root.pendingIndex
        }

        if (nextIdx === root.committedIndex) return

        root.transitionDirection = nextIdx >= root.committedIndex ? 1 : -1
        root.pendingIndex = nextIdx
        root.transitioning = true
        root.transitionProgress = 0.0
        root.focusedMetric = metricId
        carouselAnim.from = 0.0
        carouselAnim.to = 1.0
        carouselAnim.duration = HAnimation.dashboardWidgetSwitchDuration
        carouselAnim.start()
    }

    function metricIconGlyph(metricId) {
        if (metricId === "cpu") return Catalog.taskManagerIcons.cpu
        if (metricId === "gpu") return Catalog.taskManagerIcons.gpu
        if (metricId === "disk") return Catalog.taskManagerIcons.disk
        if (metricId === "network") return Catalog.taskManagerIcons.network
        return Catalog.taskManagerIcons.memory
    }

    function metricDisplayLabel(metricId) {
        if (metricId === "cpu") return "CPU"
        if (metricId === "gpu") return "GPU"
        if (metricId === "disk") return "Disk"
        if (metricId === "network") return "Network"
        return "RAM"
    }

    function metricGaugePercent(metricId) {
        if (metricId === "cpu") return root.cpuData && Number.isFinite(root.cpuData.usage) ? root.cpuData.usage : NaN
        if (metricId === "ram") return root.memoryData && Number.isFinite(root.memoryData.percent) ? root.memoryData.percent : NaN
        if (metricId === "gpu") return root.primaryGpu && Number.isFinite(root.primaryGpu.usage) ? root.primaryGpu.usage : NaN
        if (metricId === "disk") return root.mainMount && Number.isFinite(root.mainMount.percent) ? root.mainMount.percent : NaN
        if (metricId === "network") {
            var rxOk = Number.isFinite(root.netTraffic.rxBps)
            var txOk = Number.isFinite(root.netTraffic.txBps)
            if (!rxOk && !txOk) return NaN
            var current = (rxOk ? root.netTraffic.rxBps : 0) + (txOk ? root.netTraffic.txBps : 0)
            var peak = 102400
            if (Array.isArray(root.historyData)) {
                for (var i = 0; i < root.historyData.length; i++) {
                    var s = root.historyData[i]
                    if (!s) continue
                    var total = (Number.isFinite(s.rx) ? s.rx : 0) + (Number.isFinite(s.tx) ? s.tx : 0)
                    if (total > peak) peak = total
                }
            }
            return Math.max(0, Math.min(100, (current / peak) * 100.0))
        }
        return NaN
    }

    function metricHeroValue(metricId) {
        if (metricId === "network") {
            var rxOk = Number.isFinite(root.netTraffic.rxBps)
            var txOk = Number.isFinite(root.netTraffic.txBps)
            if (!rxOk && !txOk) return "—"
            return Logic.bytes((rxOk ? root.netTraffic.rxBps : 0) + (txOk ? root.netTraffic.txBps : 0)) + "/s"
        }
        if (metricId === "gpu") {
            if (!root.primaryGpu) return root.serviceReady ? "Unsupported" : "—"
            if (Number.isFinite(root.primaryGpu.usage)) return Math.round(root.primaryGpu.usage) + "%"
            var gStatus = Logic.gpuUsage(root.primaryGpu)
            return gStatus === "Unavailable" ? "—" : gStatus
        }
        var val = metricGaugePercent(metricId)
        return Number.isFinite(val) ? Math.round(val) + "%" : "—"
    }

    function detailRowsForMetric(metricId) {
        if (metricId === "cpu") {
            var c = root.cpuData || ({})
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
        if (metricId === "ram") {
            var m = root.memoryData || ({})
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
        if (metricId === "gpu") {
            var g = root.primaryGpu || ({})
            var devVal = g.name || (root.serviceReady ? "Unsupported" : "—")
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
                { label: "Power", value: cpVal }
            ]
        }
        if (metricId === "disk") {
            var mount = root.mainMount
            var d = root.disksData || ({})
            var mountVal = mount && mount.mount ? mount.mount : "—"
            var spaceVal = (mount && Number.isFinite(mount.used) && Number.isFinite(mount.total))
                ? (Logic.bytes(mount.used) + " / " + Logic.bytes(mount.total)) : "—"
            var readVal = Number.isFinite(d.readBps) ? (Logic.bytes(d.readBps) + "/s") : "—"
            var writeVal = Number.isFinite(d.writeBps) ? (Logic.bytes(d.writeBps) + "/s") : "—"
            return [
                { label: "Mount", value: mountVal },
                { label: "Used", value: spaceVal },
                { label: "Read", value: readVal },
                { label: "Write", value: writeVal }
            ]
        }
        var net = root.netTraffic || ({})
        var downVal = Number.isFinite(net.rxBps) ? (Logic.bytes(net.rxBps) + "/s") : "—"
        var upVal = Number.isFinite(net.txBps) ? (Logic.bytes(net.txBps) + "/s") : "—"
        var totalVal = (Number.isFinite(net.rxBytes) || Number.isFinite(net.txBytes))
            ? Logic.bytes((Number.isFinite(net.rxBytes) ? net.rxBytes : 0) + (Number.isFinite(net.txBytes) ? net.txBytes : 0))
            : "—"
        var stateVal = root.effectiveInterface === "All"
            ? (root.netInterfaces.length + " active")
            : (net.up === true ? "Up" : (net.up === false ? "Down" : "—"))
        return [
            { label: "Down", value: downVal },
            { label: "Up", value: upVal },
            { label: "Total", value: totalVal },
            { label: "Link", value: stateVal }
        ]
    }

    // Discard stale selection and confirmation as soon as a process disappears.
    onProcessesDataChanged: {
        if (root.selectedKey && !(root.processesData || []).some(function(row) { return row.key === root.selectedKey })) {
            root.selectedKey = ""
            root.killKey = ""
            root.detailsOpen = false
        }
    }

    function resetVisualState() {
        carouselAnim.stop()
        root.focusedMetric = "cpu"
        root.committedIndex = 0
        root.pendingIndex = -1
        root.transitionDirection = 0
        root.transitioning = false
        root.transitionProgress = 0.0
    }

    Component.onCompleted: resetVisualState()

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
        spacing: Theme.spaceLg

        ColumnLayout {
            id: leftPane
            objectName: "taskTelemetryPane"
            readonly property int paneWidth: Math.max(300, Math.min(380, Math.round(root.width * 0.36)))
            Layout.fillWidth: false
            Layout.minimumWidth: paneWidth
            Layout.preferredWidth: paneWidth
            Layout.maximumWidth: paneWidth
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            // Hero Focus Card: single active water gauge + metric details.
            Rectangle {
                id: heroFocusCard
                objectName: "taskHeroFocusCard"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(176, Math.round(root.height * 0.36))
                radius: Theme.largeRadius
                border.width: 0
                color: Theme.isLight ? Theme.surfaceSubtle(1.04) : Theme.surfaceSubtle(1.22)
                clip: true

                Item {
                    id: heroViewport
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                    clip: true

                    Repeater {
                        model: root.metricOrder

                        Item {
                            id: heroSlide
                            required property int index
                            required property string modelData
                            objectName: "taskHeroSlide_" + modelData

                            width: heroViewport.width
                            height: heroViewport.height

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

                            readonly property real gaugeVal: root.metricGaugePercent(modelData)
                            readonly property bool gaugeAvail: Number.isFinite(gaugeVal)
                            readonly property real gaugeSize: Math.max(76, Math.min(104,
                                Math.round(heroViewport.height * 0.62),
                                Math.round(heroViewport.width * 0.32)))
                            readonly property var detailRows: root.detailRowsForMetric(modelData)

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.spaceLg

                                Item {
                                    Layout.preferredWidth: waterGauge.diameter
                                    Layout.preferredHeight: waterGauge.diameter
                                    Layout.alignment: Qt.AlignVCenter

                                    HoverHandler { id: gaugeHover }

                                    TaskWaterGauge {
                                        id: waterGauge
                                        objectName: "taskHeroWaterGauge_" + heroSlide.modelData
                                        anchors.centerIn: parent
                                        diameter: heroSlide.gaugeSize
                                        borderless: true
                                        interactive: false
                                        emphasized: gaugeHover.hovered
                                        scale: (gaugeHover.hovered && !root.reducedMotion) ? 1.05 : 1.0
                                        metricId: heroSlide.modelData
                                        available: heroSlide.gaugeAvail
                                        value: heroSlide.gaugeAvail ? heroSlide.gaugeVal : 0
                                        wavePhase: root.sharedWaterWavePhase
                                        reducedMotion: root.reducedMotion || !heroSlide.visible
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
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: Theme.spaceXs

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spaceSm

                                        Text {
                                            text: root.metricIconGlyph(heroSlide.modelData)
                                            color: Theme.accent
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fontSize + 2
                                            Accessible.ignored: true
                                        }

                                        Text {
                                            text: root.metricDisplayLabel(heroSlide.modelData)
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize + 2
                                            font.bold: true
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            objectName: "taskHeroValue_" + heroSlide.modelData
                                            text: root.metricHeroValue(heroSlide.modelData)
                                            color: Theme.accent
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Math.round(Theme.fontSize * 1.55)
                                            font.bold: true
                                        }
                                    }

                                    TaskDropdown {
                                        id: interfaceCombo
                                        objectName: "taskNetworkInterfaceDropdown"
                                        visible: heroSlide.modelData === "network"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Theme.controlHeight - 4
                                        reducedMotion: root.reducedMotion
                                        model: root.netNames
                                        currentIndex: Math.max(0, root.netNames.indexOf(root.effectiveInterface))
                                        Accessible.name: "Network interface"
                                        onActivated: root.interfaceName = root.netNames[currentIndex] || "All"
                                    }

                                    Repeater {
                                        model: heroSlide.detailRows

                                        RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: Theme.spaceSm

                                            Text {
                                                text: modelData.label
                                                color: Theme.fgMuted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 1
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                horizontalAlignment: Text.AlignRight
                                                text: modelData.value
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 1
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5 selectable vertical Metric Pills.
            ColumnLayout {
                id: metricPillList
                objectName: "taskTelemetryPillList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spaceSm

                Repeater {
                    model: root.metricOrder

                    Item {
                        id: pillSlot
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: Theme.comfortableControlHeight

                        TaskManager.TaskManagerMetricPill {
                            id: metricPill
                            objectName: "taskTelemetryPill_" + pillSlot.modelData
                            anchors.fill: parent
                            metricId: pillSlot.modelData
                            snapshot: root.telemetrySnapshot
                            history: root.historyData
                            selectable: true
                            selected: root.focusedMetric === pillSlot.modelData
                            hovered: pillMouse.containsMouse || pillSlot.activeFocus
                            pressed: pillMouse.pressed
                            reducedMotion: root.reducedMotion
                        }

                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: root.metricDisplayLabel(pillSlot.modelData) + " " + metricPill.displayValueText
                        Keys.onReturnPressed: event => { root.selectMetric(pillSlot.modelData); event.accepted = true }
                        Keys.onEnterPressed: event => { root.selectMetric(pillSlot.modelData); event.accepted = true }
                        Keys.onSpacePressed: event => { root.selectMetric(pillSlot.modelData); event.accepted = true }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: root.selectMetric(pillSlot.modelData)
                        }
                    }
                }
            }
        }

        TaskProcessPane {
            id: processPane
            Layout.fillWidth: true
            Layout.minimumWidth: 360
            Layout.fillHeight: true
            processes: root.processesData
            statusError: root.statusError
            warmingUp: root.warmingUp
            actionError: root.actionError
            actionStatus: root.actionStatus
            actionBusy: root.actionBusy
            interactionOwned: root.interactionOwned
            reducedMotion: root.reducedMotion
            onCloseRequested: root.closeRequested()
            onSignalRequested: (proc, sig) => TaskManagerService.sendSignal(proc, sig)
        }
    }
}
