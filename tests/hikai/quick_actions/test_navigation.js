const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

// Exercise the production QML handler without adding test-only component options.
const source = fs.readFileSync(path.resolve(__dirname,
    '../../../src/home/.config/quickshell/hakuspace/components/sidebar/SidebarQuickActions.qml'), 'utf8')
const handler = source.match(/    function moveSelection\(dx, dy\) \{[\s\S]*?\n    \}/)[0]
for (const count of [1, 7, 8, 11]) {
    const context = { actions: Array(count), columnCount: 4, rowCount: Math.ceil(count / 4),
        selectedIndex: 0, keyboardCursor: false, returned: false }
    context.railFocusRequested = () => { context.returned = true }
    vm.createContext(context)
    vm.runInContext(handler, context)
    context.moveSelection(0, -1)
    assert.equal(context.selectedIndex, 0)
    context.moveSelection(-1, 0)
    assert.equal(context.returned, true)
    context.selectedIndex = count - 1
    context.moveSelection(1, 0)
    context.moveSelection(0, 1)
    assert.equal(context.selectedIndex, count - 1)
    if (count > 4) {
        context.selectedIndex = 3
        context.moveSelection(0, 1)
        assert.equal(context.selectedIndex, Math.min(7, count - 1))
        if (count === 11) {
            context.moveSelection(0, 1)
            assert.equal(context.selectedIndex, 10, 'Down clamps into the incomplete final row')
        }
        context.selectedIndex = count - 1
        context.moveSelection(0, -1)
        assert.equal(context.selectedIndex, count - 5)
    }
    assert.equal(context.keyboardCursor, true)
}
console.info('Quick Actions navigation passed for complete and incomplete rows')
