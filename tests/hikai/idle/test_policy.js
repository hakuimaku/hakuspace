#!/usr/bin/env node
// Exercise production idle transitions and Session search targets without waiting for timeouts.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const shell = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace')
const policy = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(shell, 'services/idle/IdlePolicy.js'), 'utf8'), policy)
// Normalize VM objects before comparing their complete transition contract.
function step(...args) { return JSON.parse(JSON.stringify(policy.transition(...args))) }
assert.deepEqual(step(true, true, false, false), {pending: true, applied: false, action: 'retry'})
assert.deepEqual(step(true, true, false, true), {pending: false, applied: true, action: 'apply'})
assert.deepEqual(step(true, true, true, true), {pending: false, applied: true, action: ''})
assert.deepEqual(step(true, false, true, true), {pending: false, applied: false, action: 'resume'})
assert.deepEqual(step(true, false, false, false), {pending: false, applied: false, action: ''})
assert.deepEqual(step(false, true, true, true), {pending: false, applied: false, action: 'resume'})
assert.equal(policy.active('classic', true, true), false)
assert.equal(policy.active('hikai', false, true), false)
assert.equal(policy.active('hikai', true, false), false)
assert.equal(policy.active('hikai', true, true), true)
// Production callers cannot dispatch forceStage even when the service is enabled.
const service = fs.readFileSync(path.join(shell, 'services/IdleService.qml'), 'utf8')
const forceSource = service.match(/function forceStage\(name\) \{([\s\S]*?)\n    \}/)[1]
const forceStage = new Function('Quickshell', 'enabled', 'stages', 'name', forceSource)
assert.equal(forceStage({env: () => ''}, true, {}, 'suspend'), 'error:test-only')
const catalog = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(shell, 'config/SettingsCatalog.js'), 'utf8')
    .replace(/^\.pragma library\r?\n/, ''), catalog)
for (const [query, id, provider] of [
    ['sleep', 'idle-suspendEnabled', 'shell'],
    ['lock', 'idle-lockEnabled', 'shell'],
    ['idle', 'idle-enabled', 'shell'],
    ['screen off', 'idle-displayOffTimeout', 'shell'],
    ['caffeine', 'idle-keep-awake', 'runtime-state'],
    ['audio playback', 'idle-inhibitOnAudio', 'shell'],
]) {
    const result = catalog.search(query).find(item => item.id === id)
    assert(result, query)
    assert.equal(result.category, 'Power & Session', query)
    assert.equal(result.provider, provider, query)
    assert.equal(result.store, provider, query)
}
console.log('PASS: idle policy and Power & Session search targets')
