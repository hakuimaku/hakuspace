const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')

const source = fs.readFileSync('src/home/.config/quickshell/hakuspace/components/base/SafeZoneGeometry.js', 'utf8')
const g = {}
vm.runInNewContext(source.replace(/^\.pragma library\s*/, ''), g)
const plain = value => JSON.parse(JSON.stringify(value))

assert.deepEqual(plain(g.inflate(g.rect(10, 10, 20, 20), 5)), { x: 5, y: 5, width: 30, height: 30 })
assert(g.contains(g.rect(0, 0, 10, 10), 9, 9))
assert(!g.contains(g.rect(0, 0, 10, 10), 10, 10))
assert(!g.contains(g.rect(0, 0, 0, 10), 0, 5))
assert(!g.containsAny([g.rect(0, 0, 10, 10)], 11, 5))
assert.deepEqual(plain(g.clampRect(g.rect(-5, -5, 20, 20), 12, 12)), { x: 0, y: 0, width: 12, height: 12 })
assert.deepEqual(plain(g.clampRect(g.rect(20, 20, 5, 5), 12, 12)), { x: 12, y: 12, width: 0, height: 0 })
assert.deepEqual(plain(g.clampRect(g.rect(1.5, 2.5, 3, 4), 12, 12)), { x: 1, y: 2, width: 4, height: 5 })
assert.deepEqual(plain(g.clampRect(g.rect(1.5, 2.5, 0, 4), 12, 12)), { x: 1, y: 2, width: 0, height: 0 })
assert.deepEqual(plain(g.horizontalBridge(g.rect(0, 0, 10, 20), g.rect(30, 5, 10, 20), 4)),
    { x: 10, y: 10.5, width: 20, height: 4 })
assert.deepEqual(plain(g.verticalBridge(g.rect(0, 0, 20, 10), g.rect(5, 30, 20, 10), 4)),
    { x: 10.5, y: 10, width: 4, height: 20 })
const diagonal = g.orthogonalBridge(g.rect(0, 0, 10, 10), g.rect(30, 30, 10, 10), 4)
assert.equal(diagonal.length, 2)
assert(diagonal.every(r => r.width <= 30 && r.height <= 30))
assert.deepEqual(plain(g.sweptEnvelope(g.rect(0, 0, 10, 10), g.rect(20, 20, 10, 10), 2)),
    { x: -2, y: -2, width: 34, height: 34 })
console.log('SafeZoneGeometry passed')
