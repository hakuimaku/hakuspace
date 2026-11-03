import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"
import "../../settings" as Settings

Rectangle {
    id: root
    property var cpu: ({})
    property var visuals
    property bool compact: false
    property bool ultraCompact: false
    property bool reducedMotion: false

    property int hoveredCoreIndex: -1
    property bool tooltipVisible: false
    property int tooltipCoreIndex: -1
    onTooltipVisibleChanged: if (tooltipVisible) tooltipCoreIndex = hoveredCoreIndex
    readonly property int hoverDelayMs: 250

    readonly property var cores: Array.isArray(cpu.cores) ? cpu.cores.slice(0, 32) : []
    readonly property int gridColumns: Math.min(6, Math.max(4, Math.ceil(cores.length / 2)))
    readonly property var freqMHz: {
        if (Number.isFinite(cpu.frequencyHighestMHz)) return cpu.frequencyHighestMHz
        if (Number.isFinite(cpu.frequencyMHz)) return cpu.frequencyMHz
        if (Number.isFinite(cpu.frequencyAverageMHz)) return cpu.frequencyAverageMHz
        return null
    }
    readonly property string loadText: {
        var load = cpu.load
        if (!Array.isArray(load) || !load.length) return "—"
        return load.slice(0, 3).map(v => Number.isFinite(v) ? v.toFixed(2) : "—").join(" / ")
    }

    function formatCoreTooltip(index) {
        if (index < 0 || index >= root.cores.length) return ""
        var raw = root.cores[index]
        var digits = (Number.isFinite(raw) && Math.abs(raw - Math.round(raw)) < 0.05) ? 0 : 1
        return "Core " + index + " · " + visuals.dashMetric(raw, "%", digits)
    }

    // Keep the hovered core highlighted while a conventional tooltip waits.
    function handleCoreHover(index, active) {
        if (active) {
            hoveredCoreIndex = index
            if (!tooltipVisible) tooltipTimer.restart()
        } else if (hoveredCoreIndex === index) clearCoreTooltip()
    }

    // Release pending hover state when the card is hidden or the pointer leaves.
    function clearCoreTooltip() {
        tooltipTimer.stop()
        tooltipVisible = false
        hoveredCoreIndex = -1
    }
    onVisibleChanged: if (!visible) clearCoreTooltip()

    Timer {
        id: tooltipTimer
        interval: root.hoverDelayMs
        onTriggered: root.tooltipVisible = root.hoveredCoreIndex >= 0 && root.hoveredCoreIndex < root.cores.length
    }

    objectName: "taskCpuCard"
    radius: Theme.radius
    border.width: 0
    color: visuals.cardSurface
    clip: true

    Accessible.role: Accessible.Grouping
    Accessible.name: "CPU " + visuals.dashMetric(cpu.usage, "%")

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: visuals.cpuCardPadding(root.height * 3.6, root.width * 3)
        spacing: root.ultraCompact ? 3 : 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                text: "CPU"
                color: visuals.primaryFg
                font.pixelSize: root.ultraCompact ? visuals.sectionTitleSize - 1 : visuals.sectionTitleSize
            }

            Label {
                visible: root.cores.length > 0
                text: "· " + root.cores.length + " cores"
                color: Theme.fgMuted
                font.pixelSize: root.ultraCompact ? visuals.metaFontSize - 1 : visuals.metaFontSize
            }

            Item { Layout.fillWidth: true }

            Label {
                objectName: "taskCpuHeroValue"
                text: visuals.dashMetric(root.cpu.usage, "%")
                color: Theme.accent
                font.bold: true
                font.pixelSize: root.ultraCompact ? visuals.heroFontSize - 2 : (root.compact ? visuals.heroFontSize - 1 : visuals.heroFontSize)
            }
        }

        TaskMetricBar {
            Layout.fillWidth: true
            implicitHeight: 3
            value: visuals.clampPercent(root.cpu.usage)
            available: Number.isFinite(root.cpu.usage)
            reducedMotion: root.reducedMotion
            trackColor: visuals.trackSurface
            fillColor: visuals.barFill
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.compact ? 8 : 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: "Freq"
                    color: Theme.fgMuted
                    font.pixelSize: root.ultraCompact ? visuals.metaFontSize - 1 : visuals.metaFontSize
                    visible: !root.ultraCompact
                }
                Label {
                    objectName: "taskCpuFreqValue"
                    Layout.fillWidth: true
                    text: visuals.dashMetric(root.freqMHz, " MHz", 0)
                    color: visuals.primaryFg
                    font.pixelSize: root.ultraCompact ? visuals.bodyFontSize - 1 : visuals.bodyFontSize
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: "Temp"
                    color: Theme.fgMuted
                    font.pixelSize: root.ultraCompact ? visuals.metaFontSize - 1 : visuals.metaFontSize
                    visible: !root.ultraCompact
                }
                Label {
                    objectName: "taskCpuTempValue"
                    Layout.fillWidth: true
                    text: visuals.dashMetric(root.cpu.temperatureC, " °C")
                    color: visuals.primaryFg
                    font.pixelSize: root.ultraCompact ? visuals.bodyFontSize - 1 : visuals.bodyFontSize
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: "Load"
                    color: Theme.fgMuted
                    font.pixelSize: root.ultraCompact ? visuals.metaFontSize - 1 : visuals.metaFontSize
                    visible: !root.ultraCompact
                }
                Label {
                    objectName: "taskCpuLoadValue"
                    Layout.fillWidth: true
                    text: root.loadText
                    color: visuals.primaryFg
                    font.pixelSize: root.ultraCompact ? visuals.bodyFontSize - 1 : visuals.bodyFontSize
                    elide: Text.ElideRight
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Keep hit targets larger than the rendered core bars.
        GridLayout {
            id: coreGrid
            objectName: "taskCpuCoreGrid"
            Layout.fillWidth: true
            visible: root.cores.length > 0
            columns: root.gridColumns
            rowSpacing: root.ultraCompact ? 1 : 2
            columnSpacing: root.ultraCompact ? 5 : 7

            Repeater {
                id: coreRepeater
                model: root.cores.length
                Item {
                    id: coreCell
                    required property int index
                    readonly property var rawUsage: root.cores[index]
                    readonly property real coreUsage: visuals.clampPercent(rawUsage)
                    readonly property bool isHovered: coreHover.hovered || root.hoveredCoreIndex === index
                    readonly property string tooltipText: root.formatCoreTooltip(index)

                    objectName: "cpuCoreCell_" + index
                    Layout.fillWidth: true
                    implicitHeight: root.ultraCompact ? 11 : 15

                    Accessible.role: Accessible.Indicator
                    Accessible.name: "Core " + index + ", " + Math.round(coreUsage) + " percent"
                    Accessible.description: tooltipText

                    HoverHandler {
                        id: coreHover
                        onHoveredChanged: root.handleCoreHover(coreCell.index, hovered)
                    }

                    Rectangle {
                        id: coreTrack
                        objectName: "cpuCoreTrack_" + coreCell.index
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: root.ultraCompact ? 3 : 4
                        radius: height / 2
                        border.width: 0
                        color: coreCell.isHovered ? visuals.hoverSurface : visuals.trackSurface
                        clip: true

                        Rectangle {
                            objectName: "cpuCoreFill_" + coreCell.index
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.round(parent.width * (coreCell.coreUsage / 100))
                            radius: parent.radius
                            border.width: 0
                            color: coreCell.isHovered ? Theme.accent : visuals.coreIdleFill
                            Behavior on width {
                                enabled: !root.reducedMotion
                                NumberAnimation {
                                    duration: HAnimation.taskBarFillDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: HAnimation.moduleCurve
                                }
                            }
                            Behavior on color {
                                enabled: !root.reducedMotion
                                ColorAnimation { duration: HAnimation.fast }
                            }
                        }
                    }
                }
            }
        }
    }

    // Reuse the lightweight popup style rather than the bar's Flare tooltip host.
    Settings.SettingsTooltip {
        objectName: "cpuCoreTooltip"
        // Keep the popup parent stable while its anchor follows the highlighted core.
        readonly property Item coreCell: root.tooltipCoreIndex >= 0 ? coreRepeater.itemAt(root.tooltipCoreIndex) : null
        readonly property point anchor: coreCell ? coreCell.mapToItem(root, coreCell.width / 2, coreCell.height) : Qt.point(0, 0)
        target: root
        x: Math.max(0, Math.min(root.width - width, anchor.x - width / 2))
        y: anchor.y + Theme.spaceXs
        text: root.formatCoreTooltip(root.tooltipCoreIndex)
        active: root.tooltipVisible && coreCell !== null
        immediate: true
        // Preserve the text and anchor until the fade-out has completed.
        onClosed: if (!root.tooltipVisible) root.tooltipCoreIndex = -1
        enter: Transition {
            NumberAnimation {
                property: "opacity"; from: 0; to: 1
                duration: root.reducedMotion ? 0 : HAnimation.fast
                easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.tooltipCurve
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"; from: 1; to: 0
                duration: root.reducedMotion ? 0 : HAnimation.fast
                easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.tooltipCurve
            }
        }
    }
}
