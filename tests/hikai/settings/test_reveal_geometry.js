const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

// Execute the production reveal functions without a compositor.
const reveal = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(__dirname,
    '../../../src/home/.config/quickshell/hakuspace/components/motion/PanelRevealGeometry.js'), 'utf8')
    .replace(/^\.pragma library\s*\n/, ''), reveal)
// Compare QML-engine objects with ordinary Node assertions.
const json = value => JSON.parse(JSON.stringify(value))
// Cover corners, cardinal edges, portrait output and compact panel dimensions.
for (const [width, height] of [[1920, 1080], [800, 600], [600, 1000], [320, 240]]) {
    // Keep the connection below the top bar and inside the screen rails.
    const bounds = {x: 6, y: 40, width: width - 12, height: height - 46}
    // Enumerate the public clockwise numbering independently of the helper.
    const anchors = [[6, 40], [width / 2, 40], [width - 6, 40], [width - 6, (height + 34) / 2],
        [width - 6, height - 6], [width / 2, height - 6], [6, height - 6], [6, (height + 34) / 2]]
    for (let position = 1; position <= 8; ++position) {
        assert.deepEqual(json(reveal.anchor(position, bounds)), {x: anchors[position - 1][0], y: anchors[position - 1][1]})
        // Cover the first visible frame, expansion and the final neck pinch.
        for (const progress of [0.001, 0.02, 0.1, 0.4, 0.75, 0.95, 0.999]) {
            // Grow the chassis around a fixed center instead of translating it.
            const body = {width: (width - 64) * progress, height: Math.min(750, height - 80) * progress}
            body.x = (width - body.width) / 2
            body.y = (height - body.height) / 2
            // Inspect the actual SVG path used by the production Shape.
            const geometry = reveal.neck(position, bounds, body, progress, 168)
            assert.deepEqual(json(geometry.center), {x: width / 2, y: height / 2})
            assert.deepEqual(json(geometry.anchor), json(reveal.anchor(position, bounds)))
            assert(geometry.path.length > 0)
            assert(!/NaN|Infinity/.test(geometry.path))
            // Cubic curves stay inside the convex hull of their bounded control points.
            const values = geometry.path.match(/-?\d+(?:\.\d+)?(?:e[+-]?\d+)?/gi).map(Number)
            assert.equal(values.length, 18)
            for (let index = 0; index < values.length; index += 2) {
                assert(values[index] >= bounds.x && values[index] <= bounds.x + bounds.width)
                assert(values[index + 1] >= bounds.y && values[index + 1] <= bounds.y + bounds.height)
            }
            assert.deepEqual(values.slice(-2), anchors[position - 1], 'root stays fixed on the selected edge or corner')
            assert(Math.abs((values[6] + values[8]) / 2 - width / 2) < 1e-8)
            assert(Math.abs((values[7] + values[9]) / 2 - height / 2) < 1e-8, 'neck spans the entire distance to the center')
        }
        for (const progress of [-0.1, 0, 1, 1.1])
            assert.equal(reveal.neck(position, bounds, {x: width / 2 - 50, y: height / 2 - 25, width: 100, height: 50}, progress, 168).path, '')
    }
}
// Reject unsupported public positions rather than silently selecting a different corner.
for (const position of [0, 9, 1.5, NaN])
    assert.throws(() => reveal.anchor(position, {x: 0, y: 0, width: 100, height: 100}), /1 to 8/)
// Degenerate output geometry must remain finite and invisible.
assert.equal(reveal.neck(1, {x: 0, y: 0, width: 0, height: 0}, {x: 0, y: 0, width: 0, height: 0}, 0.5, 168).path, '')
console.info('Panel reveal geometry checks passed for all 8 anchors')
