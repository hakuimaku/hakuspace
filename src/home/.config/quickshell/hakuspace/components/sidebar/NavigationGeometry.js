.pragma library

// Place the utility rail next to the radial controller without rotating its controls.
function rail(horizontal, diameter, thickness, length, screenWidth, screenHeight) {
    var origin = Math.round(diameter * 0.94)
    return horizontal
        ? {x: origin, y: 0, width: Math.max(1, Math.min(length, screenWidth - origin - 24)), height: thickness}
        : {x: 0, y: origin, width: thickness, height: Math.max(1, Math.min(length, 520, screenHeight - origin - 40))}
}

// Build a real corridor between the radial body and the rail on its current axis.
function bridge(horizontal, diameter, railRect) {
    var center = diameter / 2
    return horizontal
        ? {x: center, y: 0, width: Math.max(1, railRect.x + Math.min(24, railRect.width * 0.1) - center), height: Math.max(railRect.height, center)}
        : {x: 0, y: center, width: Math.max(railRect.width, center), height: Math.max(1, railRect.y + Math.min(24, railRect.height * 0.1) - center)}
}

// Left dividers point to 12/4/8 o’clock; semantic indices stay stable across layouts.
function regions(edge) {
    if (edge === "left") return [
        {key: "dashboard", icon: "", startDeg: 150, endDeg: 270, labelAngle: 210, labelRadius: 0.46, offsetX: -5, offsetY: 0},
        {key: "sidebar", icon: "", startDeg: 270, endDeg: 390, labelAngle: 330, labelRadius: 0.50, offsetX: 0, offsetY: 0},
        {key: "settings", icon: "", startDeg: 30, endDeg: 150, labelAngle: 90, labelRadius: 0.50, offsetX: 0, offsetY: 0}
    ]
    var items = [
        {key: "dashboard", icon: "", startDeg: 210, endDeg: 330, labelAngle: 270, labelRadius: 0.46, offsetX: -5, offsetY: 0},
        {key: "sidebar", icon: "", startDeg: 90, endDeg: 210,
            labelAngle: 150, labelRadius: 0.50, offsetX: -4, offsetY: 0},
        {key: "settings", icon: "", startDeg: 330, endDeg: 450,
            labelAngle: 30, labelRadius: 0.50, offsetX: 0, offsetY: 0}
    ]
    return edge !== "bottom" ? items : items.map(function(item) {
        var start = ((-item.endDeg % 360) + 360) % 360
        return Object.assign({}, item, {startDeg: start, endDeg: start + 120,
            labelAngle: ((-item.labelAngle % 360) + 360) % 360, offsetY: -item.offsetY})
    })
}
