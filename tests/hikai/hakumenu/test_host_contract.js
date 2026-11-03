#!/usr/bin/env node
// Guard menu geometry independence and bottom-edge attachment.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const base = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace')
const read = name => fs.readFileSync(path.join(base, name), 'utf8')
for (const file of ['services/UiState.qml', 'components/appbar/AppBarContent.qml', 'components/hakumenu/HakuMenuAttachedFlare.qml', 'components/flare/FlareMorph.qml']) {
    assert.doesNotMatch(read(file), /hakuMenuSeedRect|hakuMenuSeedProvider|capturedSeed|animateOpenSpan|collapseSpan|animateSpan/)
}
const ui = read('services/UiState.qml')
for (const name of ['openHakuMenu', 'toggleHakuMenu']) {
    assert.equal(ui.match(new RegExp('function ' + name + '\\(([^)]*)\\)'))[1].split(',').length, 4)
}
assert.match(read('components/hakumenu/HakuMenuAttachedFlare.qml'), /Geometry\.targetWidth/)
assert.doesNotMatch(read('components/DockBar.qml'), /screenWidth\s*\*\s*0\.(?:36|38|40)|modelData\.width\s*\*\s*0\.(?:36|38|40)/)
const source = read('services/ScreenGeometry.qml')
const state = vm.createContext({ChromeLayout: {taskbarMode: false, dockbarActive: false},
    bottomInset: 4, taskbarHeight: 65, dockbarHeight: 53})
vm.runInContext([...source.matchAll(/^    function bottomHostReservation\([^]*?^    }/gm)].map(match => match[0]).join('\n'), state)
// The one-line helper is extracted separately from the multi-line reservation.
vm.runInContext(source.match(/^    function bottomHostTop\([^\n]+/m)[0], state)
for (const height of [240, 768, 720, 1080]) {
    assert.equal(state.bottomHostTop(height), height - 4)
    state.ChromeLayout.dockbarActive = true
    assert.equal(state.bottomHostTop(height), height - 4)
    state.ChromeLayout.taskbarMode = true
    state.bottomInset = 0
    assert.equal(state.bottomHostTop(height), height - 65)
    state.ChromeLayout.taskbarMode = false
    state.ChromeLayout.dockbarActive = false
    state.bottomInset = 4
}
console.log('HakuMenu/Dock screen-edge host checks passed')
