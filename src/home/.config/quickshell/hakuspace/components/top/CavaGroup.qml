import QtQuick
import "../../services"
import ".."

TopModule {
    id: root

    readonly property string waveStyle: ShellSettingsStore.cavaStyle || "box"
    readonly property string styleLabel: waveStyle === "pill" ? "Pill" : (waveStyle === "fluid" ? "Fluid" : "Box")
    readonly property real fixedSlotWidth: Math.round(Theme.fontSize * 7.5)

    implicitWidth: verticalPresentation ? ScreenGeometry.leftModuleTouchSize : (fixedSlotWidth + (hovered ? 20 : 0))
    readonly property real hoverSafeWidth: fixedSlotWidth + 20

    visible: CenterState.centerMode === "media" && Cava.available && Cava.audioVisible
    text: root.waveStyle === "box" ? (Media.playing && Cava.bars !== "" ? Cava.bars : Array(Cava.barCount + 1).join("▁")) : ""
    tooltip: Media.playing ? ("Audio Visualizer (" + styleLabel + ") · Click to switch") : "Media paused"

    function cycleStyle() {
        var styles = ["box", "pill", "fluid"]
        var nextIndex = (styles.indexOf(waveStyle) + 1) % styles.length
        var nextStyle = styles[nextIndex]
        ShellSettingsStore.setValue("topbar", "cavaStyle", nextStyle)
        ShellSettingsStore.apply(["topbar.cavaStyle"])
    }

    onClicked: cycleStyle()

    Row {
        id: pillRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(3, Math.round((root.visualHeight - maxH) * 0.5))
        spacing: 3
        visible: root.waveStyle === "pill"
        readonly property real maxH: Math.max(12, root.visualHeight - 8)

        Repeater {
            model: Cava.barCount
            Rectangle {
                id: pillBar
                required property int index
                readonly property real level: (Media.playing && Cava.levels && Cava.levels.length > index) ? Cava.levels[index] : 0.0
                width: 3.5
                height: Math.max(3, Math.round(pillRow.maxH * level))
                radius: width * 0.5
                color: root.foregroundColor
                anchors.bottom: parent.bottom
                Behavior on height {
                    NumberAnimation {
                        duration: 60
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    Canvas {
        id: fluidCanvas
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(3, Math.round((root.visualHeight - height) * 0.5))
        width: Math.round(Theme.fontSize * 5.8)
        height: Math.max(12, Math.round(root.visualHeight - 8))
        visible: root.waveStyle === "fluid"
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        Connections {
            target: Cava
            function onLevelsChanged() {
                if (root.visible && root.waveStyle === "fluid") {
                    fluidCanvas.requestPaint()
                }
            }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width
            var h = height
            var levels = (Cava.levels && Cava.levels.length >= 12 && Media.playing) ? Cava.levels : []
            var count = 12

            var minBase = 2.0
            var targetMaxH = h - 2.0
            var points = []

            for (var i = 0; i < count; ++i) {
                var px = i * (w / (count - 1))
                var val = (levels.length > i) ? levels[i] : 0.0
                var waveH = minBase + val * (targetMaxH - minBase)
                var py = Math.max(1.0, h - waveH)
                points.push({ x: px, y: py })
            }

            // Draw fluid ink shape grounded at the bottom baseline and rising upward
            ctx.beginPath()
            ctx.moveTo(points[0].x, points[0].y)

            var tension = 0.4
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

            ctx.lineTo(w, h)
            ctx.lineTo(0, h)
            ctx.closePath()

            // Solid opaque ink fill
            ctx.fillStyle = root.foregroundColor
            ctx.fill()
        }
    }
}
