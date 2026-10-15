.pragma library

function rect(x, y, width, height) {
    return { x: x, y: y, width: Math.max(0, width), height: Math.max(0, height) }
}

function inflate(r, margin) {
    return rect(r.x - margin, r.y - margin, r.width + margin * 2, r.height + margin * 2)
}

function contains(r, x, y) {
    return r.width > 0 && r.height > 0 && x >= r.x && x < r.x + r.width
        && y >= r.y && y < r.y + r.height
}

function containsAny(rects, x, y) {
    return rects.some(function(r) { return contains(r, x, y) })
}

function unionBounds(a, b) {
    if (!a.width || !a.height) return b
    if (!b.width || !b.height) return a
    var x = Math.min(a.x, b.x), y = Math.min(a.y, b.y)
    return rect(x, y, Math.max(a.x + a.width, b.x + b.width) - x,
                Math.max(a.y + a.height, b.y + b.height) - y)
}

function clampRect(r, width, height) {
    var x = Math.max(0, Math.min(width, Math.floor(r.x)))
    var y = Math.max(0, Math.min(height, Math.floor(r.y)))
    if (!r.width || !r.height) return rect(x, y, 0, 0)
    return rect(x, y, Math.max(0, Math.min(width, Math.ceil(r.x + r.width)) - x),
                Math.max(0, Math.min(height, Math.ceil(r.y + r.height)) - y))
}

function horizontalBridge(a, b, thickness) {
    var left = a.x + a.width <= b.x ? a : b
    var right = left === a ? b : a
    var overlapTop = Math.max(a.y, b.y)
    var overlapBottom = Math.min(a.y + a.height, b.y + b.height)
    var center = overlapTop <= overlapBottom ? (overlapTop + overlapBottom) / 2
        : (left.y + left.height / 2 + right.y + right.height / 2) / 2
    return rect(left.x + left.width, center - thickness / 2,
                Math.max(0, right.x - left.x - left.width), thickness)
}

function verticalBridge(a, b, thickness) {
    var top = a.y + a.height <= b.y ? a : b
    var bottom = top === a ? b : a
    var overlapLeft = Math.max(a.x, b.x)
    var overlapRight = Math.min(a.x + a.width, b.x + b.width)
    var center = overlapLeft <= overlapRight ? (overlapLeft + overlapRight) / 2
        : (top.x + top.width / 2 + bottom.x + bottom.width / 2) / 2
    return rect(center - thickness / 2, top.y + top.height,
                thickness, Math.max(0, bottom.y - top.y - top.height))
}

function orthogonalBridge(a, b, thickness) {
    if (Math.max(a.y, b.y) <= Math.min(a.y + a.height, b.y + b.height))
        return [horizontalBridge(a, b, thickness)]
    if (Math.max(a.x, b.x) <= Math.min(a.x + a.width, b.x + b.width))
        return [verticalBridge(a, b, thickness)]
    var ax = a.x + a.width / 2, ay = a.y + a.height / 2
    var bx = b.x + b.width / 2, by = b.y + b.height / 2
    var startX = bx >= ax ? a.x + a.width : a.x
    var endY = by >= ay ? b.y : b.y + b.height
    return [rect(Math.min(startX, bx), ay - thickness / 2,
                 Math.abs(bx - startX) + thickness / 2, thickness),
            rect(bx - thickness / 2, Math.min(ay, endY),
                 thickness, Math.abs(endY - ay) + thickness / 2)]
}

function sweptEnvelope(fromRect, toRect, margin) {
    return inflate(unionBounds(fromRect, toRect), margin)
}
