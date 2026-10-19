// Keep the activation strip local to the middle fifth of each output.
function trigger(width, height) {
    return {x: width * 0.4, y: height - 4, width: width * 0.2, height: 4}
}

// Bound the complete target and animated envelope, including icon lift headroom.
function envelope(width, height, targetWidth, targetHeight, currentWidth, currentHeight, headroom) {
    var span = Math.min(width, Math.max(targetWidth, currentWidth))
    var rise = Math.min(height, Math.max(targetHeight, currentHeight) + headroom)
    return {x: (width - span) / 2, y: height - rise, width: span, height: rise}
}

// Blend neighboring icons smoothly around a pointer in fixed slot coordinates.
function hoverInfluence(pointerX, center, radius) {
    if (!isFinite(pointerX) || radius <= 0) return 0
    var weight = Math.max(0, 1 - Math.abs(pointerX - center) / radius)
    return weight * weight * (3 - 2 * weight)
}
