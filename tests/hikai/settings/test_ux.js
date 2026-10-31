#!/usr/bin/env node
// Exercise settings coverage, search and production interaction transitions.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const shell = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace')

// Load QML JavaScript modules without requiring a compositor.
function moduleAt(relative) {
    const context = vm.createContext({})
    vm.runInContext(fs.readFileSync(path.join(shell, relative), 'utf8').replace(/^\.pragma library\s*$/m, ''), context)
    return context
}
const catalog = moduleAt('config/SettingsCatalog.js')
// Hikai exposes shared preferences while leaving Classic-only Waybar themes hidden.
const template = fs.readFileSync(path.resolve(__dirname, '../../../src/home/hakucfg/setting.sh'), 'utf8')
const keys = [...template.matchAll(/^([A-Z_]+)=/gm)].map(match => match[1]).filter(key => !['SETTING_VERSION', 'WAYBAR_MODE_USER'].includes(key))
assert.deepEqual(Array.from(catalog.general.filter(item => item.store === 'general'), item => item.key).sort(), keys.sort())
const typography = Array.from(catalog.general.filter(item => item.store === 'theme'))
assert.deepEqual(typography.map(item => item.id).sort(), ['font-family', 'font-size'])
assert(typography.every(item => item.category === 'Look'))
assert(catalog.search('font family').some(item => item.id === 'font-family'))
assert(catalog.search('font size').some(item => item.id === 'font-size'))
assert.equal(catalog.general.find(item => item.key === 'SCREENSHOT_DIR').summary, 'Save new screenshots in this folder.')
assert.deepEqual(Array.from(catalog.categories), ['Look', 'Shell', 'Wallpaper', 'Power & Session', 'Capture', 'Advanced', 'About'])
for (const item of catalog.general) {
    assert(catalog.categories.includes(item.category), item.key)
    assert(catalog.search(item.key).some(result => result.key === item.key), item.key)
    if (item.control === 'number') assert(item.min >= 0 && item.max >= item.min, item.key)
}
assert.equal(catalog.search('blue light')[0].key, 'NIGHT_LIGHT_TEMPERATURE')
assert(catalog.search('Theme Mode').some(item => item.id === 'colorMode'))
assert(catalog.search('cache').some(item => item.id === 'wallpaper.proxy.maxCacheMiB'))
assert.equal(catalog.descriptor('layout').persistMode, 'auto')
assert.equal(catalog.general.find(item => item.key === 'REC_OPTS').category, 'Advanced')
assert.equal(catalog.general.find(item => item.key === 'AWWW_OPTS').category, 'Advanced')
assert.equal(catalog.descriptor('WAYBAR_MODE_USER'), undefined)
assert.equal(catalog.search('waybar').length, 0)
assert.equal(catalog.search('classic').length, 0)
assert(!catalog.groups('Advanced').includes('Classic shell'))
for (const wm of ['hyprland', 'niri', 'mango']) {
    const files = ['hyprland-custom.lua', 'niri-custom.kdl', 'mango-custom.conf'].map(name => ({id: `wm/${name}`}))
    files.push({id: 'config/cava-layer'})
    const order = files.map(file => file.id)
    const sorted = catalog.configFiles(files, wm)
    assert.equal(sorted.length, files.length)
    assert.equal(sorted[0].id.split('/')[1].split('-')[0], wm)
    assert.deepEqual(files.map(file => file.id), order, 'sorting does not mutate the store')
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

// Schema dependencies and reset metadata cover every store field exactly once.
const ids = Array.from(catalog.descriptors, d => d.id)
assert.equal(new Set(ids).size, ids.length)
for (const d of catalog.descriptors) {
    assert(d.provider && d.group && d.persistMode && d.effectMode && d.availability && d.keywords)
    assert(typeof d.summary === 'string' && d.summary.trim().length > 0, `${d.id} needs a function description`)
    assert.notEqual(d.defaultValue, undefined, d.id)
    for (const rule of d.dependsOn) assert(catalog.descriptor(rule.id), rule.id)
}
assert.equal(catalog.descriptor('wallpaper.playback.loop').summary, 'Replay the wallpaper video when it ends.')
assert(catalog.descriptor('wallpaper.playback.hardwareDecode').summary.includes('Restart Hikai'))
const read = id => ({cava: false, layout: 'taskbar', 'cava-dynamic': true})[id]
assert(!catalog.dependencyState(catalog.descriptor('cava-color'), read).visible)
assert(!catalog.dependencyState(catalog.descriptor('cava-position'), id => id === 'cava' ? true : read(id)).visible)
assert(!catalog.dependencyState(catalog.descriptor('dockbar'), read).enabled)
assert(catalog.equal(catalog.descriptor('WALL_DIR'), '~/Pictures/Wallpapers', '$HOME/Pictures/Wallpapers', '/home/test'))
assert.equal(catalog.breadcrumb(catalog.descriptor('shell.topbar.clock')), 'Shell › Top Bar › Clock')
// Feature switches and conditional options keep their declared visual positions.
const groupIds = group => Array.from(catalog.descriptors.filter(d => d.category === 'Shell' && d.group === group), d => d.id)
assert.equal(groupIds('Dockbar')[0], 'dockbar')
assert.deepEqual(groupIds('Cava Underbar'), ['cava', 'cava-color', 'cava-dynamic', 'cava-position', 'cava-height'])
for (const d of catalog.descriptors) for (const rule of d.dependsOn) {
    const parent = catalog.descriptor(rule.id)
    if (parent.category === d.category && parent.group === d.group)
        assert(catalog.descriptors.indexOf(parent) < catalog.descriptors.indexOf(d), d.id)
}
const logic = moduleAt('components/settings/SettingsValueLogic.js')
const policy = {dimEnabled: true, dimTimeout: 300, lockEnabled: true, lockTimeout: 120, displayOffEnabled: true, displayOffTimeout: 120, suspendEnabled: true, suspendTimeout: 600}
assert.deepEqual(Array.from(logic.timeline(policy), s => s.absolute), [300, 420, 540, 1140])
assert.equal(logic.intervalAt(policy, 'lock', 427), 130)
assert.equal(logic.intervalAt(policy, 'dim', 0), 10)
assert.equal(logic.intervalAt(policy, 'suspend', 999999), 86400)
policy.lockEnabled = false
assert.deepEqual(Array.from(logic.timeline(policy), s => s.absolute), [300, 300, 420, 1020])
assert.equal(policy.lockTimeout, 120)
assert.equal(logic.intervalAt(policy, 'displayOff', 500), 200)
assert.equal(logic.parseDuration('5 min', {min: 10, max: 86400, step: 10}), 300)
assert.equal(logic.parseDuration('31 sec', {min: 10, max: 86400, step: 10}), null)
assert.equal(logic.parseDuration('bad', {min: 10, max: 86400, step: 10}), null)
const args = moduleAt('components/settings/SettingsArguments.js')
const raw = '--codec h264  --max-fps=60 --device "/dev/dri/render D128"'
assert(args.parse(raw, args.recording).safe)
assert.equal(args.replace(raw, args.recording, '--max-fps', 30), '--codec h264  --max-fps 30 --device "/dev/dri/render D128"')
for (const text of ['--max-fps 60 --max-fps 30', '--device "$GPU"', '--codec "unclosed', '--codec x; command', '--max-fps nope']) {
    assert(!args.parse(text, args.recording).safe, text)
    assert.equal(args.replace(text, args.recording, '--max-fps', 30), null)
}
assert.equal(args.extras('--max-fps 60 --codec h264', args.recording, '--codec hevc'), '--max-fps 60 --codec hevc')
assert.equal(args.extras('--max-fps 60', args.recording, '--max-fps 30'), null)
console.log('Settings redesign schema, dependencies, durations and argument preservation passed')

// Explicit conversion preserves variable arguments; command substitution remains raw.
const custom = '--max-fps 60 --device "$GPU"'
assert(!args.parse(custom, args.recording).safe)
assert(args.parse(custom, args.recording, true).safe)
assert.equal(args.replace(custom, args.recording, '--max-fps', 30, true), '--max-fps 30 --device "$GPU"')
assert(!args.parse('--max-fps 60 --device $(command)', args.recording, true).safe)
