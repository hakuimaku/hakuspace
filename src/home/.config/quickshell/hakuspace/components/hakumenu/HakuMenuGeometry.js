// PURE MATHEMATICAL GEOMETRY ENGINE:
// Must remain independent from QML runtime to ensure sub-second Node.js unit testing.
// Do NOT import QML singletons or extract algorithmic ratios into QML.

// Resolve the final span for each HakuMenu profile.
function targetWidth(width, tab, mode, leftInset, rightInset, ratios) {
    var taskRatio = ratios && ratios.taskManagerMiniWidthRatio !== undefined ? ratios.taskManagerMiniWidthRatio : 0.43
    var generalRatio = ratios && ratios.hakuMenuGeneralWidthRatio !== undefined ? ratios.hakuMenuGeneralWidthRatio : 0.38
    var themeRatio = ratios && ratios.hakuMenuThemeWidthRatio !== undefined ? ratios.hakuMenuThemeWidthRatio : 0.36
    var menuRatio = ratios && ratios.hakuMenuWidthRatio !== undefined ? ratios.hakuMenuWidthRatio : 0.40
    var minWidth = ratios && ratios.hakuMenuMinWidth !== undefined ? ratios.hakuMenuMinWidth : 0
    var available = Math.max(1, width - (leftInset || 0) - (rightInset || 0))
    if (tab === "taskManager") return Math.min(minWidth > 0 ? Math.max(width * taskRatio, minWidth) : width * taskRatio, available)
    var span = mode === "general" ? width * generalRatio : mode === "theme" ? width * themeRatio : width * menuRatio
    return minWidth > 0 ? Math.min(Math.max(span, minWidth), available) : span
}

// Fit the embedded profile inside the attached surface's usable output bounds.
function attachedTaskSize(width, height, leftInset, rightInset, barHeight, oppositeInset, contentHeight, ratios) {
    var heightRatio = ratios && ratios.taskManagerMiniHeightRatio !== undefined ? ratios.taskManagerMiniHeightRatio : 0.398
    var menuHeightRatio = ratios && ratios.hakuMenuHeightRatio !== undefined ? ratios.hakuMenuHeightRatio : 0.42
    var minHeight = ratios && ratios.hakuMenuMinHeight !== undefined ? ratios.hakuMenuMinHeight : 0
    var taskMinHeight = minHeight > 0 ? Math.round(minHeight * (heightRatio / menuHeightRatio)) : 0
    return {width: targetWidth(width, "taskManager", "", leftInset, rightInset, ratios),
        height: Math.min(Math.max(height * heightRatio, taskMinHeight, contentHeight || 0), Math.max(1, height - barHeight - oppositeInset))}
}
