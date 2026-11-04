import QtQuick
import Quickshell
import "services"
import "components/taskmanager/glassgrid"

ShellRoot {
    id: root
    property int step: 0
    property int truncated: 0
    property int checks: 0
    readonly property var widths: [220, 268, 308, 332]
    // Sample geometry and fonts independently from live collectors.
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 400
        Item {
            id: card
            width: root.widths[root.step % root.widths.length]
            height: 160
            TaskManagerVisuals { id: visuals }
            TaskMetricPresentation {
                id: metric
                visuals: visuals
                expansionProgress: 1
                memory: ({percent: 45, used: 7408816128, availableBytes: 9038495744,
                    cache: 3221225472, swapUsed: 936378368, swapTotal: 12884901888})
            }
        }
    }
    // Find real rendered rows rather than duplicating the width calculation.
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children || []) {
            var found = find(child, name)
            if (found) return found
        }
        return null
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            var value = root.find(metric, "focusMemorySwap")
            var gauge = root.find(metric, "taskWaterGauge")
            var row = value.parent
            var details = row.parent
            console.info("METRIC_GEOMETRY " + JSON.stringify({width: card.width, font: Theme.fontSize,
                gauge: gauge.width, details: details.width, value: value.width,
                text: value.contentWidth, truncated: value.truncated}))
            if (value.truncated || value.width < 0 || details.width < 0
                    || value.x < row.children[0].x + row.children[0].width) {
                console.error("Metric layout failed: overlapping or truncated telemetry")
                Qt.exit(1)
                return
            }
            if (value.truncated) root.truncated++
            root.checks++
            root.step++
            if (root.step % root.widths.length === 0) Theme.fontSize += 4
            if (root.step === 12) {
                console.info("Metric layout sampled: " + root.truncated + "/" + root.checks + " truncated")
                Qt.quit()
            }
        }
    }
}
