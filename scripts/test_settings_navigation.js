const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')

// Run the same QML utility against minimal item geometry and key constants.
const Qt = Object.fromEntries(['Left', 'Right', 'Up', 'Down', 'Home', 'End'].map(key => ['Key_' + key, key]))
const nav = { Qt }
vm.runInNewContext(fs.readFileSync(path.join(__dirname,
    '../src/home/.config/quickshell/hakuspace/components/settings/SettingsNavigation.js'), 'utf8')
    .replace(/^\.pragma library\s*\n/, ''), nav)
const scope = { visible: true, enabled: true, children: [] }
function item(x, y, group) {
    return { visible: true, enabled: true, width: 40, height: 30, parent: scope,
        children: [], settingsNavItem: true, settingsNavRole: 'control', settingsNavGroup: group,
        activeFocusOnTab: false, mapToItem: (_, dx, dy) => ({ x: x + dx, y: y + dy }) }
}

const group = {}
const a = item(0, 0, group), b = item(60, 0, group)
const wrapped = item(0, 40, group), last = item(120, 90)
scope.children = [a, b, wrapped, last]
assert.equal(nav.collect(scope).length, 4, 'Tab metadata does not determine arrow targets')
a.activeFocusOnTab = true
assert.equal(nav.collect(scope).length, 4)
assert.equal(nav.rows(scope, nav.collect(scope)).length, 3, 'wrapped groups split into physical rows')
assert.equal(nav.next(scope, nav.collect(scope), a, Qt.Key_Right), b)
assert.equal(nav.next(scope, nav.collect(scope), b, Qt.Key_Left), a)
assert.equal(nav.next(scope, nav.collect(scope), a, Qt.Key_Left), null)
assert.equal(nav.next(scope, nav.collect(scope), b, Qt.Key_Down), wrapped)
assert.equal(nav.next(scope, nav.collect(scope), wrapped, Qt.Key_Right), null)
assert.equal(nav.next(scope, nav.collect(scope), wrapped, Qt.Key_Down), last)
assert.equal(nav.next(scope, nav.collect(scope), last, Qt.Key_Down), null)
assert.equal(nav.next(scope, nav.collect(scope), a, Qt.Key_Up), null)
b.visible = false
assert.equal(nav.next(scope, nav.collect(scope), a, Qt.Key_Right), null)
b.visible = true
b.enabled = false
assert.equal(nav.collect(scope).length, 3)
b.enabled = true
b.width = 0
assert.equal(nav.collect(scope).length, 3)
b.width = 40
const unrelated = item(120, 0)
assert.equal(nav.next(scope, [a, unrelated], a, Qt.Key_Right), null, 'unrelated rows never become horizontal peers')
const aligned = item(60, 40, group)
assert.equal(nav.next(scope, [a, b, wrapped, aligned], b, Qt.Key_Down), aligned)
assert.equal(nav.next(scope, [a, b, wrapped, aligned], aligned, Qt.Key_Up), b)
const coincident = item(60, 40, group)
assert.equal(nav.next(scope, [a, b, aligned, coincident], b, Qt.Key_Down), aligned, 'ties follow registry order')
assert.equal(nav.listTarget([a, b], b, Qt.Key_Right, false, true), a)
assert.equal(nav.listTarget([a, b], b, Qt.Key_Right, false, false), b)
assert.equal(nav.listTarget([a, b], b, Qt.Key_Home, false, false), a)
assert.equal(nav.listTarget([a, b], a, Qt.Key_End, false, false), b)
const child = { parent: a }
assert.equal(nav.owner(child), a)
assert.equal(nav.region(child, [scope]), 0)
const section = { parent: scope, settingsNavSection: 'Surface' }
a.parent = section
assert.equal(nav.section(child, scope), 'Surface')
assert.equal(nav.section(last, scope), '')
const header = item(0, 0), firstForm = item(0, -100), secondForm = item(0, -60)
const scroll = { parent: scope, contentItem: {}, contentX: 0, contentY: 160 }
firstForm.parent = scroll
secondForm.parent = scroll
assert.equal(nav.next(scope, [header, firstForm, secondForm], header, Qt.Key_Down), firstForm,
    'scroll offsets never reorder form rows around fixed controls')
assert.equal(nav.next(scope, [header, firstForm, secondForm], firstForm, Qt.Key_Up), header)
console.info('Settings navigation registry and row checks passed')
