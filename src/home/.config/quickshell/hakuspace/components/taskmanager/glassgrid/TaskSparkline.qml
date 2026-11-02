import QtQuick
import "../../../services"

Item {
    id: root
    property var history: []
    property string primaryKey: "memory"
    property string secondaryKey: ""
    property real fixedMax: 0
    property color strokeColor: Qt.alpha(Theme.accent, Theme.isLight ? 0.82 : 0.86)
    property color secondaryStrokeColor: Qt.alpha(Theme.overlayInk, Theme.isLight ? 0.42 : 0.48)
    property color fillColor: Qt.alpha(Theme.accent, Theme.isLight ? 0.10 : 0.12)

    // Keep a fixed time axis when telemetry cadence changes or sampling pauses.
    readonly property int windowMs: 30000
    readonly property real latestTime: history.length ? history[history.length - 1].t : 0
    readonly property var windowHistory: Array.isArray(history)
        ? history.filter(sample => Number.isFinite(sample.t) && sample.t >= latestTime - windowMs) : []

    readonly property var primarySeries: {
        var src = root.windowHistory
        var out = []
        for (var i = 0; i < src.length; i++) {
            var item = src[i]
            var v = item ? item[root.primaryKey] : null
            if (v !== null && v !== undefined && Number.isFinite(v)) out.push({t: item.t, v: Math.max(0, v)})
        }
        return out
    }

    readonly property var secondarySeries: {
        if (!root.secondaryKey) return []
        var src = root.windowHistory
        var out = []
        for (var i = 0; i < src.length; i++) {
            var item = src[i]
            var v = item ? item[root.secondaryKey] : null
            if (v !== null && v !== undefined && Number.isFinite(v)) out.push({t: item.t, v: Math.max(0, v)})
        }
        return out
    }

    readonly property bool usable: primarySeries.length >= 2 || secondarySeries.length >= 2
    visible: usable
    implicitHeight: 22

    onPrimarySeriesChanged: canvas.requestPaint()
    onSecondarySeriesChanged: canvas.requestPaint()
    onStrokeColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 4 || height <= 4 || !root.usable) return

            var p = root.primarySeries
            var s = root.secondarySeries
            var maxVal = root.fixedMax > 0 ? root.fixedMax : 1
            if (root.fixedMax <= 0) {
                for (var i = 0; i < p.length; i++) if (p[i].v > maxVal) maxVal = p[i].v
                for (var j = 0; j < s.length; j++) if (s[j].v > maxVal) maxVal = s[j].v
            }

            var drawLine = function(series, stroke, fill) {
                if (series.length < 2) return
                var pad = 1.5
                var w = width - pad * 2
                var h = height - pad * 2
                ctx.beginPath()
                for (var idx = 0; idx < series.length; idx++) {
                    var x = pad + (series[idx].t - root.latestTime + root.windowMs) / root.windowMs * w
                    var ratio = Math.max(0, Math.min(1, series[idx].v / maxVal))
                    var y = pad + h - ratio * h
                    if (idx === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.strokeStyle = stroke.toString()
                ctx.lineWidth = 1.1
                ctx.stroke()

                if (fill) {
                    ctx.lineTo(pad + w, pad + h)
                    ctx.lineTo(pad + (series[0].t - root.latestTime + root.windowMs) / root.windowMs * w, pad + h)
                    ctx.closePath()
                    ctx.fillStyle = fill.toString()
                    ctx.fill()
                }
            }

            if (s.length >= 2) drawLine(s, root.secondaryStrokeColor, null)
            if (p.length >= 2) drawLine(p, root.strokeColor, root.fillColor)
        }
    }
}
