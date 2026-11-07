.pragma library

// Measure controls independently from their wrapped height to avoid a QML binding cycle.
function infoWidth(input) {
    var available = Math.max(1, input.width - input.left - input.right)
    return Math.min(input.toolbarWidth, 640, Math.max(1, available - Math.min(176, available * 0.18) - input.gap - (input.radius || 0)))
}

// Fit content-sized controls and a bounded three-card cradle inside one output's safe area.
function leftLayout(input) {
    var padding = input.padding, gap = input.gap
    var safe = {x: input.left, y: input.top, width: Math.max(1, input.width - input.left - input.right),
        height: Math.max(1, input.height - input.top - input.bottom)}
    var info = {x: safe.x, y: safe.y, width: infoWidth(input),
        height: Math.min(input.toolbarHeight, Math.max(1, safe.height * 0.5 - padding))}
    // The corner ears shrink away when a short output needs all of the control viewport.
    var radius = Math.min(input.radius || 0, Math.max(0, safe.height * 0.5 - input.toolbarHeight - padding))
    var infoSurface = {x: info.x, y: info.y, width: info.width + radius, height: info.height + padding + radius}
    var railWidth = Math.min(Math.max(104, input.labelWidth + padding * 2), 176, safe.width * 0.18)
    // Tall rails use a stacked media switch; compact outputs keep both modes on one row.
    var mediaStacked = safe.height >= (input.mediaHeight * 2 + input.categoryHeight * 3 + gap * 4 + padding * 2) * 2
    var mediaHeight = input.mediaHeight * (mediaStacked ? 2 : 1)
    var categoryMinimum = input.categoryCount ? input.categoryHeight * 3 + gap * 2 : 0
    var headerHeight = padding * 2 + mediaHeight + (categoryMinimum ? gap + categoryMinimum : 0)
    // Overlapping previews leave room for the broad lower flare without enlarging the native window.
    var selectedScale = 1.32, nearScale = 0.8
    var overlapRatio = 0.425, insetRatio = 0.075, liftRatio = 0.75
    var revealRatio = nearScale * 0.75
    var widthFactor = selectedScale + nearScale * (1 - overlapRatio + insetRatio) + revealRatio
    var heightFactor = (selectedScale + nearScale * (1 + liftRatio)) * 9 / 16
    var baseWidth = Math.max(1, Math.min(348, (safe.width - padding * 2) / widthFactor,
        (safe.height - Math.max(infoSurface.height, Math.min(headerHeight, safe.height * 0.5)) - gap - padding * 2) / heightFactor))
    var selectedWidth = baseWidth * selectedScale, nearWidth = baseWidth * nearScale
    var selectedHeight = selectedWidth * 9 / 16, nearHeight = nearWidth * 9 / 16
    var selectedInset = nearWidth * insetRatio, selectedLift = nearHeight * liftRatio
    var upperOverlap = Math.min(gap, nearHeight / 8), reveal = baseWidth * revealRatio
    var cardsWidth = selectedWidth + nearWidth * (1 - overlapRatio) + selectedInset + padding * 2
    var gallery = {width: cardsWidth + reveal,
        height: selectedHeight + nearHeight + selectedLift - upperOverlap + padding * 2}
    gallery.x = safe.x + safe.width - gallery.width
    gallery.y = safe.y + safe.height - gallery.height
    var viewport = {x: gallery.x + reveal, y: gallery.y, width: cardsWidth, height: gallery.height}
    // Fill the selector column down to the carousel instead of capping it at its natural content height.
    var categoryHeight = input.categoryCount ? Math.max(0, gallery.y - safe.y - padding * 2 - mediaHeight - gap) : 0
    // Lower the upper arrow while preserving the carousel edge and one usable category row.
    var categoryTopInset = Math.min(36, Math.max(0, categoryHeight - input.categoryHeight))
    categoryHeight -= categoryTopInset
    var categoryArrows = categoryHeight >= input.categoryHeight * 3 + gap * 2
    var categoryViewportHeight = categoryHeight - (categoryArrows ? input.categoryHeight * 2 + gap * 2 : 0)
    // Keep the list compact and reserve equal breathing room around its scrollable content.
    var categoryRowHeight = input.categoryHeight
    var categorySpacing = Math.max(2, gap / 2) + 4
    var categoryInset = Math.min(gap * 2, Math.max(0, (categoryViewportHeight - categoryRowHeight) / 2))
    var rail = {x: safe.x + safe.width - railWidth, y: safe.y, width: railWidth,
        height: padding * 2 + mediaHeight + (categoryHeight ? gap + categoryTopInset + categoryHeight : 0)}
    var media = {x: rail.x + padding, y: rail.y + padding, width: Math.max(1, railWidth - padding * 2), height: mediaHeight}
    var categories = {x: media.x, y: media.y + media.height + gap + categoryTopInset, width: media.width, height: categoryHeight}
    // The selected card floats between two foreground previews.
    var selected = {x: cardsWidth - padding - selectedInset - selectedWidth / 2,
        y: gallery.height - padding - selectedLift - selectedHeight / 2}
    var upper = {x: cardsWidth - padding - nearWidth / 2, y: padding + nearHeight / 2}
    var left = {x: padding + nearWidth / 2, y: gallery.height - padding - nearHeight / 2}
    var tangent = {x: (upper.x - selected.x) * 0.6, y: Math.min(selected.y - upper.y, left.y - selected.y) * 0.3}
    var anchors = {upper: upper, selected: selected, left: left,
        incoming1: {x: upper.x, y: upper.y + (selected.y - upper.y) * 0.65},
        incoming2: {x: selected.x + tangent.x, y: selected.y - tangent.y},
        outgoing1: {x: selected.x - tangent.x, y: selected.y + tangent.y},
        outgoing2: {x: left.x + (selected.x - left.x) * 0.35, y: left.y}}
    var surfaceAnchors = {}
    for (var name in anchors) surfaceAnchors[name] = {x: anchors[name].x + reveal, y: anchors[name].y + gallery.y - safe.y}
    var rightSurface = {x: gallery.x, y: safe.y, width: gallery.width, height: safe.height}
    // One continuous contour leaves the vertical rail and settles horizontally into the bottom edge.
    var start = {x: rightSurface.width - railWidth, y: surfaceAnchors.upper.y - nearHeight / 8}
    var floor = {x: 0, y: rightSurface.height}
    // Wide labels keep their rail while compact artwork lets the contour pass to its left.
    var center = {x: Math.min(surfaceAnchors.selected.x, start.x - Math.min(gap, (start.x - floor.x) / 3)),
        y: surfaceAnchors.selected.y}
    var handle = {x: Math.min((start.x - center.x) * 0.8, (center.x - floor.x) * 0.4),
        y: Math.min(center.y - start.y, floor.y - center.y) * 0.4}
    // A concave ear joins the rail to the top; the lower arm reaches the full cradle width.
    var topRadius = Math.min(input.radius || 0, start.x, start.y)
    var backingCurve = {top: {x: start.x - topRadius, y: 0}, topEnd: {x: start.x, y: topRadius}, start: start, selected: center, floor: floor,
        incoming1: {x: start.x, y: start.y + (center.y - start.y) * 0.55},
        incoming2: {x: center.x + handle.x, y: center.y - handle.y},
        outgoing1: {x: center.x - handle.x, y: center.y + handle.y},
        outgoing2: {x: floor.x + (center.x - floor.x) * 0.35, y: floor.y}}
    return {safeRect: safe, infoRect: info, infoSurfaceRect: infoSurface, infoRadius: radius,
        railRect: rail, rightSurfaceRect: rightSurface, backingCurve: backingCurve, mediaRect: media, categoryRect: categories,
        galleryRect: gallery, cardViewport: viewport, anchors: anchors, surfaceAnchors: surfaceAnchors, cardWidth: baseWidth,
        selectedScale: selectedScale, nearScale: nearScale, padding: padding, gap: gap,
        categoryArrows: categoryArrows, categoryRowHeight: categoryRowHeight, categorySpacing: categorySpacing, categoryInset: categoryInset, mediaStacked: mediaStacked,
        compact: baseWidth < 240 || input.toolbarHeight > info.height}
}

// Clip moving artwork to both the visible viewport and the output's usable area.
function intersection(rect, viewport) {
    var x = Math.max(rect.x, viewport.x), y = Math.max(rect.y, viewport.y)
    return {x: x, y: y, width: Math.max(0, Math.min(rect.x + rect.width, viewport.x + viewport.width) - x),
        height: Math.max(0, Math.min(rect.y + rect.height, viewport.y + viewport.height) - y)}
}
