// Validate the Leftbar wallpaper contract without a compositor or production services.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const source = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/wallpaper')
const geometry = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(source, 'WorkspaceGeometry.js'), 'utf8').replace('.pragma library', ''), geometry)
const overlaps = (a, b) => a.x < b.x + b.width - 1e-6 && b.x < a.x + a.width - 1e-6
    && a.y < b.y + b.height - 1e-6 && b.y < a.y + a.height - 1e-6
const contains = (a, b) => b.x >= a.x - 1e-6 && b.y >= a.y - 1e-6
    && b.x + b.width <= a.x + a.width + 1e-6 && b.y + b.height <= a.y + a.height + 1e-6
let cases = 0
for (const [pixelsW, pixelsH] of [[1024, 600], [1280, 720], [1366, 768], [1536, 864], [1920, 1080], [2560, 1440]]) {
    for (const scale of [1, 1.25, 1.5]) for (const font of [12, 14, 18, 21]) {
        for (const bottom of [4, 57, 89]) for (const categoryCount of [0, 1, 5, 20]) for (const label of ['All', '自然 · Tiếng Việt 😀'.repeat(12)]) {
            const input = {width: pixelsW / scale, height: pixelsH / scale, left: 46, right: 4, top: 4, bottom,
                padding: 16, gap: 8, radius: 48, toolbarWidth: font * 26 + 32, toolbarHeight: Math.max(36, font * 2 + 2) * 5 + Math.ceil(font * 3) + 80,
                mediaHeight: Math.max(44, font * 2), categoryHeight: Math.max(32, font * 2), categoryCount, labelWidth: label.length * font}
            const layout = geometry.leftLayout(input)
            assert.equal(JSON.stringify(layout), JSON.stringify(geometry.leftLayout(input)))
            for (const rect of [layout.infoRect, layout.infoSurfaceRect, layout.railRect, layout.rightSurfaceRect, layout.mediaRect, layout.categoryRect, layout.galleryRect, layout.cardViewport]) {
                for (const value of Object.values(rect)) assert(Number.isFinite(value) && value >= 0)
                assert(contains(layout.safeRect, rect), JSON.stringify({input, rect, safe: layout.safeRect}))
            }
            assert(Math.abs(layout.infoSurfaceRect.height - layout.infoRect.height - input.padding - layout.infoRadius) < 1e-6,
                'the information backing hugs the toolbar instead of adding empty body space')
            assert(!overlaps(layout.infoSurfaceRect, layout.railRect))
            assert(!overlaps(layout.infoSurfaceRect, layout.galleryRect))
            assert(!overlaps(layout.railRect, layout.galleryRect))
            assert(contains(layout.railRect, layout.mediaRect))
            assert.equal(layout.mediaRect.height, input.mediaHeight * (layout.mediaStacked ? 2 : 1))
            if (categoryCount) assert(contains(layout.railRect, layout.categoryRect))
            if (categoryCount) assert(Math.abs(layout.railRect.y + layout.railRect.height - layout.galleryRect.y) < 1e-6,
                'the selector column ends at the carousel without a dead gap')
            if (categoryCount) {
                if (layout.categoryArrows)
                    assert(Math.abs(layout.categoryRect.y - layout.mediaRect.y - layout.mediaRect.height - input.gap - 36) < 1e-6,
                        'the upper arrow clears the media switch by thirty-six extra pixels')
                const navigationHeight = layout.categoryArrows ? input.categoryHeight * 2 + input.gap * 2 : 0
                const viewportHeight = layout.categoryRect.height - navigationHeight
                assert(viewportHeight >= input.categoryHeight, 'compact categories must retain one usable scrolling row')
                assert.equal(layout.categoryRowHeight, input.categoryHeight, 'category hit areas keep their natural row height')
                assert.equal(layout.categorySpacing, Math.max(2, input.gap / 2) + 4, 'category gaps increase by four pixels')
                assert(layout.categoryInset >= 0 && layout.categoryInset <= input.gap * 2)
                assert(layout.categoryRowHeight + layout.categoryInset * 2 <= viewportHeight + 1e-6,
                    'compact viewports retain a complete row inside their padded edges')
                const rowsHeight = categoryCount * layout.categoryRowHeight + (categoryCount - 1) * layout.categorySpacing
                const top = Math.max(layout.categoryInset, (viewportHeight - rowsHeight) / 2)
                const contentHeight = Math.max(viewportHeight, top + rowsHeight + layout.categoryInset)
                if (rowsHeight + layout.categoryInset * 2 <= viewportHeight) {
                    assert(Math.abs(top - (viewportHeight - top - rowsHeight)) < 1e-6, 'short lists have equal expanded outer margins')
                    assert.equal(contentHeight, viewportHeight)
                } else assert(contentHeight > viewportHeight, 'long lists retain padded scrolling content')
            }
            assert(contains(layout.galleryRect, layout.cardViewport))
            assert(layout.cardViewport.x > layout.galleryRect.x, 'the lower flare reveals to the left of the previews')
            assert.equal(layout.rightSurfaceRect.y, layout.safeRect.y)
            assert.equal(layout.rightSurfaceRect.height, layout.safeRect.height)
            assert(Math.abs(layout.backingCurve.start.x + layout.rightSurfaceRect.x - layout.railRect.x) < 1e-6)
            assert.equal(layout.backingCurve.incoming1.x, layout.backingCurve.start.x)
            assert.equal(layout.backingCurve.outgoing2.y, layout.backingCurve.floor.y)
            assert.equal(layout.backingCurve.floor.y, layout.safeRect.height)
            assert.equal(layout.backingCurve.floor.x, 0, 'the bottom flare reaches the full surface width')
            assert(layout.backingCurve.top.x < layout.backingCurve.start.x, 'the top ear flares left into the screen edge')
            assert.equal(layout.backingCurve.top.y, 0)
            assert.equal(layout.backingCurve.topEnd.x, layout.backingCurve.start.x)
            assert(layout.backingCurve.topEnd.y > 0 && layout.backingCurve.topEnd.y < layout.backingCurve.start.y)
            for (const name of Object.keys(layout.anchors)) {
                assert(Math.abs(layout.surfaceAnchors[name].x - layout.anchors[name].x - layout.cardViewport.x + layout.galleryRect.x) < 1e-6)
                assert.equal(layout.surfaceAnchors[name].y, layout.anchors[name].y + layout.galleryRect.y - layout.safeRect.y)
            }
            const cards = ['upper', 'selected', 'left'].map(name => {
                const width = layout.cardWidth * (name === 'selected' ? layout.selectedScale : layout.nearScale)
                const center = layout.anchors[name]
                return {x: center.x - width / 2, y: center.y - width * 9 / 32, width, height: width * 9 / 16}
            })
            const viewport = {x: 0, y: 0, width: layout.cardViewport.width, height: layout.cardViewport.height}
            for (const card of cards) assert(contains(viewport, card))
            // Small foreground previews overlap the raised selection without hiding its central artwork.
            for (const neighbor of [cards[0], cards[2]]) {
                const overlap = geometry.intersection(neighbor, cards[1])
                assert(overlap.width * overlap.height > 0)
                assert(overlap.width * overlap.height < neighbor.width * neighbor.height / 4)
            }
            assert(cards[0].y < cards[1].y && cards[2].x < cards[1].x)
            assert(cards[0].x + cards[0].width > cards[1].x + cards[1].width)
            assert(cards[2].y + cards[2].height > cards[1].y + cards[1].height)
            for (const axis of ['x', 'y']) {
                const a = layout.anchors
                assert(Math.abs(a.incoming2[axis] + a.outgoing1[axis] - a.selected[axis] * 2) < 1e-6)
                for (const point of Object.values(a)) assert(Number.isFinite(point[axis]) && point[axis] >= 0
                    && point[axis] <= (axis === 'x' ? viewport.width : viewport.height))
            }
            // The visible panel contour stays smooth and monotone from rail to bottom.
            const backing = layout.backingCurve
            const lowerMidpoint = (backing.selected.x + 3 * backing.outgoing1.x + 3 * backing.outgoing2.x + backing.floor.x) / 8
            assert(lowerMidpoint < layout.surfaceAnchors.left.x + layout.cardWidth * layout.nearScale / 4, 'the lower arm bends left across the foreground preview')
            for (const axis of ['x', 'y']) assert(Math.abs(backing.incoming2[axis] + backing.outgoing1[axis] - backing.selected[axis] * 2) < 1e-6)
            for (const points of [[backing.start, backing.incoming1, backing.incoming2, backing.selected],
                [backing.selected, backing.outgoing1, backing.outgoing2, backing.floor]]) {
                let previous = points[0]
                for (let step = 1; step <= 50; step++) {
                    const t = step / 50, u = 1 - t
                    const point = Object.fromEntries(['x', 'y'].map(axis => [axis,
                        u ** 3 * points[0][axis] + 3 * u ** 2 * t * points[1][axis] + 3 * u * t ** 2 * points[2][axis] + t ** 3 * points[3][axis]]))
                    assert(point.x <= previous.x + 1e-6 && point.y >= previous.y - 1e-6)
                    assert(point.x >= 0 && point.x <= layout.rightSurfaceRect.width + 1e-6
                        && point.y >= 0 && point.y <= layout.rightSurfaceRect.height + 1e-6)
                    previous = point
                }
            }
            const mask = geometry.intersection({x: -30, y: -20, width: viewport.width + 60, height: viewport.height + 40}, viewport)
            assert.equal(JSON.stringify(mask), JSON.stringify(viewport))
            cases++
        }
    }
}
console.log(`Leftbar wallpaper geometry passed: ${cases} output/font/dock/category/label cases`)
