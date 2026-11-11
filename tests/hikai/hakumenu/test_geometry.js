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

// Evaluate the host's production bindings so editor sizing respects either attachment edge.
const path = require('node:path')
const hostSource = fs.readFileSync(path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/components/hakumenu/HakuMenuAttachedFlare.qml'), 'utf8')
const availableExpression = hostSource.match(/readonly property real availableMenuHeight: ([\s\S]*?)\n    readonly property real menuHeight:/)[1]
const heightExpression = hostSource.match(/readonly property real menuHeight: ([\s\S]*?)\n    readonly property real surfaceHeight:/)[1]
for (const screenHeight of [240, 720, 1080]) {
    for (const edge of ["top", "left", "bottom"]) {
        const bottomAttached = edge === "bottom"
        for (const editorHeight of [0, 460, 610, 1000]) {
            const bar = bottomAttached ? 69 : edge === "left" ? 0 : 40
            const state = vm.createContext({screenHeight, bottomAttached, controlHeight: bottomAttached ? 32 : 0,
                taskManagerTab: false, taskSize: {}, menu: {editorHeight}, root: {screenHeight},
                Theme: {topBarHeight: 40, hakuMenuHeightRatio: 0.42}, ScreenGeometry: {topChromeHeight: edge === "left" ? 0 : 40, bottomHostReservation: () => 37,
                    bottomHostOppositeInset: 40, bottomInset: 4}})
            state.availableMenuHeight = vm.runInContext(availableExpression, state)
            assert.equal(state.availableMenuHeight, screenHeight - bar - (bottomAttached ? 40 : 4))
            assert.equal(vm.runInContext(heightExpression, state),
                Math.min(Math.max(screenHeight * 0.42, editorHeight), state.availableMenuHeight))
        }
    }
}
console.log('General editor host height and output bounds passed')

// Minimum clamp bounds for small screens (e.g. 720p).
const ratios720 = {
    hakuMenuWidthRatio: 0.40,
    hakuMenuGeneralWidthRatio: 0.38,
    hakuMenuThemeWidthRatio: 0.36,
    hakuMenuMinWidth: 680,
    hakuMenuMinHeight: 450
}
// Width clamp: 1280 * 0.38 = 486.4, clamped to minWidth = 680.
assert.equal(geometry.targetWidth(1280, 'hakumenu', 'general', 0, 0, ratios720), 680)
// Width unclamped on large screen: 1920 * 0.38 = 729.6 > 680.
assert.equal(geometry.targetWidth(1920, 'hakumenu', 'general', 0, 0, ratios720), 729.6)

// Height clamp in host expression on 720p: 720 * 0.42 = 302.4, clamped to minHeight = 450.
const host720 = vm.createContext({
    screenHeight: 720, bottomAttached: false, controlHeight: 0,
    taskManagerTab: false, taskSize: {}, menu: {editorHeight: 0}, root: {screenHeight: 720},
    Theme: {topBarHeight: 40, hakuMenuHeightRatio: 0.42, hakuMenuMinHeight: 450},
    ScreenGeometry: {topChromeHeight: 40, bottomHostReservation: () => 37, bottomHostOppositeInset: 40, bottomInset: 4}
})
host720.availableMenuHeight = vm.runInContext(availableExpression, host720)
assert.equal(vm.runInContext(heightExpression, host720), 450)
console.log('HakuMenu 720p min-clamp checks passed')
