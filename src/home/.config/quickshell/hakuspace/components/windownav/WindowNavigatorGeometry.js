// Fit a centered atlas into the usable output, favoring readable 16:10 previews.
function layout(width, height, count, spacing) {
    width = Math.max(0, width)
    height = Math.max(0, height)
    if (!count || !width || !height) return []
    var gap = Math.min(spacing, width / (count * 2), height / (count * 2))
    // Reserve the metadata rail beneath each preview.
    var metadataHeight = 72
    var best = null
    for (var columns = 1; columns <= count; columns++) {
        var rows = Math.ceil(count / columns)
        var cellWidth = (width - (columns - 1) * gap) / columns
        var cellHeight = (height - (rows - 1) * gap) / rows
        var cardWidth = Math.min(cellWidth, 560, Math.max(1, cellHeight - metadataHeight) * 1.6)
        var cardHeight = Math.min(cellHeight, cardWidth / 1.6 + metadataHeight)
        var score = cardWidth * Math.max(1, cardHeight - metadataHeight)
        if (!best || score > best.score) best = {columns: columns, rows: rows, width: cardWidth, height: cardHeight, score: score}
    }
    var result = []
    var top = (height - best.rows * best.height - (best.rows - 1) * gap) / 2
    for (var index = 0; index < count; index++) {
        var row = Math.floor(index / best.columns)
        var inRow = Math.min(best.columns, count - row * best.columns)
        result.push({x: (width - inRow * best.width - (inRow - 1) * gap) / 2 + (index % best.columns) * (best.width + gap),
            y: top + row * (best.height + gap), width: best.width, height: best.height})
    }
    return result
}

// Choose the nearest forward center, penalizing perpendicular displacement.
function neighbor(cards, index, direction) {
    if (!cards[index]) return index
    var source = cards[index]
    var best = index
    var distance = Infinity
    cards.forEach(function(card, candidate) {
        var dx = card.x + card.width / 2 - source.x - source.width / 2
        var dy = card.y + card.height / 2 - source.y - source.height / 2
        var forward = direction === "left" ? -dx : direction === "right" ? dx : direction === "up" ? -dy : dy
        var sideways = direction === "left" || direction === "right" ? Math.abs(dy) : Math.abs(dx)
        var score = forward + sideways * 3
        if (forward > 1 && score < distance) { best = candidate; distance = score }
    })
    return best
}

// Keep the selected capsule readable and let a Flickable contain long ribbons.
function ribbonWidth(selected, viewport) { return selected ? Math.min(280, viewport * 0.6) : 64 }
