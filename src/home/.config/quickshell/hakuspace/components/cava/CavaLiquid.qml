import QtQuick
import "../../services"

Item {
    id: root

    property var bars: CavaService.bars
    property real amplitude: CavaService.amplitude
    property real motionStrength: CavaService.motionStrength
    readonly property bool isSurfaceMode: CavaService.colorMode === "surface"
    property color inkColor: isSurfaceMode ? Theme.surface : Theme.accent
    property real inkOpacity: isSurfaceMode ? 1.0 : 0.80
    property bool showCrestLine: true
    property color crestColor: isSurfaceMode ? Qt.lighter(Theme.surface, 1.8) : Theme.accent
    property real crestOpacity: isSurfaceMode ? 0.75 : 0.95

    readonly property bool isTop: AppState.cavaTopState
    readonly property bool sleeping: CavaService.sleeping
    readonly property real overallEnergy: CavaService.overallEnergy
    readonly property real bassEnergy: CavaService.bassEnergy
    readonly property real midEnergy: CavaService.midEnergy
    readonly property real trebleEnergy: CavaService.trebleEnergy

    // Wake morph animation
    property real wakeProgress: 1.0

    onSleepingChanged: {
        if (!sleeping) {
            wakeAnimation.restart()
        }
        canvas.requestPaint()
    }

    NumberAnimation {
        id: wakeAnimation
        target: root
        property: "wakeProgress"
        from: 0.0
        to: 1.0
        duration: 180
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }

    onBarsChanged: canvas.requestPaint()
    onIsSurfaceModeChanged: canvas.requestPaint()
    onInkColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = width
            var h = height
            var barList = root.bars
            var count = barList ? barList.length : 0

            if (count < 2 || w <= 0 || h <= 0) return

            var wake = root.wakeProgress
            var motion = root.motionStrength
            var amp = root.amplitude * motion * wake
            var bassMod = root.bassEnergy * 0.25 * motion
            var trebleMod = root.trebleEnergy * 0.15 * motion
            var isTopMode = root.isTop

            // Construct array of points along the spectrum ridge
            var points = []
            var dx = w / (count - 1)
            var minBaseline = 3.5

            for (var i = 0; i < count; ++i) {
                var px = i * dx
                var rawVal = barList[i] || 0.0

                // Bass swell around the center indices
                var centerDist = Math.abs((i / (count - 1)) - 0.5) * 2.0 // 0 at center, 1 at edge
                var centerBassBoost = (1.0 - centerDist) * bassMod

                // Small micro-ripple driven by treble towards edges
                var edgeRipple = centerDist * trebleMod * ((i % 2 === 0) ? 0.5 : -0.5)

                var val = Math.max(0.0, Math.min(1.0, rawVal + centerBassBoost + edgeRipple))
                var peakH = val * (h - 4) * amp + minBaseline
                var py = isTopMode ? peakH : (h - peakH)

                points.push({ x: px, y: py })
            }

            // Draw smooth fluid surface using Cardinal / Catmull-Rom spline
            ctx.beginPath()
            ctx.moveTo(points[0].x, points[0].y)

            var tension = 0.5
            for (var j = 0; j < points.length - 1; ++j) {
                var p0 = (j > 0) ? points[j - 1] : points[j]
                var p1 = points[j]
                var p2 = points[j + 1]
                var p3 = (j < points.length - 2) ? points[j + 2] : p2

                var cp1x = p1.x + (p2.x - p0.x) * tension / 3.0
                var cp1y = p1.y + (p2.y - p0.y) * tension / 3.0
                var cp2x = p2.x - (p3.x - p1.x) * tension / 3.0
                var cp2y = p2.y - (p3.y - p1.y) * tension / 3.0

                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y)
            }

            // Close down to the base edge of the window
            if (isTopMode) {
                ctx.lineTo(w, 0)
                ctx.lineTo(0, 0)
            } else {
                ctx.lineTo(w, h)
                ctx.lineTo(0, h)
            }
            ctx.closePath()

            // Fill solid ink body
            ctx.fillStyle = Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, root.inkOpacity)
            ctx.fill()

            // Subtle crest line along the top ridge
            if (root.showCrestLine) {
                ctx.beginPath()
                ctx.moveTo(points[0].x, points[0].y)
                for (var k = 0; k < points.length - 1; ++k) {
                    var q0 = (k > 0) ? points[k - 1] : points[k]
                    var q1 = points[k]
                    var q2 = points[k + 1]
                    var q3 = (k < points.length - 2) ? points[k + 2] : q2

                    var c1x = q1.x + (q2.x - q0.x) * tension / 3.0
                    var c1y = q1.y + (q2.y - q0.y) * tension / 3.0
                    var c2x = q2.x - (q3.x - q1.x) * tension / 3.0
                    var c2y = q2.y - (q3.y - q1.y) * tension / 3.0

                    ctx.bezierCurveTo(c1x, c1y, c2x, c2y, q2.x, q2.y)
                }
                ctx.strokeStyle = Qt.rgba(root.crestColor.r, root.crestColor.g, root.crestColor.b, root.crestOpacity)
                ctx.lineWidth = 1.5
                ctx.stroke()
            }
        }
    }
}
