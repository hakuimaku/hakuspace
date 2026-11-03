const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
// Check attached bounds with either bottom host and physical frame reservations.
const geometry = vm.createContext({})
vm.runInContext(fs.readFileSync(require('node:path').resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/hakumenu/HakuMenuGeometry.js'), 'utf8'), geometry)
for (const [width, height] of [[320, 240], [1024, 768], [1280, 720], [1920, 1080], [2560, 1440]]) {
    for (const border of [0, 4, 6]) {
        for (const icon of [32, 48, 72]) {
            for (const [barHeight, opposite] of [[icon + 17, border], [icon + 17 + border, 52]]) {
                const attached = geometry.attachedTaskSize(width, height, border, border, barHeight, opposite)
                assert.equal(attached.width, Math.min(width * 0.45, width - border * 2))
                assert.equal(attached.height, Math.min(height * 0.45, height - barHeight - opposite))
                assert.ok(attached.height <= height - barHeight - opposite)
            }
        }
    }
}
console.log('HakuMenu attached geometry checks passed')
// Preserve every existing profile while sharing the final width with host chrome.
for (const width of [1, 320, 1024, 1280, 1920, 2560]) {
    for (const border of [0, 4, 6, width]) {
        for (const mode of ['general', 'theme', 'drun', 'closed']) {
            const expected = width * (mode === 'general' ? 0.38 : mode === 'theme' ? 0.36 : 0.40)
            assert.equal(geometry.targetWidth(width, 'hakumenu', mode, border, border), expected)
            assert.equal(geometry.targetWidth(width, 'taskManager', mode, border, border),
                Math.min(width * 0.45, Math.max(1, width - border * 2)))
        }
    }
}
console.log('HakuMenu shared target width checks passed')

// Content may grow for four readable pin rows while staying inside the same host bounds.
for (const preferred of [0, 390, 570, 900]) {
    const size = geometry.attachedTaskSize(1280, 720, 4, 4, 69, 48, preferred)
    assert.equal(size.height, Math.min(Math.max(720 * 0.45, preferred), 720 - 69 - 48))
}
