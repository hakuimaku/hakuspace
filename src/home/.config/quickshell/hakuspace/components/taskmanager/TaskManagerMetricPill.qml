import QtQuick
import "../../services"
import "../../config/UiCatalog.js" as Catalog
import "TaskManagerLogic.js" as Logic

Rectangle {
    id: root
    objectName: "taskManagerMetricPill"

    required property string metricId
    property var snapshot: ({})
    property var history: TaskManagerService.history
    property bool inOverlay: false
    property bool showUsed: false
    property bool dismissConfirm: false
    property bool hovered: false
    property bool pressed: false
    property bool reducedMotion: false

    readonly property string iconGlyph: metricId === "cpu" ? Catalog.taskManagerIcons.cpu
        : metricId === "gpu" ? Catalog.taskManagerIcons.gpu
        : Catalog.taskManagerIcons.memory

    readonly property string historyKey: metricId === "cpu" ? "cpu"
        : metricId === "gpu" ? "gpu"
        : "memory"

    readonly property real rawPercent: {
        if (metricId === "cpu") {
            var c = snapshot && snapshot.cpu ? snapshot.cpu : ({})
            return Number.isFinite(c.usage) ? c.usage : NaN
        }
        if (metricId === "gpu") {
            var gpus = snapshot && Array.isArray(snapshot.gpus) ? snapshot.gpus : []
            var g = gpus[0] || ({})
            return Number.isFinite(g.usage) ? g.usage : NaN
        }
        var m = snapshot && snapshot.memory ? snapshot.memory : ({})
        return Number.isFinite(m.percent) ? m.percent : NaN
    }

    readonly property string valueText: Number.isFinite(rawPercent) ? Math.round(rawPercent) + "%" : "—"
    readonly property string usedValueText: {
        if (metricId === "ram") {
            var m = snapshot && snapshot.memory ? snapshot.memory : ({})
            return Number.isFinite(m.used) ? Logic.bytes(m.used) : "—"
        }
        if (metricId === "gpu") {
            var gpus = snapshot && Array.isArray(snapshot.gpus) ? snapshot.gpus : []
            var g = gpus[0] || ({})
            if (g.memoryType === "shared") return "Shared"
            if (Number.isFinite(g.memoryUsed)) return Logic.bytes(g.memoryUsed)
            if (Number.isFinite(g.temperatureC)) return Math.round(g.temperatureC) + " °C"
            return "—"
        }
        var c = snapshot && snapshot.cpu ? snapshot.cpu : ({})
        var freqRaw = c.frequencyHighestMHz !== undefined && c.frequencyHighestMHz !== null
            ? c.frequencyHighestMHz
            : (c.frequencyMHz !== undefined && c.frequencyMHz !== null ? c.frequencyMHz : c.frequencyAverageMHz)
        var hasTemp = Number.isFinite(c.temperatureC)
        var hasFreq = Number.isFinite(freqRaw) && freqRaw > 0
        if (hasTemp && hasFreq) {
            var freqShort = freqRaw >= 1000 ? (freqRaw / 1000).toFixed(1) + "G" : Math.round(freqRaw) + "M"
            return Math.round(c.temperatureC) + "°C · " + freqShort
        }
        if (hasTemp) return Math.round(c.temperatureC) + " °C"
        if (hasFreq) return freqRaw >= 1000 ? (freqRaw / 1000).toFixed(1) + " GHz" : Math.round(freqRaw) + " MHz"
        return "—"
    }
    readonly property string displayValueText: (root.inOverlay && root.showUsed) ? usedValueText : valueText
    readonly property int horizontalInset: Math.max(Theme.taskMetricPillPaddingX, Math.round(height * 0.46))

    readonly property int sparklineWindowMs: 30000
    readonly property var sparklineSeries: {
        var src = root.history
        if (!Array.isArray(src) || src.length === 0) return []
        var latestT = src[src.length - 1].t
        if (!Number.isFinite(latestT)) return []
        var cutoff = latestT - sparklineWindowMs
        var out = []
        for (var i = 0; i < src.length; i++) {
            var sample = src[i]
            if (!sample || !Number.isFinite(sample.t) || sample.t < cutoff) continue
            var val = sample[root.historyKey]
            if (val !== null && val !== undefined && Number.isFinite(val)) {
                out.push({ t: sample.t, v: Math.max(0, Math.min(100, val)) })
            }
        }
        return out
    }

    onSparklineSeriesChanged: pillSparkline.requestPaint()
    onRawPercentChanged: pillSparkline.requestPaint()
    onInOverlayChanged: pillSparkline.requestPaint()

    Connections {
        target: Theme
        function onAccentChanged() { pillSparkline.requestPaint() }
        function onOnAccentColorChanged() { pillSparkline.requestPaint() }
        function onIsLightChanged() { pillSparkline.requestPaint() }
    }

    border.width: 0
    radius: height / 2
    color: inOverlay ? Theme.surface : Theme.accent
    clip: true

    scale: pressed && !reducedMotion ? 0.985 : (hovered && !reducedMotion ? 1.05 : 1.0)

    Behavior on color {
        enabled: !root.reducedMotion
        ColorAnimation {
            duration: HAnimation.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.moduleCurve
        }
    }

    Behavior on scale {
        enabled: !root.reducedMotion
        NumberAnimation {
            duration: root.hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
        }
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: root.metricId.toUpperCase() + " " + root.displayValueText

    Item {
        id: metricContent
        anchors.fill: parent
        anchors.leftMargin: root.horizontalInset
        anchors.rightMargin: root.horizontalInset
        opacity: (root.inOverlay && root.dismissConfirm) ? 0.0 : 1.0

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: HAnimation.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }

        Text {
            id: pillIcon
            objectName: "taskManagerMetricPillIcon"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconGlyph
            color: root.inOverlay ? Theme.accent : Theme.onAccentColor
            font.family: Theme.iconFontFamily
            font.pixelSize: Math.max(32, Math.round(Math.min(root.height * 0.7, Theme.fontSize * Theme.taskMetricPillIconFactor)))
            Accessible.ignored: true

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.fast }
            }
        }

        Canvas {
            id: pillSparkline
            objectName: "taskManagerMetricPillSparkline"
            anchors {
                left: pillIcon.right
                right: pillValue.left
                leftMargin: Theme.spaceMd
                rightMargin: Theme.spaceMd
                verticalCenter: parent.verticalCenter
            }
            height: Math.max(12, Math.round(root.height * 0.46))
            opacity: (root.inOverlay && root.showUsed) ? 0.0 : 1.0
            renderTarget: Canvas.Image
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            Behavior on opacity {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: HAnimation.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.moduleCurve
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                if (width <= 4 || height <= 4) return

                var pad = 1.5
                var w = width - pad * 2
                var h = height - pad * 2
                var series = root.sparklineSeries
                var pts = []

                if (series.length >= 2) {
                    var latestT = series[series.length - 1].t
                    var startT = latestT - root.sparklineWindowMs
                    for (var i = 0; i < series.length; i++) {
                        var ratioX = Math.max(0, Math.min(1, (series[i].t - startT) / root.sparklineWindowMs))
                        var ratioY = Math.max(0, Math.min(1, series[i].v / 100.0))
                        pts.push({ x: pad + ratioX * w, y: pad + h - ratioY * h })
                    }
                } else {
                    var fallbackPct = Number.isFinite(root.rawPercent) ? Math.max(0, Math.min(100, root.rawPercent)) : 0
                    var fy = pad + h - (fallbackPct / 100.0) * h
                    pts.push({ x: pad, y: fy })
                    pts.push({ x: pad + w, y: fy })
                }

                var strokeCol = root.inOverlay
                    ? Qt.alpha(Theme.accent, 0.88)
                    : Qt.alpha(Theme.onAccentColor, 0.80)
                var fillCol = root.inOverlay
                    ? Qt.alpha(Theme.accent, 0.16)
                    : Qt.alpha(Theme.onAccentColor, 0.16)

                ctx.beginPath()
                ctx.moveTo(pts[0].x, pad + h)
                for (var k = 0; k < pts.length; k++) ctx.lineTo(pts[k].x, pts[k].y)
                ctx.lineTo(pts[pts.length - 1].x, pad + h)
                ctx.closePath()
                ctx.fillStyle = fillCol.toString()
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var m = 1; m < pts.length; m++) ctx.lineTo(pts[m].x, pts[m].y)
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.strokeStyle = strokeCol.toString()
                ctx.stroke()
            }
        }

        Text {
            id: pillValue
            objectName: "taskManagerMetricPillValue"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: (root.inOverlay && root.showUsed)
                ? Math.min(implicitWidth, Math.max(0, metricContent.width - pillIcon.width - Theme.spaceSm))
                : implicitWidth
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: root.displayValueText
            color: root.inOverlay ? Theme.fg : Theme.onAccentColor
            font.family: Theme.fontFamily
            font.pixelSize: (root.inOverlay && root.showUsed)
                ? Math.max(13, Math.round(root.height * 0.31))
                : Math.max(15, Math.round(Math.min(root.height * 0.39, Theme.fontSize * Theme.taskMetricPillValueFactor)))
            font.bold: true
            Accessible.ignored: true

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.fast }
            }
        }
    }

    Text {
        id: trashIcon
        objectName: "taskManagerMetricPillTrash"
        anchors.centerIn: parent
        visible: root.inOverlay
        opacity: (root.inOverlay && root.dismissConfirm) ? 1.0 : 0.0
        scale: (root.inOverlay && root.dismissConfirm) ? 1.0 : 0.85
        text: Catalog.taskManagerIcons.trash
        color: Theme.danger
        font.family: Theme.iconFontFamily
        font.pixelSize: Math.max(20, Math.round(root.height * 0.52))
        Accessible.ignored: true

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: HAnimation.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }

        Behavior on scale {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: HAnimation.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.moduleCurve
            }
        }
    }
}
