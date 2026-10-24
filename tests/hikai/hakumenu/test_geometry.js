const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
// Exercise local coordinates independently of monitor placement and layer-shell origins.
const geometry = vm.createContext({})
vm.runInContext(fs.readFileSync(require('node:path').resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/hakumenu/HakuMenuGeometry.js'), 'utf8'), geometry)
const json = value => JSON.parse(JSON.stringify(value))
for (const [width, height] of [[320, 240], [640, 480], [1280, 720], [1920, 1080], [2560, 1440]]) {
    for (const border of [0, 4, 6]) {
        for (const icon of [32, 48, 72]) {
            for (const dock of [0, icon + 17]) {
                const card = geometry.finalRect(width, height, border, 52, border, dock, 16)
                assert.equal(card.x + card.width / 2, width / 2)
                assert.ok(card.x >= border && card.x + card.width <= width - border)
                assert.ok(card.y >= 52 && card.y + card.height <= height - border - dock - 16)
                const anchor = {x: border + 32, y: height - border - icon, width: icon, height: icon}
                const seed = geometry.seedRect(anchor, width, height, icon, border, 16, card)
                assert.equal(seed.x + seed.width / 2, anchor.x + anchor.width / 2)
                assert.equal(seed.y + seed.height / 2, anchor.y + anchor.height / 2)
                assert.deepEqual(json(geometry.mixRect(seed, card, -0.1)), json(seed))
                assert.deepEqual(json(geometry.mixRect(seed, card, 1.08)), json(card))
                const halfway = geometry.mixRect(seed, card, 0.5)
                assert.equal(halfway.x, (seed.x + card.x) / 2)
                assert.equal(halfway.height, (seed.height + card.height) / 2)
                const fallback = geometry.seedRect(null, width, height, icon, border, 16, card)
                assert.equal(fallback.x + fallback.width / 2, width / 2)
                assert.ok(fallback.y + fallback.height <= height - border)
            }
        }
    }
}
console.log('HakuMenu geometry checks passed')
