import QtQuick
import QtQuick.Controls
import "../../../services"
import "TaskManagerMotion.js" as Motion

Item {
    id: root

    // Bind metric identity and values as one telemetry sample.
    property var sample: null

    // Support standalone gauge previews.
    property string metricId: ""
    property real value: 0
    property bool available: true
    property string mainText: ""
    property string secondaryText: ""
    property string usedText: ""
    property string totalText: ""
    property string unit: "%"
    property real expansionProgress: 0.0
    property real wavePhase: 0.0
    property real diameter: 84
    property bool showNumeric: false
    property bool interactive: true
    property bool reducedMotion: false
    signal showNumericToggled(bool showNumeric)

    width: diameter
    height: diameter

    property string activeMetricId: ""
    property real displayValue: 0.0
    property bool _hasActiveSample: false

    function _applySample(s) {
        if (!s) return
        var mid = s.metricId || ""
        var avail = (typeof s.available !== "undefined") ? !!s.available : true
        var rawVal = Number(s.value)
        var targetVal = (avail && Number.isFinite(rawVal)) ? Math.max(0, Math.min(100, rawVal)) : 0

        if (!_hasActiveSample || mid !== activeMetricId) {
            // Snap on metric changes to avoid animating between unrelated values.
            telemetryAnim.stop()
            activeMetricId = mid
            displayValue = targetVal
            _hasActiveSample = true
            canvas.requestPaint()
            return
        }

        var diff = Math.abs(displayValue - targetVal)
        if (diff < 0.001) {
            return
        }

        if (!root.reducedMotion) {
            telemetryAnim.stop()
            telemetryAnim.from = displayValue
            telemetryAnim.to = targetVal
            telemetryAnim.start()
        } else {
            telemetryAnim.stop()
            displayValue = targetVal
            canvas.requestPaint()
        }
    }

    onSampleChanged: _applySample(sample)

    onMetricIdChanged: if (!sample) _applySample({ metricId: metricId, value: value, available: available, usedText: usedText, totalText: totalText })
    onValueChanged: if (!sample) _applySample({ metricId: metricId, value: value, available: available, usedText: usedText, totalText: totalText })
    onAvailableChanged: if (!sample) _applySample({ metricId: metricId, value: value, available: available, usedText: usedText, totalText: totalText })

    Component.onCompleted: {
        if (sample) {
            _applySample(sample)
        } else if (metricId !== "" || value !== 0) {
            _applySample({ metricId: metricId, value: value, available: available, usedText: usedText, totalText: totalText })
        }
    }

    NumberAnimation {
        id: telemetryAnim
        target: root
        property: "displayValue"
        duration: HAnimation.taskBarFillDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.moduleCurve
        onRunningChanged: if (!running) canvas.requestPaint()
    }

    readonly property bool currentAvailable: sample ? (typeof sample.available !== "undefined" ? !!sample.available : true) : available
    readonly property string currentUsedText: sample ? (sample.usedText || "") : usedText
    readonly property string currentTotalText: sample ? (sample.totalText || "") : totalText

    // Keep telemetry independent of card expansion.
    readonly property real fillRatio: Math.max(0, Math.min(1.0, displayValue / 100.0))
    readonly property real fillY: {
        var r = (diameter / 2) - 1.5
        var cy = diameter / 2
        return (cy + r) - (2.0 * r * fillRatio)
    }

    // Remove byte units from compact value labels.
    function stripUnits(str) {
        if (!str) return "—"
        var m = String(str).match(/^([\d.,]+)/)
        return m ? m[1] : str.replace(/\s*[A-Za-z/]+$/, "").trim()
    }

    readonly property string percentText: currentAvailable && Number.isFinite(displayValue) ? Math.round(displayValue) + "%" : "—"
    readonly property string usedNumberOnly: stripUnits(currentUsedText)

    readonly property string focusText: {
        if (!currentAvailable) return "—"
        if (showNumeric) {
            return usedNumberOnly !== "" ? usedNumberOnly : percentText
        }
        return percentText
    }

    onWavePhaseChanged: canvas.requestPaint()
    onDisplayValueChanged: canvas.requestPaint()
    onFillRatioChanged: canvas.requestPaint()
    onDiameterChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Connections {
        target: Theme
        function onIsLightChanged() { canvas.requestPaint() }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width
            var h = height
            if (w <= 0 || h <= 0) return

            var cx = w / 2
            var cy = h / 2
            var r = Math.min(cx, cy) - 1.5
            if (r <= 0) return

            ctx.save()

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.clip()

            ctx.fillStyle = Theme.isLight ? "#cecac3" : "#16151b"
            ctx.fill()

            if (root.available && root.fillRatio > 0.001) {
                var ratio = root.fillRatio
                var waterY = (cy + r) - (2.0 * r * ratio)
                var amp = (ratio <= 0.025 || ratio >= 0.975) ? 0.6 : Math.max(1.2, Math.min(3.2, r * 0.065))

                // Back wave.
                ctx.beginPath()
                ctx.moveTo(cx - r, cy + r)
                for (var x = cx - r; x <= cx + r; x += 3) {
                    var relX = (x - (cx - r)) / (2 * r)
                    var wy1 = waterY + amp * Math.sin(relX * Math.PI * 2.2 + root.wavePhase + 1.2)
                    ctx.lineTo(x, wy1)
                }
                ctx.lineTo(cx + r, cy + r)
                ctx.closePath()
                ctx.fillStyle = Theme.isLight ? Qt.alpha("#000000", 0.09) : Qt.alpha("#ffffff", 0.10)
                ctx.fill()

                // Front wave.
                ctx.beginPath()
                ctx.moveTo(cx - r, cy + r)
                for (var x2 = cx - r; x2 <= cx + r; x2 += 3) {
                    var relX2 = (x2 - (cx - r)) / (2 * r)
                    var wy2 = waterY + amp * Math.sin(relX2 * Math.PI * 2.2 + root.wavePhase)
                    ctx.lineTo(x2, wy2)
                }
                ctx.lineTo(cx + r, cy + r)
                ctx.closePath()
                ctx.fillStyle = Theme.isLight ? Qt.alpha("#000000", 0.16) : Qt.alpha("#ffffff", 0.20)
                ctx.fill()
            }

            ctx.restore()

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.lineWidth = 1.5
            ctx.strokeStyle = Theme.isLight ? "#aba59c" : "#36353d"
            ctx.stroke()
        }
    }

    // Clip text colors at the current waterline.
    Item {
        id: airViewport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(0, Math.min(root.height, root.fillY))
        clip: true

        Item {
            width: root.width
            height: root.height
            anchors.top: parent.top

            Label {
                id: airMainLabel
                anchors.centerIn: parent
                text: root.focusText
                color: Theme.isLight ? "#111015" : "#ffffff"
                font.bold: true
                font.pixelSize: Math.max(12, Math.round(root.diameter * 0.25))
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: waterViewport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, Math.min(root.height, root.fillY))
        height: Math.max(0, root.height - root.fillY)
        clip: true

        Item {
            width: root.width
            height: root.height
            y: -waterViewport.anchors.topMargin

            Label {
                id: waterMainLabel
                anchors.centerIn: parent
                text: root.focusText
                color: Theme.isLight ? "#111015" : "#ffffff"
                font.bold: true
                font.pixelSize: Math.max(12, Math.round(root.diameter * 0.25))
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: root.interactive
        onClicked: {
            if (root.interactive) {
                root.showNumeric = !root.showNumeric
                root.showNumericToggled(root.showNumeric)
            }
        }
    }
}
