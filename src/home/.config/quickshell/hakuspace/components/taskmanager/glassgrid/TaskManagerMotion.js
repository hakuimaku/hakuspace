.pragma library

function clamp01(value) {
    if (value === null || value === undefined || !Number.isFinite(value)) return 0
    return Math.max(0, Math.min(1, value))
}

function segment(progress, start, end) {
    var p = clamp01(progress)
    if (end <= start) return p >= end ? 1 : 0
    if (p <= start) return 0
    if (p >= end) return 1
    return (p - start) / (end - start)
}

function lerp(a, b, t) {
    var s = Number.isFinite(a) ? a : 0
    var e = Number.isFinite(b) ? b : 0
    return s + (e - s) * clamp01(t)
}

function lerpRect(r1, r2, t) {
    var p = clamp01(t)
    var s = r1 || { x: 0, y: 0, width: 0, height: 0 }
    var e = r2 || { x: 0, y: 0, width: 0, height: 0 }
    return {
        x: lerp(s.x, e.x, p),
        y: lerp(s.y, e.y, p),
        width: lerp(s.width, e.width, p),
        height: lerp(s.height, e.height, p)
    }
}

function reversibleDuration(baseMs, currentProgress, targetProgress, reducedMotion) {
    if (reducedMotion) return 0
    var base = Number.isFinite(baseMs) ? baseMs : 0
    var delta = Math.abs(clamp01(targetProgress) - clamp01(currentProgress))
    return Math.max(0, Math.round(base * delta))
}
