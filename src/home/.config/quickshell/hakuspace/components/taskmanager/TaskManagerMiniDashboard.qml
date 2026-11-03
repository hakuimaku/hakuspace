import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../services"
import "glassgrid" as Glass
import "../motion" as Motion
import "TaskManagerLogic.js" as Logic
import "../../config/UiCatalog.js" as Catalog

FocusScope {
    id: root
    // Share telemetry and live-instance pins with the standalone presentation.
    property var snapshot: ({})
    property var pinnedProcesses: TaskManagerPins.pinnedProcesses
    property bool reducedMotion: false
    // Keep confirmation tied to the process lifetime across telemetry refreshes.
    property string pendingUnpinKey: ""
    property Item hoveredPinRow: null
    // Retain geometry across row gaps without retaining the active hover state.
    property Item pinHoverTarget: null
    onHoveredPinRowChanged: if (hoveredPinRow) pinHoverTarget = hoveredPinRow
    onPinnedProcessesChanged: if (!pinnedProcesses.some(process => process.key === pendingUnpinKey)) pendingUnpinKey = ""
    onVisibleChanged: if (!visible) { pendingUnpinKey = ""; hoveredPinRow = null; pinHoverTarget = null }
    onEnabledChanged: if (!enabled) { pendingUnpinKey = ""; hoveredPinRow = null; pinHoverTarget = null }
    Keys.onEscapePressed: event => {
        if (pendingUnpinKey) { pendingUnpinKey = ""; event.accepted = true }
        else event.accepted = false
    }
    readonly property int maxVisiblePins: 4
    readonly property bool compact: width < Theme.fontSize * 44
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpu: (snapshot.gpus || [])[0] || ({})
    readonly property string hoveredMetric: cpuMetric.hovered ? "CPU" : memoryMetric.hovered ? "Memory" : gpuMetric.hovered ? "GPU" : ""
    // Fit the presentation to its actual rows instead of reserving an empty table.
    readonly property int contentPadding: Theme.spaceMd
    implicitHeight: header.height + Theme.spaceSm + body.implicitHeight
    // Share one decorative clock and stop it when the Mini page is no longer painted.
    property real waterWavePhase: 0
    NumberAnimation on waterWavePhase {
        from: 0
        to: Math.PI * 2
        duration: 3400
        loops: Animation.Infinite
        running: root.visible && !root.reducedMotion
            && metricsRow.y + metricsRow.height > viewport.contentY
            && metricsRow.y < viewport.contentY + viewport.height
    }
    signal openFullRequested()

    // Keep the standalone handoff as the initial Mini focus target.
    function forcePrimaryFocus() { openFull.forceActiveFocus() }
    function clearPrimaryFocus() { pendingUnpinKey = ""; hoveredPinRow = null; pinHoverTarget = null; focus = false }

    // Coalesce leave/enter so a row-to-row move retargets the existing pill.
    function clearPinHover() {
        if (root && root.hoveredPinRow && !root.hoveredPinRow.hovered) root.hoveredPinRow = null
    }

    // First activation asks; only another activation of the same identity removes its pin.
    function activatePin(process) {
        if (!process || !process.key) return
        if (pendingUnpinKey === process.key) {
            pendingUnpinKey = ""
            TaskManagerPins.unpin(process)
        } else pendingUnpinKey = process.key
    }

    Glass.TaskManagerVisuals { id: miniVisuals }

    RowLayout {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: openFull.implicitHeight
        spacing: Theme.spaceSm
        Text {
            text: Catalog.taskManagerIcons.overview
            opacity: TaskManagerService.error || root.hoveredMetric ? 1 : 0.8
            Behavior on opacity {
                enabled: !root.reducedMotion
                NumberAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
            }
            color: TaskManagerService.error ? Theme.danger : Theme.accent
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
            Accessible.ignored: true
        }
        Text {
            Layout.fillWidth: true
            text: TaskManagerService.error || (TaskManagerService.warmingUp ? "Warming up…" : "System overview")
            color: TaskManagerService.error ? Theme.danger : miniVisuals.secondaryFg
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Glass.TaskActionButton {
            id: openFull
            objectName: "taskManagerMiniOpenFull"
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            text: "Task Manager"
            icon: Catalog.taskManagerIcons.open
            fontSize: Theme.fontSize
            implicitHeight: Theme.controlHeight
            radius: Theme.radius
            visuals: miniVisuals
            reducedMotion: root.reducedMotion
            compact: root.compact
            accent: true
            horizontalPadding: (compact ? 8 : 10) + 8
            foregroundColor: Theme.onAccentColor
            color: Theme.accent
            border.width: 1
            border.color: Qt.alpha(Theme.onAccentColor, activeFocus ? 0.55 : openHover.hovered ? 0.24 : 0)
            Behavior on border.color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
            }
            HoverHandler { id: openHover; cursorShape: Qt.PointingHandCursor }
            Accessible.name: "Open Task Manager"
            onClicked: root.openFullRequested()
        }
    }

    // Keep the three metrics in row one and pinned processes directly in row two.
    Flickable {
        id: viewport
        objectName: "taskManagerMiniViewport"
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: Theme.spaceSm }
        contentWidth: width
        contentHeight: body.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: body
            objectName: "taskManagerMiniGrid"
            width: parent.width
            spacing: Theme.spaceMd
            RowLayout {
                id: metricsRow
                objectName: "taskManagerMiniMetricsRow"
                Layout.fillWidth: true
                // Leave room for the painted lift inside the clipped viewport.
                Layout.topMargin: Theme.spaceXs
                spacing: Theme.spaceMd
                TaskManagerMiniMetric {
                    id: cpuMetric
                    objectName: "taskManagerMiniCpu"
                    Layout.fillWidth: true
                    compact: root.compact
                    visuals: miniVisuals
                    label: "CPU"
                    subdued: root.hoveredMetric !== "" && root.hoveredMetric !== "CPU"
                    waterWavePhase: root.waterWavePhase
                    value: Logic.metric(root.cpu.usage, "%", 0)
                    usage: Number.isFinite(root.cpu.usage) ? root.cpu.usage : NaN
                    secondary: Number.isFinite(root.cpu.temperatureC) ? Logic.metric(root.cpu.temperatureC, "°C", 0) : "—"
                    reducedMotion: root.reducedMotion
                }
                TaskManagerMiniMetric {
                    id: memoryMetric
                    objectName: "taskManagerMiniMemory"
                    Layout.fillWidth: true
                    compact: root.compact
                    visuals: miniVisuals
                    label: "Memory"
                    subdued: root.hoveredMetric !== "" && root.hoveredMetric !== "Memory"
                    waterWavePhase: root.waterWavePhase
                    value: Logic.metric(root.memory.percent, "%", 0)
                    usage: Number.isFinite(root.memory.percent) ? root.memory.percent : NaN
                    secondary: Number.isFinite(root.memory.used) && Number.isFinite(root.memory.total)
                        ? Logic.bytes(root.memory.used) + " / " + Logic.bytes(root.memory.total) : "—"
                    reducedMotion: root.reducedMotion
                }
                TaskManagerMiniMetric {
                    id: gpuMetric
                    objectName: "taskManagerMiniGpu"
                    Layout.fillWidth: true
                    compact: root.compact
                    visuals: miniVisuals
                    label: "GPU"
                    subdued: root.hoveredMetric !== "" && root.hoveredMetric !== "GPU"
                    waterWavePhase: root.waterWavePhase
                    value: Number.isFinite(root.gpu.usage) ? Logic.gpuUsage(root.gpu) : "Unavailable"
                    usage: Number.isFinite(root.gpu.usage) ? root.gpu.usage : NaN
                    secondary: Number.isFinite(root.gpu.temperatureC) ? Logic.metric(root.gpu.temperatureC, "°C", 0) : "—"
                    reducedMotion: root.reducedMotion
                }
            }
            // Confirm unpinning inline without opening full process controls.
            Rectangle {
                objectName: "taskManagerMiniPinsPane"
                Layout.fillWidth: true
                implicitHeight: pins.implicitHeight + root.contentPadding * 2
                radius: Theme.radius
                color: miniVisuals.paneSurface
                Item {
                    id: hoverLayer
                    anchors.fill: parent
                    Motion.SelectionPill {
                        objectName: "taskManagerMiniPinHoverPill"
                        targetItem: root.pinHoverTarget
                        coordinateSpace: hoverLayer
                        normalColor: miniVisuals.miniRowHoverSurface
                        shown: root.visible && root.enabled && targetItem !== null
                        opacity: root.hoveredPinRow ? 1 : 0
                        duration: root.reducedMotion ? 0 : HAnimation.taskBarFillDuration
                        fadeDuration: root.reducedMotion ? 0 : HAnimation.fast
                        curve: HAnimation.moduleCurve
                        fadeCurve: HAnimation.moduleCurve
                        onDurationChanged: if (!duration) snap()
                        onNormalColorChanged: syncTarget(root.reducedMotion)
                    }
                }
                ColumnLayout {
                    id: pins
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.contentPadding }
                    spacing: Theme.spaceXs
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm
                        Text {
                            text: Catalog.taskManagerIcons.pin
                            color: root.hoveredPinRow ? Theme.accent : miniVisuals.secondaryFg
                            Behavior on color {
                                enabled: !root.reducedMotion
                                ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                            }
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fontSize
                            Accessible.ignored: true
                        }
                        Text {
                            text: TaskManagerPins.error || "Pinned"
                            color: TaskManagerPins.error ? Theme.danger : miniVisuals.primaryFg
                            elide: Text.ElideRight
                            Layout.maximumWidth: pins.width - Theme.fontSize * 5
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            visible: root.pinnedProcesses.length > 1
                            text: "· " + root.pinnedProcesses.length
                            color: miniVisuals.secondaryFg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Item { Layout.fillWidth: true }
                    }
                    Text {
                        objectName: "taskManagerMiniEmptyPins"
                        Layout.fillWidth: true
                        visible: root.pinnedProcesses.length === 0
                        text: "Pin processes in Task Manager to follow them here."
                        color: miniVisuals.secondaryFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.WordWrap
                    }
                    // Update payloads in place so telemetry cannot reset hover, focus or taps.
                    ScriptModel {
                        id: pinnedModel
                        values: root.pinnedProcesses.slice(0, root.maxVisiblePins)
                        objectProp: "key"
                        comparisonMode: ObjectComparison.Structure
                    }
                    Repeater {
                        model: pinnedModel
                        Rectangle {
                            id: pinRow
                            required property var modelData
                            objectName: "taskManagerMiniPinnedRow"
                            Layout.fillWidth: true
                            implicitHeight: Theme.comfortableControlHeight
                            radius: Theme.radius
                            readonly property bool hovered: visible && enabled && rowHover.hovered
                            onHoveredChanged: {
                                if (hovered) root.hoveredPinRow = pinRow
                                else Qt.callLater(root.clearPinHover)
                            }
                            readonly property bool confirming: root.pendingUnpinKey === modelData.key
                            color: miniVisuals.wellSurface
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.name + ", CPU " + Logic.metric(modelData.cpuTotalPercent, "%") + ", memory " + Logic.bytes(modelData.rss)
                            Accessible.description: confirming ? "Press again to unpin" : "Press twice to unpin"
                            Accessible.onPressAction: root.activatePin(modelData)
                            Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.activatePin(modelData); event.accepted = true }
                            Keys.onSpacePressed: event => { if (!event.isAutoRepeat) root.activatePin(modelData); event.accepted = true }
                            HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onTapped: { pinRow.forceActiveFocus(); root.activatePin(pinRow.modelData) }
                            }
                            RowLayout {
                                anchors { fill: parent; leftMargin: Theme.spaceMd; rightMargin: Theme.spaceMd }
                                spacing: Theme.spaceSm
                                RowLayout {
                                    objectName: "taskManagerMiniPinNameGroup"
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: Theme.spaceSm
                                    // Nudge the name group while numeric columns stay aligned.
                                    transform: Translate {
                                        x: pinRow.hovered && !root.reducedMotion ? 3 : 0
                                        Behavior on x {
                                            enabled: !root.reducedMotion
                                            NumberAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                                        }
                                    }
                                    Text {
                                        text: Catalog.taskManagerIcons.pin
                                        color: pinRow.hovered ? Theme.accent : miniVisuals.secondaryFg
                                        Behavior on color {
                                            enabled: !root.reducedMotion
                                            ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                                        }
                                        rotation: pinRow.hovered && !root.reducedMotion ? -6 : 0
                                        Behavior on rotation {
                                            enabled: !root.reducedMotion
                                            NumberAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                                        }
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fontSize
                                        Accessible.ignored: true
                                    }
                                    Text {
                                        objectName: "taskManagerMiniPinnedName"
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: pinRow.modelData.name
                                        color: miniVisuals.primaryFg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    objectName: "taskManagerMiniUnpinPrompt"
                                    Layout.preferredWidth: Theme.fontSize * (pinRow.confirming ? 16 : 8) + (pinRow.confirming ? Theme.spaceSm : 0)
                                    horizontalAlignment: Text.AlignRight
                                    text: pinRow.confirming ? "Unpin? Click again" : "CPU " + Logic.metric(pinRow.modelData.cpuTotalPercent, "%")
                                    elide: Text.ElideRight
                                    color: Qt.alpha(Theme.accent, pinRow.hovered ? 1 : 0.85)
                                    Behavior on color {
                                        enabled: !root.reducedMotion
                                        ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                }
                                Text {
                                    visible: !pinRow.confirming
                                    Layout.preferredWidth: Theme.fontSize * 8
                                    horizontalAlignment: Text.AlignRight
                                    text: "RAM " + Logic.bytes(pinRow.modelData.rss)
                                    elide: Text.ElideRight
                                    color: miniVisuals.secondaryFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                }
                            }
                        }
                    }
                    Text {
                        objectName: "taskManagerMiniMorePins"
                        visible: root.pinnedProcesses.length > root.maxVisiblePins
                        text: "+" + (root.pinnedProcesses.length - root.maxVisiblePins) + " pinned"
                        color: miniVisuals.secondaryFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
