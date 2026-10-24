// Clamp the image center so the square crop never contains an empty edge.
function center(value, imageExtent, viewportExtent) {
    var halfOverflow = Math.max(0, (imageExtent - viewportExtent) / 2)
    return Math.max(-halfOverflow, Math.min(halfOverflow, value))
}

// Scale the decoded image to cover the crop before applying user zoom.
function cover(width, height, viewport) {
    return Math.max(viewport / Math.max(1, width), viewport / Math.max(1, height))
}
