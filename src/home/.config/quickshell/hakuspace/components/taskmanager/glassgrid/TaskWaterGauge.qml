import QtQuick
import "../../../services"

Item {
    id: root
    objectName: "taskWaterGauge"

    // Bind metric identity and values as one telemetry sample.
    property var sample: null

    // Support standalone gauge previews.
    property string metricId: ""
    property real value: 0
    property bool available: true
    property real wavePhase: 0.0
    property real diameter: 84
    property bool showNumeric: false
    property bool interactive: true
    property bool reducedMotion: false
    // Change only the painted emphasis; telemetry and the wave clock remain independent.
    property bool emphasized: false
    onEmphasizedChanged: canvas.requestPaint()
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

    onMetricIdChanged: if (!sample) _applySample({ metricId: metricId, value: value, available: available })
    onValueChanged: if (!sample) _applySample({ metricId: metricId, value: value, available: available })
    onAvailableChanged: if (!sample) _applySample({ metricId: metricId, value: value, available: available })

    Component.onCompleted: {
        if (sample) {
            _applySample(sample)
        } else if (metricId !== "" || value !== 0) {
            _applySample({ metricId: metricId, value: value, available: available })
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

    // Keep telemetry independent of card expansion.
    readonly property real fillRatio: Math.max(0, Math.min(1.0, displayValue / 100.0))
    // Surrounding cards place this reading outside the water surface.
    readonly property string percentText: currentAvailable && Number.isFinite(displayValue) ? Math.round(displayValue) + "%" : "—"

    onWavePhaseChanged: canvas.requestPaint()
    onDisplayValueChanged: canvas.requestPaint()
    onFillRatioChanged: canvas.requestPaint()
    onDiameterChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    // Repaint theme colors even when the wave clock is paused.
    Connections {
        target: Theme
        function onIsLightChanged() { canvas.requestPaint() }
        function onAccentChanged() { canvas.requestPaint() }
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
            // Keep the thicker stroke inside the existing outer edge.
            var r = Math.min(cx, cy) - 2.5
            if (r <= 0) return

            ctx.save()

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.clip()

            ctx.fillStyle = Theme.isLight ? "#cecac3" : "#16151b"
            ctx.fill()

            if (root.currentAvailable && root.fillRatio > 0.001) {
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
                ctx.fillStyle = Qt.alpha(Theme.accent, root.emphasized ? 0.45 : 0.35)
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
                ctx.fillStyle = Theme.accent
                ctx.fill()
            }

            ctx.restore()

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.lineWidth = 3.5
            ctx.strokeStyle = root.emphasized ? Qt.alpha(Theme.accent, 0.45) : (Theme.isLight ? "#aba59c" : "#36353d")
            ctx.stroke()
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
