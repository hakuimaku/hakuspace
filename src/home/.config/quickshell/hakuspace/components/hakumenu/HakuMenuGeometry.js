// PURE MATHEMATICAL GEOMETRY ENGINE:
// Must remain independent from QML runtime to ensure sub-second Node.js unit testing.
// Do NOT import QML singletons or extract algorithmic ratios into QML.

// Resolve the final span for each HakuMenu profile.
function targetWidth(width, tab, mode, leftInset, rightInset, ratios) {
    var taskRatio = ratios && ratios.taskManagerMiniWidthRatio !== undefined ? ratios.taskManagerMiniWidthRatio : 0.45
    var generalRatio = ratios && ratios.hakuMenuGeneralWidthRatio !== undefined ? ratios.hakuMenuGeneralWidthRatio : 0.38
    var themeRatio = ratios && ratios.hakuMenuThemeWidthRatio !== undefined ? ratios.hakuMenuThemeWidthRatio : 0.36
    var menuRatio = ratios && ratios.hakuMenuWidthRatio !== undefined ? ratios.hakuMenuWidthRatio : 0.40
    if (tab === "taskManager") return Math.min(width * taskRatio, Math.max(1, width - leftInset - rightInset))
    if (mode === "general") return width * generalRatio
    if (mode === "theme") return width * themeRatio
    return width * menuRatio
}

// Fit the embedded profile inside the attached surface's usable output bounds.
function attachedTaskSize(width, height, leftInset, rightInset, barHeight, oppositeInset, contentHeight, ratios) {
    var heightRatio = ratios && ratios.taskManagerMiniHeightRatio !== undefined ? ratios.taskManagerMiniHeightRatio : 0.45
    return {width: targetWidth(width, "taskManager", "", leftInset, rightInset, ratios),
        height: Math.min(Math.max(height * heightRatio, contentHeight || 0), Math.max(1, height - barHeight - oppositeInset))}
}
