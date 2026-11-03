// Resolve the final span for each HakuMenu profile.
function targetWidth(width, tab, mode, leftInset, rightInset) {
    if (tab === "taskManager") return Math.min(width * 0.40, Math.max(1, width - leftInset - rightInset))
    if (mode === "general") return width * 0.38
    if (mode === "theme") return width * 0.36
    return width * 0.40
}

// Fit the embedded profile inside the attached surface's usable output bounds.
function attachedTaskSize(width, height, leftInset, rightInset, barHeight, oppositeInset) {
    return {width: targetWidth(width, "taskManager", "", leftInset, rightInset),
        height: Math.min(height * 0.40, Math.max(1, height - barHeight - oppositeInset))}
}
