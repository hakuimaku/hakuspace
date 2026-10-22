const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
// Run the pure production functions without a compositor or QML runtime.
function load(path) {
    const context = vm.createContext({})
    vm.runInContext(fs.readFileSync(path, 'utf8'), context)
    return context
}
const model = load('src/home/.config/quickshell/hakuspace/services/WindowNavigatorModel.js')
const geometry = load('src/home/.config/quickshell/hakuspace/components/windownav/WindowNavigatorGeometry.js')
const addresses = entries => entries.map(entry => entry.address).join(',')
const fixture = (address, workspace = 1, monitor = 'DP-1') => ({address, title: 'Same title',
    workspace: {id: workspace, name: workspace < 0 ? 'special:magic' : String(workspace)},
    monitor: {name: monitor}, activated: address === 'c', urgent: address === 'b',
    wayland: {appId: 'same-app', minimized: false, fullscreen: false, parent: null}})
const raw = [fixture('a'), fixture('b'), fixture('c'), fixture('d', 2), fixture('e', 3, 'DP-2'), fixture('f', -99)]
const windows = model.normalize(raw.concat(raw[0], {address: '', workspace: {id: 1}}, {address: 'ghost'}), () => null)
assert.equal(windows.length, 6)
assert.equal(windows[0].key, 'hypr:a')
assert.equal(windows[0].icon, 'application-x-executable')
assert.equal(windows[5].special, true)
assert.equal(windows[1].urgent, true)
assert.equal(model.normalize([fixture('a')], () => ({id: 'app.desktop', name: 'App', icon: 'app'}))[0].appName, 'App')
let mru = model.mru(['b', 'a', 'b', 'closed'], windows, 'c')
assert.equal(mru.join(','), 'c,b,a,d,e,f')
mru = model.mru(mru, windows, 'b')
assert.equal(mru.join(','), 'b,c,a,d,e,f')
const snapshot = model.ordered(windows, mru, false, 1, 'DP-1')
assert.equal(snapshot[model.cycle(0, 1, 6)].address, 'c')
assert.equal(model.cycle(0, -1, 6), 5)
assert.equal(model.cycle(5, 1, 6), 0)
assert.equal(model.cycle(0, 1, 0), -1)
assert.equal(addresses(model.ordered(windows, ['f', 'e', 'd', 'c', 'b', 'a'], true, 1, 'DP-1')), 'c,b,a,d,e,f')
assert.equal(model.ordered(windows, mru, true, -99, 'DP-1')[0].address, 'f')
const changed = windows.filter(window => window.address !== 'c').concat(model.normalize([fixture('g')], () => null))
const reconciled = model.reconcile(snapshot, changed, false, 'c', 1)
assert.equal(addresses(reconciled.windows), 'b,a,d,e,f')
assert.equal(reconciled.index, 1)
assert.equal(model.reconcile(snapshot, changed, false, 'a', 2).index, 1)
assert.equal(model.reconcile(snapshot, [], false, 'c', 1).index, -1)
assert.equal(model.reconcile(snapshot, changed, true, 'c', 1).windows.length, 6)
assert.equal(model.reconcile(snapshot, changed, true, 'g', 0).index, 5)
assert.equal(addresses(snapshot), 'b,c,a,d,e,f')

// Cover small, crowded, portrait, ultrawide and unusually tiny output regions.
for (const [width, height] of [[1920, 1000], [700, 1200], [3400, 900], [80, 60]]) {
    for (const count of [1, 2, 3, 4, 6, 9, 12, 20]) {
        const cards = geometry.layout(width, height, count, 20)
        assert.equal(cards.length, count)
        cards.forEach((card, index) => {
            assert.ok(card.width > 0 && card.height > 0)
            assert.ok(card.x >= -0.001 && card.y >= -0.001)
            assert.ok(card.x + card.width <= width + 0.001 && card.y + card.height <= height + 0.001)
            cards.slice(index + 1).forEach(other => {
                assert.ok(card.x + card.width <= other.x + 0.001 || other.x + other.width <= card.x + 0.001
                    || card.y + card.height <= other.y + 0.001 || other.y + other.height <= card.y + 0.001)
            })
            for (const direction of ['left', 'right', 'up', 'down']) {
                const neighbor = geometry.neighbor(cards, index, direction)
                assert.ok(neighbor >= 0 && neighbor < count)
                assert.equal(geometry.neighbor(cards, index, direction), neighbor)
            }
        })
    }
}
const grid = geometry.layout(1200, 800, 4, 20)
assert.equal(geometry.neighbor(grid, 0, 'right'), 1)
assert.equal(geometry.neighbor(grid, 0, 'down'), 2)
assert.equal(geometry.neighbor(grid, 3, 'left'), 2)
assert.equal(geometry.neighbor(grid, 3, 'up'), 1)
assert.equal(geometry.neighbor(grid, 0, 'left'), 0)
assert.equal(geometry.layout(0, 0, 4, 20).length, 0)
assert.ok(geometry.ribbonWidth(true, 120) <= 120)
assert.equal(geometry.ribbonWidth(true, 1920), 280)
assert.equal(geometry.ribbonWidth(false, 1920), 64)
console.log('PASS: Window Navigator identity, MRU, snapshots, ordering and geometry')
