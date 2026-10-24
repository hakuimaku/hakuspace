#!/usr/bin/env node
// Exercise settings coverage, search, crop geometry and production interaction transitions.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const shell = path.resolve(__dirname, '../src/home/.config/quickshell/hakuspace')

// Load QML JavaScript modules without requiring a compositor.
function moduleAt(relative) {
    const context = vm.createContext({})
    vm.runInContext(fs.readFileSync(path.join(shell, relative), 'utf8'), context)
    return context
}
const catalog = moduleAt('components/settings/SettingsCatalog.js')
const crop = moduleAt('components/dashboard/AvatarCropGeometry.js')
// Every editable template assignment is available and searchable without a mode switch.
const template = fs.readFileSync(path.resolve(__dirname, '../src/home/hakucfg/setting.sh'), 'utf8')
const keys = [...template.matchAll(/^([A-Z_]+)=/gm)].map(match => match[1]).filter(key => key !== 'SETTING_VERSION')
assert.deepEqual(Array.from(catalog.general.filter(item => item.store === 'general'), item => item.key).sort(), keys.sort())
const typography = Array.from(catalog.general.filter(item => item.store === 'theme'))
assert.deepEqual(typography.map(item => item.id).sort(), ['font-family', 'font-size'])
assert(typography.every(item => item.category === 'General'))
assert(catalog.search('font family').some(item => item.id === 'font-family'))
assert(catalog.search('font size').some(item => item.id === 'font-size'))
assert.equal(catalog.general.find(item => item.key === 'SCREENSHOT_DIR').summary, '')
assert(!catalog.categories.includes('Advanced') && !catalog.categories.includes('Shortcuts'))
assert(catalog.categories.includes('Session') && catalog.categories.includes('Configuration'))
for (const item of catalog.general) {
    assert(catalog.categories.includes(item.category), item.key)
    assert(catalog.search(item.key).some(result => result.key === item.key), item.key)
    if (item.control === 'number') assert(item.min > 0 && item.max >= item.min, item.key)
}
assert.equal(catalog.search('blue light')[0].key, 'NIGHT_LIGHT_TEMPERATURE')
assert.equal(catalog.search('video cache').length, 1)
assert.equal(catalog.general.find(item => item.key === 'REC_OPTS').category, 'Recording')
assert.equal(catalog.general.find(item => item.key === 'AWWW_OPTS').category, 'Wallpaper')
assert.equal(catalog.general.find(item => item.key === 'WAYBAR_MODE_USER').category, 'Appearance')
for (const wm of ['hyprland', 'niri', 'mango']) {
    const files = ['hyprland-custom.lua', 'niri-custom.kdl', 'mango-custom.conf'].map(name => ({id: `wm/${name}`}))
    files.push({id: 'config/cava-layer'})
    const order = files.map(file => file.id)
    const sorted = catalog.configFiles(files, wm)
    assert.equal(sorted.length, files.length)
    assert.equal(sorted[0].id.split('/')[1].split('-')[0], wm)
    assert.deepEqual(files.map(file => file.id), order, 'sorting does not mutate the store')
}
for (const [width, height] of [[4000, 1000], [1000, 4000], [512, 512]]) {
    const scale = crop.cover(width, height, 320)
    assert(width * scale >= 320 && height * scale >= 320)
    for (const zoom of [1, 2, 4]) {
        for (const desired of [-10000, 0, 10000]) {
            const extent = width * scale * zoom
            const center = crop.center(desired, extent, 320)
            assert((320 - extent) / 2 + center <= 0)
            assert((320 + extent) / 2 + center >= 320)
        }
    }
}
// Use the actual UiState methods with signals and the activePanel handler wired in order.
const source = fs.readFileSync(path.join(shell, 'services/UiState.qml'), 'utf8')
const state = vm.createContext({
    Qt: {rect: (x, y, width, height) => ({x, y, width, height})},
    nativeDialogOwner: '', nativeDialogScreenName: '', nativeDialogSerial: 0,
    interactionOwner: '', interactionScreenName: '', tempNoteOpen: false, tempNoteScreenName: '',
    navigationMode: 'closed', navigationScreenName: '', dashboardVisuallyActive: false,
    wallpaperScreenName: '', settingsScreenName: '', actionMenuScreenName: '',
    hakuMenuMode: 'closed', hakuMenuScreenName: '', trayMenu: null, notificationPanel: null,
    Theme: {pad: 10, fontSize: 14}, ScreenGeometry: {fallbackModuleAnchor: () => ({})},
    released: [], flushed: [], interactionReleasing(owner, screen) { state.released.push([owner, screen]) },
    tempNoteClosing(screen) { state.flushed.push(screen) }, nativeDialogFinished() {},
    tempNoteFocusRequested(screen) { state.claimInteraction('tempNote', screen) }
})
const methods = [...source.matchAll(/^    function [\s\S]*?^    }/gm)].map(match => match[0].replace(/: string/g, ''))
vm.runInContext(methods.join('\n'), state)
Object.defineProperty(state, 'nativeDialogOpen', {get: () => state.nativeDialogOwner.length > 0})
const activeHandler = source.match(/^    onActivePanelChanged: \{([\s\S]*?)^    }/m)[1]
let active = ''
Object.defineProperty(state, 'activePanel', {get: () => active, set(value) { if (active === value) return; active = value; vm.runInContext(activeHandler, state) }})
for (let index = 0; index < 20; index++) {
    const screen = index % 2 ? 'B' : 'A'
    state.openNavigation(screen, {})
    assert(state.ownsInteraction('navigation', screen))
    state.openTempNote(screen)
    assert.equal(state.activePanel, '')
    assert.equal(state.navigationMode, 'closed')
    assert(state.ownsInteraction('tempNote', screen))
    state.openSettings(screen)
    assert(state.tempNoteOpen)
    assert(state.ownsInteraction('settings', screen))
    state.claimInteraction('tempNote', screen)
    state.closeTempNote()
    assert.equal(state.interactionOwner, '')
    assert.equal(state.activePanel, 'settings')
    state.claimInteraction('settings', screen)
    state.closeSettings()
    assert.equal(state.interactionOwner, '')
}
state.openTempNote('A')
state.claimInteraction('tempNote', 'A')
state.openTempNote('B')
assert(!state.ownsInteraction('tempNote', 'A'))
state.closeTempNoteIfScreen('A')
assert(state.tempNoteOpen)
state.closeTempNoteIfScreen('B')
assert(!state.tempNoteOpen)

// Folder and avatar pickers must suspend input and ignore stale completion tokens.
state.openSettings('A')
const lease = state.beginNativeDialog('settings')
assert(lease > 0 && state.nativeDialogOpen)
assert(state.ownsInteraction('nativeDialog', 'A'))
state.endNativeDialog(lease - 1)
assert(state.nativeDialogOpen)
state.endNativeDialog(lease)
assert(!state.nativeDialogOpen && state.ownsInteraction('settings', 'A'))
for (const value of ['~/Pictures', '$HOME/Pictures', '${HOME}/Pictures'])
    assert.equal(catalog.folderPath(value, '/home/test'), '/home/test/Pictures')
assert.equal(catalog.folderPath('/Pictures', '/home/test'), '/Pictures')
assert.equal(catalog.folderPath('$(command)', '/home/test'), '$(command)')

console.log('Hikai UX logic checks passed')
