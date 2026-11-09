.pragma library

// PURE MATHEMATICAL GEOMETRY ENGINE:
// Must remain independent from QML runtime to ensure sub-second Node.js unit testing.
// Do NOT import QML singletons or extract algorithmic ratios into QML.

// Keep malformed runtime coordinates from producing invalid masks or panel bounds.
function finite(value) { return Number.isFinite(value) ? value : 0; }

// Keep paint, pointer slots and accessibility growth independent from Topbar metrics.
function leftMetrics(fontSize) {
    var icon = Math.ceil(Math.max(14, fontSize * 1.1));
    var visual = Math.max(30, icon + 14);
    var touch = Math.max(36, visual + 6);
    var gutter = 8;
    return {visual: visual, touch: touch, gutter: gutter, icon: icon,
        rail: Math.max(46, visual + gutter * 2), slot: touch, controlGap: 0,
        gap: Math.max(6, Math.ceil(fontSize / 3)), hover: (touch - visual) / 2};
}

// Return finite screen-local coordinates with nonnegative dimensions.
function rect(value) {
    value = value || {};
    return {x: finite(value.x), y: finite(value.y),
        width: Math.max(0, finite(value.width)), height: Math.max(0, finite(value.height))};
}

// Collapse very narrow screens safely when their two side insets overlap.
function horizontalBounds(width, inset) {
    width = Math.max(0, finite(width));
    inset = Math.min(width / 2, Math.max(0, finite(inset)));
    return {start: inset, end: width - inset};
}

// Clamp the physical corner envelope only at the rendering boundary.
function maskRadius(width, height, radius, inset) {
    return Math.max(0, Math.min(finite(radius), (finite(width) - 2 * finite(inset)) / 2,
        (finite(height) - finite(inset)) / 2));
}

// Intersect a screen-local anchor with its host and translate the result once.
function localizeRect(anchor, host) {
    anchor = rect(anchor);
    host = rect(host);
    var x = Math.max(0, Math.min(host.width, anchor.x - host.x));
    var y = Math.max(0, Math.min(host.height, anchor.y - host.y));
    return {x: x, y: y,
        width: Math.max(0, Math.min(host.width, anchor.x + anchor.width - host.x) - x),
        height: Math.max(0, Math.min(host.height, anchor.y + anchor.height - host.y) - y)};
}

// Map logical distances into upright top- or bottom-attached rectangles.
function attachedY(seam, height, distance, bottom) { return bottom ? seam - distance - height : seam + distance; }

// Keep the taskbar centered between asymmetric status lanes.
function centerSpan(width, leftEdge, rightEdge, gap) {
    return Math.max(0, 2 * Math.min(width / 2 - leftEdge - gap, rightEdge - gap - width / 2));
}

// Expose the pure functions to the repository's Node geometry tests.
if (typeof module !== "undefined") module.exports = {rect, horizontalBounds, localizeRect, maskRadius, attachedY, centerSpan, leftMetrics};
