const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
// Execute the same pure model functions imported by DockApps.qml.
const model = vm.createContext({})
vm.runInContext(fs.readFileSync(require('node:path').resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/services/DockAppModel.js'), 'utf8'), model)
const firefox = {id: 'firefox.desktop', name: 'Firefox', icon: 'firefox', startupClass: 'FirefoxClass'}
const kitty = {id: 'kitty', name: 'Kitty', icon: 'kitty', startupClass: 'kitty'}
const entries = [firefox, kitty]
const lookup = id => model.resolve(id, entries, candidate => entries.find(e => e.id === candidate),
    candidate => candidate === 'org.mozilla.firefox' ? firefox : null)
const a = {appId: 'firefox', title: 'A', activated: false}
const b = {appId: 'org.mozilla.firefox', title: 'B', activated: true}
const c = {appId: 'discord', title: 'C', activated: false}
let groups = model.group([a, b, c], lookup)
assert.equal(groups.length, 2)
assert.equal(groups[0].runningCount, 2)
assert.equal(groups[0].active, true)
assert.equal(lookup('FirefoxClass'), firefox)
assert.equal(model.nextWindow(groups[0].windows), a)
a.activated = true; b.activated = false
assert.equal(model.nextWindow(groups[0].windows), b)
a.activated = false
assert.equal(model.nextWindow(groups[0].windows, a), b)
assert.equal(model.nextWindow(groups[0].windows, b), a)
assert.equal(model.nextWindow([]), null)
let pins = [{id: 'menu', type: 'system'}, {id: 'kitty', type: 'app'}, {id: 'firefox', type: 'app'}]
let merged = model.merge(pins, groups, lookup)
assert.equal(merged.map(e => e.key).join(','), 'system:menu,kitty,firefox,discord')
assert.equal(merged[2].runningCount, 2)
assert.equal(merged[1].runningCount, 0)
assert.equal(merged[3].pinned, false)
groups = model.group([c], lookup)
merged = model.merge(pins, groups, lookup)
assert.equal(merged[2].runningCount, 0)
assert.equal(model.merge(pins, [], lookup).length, 3)
assert.equal(model.group([], lookup).length, 0)
assert.equal(model.group([{appId: '', title: 'Unknown'}, {appId: '', title: 'Other'}], lookup).length, 2)
console.log('Dock application model checks passed')
