.pragma library

// Share the available height between scrollable controls and a bounded title lane.
function lanes(bottom, logoBottom, workspaces, status, title, gap, inset, fontSize) {
    var end = Math.max(0, bottom - inset)
    // Logo and workspace wrappers already include their visual insets.
    var start = Math.min(end, logoBottom)
    var room = Math.max(0, end - start)
    var upper = Math.min(workspaces, room * 0.22)
    var minimumTitle = Math.min(title, Math.max(144, fontSize * 8), Math.max(0, room - upper - gap * 2))
    var lower = Math.min(status, Math.max(0, room - upper - minimumTitle - gap * 2))
    var titleRoom = Math.max(0, room - upper - lower - gap * 2)
    var titleHeight = Math.min(title, titleRoom)
    return {upperY: start, upperHeight: upper, bottomY: end - lower, bottomHeight: lower,
        titleY: start + upper + gap + (titleRoom - titleHeight) / 2, titleHeight: titleHeight}
}
