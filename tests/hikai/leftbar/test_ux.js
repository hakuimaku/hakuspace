// Exercise shared presentation geometry and controller boundaries without a desktop session.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const shell = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace')
const read = name => fs.readFileSync(path.join(shell, name), 'utf8')
function library(name) {
    const scope = vm.createContext({})
    vm.runInContext(read(name).replace(/^\.pragma library\s*$/m, ''), scope)
    return scope
}
function methods(name, scope, only) {
    const source = read(name)
    const functions = []
    for (const match of source.matchAll(/^    function \w+\(/gm)) {
        let end = source.indexOf('{', match.index), depth = 0, quote = ''
        for (; end < source.length; end++) {
            const character = source[end]
            if (quote) {
                if (character === '\\') end++
                else if (character === quote) quote = ''
                continue
            }
            if ('"\'`'.includes(character)) { quote = character; continue }
            if (character === '{') depth++
            if (character === '}' && --depth === 0) { end++; break }
        }
        functions.push(source.slice(match.index, end))
    }
    vm.runInContext(functions.filter(source => !only || source.trimStart().startsWith("function " + only + "(")).join('\n'), scope)
}
// Normal paint density and deliberate accessibility growth share one metrics owner.
const metrics = library('services/ScreenGeometry.js')
for (const [font, rail, visual, icon] of [[12, 46, 30, 14], [14, 46, 30, 16], [18, 50, 34, 20], [21, 54, 38, 24]]) {
    const result = metrics.leftMetrics(font)
    assert.equal(result.rail, rail)
    assert.equal(result.visual, visual)
    assert.equal(result.icon, icon)
    assert(result.touch >= 36 && result.visual + result.hover * 2 <= result.slot)
    assert.equal((result.rail - result.visual) / 2, 8)
    assert.equal(result.gap, Math.max(6, Math.ceil(font / 3)))
}
// Workspace markers retain the user's previous 20/50 style; only transparent hit mapping changes.
const workspaces = vm.createContext({items: [], activeIdx: 0, dot: 20, activeW: 50, gap: 6, vertical: true})
workspaces.root = workspaces
methods('components/top/Workspaces.qml', workspaces)
for (const count of [3, 5, 10]) {
    workspaces.items = Array.from({length: count}, (_, index) => ({special: index === 1}))
    for (const selected of [0, count - 1]) {
        workspaces.activeIdx = selected
        const end = workspaces.slotX(count - 1) + (count - 1 === selected ? 50 : 20)
        for (let position = 0.25; position < end; position += 0.5) assert(workspaces.indexAt(position) >= 0)
        assert.equal(workspaces.indexAt(-1), -1)
        assert.equal(workspaces.indexAt(end), -1)
    }
}
workspaces.vertical = false
workspaces.items = [{}, {}, {}]
workspaces.activeIdx = 0
assert.equal(workspaces.indexAt(52), -1)
assert.equal(workspaces.indexAt(56), 1)
// Bottom side tooltips use the real content edge rather than a detached inset shelf.
const tooltipBounds = read('components/base/TooltipLayer.qml').match(/readonly property var sideBounds: ([\s\S]*?)\n    readonly property real maxSideContentHeight/)[1]
for (const height of [768, 864, 1080]) {
    for (const dock of [4, 57]) {
        const tooltip = vm.createContext({height, sideMargin: 36, screenName: 'A',
            ScreenGeometry: {topBorderThickness: 4, bottomReservation: () => dock}})
        const bounds = vm.runInContext(tooltipBounds, tooltip)
        assert.equal(bounds.start, 4)
        assert.equal(bounds.end, height - dock)
    }
}

// Physical top paint is consumed once; Leftbar never reserves the old bottom frame.
const screenSource = read('services/ScreenGeometry.qml')
const topExpression = screenSource.match(/readonly property real topBorderThickness: ([^\n]+)/)[1]
const bottomExpression = screenSource.match(/readonly property real frameBottomReservation: ([^\n]+)/)[1]
for (const mode of ['top', 'left', 'bottom']) {
    for (const border of [0, 4]) {
        const screen = vm.createContext({ChromeLayout: {topBarMode: mode === 'top', leftBarMode: mode === 'left', taskbarMode: mode === 'bottom'},
            borderThickness: border, bottomInset: mode === 'bottom' ? 0 : border,
            bottomAttached: mode === 'bottom', chromeBarHeight: mode === 'top' ? 40 : mode === 'bottom' ? 53 : border})
        screen.topBorderThickness = vm.runInContext(topExpression, screen)
        assert.equal(screen.topBorderThickness, mode === 'top' ? 0 : border)
        assert.equal(vm.runInContext(bottomExpression, screen), mode === 'top' ? border : 0)
        methods('services/ScreenGeometry.qml', screen)
        assert.equal(screen.availableAttachedHeight(720), 720 - (mode === 'top' ? 40 + border : mode === 'bottom' ? 53 + border : border * 2))
    }
}
const seed = vm.createContext({leftAttached: true, surfaceStart: 4, surfaceEnd: 163, anchorStart: 8, anchorEnd: 38, anchorBodyHeight: 0, flareTargetHeight: 117})
methods('components/NavigationPanel.qml', seed)
seed.seedLogoGeometry()
assert.equal(seed.flareStart, 4)
assert.equal(seed.flareEnd, 163)
assert.equal(seed.flareHeight, 0)
seed.leftAttached = false
seed.anchorBodyHeight = 30
seed.seedLogoGeometry()
assert.equal(seed.flareStart, 8)
assert.equal(seed.flareEnd, 38)
assert.equal(seed.flareHeight, 30)
// A returned logo ignores stationary re-entry while preserving the next real hover.
const returns = []
const handoff = vm.createContext({leftAttached: true, modelData: {name: 'A'}, panelOpen: false,
    capturedAnchorRect: {x: 8, y: 11, width: 30, height: 30}, ScreenGeometry: {leftModuleTouchSize: 36},
    safeZoneHover: {hovered: true, point: {position: {x: 6, y: 12}}},
    UiState: {navigationVisualScreenName: 'A', navigationLogoReturning: (screen, inside) => returns.push([screen, inside]),
        finishNavigationVisual: screen => returns.push(['finish', screen])}})
handoff.root = handoff
methods('components/NavigationPanel.qml', handoff)
handoff.finishVisual()
assert.deepEqual(returns.splice(0), [['A', true], ['finish', 'A']])
handoff.safeZoneHover.point.position.x = 100
handoff.prepareLogoReturn()
assert.deepEqual(returns.splice(0), [['A', false]])
handoff.safeZoneHover.hovered = false
handoff.safeZoneHover.point.position.x = 10
handoff.prepareLogoReturn()
assert.deepEqual(returns.splice(0), [['A', false]])
handoff.leftAttached = false
handoff.prepareLogoReturn()
assert.equal(returns.length, 0)
// An active transfer must capture its own anchor before notifying the new output.
let capturedAnchor = null
const owner = vm.createContext({activePanel: 'navigation', navigationScreenName: 'A', navigationMode: 'open',
    navigationVisualScreenName: 'A', claimInteraction() {}, navigationAnchorRect: {width: 30}})
methods('services/UiState.qml', owner, 'openNavigation')
Object.defineProperty(owner, 'navigationScreenName', {get: () => 'A', set: () => { capturedAnchor = owner.navigationAnchorRect }})
const nextAnchor = {x: 10, y: 12, width: 38, height: 38}
owner.openNavigation('B', nextAnchor)
assert.equal(capturedAnchor, nextAnchor)

const title = library('components/top/TitleFormatting.js')
assert.equal(title.title('', ''), '...hakushell...')
assert.equal(title.title('', 'kitty'), 'kitty')
assert.equal(title.title('日本語 · Tiếng Việt', 'kitty'), '日本語 · Tiếng Việt')
assert.equal(title.shorten('😀😄😅😆', 3), '😀😄…')
assert.equal(title.icon('org.mozilla.firefox'), '')
assert.equal(title.icon('kitty'), '')

const navigation = library('components/sidebar/NavigationGeometry.js')
const pointer = vm.createContext({circleRadius: 100})
methods('components/NavigationPanel.qml', pointer)
for (const edge of ['top', 'left', 'bottom']) {
    pointer.regions = navigation.regions(edge)
    for (let angle = 0.25; angle < 360; angle += 0.5) {
        const expected = pointer.regions.findIndex(region => pointer.angleInSector(angle, region.startDeg, region.endDeg))
        const radians = angle * Math.PI / 180
        assert.equal(pointer.indexAt(100 + 80 * Math.cos(radians), 100 + 80 * Math.sin(radians), false), expected)
    }
    for (const [index, region] of Array.from(pointer.regions).entries()) {
        const radians = region.labelAngle * Math.PI / 180
        assert.equal(pointer.indexAt(100 + 80 * Math.cos(radians), 100 + 80 * Math.sin(radians), false), index)
    }
    assert.equal(pointer.indexAt(250, 100, false), -1)
}
assert.deepEqual(Array.from(navigation.regions('top'), item => item.labelAngle), [270, 150, 30])
assert.deepEqual(Array.from(navigation.regions('bottom'), item => item.labelAngle), [90, 210, 330])
assert.deepEqual(Array.from(navigation.regions('left'), item => item.labelAngle), [210, 330, 90])
assert.equal(navigation.regions('left')[1].key, 'sidebar')

// Wallpaper geometry has its own scoped regression entry point.
require('./test_wallpaper_geometry.js')

// Short outputs allocate independent scroll lanes with a real gap around the title.
const rail = library('components/bar/LeftBarGeometry.js')
for (const font of [12, 14, 18, 21]) {
    for (const height of [480, 720, 768, 928, 1080]) {
        for (const statusHeight of [80, 360, 900]) {
            const layout = rail.lanes(height - 57, 44, 180, statusHeight, 240, 12, 8, font)
            assert(layout.upperHeight >= 0 && layout.bottomHeight >= 0)
            assert(layout.titleY >= layout.upperY + layout.upperHeight + 12)
            assert(layout.titleY + layout.titleHeight + 12 <= layout.bottomY + 0.001)
            assert(layout.bottomY + layout.bottomHeight <= height - 57)
        }
    }
}

// Layout changes must not save an unrelated Settings draft or select an unconfirmed edge.
const Catalog = library('config/SettingsCatalog.js')
const Defaults = library('config/Defaults.js')
let preferenceWrites = 0
let preferenceSchedules = 0
const preferences = () => ({ready: true, loading: false, saving: false, error: '', apply() { preferenceWrites++ }})
const ShellSettingsStore = {...preferences(), values: Defaults.shellDefaults(), savedValues: Defaults.shellDefaults(), statusEdge: 'top',
    confirmStatusEdge(edge) { this.statusEdge = edge; this.values.chrome.statusEdge = edge; this.savedValues.chrome.statusEdge = edge }}
ShellSettingsStore.values.topbar.center = false
const state = vm.createContext({Catalog, ShellSettingsStore, SettingsStore: preferences(), WallpaperSettingsStore: preferences(),
    AppState: {taskbarManualState: false}, Quickshell: {env: () => '/private/home', shellPath: value => value}, Env: {binDir: '/private/bin'},
    runtimePending: {}, runtimeWritingId: '', runtimeWritingValue: null, runtimeError: '', pendingIds: {}, transaction: null,
    busy: false, runtimeWriter: {running: false}, runtimeErr: {text: 'fixture rejected the layout'},
    debounce: {restart() { preferenceSchedules++ }}, toast: {restart() {}}})
state.root = state
methods('services/SettingsCoordinator.qml', state)
const exitedBody = read('services/SettingsCoordinator.qml').split('property Process runtimeWriter: Process {')[1]
    .match(/onExited: code => \{([\s\S]*?)\n        }\n    }/)[1]
const exited = vm.runInContext('(code => {' + exitedBody + '})', state)
assert(state.set('layout', 'leftbar'))
assert.equal(preferenceWrites, 0)
assert.equal(ShellSettingsStore.statusEdge, 'top')
assert.equal(state.runtimeWriter.command.at(-1), 'leftbar')
state.busy = true
assert.equal(state.set('layout', 'taskbar'), false)
state.busy = false
state.runtimeWriter.running = false
exited(1)
assert.equal(ShellSettingsStore.statusEdge, 'top')
assert.equal(state.runtimePending.layout, undefined)
assert(state.runtimeError.includes('rejected'))
assert.equal(ShellSettingsStore.values.topbar.center, false)
assert(state.set('layout', 'leftbar'))
state.runtimeWriter.running = false
exited(0)
assert.equal(ShellSettingsStore.statusEdge, 'left')
assert.equal(state.runtimePending.layout, undefined)
assert.equal(ShellSettingsStore.values.topbar.center, false)
assert.equal(ShellSettingsStore.savedValues.topbar.center, true)
assert.equal(preferenceWrites, 0)
assert.equal(preferenceSchedules, 0)
assert(state.set('layout', 'taskbar'))
state.runtimeWriter.running = false
exited(0)
assert.equal(state.AppState.taskbarManualState, true)
assert.equal(ShellSettingsStore.statusEdge, 'left')
assert.equal(preferenceSchedules, 0)

// Filtering removes the actual Theme model row, including query-only and Classic cases.
const UiCatalog = library('config/UiCatalog.js')
const theme = vm.createContext({items: UiCatalog.hakuMenuThemeItems, visibleItems: [], query: '', visible: true,
    hikaiBackend: true, ChromeLayout: {taskbarMode: false}, ShellSettingsStore, SettingsCoordinator: state,
    themeList: {currentIndex: -1, positionViewAtIndex() {}}, ListView: {Contain: 0}, Qt: {callLater: fn => fn()}})
theme.root = theme
methods('components/hakumenu/ThemeList.qml', theme)
theme.highlightedLabelChanged = () => {}
theme.rebuildModel()
assert(theme.visibleItems.some(item => item.statusEdgeSwitch))
theme.ChromeLayout.taskbarMode = true
theme.rebuildModel()
assert(!theme.visibleItems.some(item => item.statusEdgeSwitch))
assert(theme.visibleItems.some(item => item.chromeKey === 'taskbar'))
theme.query = 'Status Bar Position'
theme.rebuildModel()
assert.equal(theme.visibleItems.length, 0)
theme.ChromeLayout.taskbarMode = false
theme.hikaiBackend = false
theme.query = ''
theme.rebuildModel()
assert(!theme.visibleItems.some(item => item.statusEdgeSwitch))
console.log('Leftbar tooltip edges, navigation ownership and geometry contracts passed')
