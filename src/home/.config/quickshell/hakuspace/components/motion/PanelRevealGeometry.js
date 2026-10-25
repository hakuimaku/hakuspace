.pragma library

// Clockwise anchors: top-left, top, top-right, right, bottom-right, bottom, bottom-left, left.
var directions = [[-1, -1], [0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0]]

// Resolve one of the eight attachment points inside the available screen bounds.
function anchor(position, bounds) {
    // Reject positions outside the public one-based anchor map.
    var direction = directions[position - 1]
    if (!direction) throw new Error("Panel reveal position must be an integer from 1 to 8")
    return {x: bounds.x + (direction[0] + 1) * bounds.width / 2,
            y: bounds.y + (direction[1] + 1) * bounds.height / 2}
}

// Widen a full-length connection to a centered chassis without translating either endpoint.
function neck(position, bounds, body, progress, width) {
    // Keep the attachment fixed on the chosen edge or corner.
    var origin = anchor(position, bounds)
    // Follow the chassis center independently of its changing size.
    var center = {x: body.x + body.width / 2, y: body.y + body.height / 2}
    if (progress <= 0 || progress >= 1 || body.width <= 0 || body.height <= 0)
        return {anchor: origin, center: center, path: ""}
    // Normalize the diagonal so width is measured perpendicular to its length.
    var distance = Math.max(1, Math.hypot(center.x - origin.x, center.y - origin.y))
    // Keep the two flanks symmetric around the fixed attachment-to-center line.
    var normal = {x: -(center.y - origin.y) / distance, y: (center.x - origin.x) / distance}
    // Pinch the rail contact as the chassis reaches its full size.
    var base = Math.min(width / 2, body.width / 2, body.height / 2) * (1 - progress)
    // End the wider shoulder inside the chassis so the surfaces overlap.
    var shoulder = Math.min(body.width, body.height) * 0.5 * (1 - progress)

    // Bound every Bezier control point so the neck cannot paint across a status bar.
    function point(t, offset) {
        return Math.max(bounds.x, Math.min(bounds.x + bounds.width,
            origin.x + (center.x - origin.x) * t + normal.x * offset)) + " "
            + Math.max(bounds.y, Math.min(bounds.y + bounds.height,
            origin.y + (center.y - origin.y) * t + normal.y * offset))
    }

    return {anchor: origin, center: center,
        path: "M " + point(0, base)
            + " C " + point(0.35, base) + " " + point(0.65, shoulder) + " " + point(1, shoulder)
            + " L " + point(1, -shoulder)
            + " C " + point(0.65, -shoulder) + " " + point(0.35, -base) + " " + point(0, -base)
            + " L " + origin.x + " " + origin.y + " Z"}
}
