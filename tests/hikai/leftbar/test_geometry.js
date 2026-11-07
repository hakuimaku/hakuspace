// Exercise rail placement and shared chrome geometry without a running compositor.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const base = 'src/home/.config/quickshell/hakuspace/'
const geometry = {}
vm.createContext(geometry)
vm.runInContext(fs.readFileSync(base + 'components/sidebar/NavigationGeometry.js', 'utf8').replace('.pragma library', ''), geometry)
for (const [width, height] of [[1366, 768], [1920, 1080], [2560, 1440], [3440, 1440]]) {
    for (const fontScale of [1, 1.25, 1.5]) {
        for (const horizontal of [true, false]) {
            const diameter = Math.max(146, 14 * fontScale * 10.5) + 8
            const thickness = Math.max(70, 14 * fontScale * 3.1 + 24)
            const rail = geometry.rail(horizontal, diameter, thickness, 260, width, height)
            const bridge = geometry.bridge(horizontal, diameter, rail)
            assert(rail.x >= 0 && rail.y >= 0 && rail.x + rail.width <= width && rail.y + rail.height <= height)
            assert(bridge.width > 0 && bridge.height > 0)
            if (horizontal) {
                assert(bridge.x + bridge.width > rail.x)
                assert.equal(rail.y, 0)
            } else {
                assert(bridge.y + bridge.height > rail.y)
                assert.equal(rail.x, 0)
            }
        }
    }
}
console.log('Leftbar rail geometry passed across output sizes and font scales')

// Narrow panels must fit to the right of Leftbar without changing other layouts.
const settingsSource = fs.readFileSync(base + 'components/SettingsPanel.qml', 'utf8')
const taskSource = fs.readFileSync(base + 'components/TaskManagerOverlay.qml', 'utf8')
const settingsWidth = settingsSource.match(/readonly property real targetBodyWidth: ([^\n]+)/)[1]
const taskWidth = taskSource.match(/readonly property real cardWidth: ([^\n]+)/)[1]
for (const width of [320, 720, 1024, 1366, 1920, 2560]) {
    for (const leftBarMode of [false, true]) {
        const state = vm.createContext({width, modelData: {width}, cardSize: {width: 1100},
            ChromeLayout: {leftBarMode}, ScreenGeometry: {contentLeftEdge: 66, reservedLeft: 66, rightInset: 4}})
        const settings = vm.runInContext(settingsWidth, state)
        const task = vm.runInContext(taskWidth, state)
        assert(settings > 0 && settings <= width)
        assert(task > 0 && task <= width)
        if (leftBarMode) {
            assert((width - settings) / 2 >= 66 + 16)
            assert(task + 66 + 4 <= width)
        } else {
            assert.equal(settings, Math.min(1180, width - 64))
            assert.equal(task, Math.min(1100, width))
        }
    }
}
console.log('Leftbar panel clearances and unchanged horizontal layouts passed')
