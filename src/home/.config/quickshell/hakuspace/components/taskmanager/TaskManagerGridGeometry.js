.pragma library

// PURE MATHEMATICAL GEOMETRY ENGINE:
// Must remain independent from QML runtime to ensure sub-second Node.js unit testing.
// Do NOT import QML singletons or extract algorithmic ratios into QML.

function finite(value) {
    return Number.isFinite(value) ? value : 0
}

function pillDimensions(fontSize, spaceSm, spaceLg) {
    var fs = Math.max(10, finite(fontSize) || 14)
    var sm = Math.max(4, finite(spaceSm) || 8)
    var lg = Math.max(8, finite(spaceLg) || 16)
    return {
        width: Math.round(fs * 12.2 + lg),
        height: Math.round(fs * 3.15 + sm * 0.25)
    }
}

function usableArea(screenWidth, screenHeight, insets) {
    var cfg = insets || {}
    var pad = Math.max(0, finite(cfg.padding !== undefined ? cfg.padding : 12))
    var left = Math.max(0, finite(cfg.left)) + pad
    var top = Math.max(0, finite(cfg.top)) + pad
    var right = Math.max(0, finite(cfg.right)) + pad
    var bottom = Math.max(0, finite(cfg.bottom)) + pad
    var w = Math.max(0, finite(screenWidth) - left - right)
    var h = Math.max(0, finite(screenHeight) - top - bottom)
    return { x: left, y: top, width: w, height: h }
}

function clampPosition(rawX, rawY, pillSpec, usable) {
    var area = usable || { x: 0, y: 0, width: 1920, height: 1080 }
    var spec = pillSpec || {}
    var pw = Math.max(1, finite(spec.width) || 180)
    var ph = Math.max(1, finite(spec.height) || 46)
    var minX = finite(area.x)
    var minY = finite(area.y)
    var maxX = minX + Math.max(0, finite(area.width) - pw)
    var maxY = minY + Math.max(0, finite(area.height) - ph)
    return {
        x: Math.max(minX, Math.min(maxX, finite(rawX))),
        y: Math.max(minY, Math.min(maxY, finite(rawY)))
    }
}

function resolveMagneticPosition(rawX, rawY, pillSpec, usable, otherOverlays, options) {
    var area = usable || { x: 0, y: 0, width: 1920, height: 1080 }
    var spec = pillSpec || {}
    var pw = Math.max(1, finite(spec.width) || 180)
    var ph = Math.max(1, finite(spec.height) || 46)
    var opts = options || {}
    var gap = Math.max(0, finite(opts.gap !== undefined ? opts.gap : 8))
    var axisThreshold = Math.max(0, finite(opts.axisThreshold !== undefined ? opts.axisThreshold : 14))
    var gapThreshold = Math.max(0, finite(opts.gapThreshold !== undefined ? opts.gapThreshold : 18))
    var proximityLimit = Math.max(0, finite(opts.proximityLimit !== undefined ? opts.proximityLimit : pw * 2.5))

    var rx = finite(rawX)
    var ry = finite(rawY)
    var base = clampPosition(rx, ry, { width: pw, height: ph }, area)
    var x = base.x
    var y = base.y
    var snappedX = false
    var snappedY = false

    var rawList = Array.isArray(otherOverlays) ? otherOverlays : []
    var others = []
    for (var i = 0; i < rawList.length; i++) {
        var o = rawList[i]
        if (!o || finite(o.width) <= 0 || finite(o.height) <= 0) continue
        if (opts.movingMetricId && o.metricId === opts.movingMetricId) continue
        others.push({
            metricId: o.metricId || "",
            x: finite(o.x),
            y: finite(o.y),
            width: finite(o.width),
            height: finite(o.height)
        })
    }

    function fitsUsable(cand) {
        return cand.x >= finite(area.x) - 0.5
            && cand.y >= finite(area.y) - 0.5
            && cand.x + pw <= finite(area.x) + finite(area.width) + 0.5
            && cand.y + ph <= finite(area.y) + finite(area.height) + 0.5
    }

    function overlapsAny(cand) {
        var rect = { x: cand.x, y: cand.y, width: pw, height: ph }
        for (var j = 0; j < others.length; j++) {
            if (rectsOverlap(rect, others[j])) return true
        }
        return false
    }

    var bestAxisX = null
    var bestAxisY = null
    var bestPair = null

    for (var k = 0; k < others.length; k++) {
        var other = others[k]
        var dxEdge = Math.max(0, base.x - (other.x + other.width), other.x - (base.x + pw))
        var dyEdge = Math.max(0, base.y - (other.y + other.height), other.y - (base.y + ph))
        if (Math.hypot(dxEdge, dyEdge) > proximityLimit) continue

        var absDx = Math.abs(base.x - other.x)
        if (absDx <= axisThreshold && (!bestAxisX || absDx < bestAxisX.diff)) {
            bestAxisX = { x: other.x, diff: absDx }
        }

        var absDy = Math.abs(base.y - other.y)
        if (absDy <= axisThreshold && (!bestAxisY || absDy < bestAxisY.diff)) {
            bestAxisY = { y: other.y, diff: absDy }
        }

        if (absDx <= gapThreshold) {
            var diffAbove = Math.abs((base.y + ph + gap) - other.y)
            if (diffAbove <= gapThreshold) {
                var candAbove = { x: other.x, y: other.y - ph - gap, score: absDx + diffAbove }
                if (fitsUsable(candAbove) && !overlapsAny(candAbove) && (!bestPair || candAbove.score < bestPair.score)) {
                    bestPair = candAbove
                }
            }
            var diffBelow = Math.abs(base.y - (other.y + other.height + gap))
            if (diffBelow <= gapThreshold) {
                var candBelow = { x: other.x, y: other.y + other.height + gap, score: absDx + diffBelow }
                if (fitsUsable(candBelow) && !overlapsAny(candBelow) && (!bestPair || candBelow.score < bestPair.score)) {
                    bestPair = candBelow
                }
            }
        }

        if (absDy <= gapThreshold) {
            var diffLeft = Math.abs((base.x + pw + gap) - other.x)
            if (diffLeft <= gapThreshold) {
                var candLeft = { x: other.x - pw - gap, y: other.y, score: absDy + diffLeft }
                if (fitsUsable(candLeft) && !overlapsAny(candLeft) && (!bestPair || candLeft.score < bestPair.score)) {
                    bestPair = candLeft
                }
            }
            var diffRight = Math.abs(base.x - (other.x + other.width + gap))
            if (diffRight <= gapThreshold) {
                var candRight = { x: other.x + other.width + gap, y: other.y, score: absDy + diffRight }
                if (fitsUsable(candRight) && !overlapsAny(candRight) && (!bestPair || candRight.score < bestPair.score)) {
                    bestPair = candRight
                }
            }
        }
    }

    if (bestPair) {
        x = bestPair.x
        y = bestPair.y
        snappedX = true
        snappedY = true
    } else {
        if (bestAxisX) {
            x = bestAxisX.x
            snappedX = true
        }
        if (bestAxisY) {
            y = bestAxisY.y
            snappedY = true
        }
    }

    var clamped = clampPosition(x, y, { width: pw, height: ph }, area)
    x = clamped.x
    y = clamped.y

    if (overlapsAny({ x: x, y: y })) {
        function findAdjacentPlacement(anchorList) {
            var candidates = []
            for (var a = 0; a < anchorList.length; a++) {
                var anc = anchorList[a]
                var spots = [
                    { x: anc.x, y: anc.y + anc.height + gap },
                    { x: anc.x, y: anc.y - ph - gap },
                    { x: anc.x + anc.width + gap, y: anc.y },
                    { x: anc.x - pw - gap, y: anc.y }
                ]
                for (var s = 0; s < spots.length; s++) {
                    var pt = spots[s]
                    var distSq = (pt.x - rx) * (pt.x - rx) + (pt.y - ry) * (pt.y - ry)
                    candidates.push({ x: pt.x, y: pt.y, distSq: distSq })
                }
            }
            candidates.sort(function(p, q) { return p.distSq - q.distSq })
            for (var c = 0; c < candidates.length; c++) {
                if (fitsUsable(candidates[c]) && !overlapsAny(candidates[c])) {
                    return candidates[c]
                }
            }
            return null
        }

        var overlapped = []
        var curRect = { x: x, y: y, width: pw, height: ph }
        for (var m = 0; m < others.length; m++) {
            if (rectsOverlap(curRect, others[m])) overlapped.push(others[m])
        }

        var pushed = findAdjacentPlacement(overlapped) || findAdjacentPlacement(others)
        if (pushed) {
            var pushedClamped = clampPosition(pushed.x, pushed.y, { width: pw, height: ph }, area)
            x = pushedClamped.x
            y = pushedClamped.y
            snappedX = true
            snappedY = true
        }
    }

    var finalClamped = clampPosition(Math.round(x), Math.round(y), { width: pw, height: ph }, area)
    return {
        x: Math.round(finalClamped.x),
        y: Math.round(finalClamped.y),
        width: pw,
        height: ph,
        snappedX: snappedX,
        snappedY: snappedY
    }
}

function slotIndexAtY(localY, columnHeight, slotCount, spacing) {
    var count = Math.max(1, Math.round(finite(slotCount) || 3))
    var h = Math.max(1, finite(columnHeight))
    var gap = Math.max(0, finite(spacing))
    var slotH = Math.max(1, (h - gap * (count - 1)) / count)
    var idx = Math.floor((finite(localY) + gap / 2) / (slotH + gap))
    return Math.max(0, Math.min(count - 1, idx))
}

function reorderSlots(order, metricId, targetIndex) {
    if (!Array.isArray(order)) return ["cpu", "gpu", "ram"]
    var next = order.slice()
    var fromIndex = next.indexOf(metricId)
    if (fromIndex < 0) return next
    var toIndex = Math.max(0, Math.min(next.length - 1, Math.round(finite(targetIndex))))
    if (fromIndex === toIndex) return next
    next.splice(fromIndex, 1)
    next.splice(toIndex, 0, metricId)
    return next
}

function rectsOverlap(a, b) {
    if (!a || !b || a.width <= 0 || a.height <= 0 || b.width <= 0 || b.height <= 0) return false
    return a.x < b.x + b.width && a.x + a.width > b.x
        && a.y < b.y + b.height && a.y + a.height > b.y
}

if (typeof module !== "undefined") {
    module.exports = {
        pillDimensions: pillDimensions,
        usableArea: usableArea,
        clampPosition: clampPosition,
        resolveMagneticPosition: resolveMagneticPosition,
        slotIndexAtY: slotIndexAtY,
        reorderSlots: reorderSlots,
        rectsOverlap: rectsOverlap
    }
}
