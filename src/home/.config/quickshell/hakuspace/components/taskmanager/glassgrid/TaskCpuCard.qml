import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"
import "TaskManagerMotion.js" as Motion

Rectangle {
    id: root
    property var cpu: ({})
    property var visuals
    property bool compact: false
    property bool ultraCompact: false
    property bool reducedMotion: false

    property int hoveredCoreIndex: -1
    property bool tooltipVisible: false
    property int hoverDelayMs: 280
    property real stemProgress: 0.0
    property real unfurlProgress: 0.0

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

    function _openTooltipWithMotion() {
        tooltipCloseAnim.stop()
        root.tooltipVisible = true
        if (root.reducedMotion) {
            tooltipOpenAnim.stop()
            root.stemProgress = 1.0
            root.unfurlProgress = 1.0
        } else if (!tooltipOpenAnim.running && (root.stemProgress < 1.0 || root.unfurlProgress < 1.0)) {
            tooltipOpenAnim.restart()
        }
    }

    function _closeTooltipWithMotion() {
        tooltipOpenAnim.stop()
        root.tooltipVisible = false
        if (root.reducedMotion) {
            tooltipCloseAnim.stop()
            root.stemProgress = 0.0
            root.unfurlProgress = 0.0
            root.hoveredCoreIndex = -1
        } else {
            tooltipCloseAnim.restart()
        }
    }

    function handleCoreHover(index, active) {
        if (active) {
            leaveTimer.stop()
            root.hoveredCoreIndex = index
            if (root.tooltipVisible) {
                tooltipTimer.stop()
                tooltipCloseAnim.stop()
                root.stemProgress = 1.0
                root.unfurlProgress = 1.0
            } else {
                tooltipTimer.restart()
            }
        } else if (root.hoveredCoreIndex === index) {
            tooltipTimer.stop()
            leaveTimer.restart()
        }
    }

    function showCoreTooltip(index) {
        tooltipTimer.stop()
        leaveTimer.stop()
        tooltipOpenAnim.stop()
        tooltipCloseAnim.stop()
        if (index >= 0 && index < root.cores.length) {
            root.hoveredCoreIndex = index
            root.tooltipVisible = true
            root.stemProgress = 1.0
            root.unfurlProgress = 1.0
        } else {
            root.hoveredCoreIndex = -1
            root.tooltipVisible = false
            root.stemProgress = 0.0
            root.unfurlProgress = 0.0
        }
    }

    function setCoreTooltipMotion(index, stemP, unfurlP) {
        tooltipTimer.stop()
        leaveTimer.stop()
        tooltipOpenAnim.stop()
        tooltipCloseAnim.stop()
        if (index >= 0 && index < root.cores.length) {
            root.hoveredCoreIndex = index
            root.tooltipVisible = true
            root.stemProgress = Motion.clamp01(stemP)
            root.unfurlProgress = Motion.clamp01(unfurlP)
        } else {
            root.hoveredCoreIndex = -1
            root.tooltipVisible = false
            root.stemProgress = 0.0
            root.unfurlProgress = 0.0
        }
    }

    function clearCoreTooltip() {
        tooltipTimer.stop()
        leaveTimer.stop()
        tooltipOpenAnim.stop()
        tooltipCloseAnim.stop()
        root.hoveredCoreIndex = -1
        root.tooltipVisible = false
        root.stemProgress = 0.0
        root.unfurlProgress = 0.0
    }

    Timer {
        id: tooltipTimer
        interval: root.hoverDelayMs
        repeat: false
        onTriggered: {
            if (root.hoveredCoreIndex >= 0 && root.hoveredCoreIndex < root.cores.length) {
                root._openTooltipWithMotion()
            }
        }
    }

    Timer {
        id: leaveTimer
        interval: 35
        repeat: false
        onTriggered: root._closeTooltipWithMotion()
    }

    SequentialAnimation {
        id: tooltipOpenAnim
        NumberAnimation {
            target: root
            property: "stemProgress"
            to: 1.0
            duration: HAnimation.taskTooltipStemDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.taskTooltipCurve
        }
        NumberAnimation {
            target: root
            property: "unfurlProgress"
            to: 1.0
            duration: HAnimation.taskTooltipUnfurlDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.taskTooltipCurve
        }
    }

    SequentialAnimation {
        id: tooltipCloseAnim
        NumberAnimation {
            target: root
            property: "unfurlProgress"
            to: 0.0
            duration: Math.round(HAnimation.taskTooltipUnfurlDuration * 0.72)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.taskDropdownCloseCurve
        }
        NumberAnimation {
            target: root
            property: "stemProgress"
            to: 0.0
            duration: Math.round(HAnimation.taskTooltipStemDuration * 0.72)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.taskDropdownCloseCurve
        }
        ScriptAction {
            script: if (!root.tooltipVisible) root.hoveredCoreIndex = -1
        }
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

    // Hover stem.
    Rectangle {
        id: coreTooltipStem
        objectName: "cpuCoreTooltipStem"
        z: 49
        readonly property int fullStemHeight: 5
        readonly property real targetStemX: Math.round(coreTooltip.cellPos.x - width / 2)
        visible: (root.tooltipVisible || root.stemProgress > 0) && root.hoveredCoreIndex >= 0
        width: 2
        height: Math.round(fullStemHeight * root.stemProgress)
        radius: 1
        border.width: 0
        x: targetStemX
        y: Math.round(coreTooltip.cellPos.y - height)
        color: Theme.accent
        Behavior on x {
            enabled: !root.reducedMotion && root.tooltipVisible
            NumberAnimation {
                duration: HAnimation.taskTooltipSlideDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.taskTooltipCurve
            }
        }
    }

    // Reveal the tooltip by clipping its geometry.
    Rectangle {
        id: coreTooltip
        objectName: "cpuCoreTooltip"
        z: 50
        readonly property Item targetCell: (root.hoveredCoreIndex >= 0 && root.hoveredCoreIndex < coreRepeater.count)
            ? coreRepeater.itemAt(root.hoveredCoreIndex)
            : null
        readonly property point cellPos: targetCell ? targetCell.mapToItem(root, targetCell.width / 2, 0) : Qt.point(root.width / 2, root.height - 28)
        readonly property string text: root.formatCoreTooltip(root.hoveredCoreIndex)
        readonly property int fullWidth: tooltipLabel.implicitWidth + 18
        readonly property int fullHeight: tooltipLabel.implicitHeight + 10
        readonly property real targetBaseX: Math.max(8, Math.min(root.width - fullWidth - 8, Math.round(cellPos.x - fullWidth / 2)))
        property real animatedBaseX: targetBaseX
        Behavior on animatedBaseX {
            enabled: !root.reducedMotion && root.tooltipVisible
            NumberAnimation {
                duration: HAnimation.taskTooltipSlideDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.taskTooltipCurve
            }
        }

        visible: (root.tooltipVisible || root.unfurlProgress > 0) && root.hoveredCoreIndex >= 0 && text !== "" && width > 0
        width: Math.round(fullWidth * root.unfurlProgress)
        height: fullHeight
        x: Math.round(animatedBaseX + (fullWidth - width) / 2)
        y: Math.max(4, Math.round(cellPos.y - height - coreTooltipStem.fullStemHeight))
        radius: 6
        border.width: 0
        color: visuals.popupSurface
        clip: true

        Item {
            x: -(coreTooltip.x - Math.round(coreTooltip.animatedBaseX))
            y: 0
            width: coreTooltip.fullWidth
            height: coreTooltip.fullHeight

            Label {
                id: tooltipLabel
                objectName: "cpuCoreTooltipLabel"
                anchors.centerIn: parent
                text: coreTooltip.text
                color: visuals.primaryFg
                font.family: Theme.fontFamily
                font.pixelSize: visuals.metaFontSize
            }
        }
    }
}
