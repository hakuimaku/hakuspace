import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import "glassgrid" as Glass
import "TaskManagerLogic.js" as Logic

FocusScope {
    id: root
    // Share telemetry and live-instance pins with the standalone presentation.
    property var snapshot: ({})
    property var pinnedProcesses: TaskManagerPins.pinnedProcesses
    property bool reducedMotion: false
    readonly property int maxVisiblePins: 4
    readonly property bool compact: height < 300
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpu: (snapshot.gpus || [])[0] || ({})
    // Keep the extra inset local to Task Manager cards.
    readonly property int contentPadding: Theme.cardPadding + 4
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

    // Keep the standalone handoff as the only Mini action in the focus path.
    function forcePrimaryFocus() { openFull.forceActiveFocus() }
    function clearPrimaryFocus() { focus = false }

    Glass.TaskManagerVisuals { id: miniVisuals }

    RowLayout {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: openFull.implicitHeight
        spacing: Theme.spaceSm
        Rectangle {
            width: 5; height: 5; radius: 2.5
            color: TaskManagerService.error ? Theme.danger : Theme.accent
        }
        Text {
            Layout.fillWidth: true
            text: TaskManagerService.error || (TaskManagerService.warmingUp ? "Warming up…" : "System overview")
            color: TaskManagerService.error ? Theme.danger : miniVisuals.secondaryFg
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: miniVisuals.metaFontSize
        }
        Glass.TaskActionButton {
            id: openFull
            objectName: "taskManagerMiniOpenFull"
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            text: "↗ Task Manager"
            visuals: miniVisuals
            reducedMotion: root.reducedMotion
            compact: root.compact
            accent: true
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
            // Keep pinned rows read-only; process management remains in the standalone window.
            Rectangle {
                objectName: "taskManagerMiniPinsPane"
                Layout.fillWidth: true
                implicitHeight: pins.implicitHeight + root.contentPadding * 2
                radius: Theme.radius
                color: miniVisuals.paneSurface
                ColumnLayout {
                    id: pins
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.contentPadding }
                    spacing: Theme.spaceSm
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm
                        Text {
                            Layout.fillWidth: true
                            text: TaskManagerPins.error || "Pinned"
                            color: TaskManagerPins.error ? Theme.danger : miniVisuals.secondaryFg
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: miniVisuals.metaFontSize
                        }
                        Repeater {
                            model: ["CPU", "RAM"]
                            Text {
                                required property string modelData
                                visible: root.pinnedProcesses.length > 0
                                Layout.preferredWidth: Theme.fontSize * (modelData === "CPU" ? 5 : 6)
                                horizontalAlignment: Text.AlignRight
                                text: modelData
                                color: miniVisuals.secondaryFg
                                font.family: Theme.fontFamily
                                font.pixelSize: miniVisuals.metaFontSize
                            }
                        }
                    }
                    Text {
                        objectName: "taskManagerMiniEmptyPins"
                        Layout.fillWidth: true
                        visible: root.pinnedProcesses.length === 0
                        text: "Pin processes in Task Manager to follow them here."
                        color: miniVisuals.secondaryFg
                        font.family: Theme.fontFamily
                        font.pixelSize: miniVisuals.metaFontSize
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: root.pinnedProcesses.slice(0, root.maxVisiblePins)
                        RowLayout {
                            required property var modelData
                            objectName: "taskManagerMiniPinnedRow"
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.controlHeight
                            spacing: Theme.spaceSm
                            Accessible.role: Accessible.Grouping
                            Accessible.name: modelData.name + ", CPU " + Logic.metric(modelData.cpuTotalPercent, "%") + ", memory " + Logic.bytes(modelData.rss)
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: miniVisuals.primaryFg
                                font.family: Theme.fontFamily
                                font.pixelSize: miniVisuals.metaFontSize
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.preferredWidth: Theme.fontSize * 5
                                horizontalAlignment: Text.AlignRight
                                text: Logic.metric(modelData.cpuTotalPercent, "%")
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: miniVisuals.metaFontSize
                            }
                            Text {
                                Layout.preferredWidth: Theme.fontSize * 6
                                horizontalAlignment: Text.AlignRight
                                text: Logic.bytes(modelData.rss)
                                color: miniVisuals.secondaryFg
                                font.family: Theme.fontFamily
                                font.pixelSize: miniVisuals.metaFontSize
                            }
                        }
                    }
                    Text {
                        objectName: "taskManagerMiniMorePins"
                        visible: root.pinnedProcesses.length > root.maxVisiblePins
                        text: "+" + (root.pinnedProcesses.length - root.maxVisiblePins) + " pinned"
                        color: miniVisuals.secondaryFg
                        font.family: Theme.fontFamily
                        font.pixelSize: miniVisuals.metaFontSize
                    }
                }
            }
        }
    }
}
