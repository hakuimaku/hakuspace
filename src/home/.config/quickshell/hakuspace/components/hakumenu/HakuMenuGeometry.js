// PURE MATHEMATICAL GEOMETRY ENGINE:
// Must remain independent from QML runtime to ensure sub-second Node.js unit testing.
// Do NOT import QML singletons or extract algorithmic ratios into QML.

// Resolve the final span for each HakuMenu profile.
function targetWidth(width, tab, mode, leftInset, rightInset) {
    if (tab === "taskManager") return Math.min(width * 0.45, Math.max(1, width - leftInset - rightInset))
    if (mode === "general") return width * 0.38
    if (mode === "theme") return width * 0.36
    return width * 0.40
}

// Fit the embedded profile inside the attached surface's usable output bounds.
function attachedTaskSize(width, height, leftInset, rightInset, barHeight, oppositeInset, contentHeight) {
    return {width: targetWidth(width, "taskManager", "", leftInset, rightInset),
        height: Math.min(Math.max(height * 0.45, contentHeight || 0), Math.max(1, height - barHeight - oppositeInset))}
}
