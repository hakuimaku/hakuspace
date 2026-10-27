import QtQuick
import "../../services"
import "ImageEditorGeometry.js" as Geometry
import "ImageEditorOps.js" as Ops

Canvas {
    id: root
    // Allocate annotation pixels only at viewport resolution, never source resolution.
    property var draft: null
    property int replacing: -1
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onDraftChanged: requestPaint()
    Connections {
        target: ImageEditor
        function onAnnotationsChanged() { root.requestPaint() }
        function onSelectedAnnotationChanged() { root.requestPaint() }
    }
    function draw(context, item) {
        var w = item.width * Math.min(width, height)
        context.strokeStyle = item.color; context.fillStyle = item.color
        context.globalAlpha = item.opacity; context.lineWidth = w
        context.lineCap = "round"; context.lineJoin = "round"
        context.beginPath()
        if (item.type === "arrow") {
            var sx = item.start.x * width, sy = item.start.y * height
            var ex = item.end.x * width, ey = item.end.y * height
            context.moveTo(sx, sy); context.lineTo(ex, ey); context.stroke()
            var angle = Math.atan2(ey - sy, ex - sx), length = w * 4
            context.beginPath(); context.moveTo(ex, ey)
            context.lineTo(ex - length * Math.cos(angle - 0.5), ey - length * Math.sin(angle - 0.5))
            context.lineTo(ex - length * Math.cos(angle + 0.5), ey - length * Math.sin(angle + 0.5))
            context.closePath(); context.fill()
        } else if (item.points.length === 1) {
            context.arc(item.points[0].x * width, item.points[0].y * height, w / 2, 0, Math.PI * 2); context.fill()
        } else {
            item.points.forEach(function(point, index) {
                if (!index) context.moveTo(point.x * width, point.y * height)
                else context.lineTo(point.x * width, point.y * height)
            })
            context.stroke()
        }
    }
    onPaint: {
        var context = getContext("2d")
        context.reset()
        ImageEditor.annotations.forEach(function(item, index) {
            if (index !== root.replacing || !root.draft) root.draw(context, item)
        })
        if (draft) draw(context, draft)
        var selected = draft && replacing >= 0 ? draft : ImageEditor.annotations[ImageEditor.selectedAnnotation]
        if (selected && selected.type === "arrow") {
            context.globalAlpha = 1; context.fillStyle = Theme.accent
            ;[selected.start, selected.end].forEach(function(point) {
                context.beginPath(); context.arc(point.x * root.width, point.y * root.height, 6, 0, Math.PI * 2); context.fill()
            })
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: ImageEditor.tool !== "crop" && ImageEditor.ready
        preventStealing: true
        property var start: null
        property var original: null
        property string endpoint: ""
        function point(mouse) { return {x: Geometry.clamp(mouse.x / width, 0, 1), y: Geometry.clamp(mouse.y / height, 0, 1)} }
        function hit(item, p) {
            var tolerance = Math.max(10, item.width * Math.min(width, height) / 2 + 4)
            if (item.type === "arrow") return Geometry.segmentDistance(p, item.start, item.end, width, height) <= tolerance
            for (var index = 0; index < item.points.length; ++index) {
                if (Geometry.segmentDistance(p, item.points[index], item.points[Math.max(0, index - 1)], width, height) <= tolerance) return true
            }
            return false
        }
        onPressed: mouse => {
            start = point(mouse); endpoint = ""; root.replacing = -1
            if (ImageEditor.tool === "select") {
                var selected = ImageEditor.annotations[ImageEditor.selectedAnnotation]
                if (selected && selected.type === "arrow") {
                    ;["start", "end"].forEach(function(key) {
                        if (Math.hypot((selected[key].x - start.x) * width, (selected[key].y - start.y) * height) < 14) endpoint = key
                    })
                }
                if (endpoint) root.replacing = ImageEditor.selectedAnnotation
                else {
                    for (var index = ImageEditor.annotations.length - 1; index >= 0; --index) {
                        if (hit(ImageEditor.annotations[index], start)) { root.replacing = index; break }
                    }
                }
                ImageEditor.selectedAnnotation = root.replacing
                original = root.replacing >= 0 ? Ops.copy(ImageEditor.annotations[root.replacing]) : null
                root.draft = original
            } else {
                ImageEditor.selectedAnnotation = -1
                var item = {type: ImageEditor.tool === "arrow" ? "arrow" : "stroke", color: ImageEditor.inkColor,
                    width: ImageEditor.inkWidth * (ImageEditor.tool === "marker" ? 3 : 1),
                    opacity: ImageEditor.inkOpacity * (ImageEditor.tool === "marker" ? 0.35 : 1)}
                if (item.type === "arrow") { item.start = start; item.end = start }
                else item.points = [start]
                root.draft = item
            }
        }
        onPositionChanged: mouse => {
            if (!pressed || !root.draft) return
            var p = point(mouse), item = root.draft
            if (ImageEditor.tool === "select") {
                item = Ops.copy(original)
                if (endpoint) item[endpoint] = p
                else {
                    var points = item.type === "arrow" ? [item.start, item.end] : item.points
                    var dx = p.x - start.x, dy = p.y - start.y
                    points.forEach(function(point) { dx = Geometry.clamp(dx, -point.x, 1 - point.x); dy = Geometry.clamp(dy, -point.y, 1 - point.y) })
                    points.forEach(function(point) { point.x += dx; point.y += dy })
                }
            } else if (item.type === "arrow") item.end = p
            else {
                var last = item.points[item.points.length - 1]
                if (Math.hypot((p.x - last.x) * width, (p.y - last.y) * height) < 2 || item.points.length >= 20000) return
                item.points.push(p)
            }
            root.draft = item
            root.requestPaint()
        }
        onReleased: {
            if (root.draft) {
                if (root.replacing >= 0) ImageEditor.replaceAnnotation(root.replacing, root.draft)
                else if (ImageEditor.tool !== "select") ImageEditor.addAnnotation(root.draft)
            }
            root.draft = null; root.replacing = -1; root.requestPaint()
        }
        onCanceled: { root.draft = null; root.replacing = -1; root.requestPaint() }
    }
}
