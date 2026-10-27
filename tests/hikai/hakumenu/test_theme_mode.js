#!/usr/bin/env node
// Check quick mode writes and draft preservation without a running desktop.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const shell = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace')
const source = fs.readFileSync(path.join(shell, 'services/ShellSettingsStore.qml'), 'utf8')
const store = vm.createContext({ready: true, loading: false, saving: false, error: '', writeProc: {}})

// Run production store methods with a process stub at the persistence boundary.
vm.runInContext([...source.matchAll(/^    function [\s\S]*?^    }/gm)].map(match => match[0]).join('\n'), store)
store.command = action => [action]
store.values = store.defaults()
store.savedValues = store.defaults()
for (const flag of ['loading', 'saving']) {
    store[flag] = true
    store.applyColorMode('light')
    assert.equal(store.writeProc.running, undefined)
    store[flag] = false
}
store.ready = false
store.applyColorMode('light')
assert.equal(store.writeProc.running, undefined)
store.ready = true
store.applyColorMode('invalid')
assert.equal(store.writeProc.running, undefined)

// A quick mode write sends only the selected mode, leaving previews untouched.
store.values.appearance.baseRadius = 20
store.values.appearance.colorMode = 'light'
store.applyColorMode('dark')
assert.deepEqual(JSON.parse(store.writeProc.environment.HAKUSPACE_HIKAI_SETTINGS_JSON), {appearance: {colorMode: 'dark'}})
assert.equal(store.writeProc.modeOnly, true)
assert.equal(store.writeProc.running, true)
assert.equal(store.savedValues.appearance.colorMode, 'dark')
assert.equal(store.values.appearance.colorMode, 'light')
assert.equal(store.saving, true)

// Failed or malformed responses cannot replace either settings snapshot.
for (const response of ['invalid json', JSON.stringify({ok: false}), JSON.stringify({ok: true, values: {}})]) {
    assert.throws(() => store.accept(response, true))
    assert.equal(store.values.appearance.baseRadius, 20)
    assert.equal(store.savedValues.appearance.baseRadius, 12)
}

// Preserve pending fields while accepting concurrent disk changes and the applied mode.
const saved = store.defaults()
saved.appearance.colorMode = 'light'
saved.topbar.clock = false
store.accept(JSON.stringify({ok: true, values: saved}), true)
assert.equal(store.values.appearance.colorMode, 'light')
assert.equal(store.values.appearance.baseRadius, 20)
assert.equal(store.savedValues.appearance.baseRadius, 12)
assert.equal(store.values.topbar.clock, false)
store.saving = false
store.discard()
assert.equal(store.values.appearance.colorMode, 'light')
assert.equal(store.values.appearance.baseRadius, 12)

// Normal Apply still writes the complete draft patch and accepts the saved snapshot.
store.values.appearance.surfaceTone = 'soft'
store.dirty = true
store.valid = true
store.apply()
assert.equal(store.writeProc.modeOnly, false)
assert.deepEqual(JSON.parse(store.writeProc.environment.HAKUSPACE_HIKAI_SETTINGS_JSON), {appearance: {surfaceTone: 'soft'}})
store.accept(JSON.stringify({ok: true, values: saved}))
assert.equal(store.values.appearance.surfaceTone, 'dark')
console.log('HakuMenu theme mode logic checks passed')
