.pragma library

// Keep malformed runtime coordinates from producing invalid masks or panel bounds.
function finite(value) { return Number.isFinite(value) ? value : 0; }

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

// Expose the pure functions to the repository's Node geometry tests.
if (typeof module !== "undefined") module.exports = {rect, horizontalBounds, localizeRect, maskRadius};
