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

// Evaluate production ownership for app clicks, default/IPC entry and output transfer.
const taskbar = read('components/Taskbar.qml')
const ownership = taskbar.match(/readonly property bool menuOwned: ([\s\S]*?)\n    readonly property real targetHeight:/)[1]
for (const source of ['taskbar', 'default', '']) {
    for (const active of [false, true]) {
        for (const style of ['topFlare', 'bottomFlare']) {
            for (const mode of ['closed', 'drun', 'general', 'theme']) {
                for (const screenName of ['A', 'B']) {
                    const context = {active, modelData: {name: 'A'}, UiState: {
                        activePanel: 'hakumenu', hakuMenuSource: source, hakuMenuStyle: style,
                        hakuMenuMode: mode, hakuMenuScreenName: screenName}}
                    assert.equal(vm.runInNewContext(ownership, context),
                        active && style === 'bottomFlare' && mode !== 'closed' && screenName === 'A')
                    context.UiState.activePanel = ''
                    assert.equal(vm.runInNewContext(ownership, context), false)
                }
            }
        }
    }
}
assert.match(taskbar, /active: root\.active\n\s+shown: root\.active && !root\.menuOwned/)
assert.match(taskbar, /viewportLimit: statusModules\.centerViewportWidth/)
assert.match(taskbar, /Component\.onDestruction: ScreenGeometry\.setTaskbarCenterRect\(registeredOutput, null\)/)

// Keep one arrow implementation and preserve its accessibility and motion contracts.
const control = read('components/hakumenu/HakuMenuReturnControl.qml')
const host = read('components/hakumenu/HakuMenuAttachedFlare.qml')
for (const pattern of [/objectName: "hakumenu-return-button"/, /Accessible\.name: "Close HakuMenu"/,
    /Accessible\.onPressAction: UiState\.returnFromHakuMenu\(\)/, /onClicked: UiState\.returnFromHakuMenu\(\)/,
    /duration: returnButton\.reducedMotion \? 0 : 650/, /duration: 2200/,
    /&& !returnButton\.reducedMotion/, /model: 3/, /arrowPhase \+ index \/ 3/]) assert.match(control, pattern)
assert.doesNotMatch(host, /NumberAnimation on arrowPhase|RadialGradient/)
assert.equal((host.match(/HakuMenuReturnControl \{/g) || []).length, 2)
assert.match(source, /bottomHostControlHeight: ChromeLayout\.dockbarActive && !ChromeLayout\.taskbarMode \? dockbarHeight : 0/)
assert.match(host, /surfaceHeight: menuHeight \+ controlHeight/)
assert.match(host, /menuTop: bottomAttached \? ScreenGeometry\.bottomHostTop\(screenHeight\) : ScreenGeometry\.topChromeHeight/)

// Exercise live center-lane publication, unchanged updates and output revocation.
const lanes = vm.createContext({taskbarCenterRects: {}})
vm.runInContext(source.match(/^    function setTaskbarCenterRect\([^]*?^    }/m)[0], lanes)
const rect = {x: 400, y: 655, width: 480, height: 65}
lanes.setTaskbarCenterRect('A', rect)
lanes.setTaskbarCenterRect('B', {...rect, width: 200})
const unchanged = lanes.taskbarCenterRects
lanes.setTaskbarCenterRect('A', {...rect})
assert.equal(lanes.taskbarCenterRects, unchanged)
lanes.setTaskbarCenterRect('A', null)
assert.equal(lanes.taskbarCenterRects.A, undefined)
assert.equal(lanes.taskbarCenterRects.B.width, 200)

// Evaluate the actual Taskbar lane binding across output sizes and lane changes.
const center = taskbar.match(/readonly property var centerRect: ([\s\S]*?)\n    property string registeredOutput:/)[1]
for (const width of [320, 1024, 1920]) for (const laneWidth of [0, 48, width / 3, width + 100]) {
    const context = {active: true, taskbarWindow: {width, height: 720}, targetHeight: 65,
        statusModules: {centerViewportWidth: laneWidth}, Safe: {rect: (x, y, width, height) => ({x, y, width, height})}}
    const result = vm.runInNewContext(center, context)
    assert.ok(result.x >= 0 && result.x + result.width <= width)
    assert.equal(result.y, 655)
    assert.equal(result.height, 65)
    assert.equal(result.width, Math.min(width, laneWidth))
    context.active = false
    assert.equal(vm.runInNewContext(center, context), null)
}
assert.match(host, /width: root\.taskbarReturnRect\.width; height: root\.taskbarReturnRect\.height/)
assert.match(host, /SafeZoneGeometry\.contains\(root\.taskbarReturnRect, x, y\)/)
assert.match(host, /Math\.min\(zone\.height, Math\.max\(0, menuTop - zone\.y\)\)/)
console.log('Taskbar handoff, shared return control and center-lane contracts passed')
