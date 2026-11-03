#!/usr/bin/env node
// Exercise production state methods without a desktop or backend collectors.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const source = fs.readFileSync(path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/services/UiState.qml'), 'utf8')
const state = vm.createContext({hakuPanelTab: 'hakumenu', hakuMenuMode: 'theme', hakuMenuQuery: '~', activePanel: 'hakumenu'})
vm.runInContext([...source.matchAll(/^    function (?:setHakuPanelTab|setHakuMenuMode|setHakuMenuQuery|closeHakuMenu)\([\s\S]*?^    }/gm)].map(match => match[0]).join('\n'), state)
assert.match(source, /property string hakuPanelTab: "hakumenu"/)
for (const mode of ['general', 'drun', 'theme']) {
    state.hakuMenuMode = mode
    for (let cycle = 0; cycle < 50; cycle++) {
        state.setHakuPanelTab('taskManager')
        assert.equal(state.hakuMenuMode, mode)
        state.setHakuMenuQuery('>blocked')
        assert.equal(state.hakuMenuQuery, '~')
        state.setHakuPanelTab('invalid')
        assert.equal(state.hakuPanelTab, 'taskManager')
        state.setHakuMenuMode('taskManager')
        assert.equal(state.hakuMenuMode, mode)
        state.setHakuPanelTab('hakumenu')
        assert.equal(state.hakuMenuMode, mode)
    }
}
state.setHakuPanelTab('taskManager')
state.closeHakuMenu()
assert.equal(state.hakuPanelTab, 'hakumenu')
assert.equal(state.hakuMenuMode, 'closed')
console.log('HakuMenu root tab state checks passed')

// Source metadata and the interaction anchor cannot leak across sessions.
Object.assign(state, {
    ChromeLayout: {defaultHakuMenuPresentation: 'topFlare', topEdgeHakuMenuEnabled: true, taskbarMode: false, dockbarActive: true},
    Quickshell: {screens: [{name: 'A', width: 1280, height: 720}]},
    ShellSettingsStore: {dockIconSize: 48}, ScreenGeometry: {taskbarHeight: 65},
    claimInteraction() {}
})
vm.runInContext([...source.matchAll(/^    function (?:resolveHakuMenuPresentation|openHakuMenu|toggleHakuMenu)\([\s\S]*?^    }/gm)].map(match => match[0]).join('\n'), state)
assert.equal(state.resolveHakuMenuPresentation('edge'), 'topFlare')
assert.equal(state.resolveHakuMenuPresentation('dockbar'), 'bottomFlare')
assert.equal(state.resolveHakuMenuPresentation('taskbar'), '')
const anchor = {x: 40, y: 660, width: 48, height: 48}
state.openHakuMenu('A', 'drun', 'dockbar', anchor)
assert.equal(state.hakuMenuSource, 'dockbar')
assert.equal(state.hakuMenuStyle, 'bottomFlare')
anchor.x = 100
assert.equal(state.hakuMenuAnchorRect.x, 40)
state.toggleHakuMenu('A', 'drun', 'dockbar', anchor)
assert.equal(state.activePanel, '')
assert.equal(state.hakuMenuSource, '')
for (const invalid of [null, {x: NaN, y: 0, width: 1, height: 1}, {x: 0, y: Infinity, width: 1, height: 1}, {x: 0, y: 0, width: 0, height: 1}]) {
    state.openHakuMenu('A', 'drun', 'dockbar', invalid)
    assert.equal(state.activePanel, '')
}
state.ChromeLayout.dockbarActive = false
state.openHakuMenu('A', 'drun', 'dockbar', anchor)
assert.equal(state.activePanel, '')
state.ChromeLayout.taskbarMode = true
state.ChromeLayout.topEdgeHakuMenuEnabled = false
state.ChromeLayout.defaultHakuMenuPresentation = 'bottomFlare'
assert.equal(state.resolveHakuMenuPresentation('edge'), '')
assert.equal(state.resolveHakuMenuPresentation('taskbar'), 'bottomFlare')
state.openHakuMenu('A', 'general', 'taskbar', anchor)
assert.equal(state.hakuMenuSource, 'taskbar')
state.openHakuMenu('A', 'general', 'invalid', anchor)
assert.equal(state.hakuMenuSource, 'taskbar')
state.closeHakuMenu()
state.openHakuMenu('A', 'general')
assert.equal(state.hakuMenuSource, 'default')
console.log('HakuMenu source and anchor state checks passed')

// Returning to the owning host emits intent before clearing the menu state.
const returnedScreens = []
state.hakuMenuReturnRequested = screen => returnedScreens.push(screen)
vm.runInContext(source.match(/^    function returnFromHakuMenu\([^]*?^    }/m)[0], state)
state.returnFromHakuMenu()
assert.deepEqual(returnedScreens, ['A'])
assert.equal(state.activePanel, '')
state.returnFromHakuMenu()
assert.deepEqual(returnedScreens, ['A'])
console.log('HakuMenu host return checks passed')
