// Keep all edit coordinates on the oriented full image, independent of viewport size.
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }

// Map a normalized point through one visible quarter turn or mirror.
function transformPoint(point, operation) {
    point = {x: clamp(point.x, 0, 1), y: clamp(point.y, 0, 1)}
    if (operation === "cw") return {x: 1 - point.y, y: point.x}
    if (operation === "ccw") return {x: point.y, y: 1 - point.x}
    if (operation === "horizontal") return {x: 1 - point.x, y: point.y}
    return {x: point.x, y: 1 - point.y}
}

// Transform all corners so crop bounds remain axis-aligned after orientation changes.
function transformRect(rect, operation) {
    var points = [{x: rect.x, y: rect.y}, {x: rect.x + rect.width, y: rect.y + rect.height}]
        .map(function(point) { return transformPoint(point, operation) })
    return {x: Math.min(points[0].x, points[1].x), y: Math.min(points[0].y, points[1].y),
        width: Math.abs(points[1].x - points[0].x), height: Math.abs(points[1].y - points[0].y)}
}

// Fit the largest centered crop of a pixel aspect ratio inside normalized bounds.
function ratioRect(rect, ratio, width, height) {
    if (!ratio) return rect
    var w = rect.width, h = rect.height
    if (w * width / (h * height) > ratio) w = h * height * ratio / width
    else h = w * width / ratio / height
    return {x: rect.x + (rect.width - w) / 2, y: rect.y + (rect.height - h) / 2, width: w, height: h}
}

// Construct a bounded drag crop with its aspect ratio expressed in image pixels.
function dragRect(start, end, ratio, width, height) {
    var rect = {x: Math.min(start.x, end.x), y: Math.min(start.y, end.y),
        width: Math.abs(end.x - start.x), height: Math.abs(end.y - start.y)}
    return ratioRect(rect, ratio, width, height)
}

// Measure a segment in viewport pixels for selection and endpoint handles.
function segmentDistance(point, start, end, width, height) {
    var dx = (end.x - start.x) * width, dy = (end.y - start.y) * height
    var px = (point.x - start.x) * width, py = (point.y - start.y) * height
    var t = clamp((px * dx + py * dy) / (dx * dx + dy * dy || 1), 0, 1)
    return Math.hypot(px - t * dx, py - t * dy)
}

// Match backend boundary rounding and report the actual resized output dimensions.
function outputSize(rect, width, height, scale, avatar) {
    if (avatar) return {width: 512, height: 512}
    var w = Math.round((rect.x + rect.width) * width) - Math.round(rect.x * width)
    var h = Math.round((rect.y + rect.height) * height) - Math.round(rect.y * height)
    return {width: Math.max(1, Math.round(w * scale)), height: Math.max(1, Math.round(h * scale))}
}

// Prefer corners, then edges, with a forgiving hit area on either side of the crop border.
function cropHandle(point, rect, width, height, slop) {
    var x = point.x * width, y = point.y * height
    var left = rect.x * width, right = (rect.x + rect.width) * width
    var top = rect.y * height, bottom = (rect.y + rect.height) * height
    if (x < left - slop || x > right + slop || y < top - slop || y > bottom + slop) return ""
    var horizontal = Math.min(Math.abs(x - left), Math.abs(x - right)) <= slop
        ? (Math.abs(x - left) <= Math.abs(x - right) ? "w" : "e") : ""
    var vertical = Math.min(Math.abs(y - top), Math.abs(y - bottom)) <= slop
        ? (Math.abs(y - top) <= Math.abs(y - bottom) ? "n" : "s") : ""
    return vertical + horizontal || "move"
}

// Resize against the opposite edge/corner; ratio-constrained edges expand around their center.
function resizeCrop(rect, handle, point, ratio, width, height) {
    var west = handle.indexOf("w") >= 0, east = handle.indexOf("e") >= 0
    var north = handle.indexOf("n") >= 0, south = handle.indexOf("s") >= 0
    var left = rect.x, right = rect.x + rect.width, top = rect.y, bottom = rect.y + rect.height
    if (!ratio) {
        if (west) left = clamp(point.x, 0, right - 1 / width)
        if (east) right = clamp(point.x, left + 1 / width, 1)
        if (north) top = clamp(point.y, 0, bottom - 1 / height)
        if (south) bottom = clamp(point.y, top + 1 / height, 1)
        return {x: left, y: top, width: right - left, height: bottom - top}
    }
    var anchorX = west ? right : left, anchorY = north ? bottom : top
    var centerX = (left + right) / 2, centerY = (top + bottom) / 2
    var cropWidth, cropHeight, maximum
    if ((west || east) && (north || south)) {
        maximum = Math.min((west ? anchorX : 1 - anchorX) * width,
            (north ? anchorY : 1 - anchorY) * height * ratio)
        cropWidth = clamp(Math.max((west ? anchorX - point.x : point.x - anchorX) * width,
            (north ? anchorY - point.y : point.y - anchorY) * height * ratio), Math.min(Math.max(1, ratio), maximum), maximum)
        cropHeight = cropWidth / ratio
        return {x: west ? anchorX - cropWidth / width : anchorX,
            y: north ? anchorY - cropHeight / height : anchorY, width: cropWidth / width, height: cropHeight / height}
    }
    if (west || east) {
        maximum = Math.min((west ? anchorX : 1 - anchorX) * width, 2 * Math.min(centerY, 1 - centerY) * height * ratio)
        cropWidth = clamp((west ? anchorX - point.x : point.x - anchorX) * width, Math.min(Math.max(1, ratio), maximum), maximum)
        cropHeight = cropWidth / ratio
        return {x: west ? anchorX - cropWidth / width : anchorX, y: centerY - cropHeight / height / 2,
            width: cropWidth / width, height: cropHeight / height}
    }
    maximum = Math.min((north ? anchorY : 1 - anchorY) * height, 2 * Math.min(centerX, 1 - centerX) * width / ratio)
    cropHeight = clamp((north ? anchorY - point.y : point.y - anchorY) * height, Math.min(Math.max(1, 1 / ratio), maximum), maximum)
    cropWidth = cropHeight * ratio
    return {x: centerX - cropWidth / width / 2, y: north ? anchorY - cropHeight / height : anchorY,
        width: cropWidth / width, height: cropHeight / height}
}
