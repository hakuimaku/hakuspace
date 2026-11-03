import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../services"
import "glassgrid" as Glass
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
    onPinnedProcessesChanged: if (!pinnedProcesses.some(process => process.key === pendingUnpinKey)) pendingUnpinKey = ""
    onVisibleChanged: if (!visible) pendingUnpinKey = ""
    onEnabledChanged: if (!enabled) pendingUnpinKey = ""
    Keys.onEscapePressed: event => {
        if (pendingUnpinKey) { pendingUnpinKey = ""; event.accepted = true }
        else event.accepted = false
    }
    readonly property int maxVisiblePins: 4
    readonly property bool compact: width < Theme.fontSize * 44
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpu: (snapshot.gpus || [])[0] || ({})
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
    function clearPrimaryFocus() { pendingUnpinKey = ""; focus = false }

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
            accent: false
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
                    objectName: "taskManagerMiniCpu"
                    Layout.fillWidth: true
                    compact: root.compact
                    visuals: miniVisuals
                    label: "CPU"
                    waterWavePhase: root.waterWavePhase
                    value: Logic.metric(root.cpu.usage, "%", 0)
                    usage: Number.isFinite(root.cpu.usage) ? root.cpu.usage : NaN
                    secondary: Number.isFinite(root.cpu.temperatureC) ? Logic.metric(root.cpu.temperatureC, "°C", 0) : "—"
                    reducedMotion: root.reducedMotion
                }
                TaskManagerMiniMetric {
                    objectName: "taskManagerMiniMemory"
                    Layout.fillWidth: true
                    compact: root.compact
                    visuals: miniVisuals
                    label: "Memory"
                    waterWavePhase: root.waterWavePhase
                    value: Logic.metric(root.memory.percent, "%", 0)
                    usage: Number.isFinite(root.memory.percent) ? root.memory.percent : NaN
                    secondary: Number.isFinite(root.memory.used) && Number.isFinite(root.memory.total)
                        ? Logic.bytes(root.memory.used) + " / " + Logic.bytes(root.memory.total) : "—"
                    reducedMotion: root.reducedMotion
                }
                TaskManagerMiniMetric {
                    objectName: "taskManagerMiniGpu"
                    Layout.fillWidth: true
                    compact: root.compact
                    visuals: miniVisuals
                    label: "GPU"
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
                HoverHandler { id: paneHover; cursorShape: Qt.ArrowCursor }
                ColumnLayout {
                    id: pins
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.contentPadding }
                    spacing: Theme.spaceXs
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm
                        Text {
                            text: Catalog.taskManagerIcons.pin
                            color: paneHover.hovered ? Theme.accent : miniVisuals.secondaryFg
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
                            readonly property bool hovered: rowHover.hovered
                            readonly property bool confirming: root.pendingUnpinKey === modelData.key
                            color: hovered ? miniVisuals.miniRowHoverSurface : miniVisuals.wellSurface
                            Behavior on color {
                                enabled: !root.reducedMotion
                                ColorAnimation { duration: HAnimation.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                            }
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
                                // Nudge only the content, preserving the row's hover hit box.
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
