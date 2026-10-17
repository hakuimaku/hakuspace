// Exercise the shared geometry at the screen/host boundary without a QML runtime.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname,
    '../src/home/.config/quickshell/hakuspace/services/ScreenGeometry.js'), 'utf8')
    .replace(/^\.pragma library\s*$/m, '');
const loaded = {exports: {}};
new Function('module', source)(loaded);
const geometry = loaded.exports;

// Side bounds stay finite and inside the screen even when insets exceed its width.
for (const border of [0, 1, 4, 6]) {
    for (const radius of [0, 4, 20, 24]) {
        assert.equal(geometry.maskRadius(1280, 720, radius, border), radius);
        assert(geometry.maskRadius(1, 1, radius, border) >= 0);
        assert(Number.isFinite(geometry.maskRadius(NaN, Infinity, radius, border)));
    }
    assert.deepEqual(geometry.horizontalBounds(1280, border), {start: border, end: 1280 - border});
    for (const width of [0, 1, 8, 1280, NaN, Infinity]) {
        const bounds = geometry.horizontalBounds(width, border);
        assert(Number.isFinite(bounds.start) && Number.isFinite(bounds.end));
        assert(bounds.start >= 0 && bounds.end >= bounds.start);
        if (Number.isFinite(width)) assert(bounds.end <= width);
    }
}

// A captured module uses the same screen coordinates across all host placements.
const anchor = {x: 1180, y: 8, width: 32, height: 24};
assert.deepEqual(geometry.localizeRect(anchor, {x: 0, y: 0, width: 1280, height: 720}), anchor);
assert.deepEqual(geometry.localizeRect(anchor, {x: 1000, y: 0, width: 280, height: 720}),
    {x: 180, y: 8, width: 32, height: 24});
assert.deepEqual(geometry.localizeRect({x: 20, y: 8, width: 32, height: 24},
    {x: 10, y: 4, width: 300, height: 700}), {x: 10, y: 4, width: 32, height: 24});

// Clipped and malformed anchors cannot produce masks outside their host.
for (const anchor of [null, {}, {x: -40, y: -10, width: 70, height: 40},
    {x: 2000, y: 1000, width: 60, height: 30}, {x: NaN, y: Infinity, width: -1, height: NaN}]) {
    const result = geometry.localizeRect(anchor, {x: 10, y: 4, width: 300, height: 700});
    assert(Object.values(result).every(Number.isFinite));
    assert(result.x >= 0 && result.y >= 0 && result.width >= 0 && result.height >= 0);
    assert(result.x + result.width <= 300 && result.y + result.height <= 700);
}
console.info('ScreenGeometry tests passed');
