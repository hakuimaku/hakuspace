// Fit a stable bottom-centered card above the Dock and below the upper chassis.
function finalRect(width, height, sideInset, topInset, bottomInset, dockHeight, gap) {
    var side = Math.min(Math.max(0, sideInset + gap), Math.max(0, (width - 1) / 2))
    var top = Math.min(Math.max(0, topInset), Math.max(0, height - 1))
    var bottom = Math.min(Math.max(0, bottomInset + dockHeight + gap), Math.max(0, height - top - 1))
    var cardWidth = Math.min(Math.max(360, width * 0.42), Math.max(1, width - side * 2))
    var cardHeight = Math.min(Math.max(260, height * 0.40), Math.max(1, height - top - bottom))
    return {x: (width - cardWidth) / 2, y: height - bottom - cardHeight, width: cardWidth, height: cardHeight}
}

// Preserve the captured artwork center or use a small bottom-center fallback capsule.
function seedRect(anchor, width, height, iconSize, bottomInset, gap, target) {
    var size = Math.max(1, Math.min(iconSize, target.width, target.height,
        anchor ? Math.min(anchor.width, anchor.height) : iconSize))
    var x = anchor ? anchor.x + anchor.width / 2 - size / 2 : (width - size) / 2
    var y = anchor ? anchor.y + anchor.height / 2 - size / 2 : height - bottomInset - gap - size
    return {x: Math.max(0, Math.min(width - size, x)), y: Math.max(0, Math.min(height - size, y)), width: size, height: size}
}

// Clamp easing overshoot before interpolating screen-local chassis geometry.
function mixRect(seed, target, progress) {
    var t = Math.max(0, Math.min(1, progress))
    return {x: seed.x + (target.x - seed.x) * t, y: seed.y + (target.y - seed.y) * t,
        width: seed.width + (target.width - seed.width) * t, height: seed.height + (target.height - seed.height) * t}
}
