.pragma library

// Collect explicit focus targets as units, skipping unavailable visual subtrees.
function collect(scope, role) {
    if (!scope || !scope.visible || !scope.enabled) return []
    if (scope.settingsNavItem === true)
        return scope.width > 0 && scope.height > 0 && (!role || scope.settingsNavRole === role) ? [scope] : []
    var result = []
    for (var child of scope.children) result = result.concat(collect(child, role))
    return result
}

// Native controls can focus descendants of the registered navigation target.
function owner(item) {
    for (; item; item = item.parent) if (item.settingsNavItem === true) return item
    return null
}

// Regions are supplied by the Settings layer rather than inferred from controls.
function region(item, regions) {
    for (; item; item = item.parent) {
        var index = regions.indexOf(item)
        if (index >= 0) return index
    }
    return -1
}

// Section ownership is declared by cards, including controls nested inside rows.
function section(item, scope) {
    for (; item && item !== scope; item = item.parent)
        if (item.settingsNavSection !== undefined) return item.settingsNavSection
    return ""
}

// Explicit groups share horizontal movement; wrapped groups split into visual lines.
function rows(scope, items) {
    var entries = items.map(function(item, index) {
        var point = item.mapToItem(scope, item.width / 2, item.height / 2)
        // Scrolling must not reorder form rows relative to fixed page controls.
        for (var parent = item.parent; parent && parent !== scope; parent = parent.parent) {
            if (parent.contentItem && parent.contentY !== undefined) {
                point.x += parent.contentX
                point.y += parent.contentY
            }
        }
        return {item: item, group: item.settingsNavGroup || item, index: index,
            x: point.x, y: point.y, height: item.height}
    }).sort((a, b) => a.y - b.y || a.x - b.x || a.index - b.index)
    var result = []
    for (var entry of entries) {
        var row = result.find(row => row.group === entry.group
            && Math.abs(row.y - entry.y) < Math.min(row.height, entry.height) / 2)
        if (row) row.entries.push(entry)
        else result.push({group: entry.group, y: entry.y, height: entry.height, entries: [entry]})
    }
    for (var row of result) row.entries.sort((a, b) => a.x - b.x || a.index - b.index)
    return result
}

// Vertical movement chooses the adjacent semantic row, then horizontal alignment.
function next(scope, items, current, key) {
    var layout = rows(scope, items)
    var rowIndex = layout.findIndex(row => row.entries.some(entry => entry.item === current))
    if (rowIndex < 0) return null
    var row = layout[rowIndex]
    var index = row.entries.findIndex(entry => entry.item === current)
    if (key === Qt.Key_Left || key === Qt.Key_Right) {
        var entry = row.entries[index + (key === Qt.Key_Left ? -1 : 1)]
        return entry ? entry.item : null
    }
    var adjacent = layout[rowIndex + (key === Qt.Key_Up ? -1 : 1)]
    if (!adjacent) return null
    var x = row.entries[index].x
    var closest = adjacent.entries.reduce((best, entry) => Math.abs(entry.x - x) < Math.abs(best.x - x) ? entry : best)
    return closest.item
}

// Lists have an explicit axis and wrapping policy; collecting never activates items.
function listTarget(items, current, key, vertical, wrap) {
    if (!items.length) return null
    if (key === Qt.Key_Home) return items[0]
    if (key === Qt.Key_End) return items[items.length - 1]
    var step = key === (vertical ? Qt.Key_Up : Qt.Key_Left) ? -1
        : key === (vertical ? Qt.Key_Down : Qt.Key_Right) ? 1 : 0
    if (!step) return null
    var index = items.indexOf(current)
    if (index < 0) index = step > 0 ? -1 : items.length
    index += step
    index = wrap ? (index + items.length) % items.length : Math.max(0, Math.min(items.length - 1, index))
    return items[index]
}
