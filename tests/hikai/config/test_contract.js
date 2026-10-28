#!/usr/bin/env node
// Guard static config ownership, public facades and independent preference defaults.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const {execFileSync} = require('node:child_process')
// Locate production sources from any working directory.
const root = path.resolve(__dirname, '../../..')
const shell = path.join(root, 'src/home/.config/quickshell/hakuspace')

// Read deployed QML and JavaScript source relative to the shell.
function read(relative) { return fs.readFileSync(path.join(shell, relative), 'utf8') }
// Evaluate a QML library using the same exported variables as its consumers.
function library(name) {
    const context = vm.createContext({}) // Isolate each module's namespace.
    vm.runInContext(read(`config/${name}.js`).replace(/^\.pragma library\s*$/m, ''), context)
    return context
}
// Normalize objects from separate VM contexts before comparing contracts.
function plain(value) { return JSON.parse(JSON.stringify(value)) }

// Ignore comments and quoted metadata while checking actual imports and runtime names.
function staticConfig(source) {
    const uncommented = source.replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\/\/[^\n]*|\/\*[\s\S]*?\*\//g,
        token => token.startsWith('//') || token.startsWith('/*') ? '' : token)
    const imports = uncommented.match(/^\s*\.?import\s+[^\n]+/gm) || []
    if (imports.some(line => /(?:^|["'/])(?:services|components)(?:["'/]|$)/.test(line))) return false
    const code = uncommented.replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g, '')
    return !/\b(?:Quickshell|Process|FileView|Env|UiState|WM|ShellSettingsStore|SettingsCoordinator|IpcHandler|IPC)\b/.test(code)
}
// Architecture checks must accept documentation and string labels mentioning runtime names.
assert(staticConfig('// Env.value; import "../services"\n/* Process {} */\nvar label = "UiState WM FileView"'))
for (const source of ['import "../services"', '.import "../components/Helpers.js" as Helpers',
    'import Quickshell.Io', 'Process {}', 'FileView {}', 'Env["value"]', 'UiState.close()',
    'WM.backendName', 'ShellSettingsStore.values', 'SettingsCoordinator.apply()', 'IpcHandler {}',
    'var label = `${Env.value}`']) assert(!staticConfig(source), source)

// Config may import static Qt types and sibling files, never runtime shell services.
for (const entry of fs.readdirSync(path.join(shell, 'config'), {recursive: true})) {
    if (!/\.(qml|js)$/.test(entry)) continue
    assert(staticConfig(read(`config/${entry}`)), entry)
}

// Keep the facade API used by layout, generated themes and animated surfaces.
for (const [service, names] of Object.entries({
    Theme: 'colorMode isLight accentSeed accentDark accentLight accent surface hoverMuted onAccentColor fg fgDim fgMuted danger warning success radius largeRadius hugRadius giantRadius gap pad font fontFamily fontSize spaceXs spaceSm spaceMd spaceLg spaceXl panelPadding cardPadding controlHeight comfortableControlHeight sectionGap topBarHeight levelOsdWidth levelOsdHeight shellTransitionAccentDuration',
    HAnimation: 'fast normal slow tooltipDuration tooltipCurve navigationOpenDuration navigationCloseDuration dashboardOpenDuration dashboardCloseDuration sidebarOpenDuration sidebarCloseDuration sidebarToolOpenDuration floatingPanelOpenDuration floatingPanelCloseDuration hakuMenuOpenDuration hakuMenuCloseDuration hakuMenuResizeDuration hakuMenuBounceHeadroom settingsResizeDuration dockOpenDuration dockCloseDuration spatial trailFactor selectionMorphDuration selectionMorphCurve buttonSelectDuration buttonSelectCurve actionLayerOpenDuration actionLayerCloseDuration shellTransitionCurve'
})) {
    for (const name of names.split(' '))
        assert.match(read(`services/${service}.qml`), new RegExp(`\\bproperty \\S+ ${name}:`), `${service}.${name}`)
}

// Migrated lists must bind to the catalog instead of reintroducing local arrays.
for (const [file, property, catalog] of [
    ['hakumenu/HakuMenuContent.qml', 'modes', 'hakuMenuModes'],
    ['hakumenu/GeneralList.qml', 'fixedItems', 'hakuMenuGeneralItems'],
    ['hakumenu/ThemeList.qml', 'items', 'hakuMenuThemeItems'],
    ['actionmenu/pages/ThemePage.qml', 'items', 'actionMenuThemeItems'],
    ['actionmenu/pages/ThemeAccentPage.qml', 'allItems', 'accentPresets'],
    ['actionmenu/pages/ThemeFontSizePage.qml', 'sizes', 'fontSizePresets'],
    ['actionmenu/pages/PowerPage.qml', 'actions', 'actionMenuPowerActions'],
    ['actionmenu/pages/RecordPage.qml', 'modes', 'actionMenuRecordModes'],
    ['sidebar/SidebarSurface.qml', 'tools', 'sidebarTools'],
    ['sidebar/SidebarQuickActions.qml', 'actions', 'sidebarQuickActions'],
    ['dashboard/DashboardWidgetHost.qml', 'widgets', 'dashboardWidgets'],
    ['wallpaper/WallpaperBrowser.qml', 'kinds', 'wallpaperKinds'],
    ['wallpaper/WallpaperBrowser.qml', 'options', 'wallpaperVideoProfiles']
]) {
    assert.match(read(`components/${file}`), new RegExp(`property var ${property}: UiCatalog\\.${catalog}\\b`), file)
    assert.doesNotMatch(read(`components/${file}`), new RegExp(`property var ${property}:\\s*\\[`), file)
}
assert(!fs.existsSync(path.join(shell, 'components/settings/SettingsCatalog.js')))

// Catalog data preserves navigation order and exposes only static state identifiers.
const ui = library('UiCatalog')
// Original descriptors are fixtures so labels, icons, identifiers and order cannot drift silently.
const catalogs = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/ui_catalog.json'), 'utf8'))
for (const [name, entries] of Object.entries(catalogs)) assert.deepEqual(plain(ui[name]), entries, name)
// Resolve real local Component mappings instead of putting QML objects in config.
const widgetExpression = read('components/dashboard/DashboardWidgetHost.qml').match(/property var widgets: ([\s\S]*?\n    \}\))/)[1]
const widgets = vm.runInNewContext(widgetExpression, {UiCatalog: ui,
    calendarWidgetComponent: 'calendar-component', bioWidgetComponent: 'bio-component'})
assert.deepEqual(plain(widgets), catalogs.dashboardWidgets.map(widget => ({...widget, component: `${widget.key}-component`})))
// Inspect destructive dispatch with stubs so no real power or recording action runs.
for (const [file, method, items, repeater] of [
    ['PowerPage', 'activateAction', ui.actionMenuPowerActions, 'buttonsRepeater'],
    ['RecordPage', 'activateIndex', ui.actionMenuRecordModes, 'modesRepeater']
]) {
    const calls = [] // Collect only dispatch arguments, never execute them.
    const context = vm.createContext({actions: items, modes: items, powerProc: {}, Env: {binDir: '/fixture/bin'},
        Quickshell: {execDetached: command => calls.push(plain(command))},
        [repeater]: {itemAt: () => null}, requestClose() {}, pushSubmenu: page => calls.push(page)})
    context.root = context
    vm.runInContext(read(`components/actionmenu/pages/${file}.qml`).match(new RegExp(`    function ${method}[\\s\\S]*?^    }`, 'm'))[0], context)
    items.forEach((item, index) => {
        context[method](index)
        if (file === 'PowerPage') assert.deepEqual(item.id === 'logout' ? calls.pop() : plain(context.powerProc.command),
            item.id === 'logout' ? 'pages/ExitPage.qml' : ['/fixture/bin/power_ctl.sh', item.id])
        else assert.deepEqual(calls.pop(), item.isSubmenu ? 'pages/RecordSourcePage.qml'
            : ['/fixture/bin/record_ctl.sh', 'start', item.id])
    })
}
assert.deepEqual(plain(ui.hakuMenuModes.map(item => item.key)), ['general', 'drun', 'theme'])
assert.deepEqual(plain(ui.actionMenuThemeItems.map(item => item.id)), ['font', 'size', 'accent', 'niriAnimation'])
assert.deepEqual(plain(ui.fontSizePresets), [10, 12, 14, 16, 18])
assert.equal(ui.accentPresets[0].isPicker, true)
assert(ui.accentPresets.slice(1).every(item => /^#[a-f\d]{6}$/i.test(item.hex)))

// Resolve real state keys against a service stub without importing it into config.
const themeList = read('components/hakumenu/ThemeList.qml')
const stateKeys = ui.hakuMenuThemeItems.filter(item => item.stateKey && item.stateKey !== 'randomWallpaper').map(item => item.stateKey)
const state = vm.createContext({Env: Object.fromEntries(stateKeys.map(key => [key, `/state/${key}`]))})
vm.runInContext(themeList.match(/^    function statePathFor[\s\S]*?^    }/m)[0], state)
for (const item of ui.hakuMenuThemeItems) {
    assert.equal(state.statePathFor(item), item.stateKey === 'randomWallpaper' ? '/tmp/random_wallpaper_status'
        : item.stateKey ? `/state/${item.stateKey}` : '')
    if (item.stateKey && item.stateKey !== 'randomWallpaper')
        assert.match(read('services/Env.qml'), new RegExp(`property \\S+ ${item.stateKey}:`))
}

// Compare every backend field and schema version without executing its CLI.
const Defaults = library('Defaults')
const expected = JSON.parse(execFileSync('python3', ['-B', '-c',
    'import importlib.util,json,sys; s=importlib.util.spec_from_file_location("settings",sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(json.dumps(m.DEFAULTS))',
    path.join(root, 'src/core/backend/user/hikai_settings_ctl.py')], {encoding: 'utf8'}))
assert.equal(Defaults.shellSchemaVersion, expected.version)
assert.deepEqual(plain(Defaults.shellDefaults()), expected)
const draft = Defaults.shellDefaults() // Mutating one snapshot cannot change another.
draft.appearance.baseRadius = 24
draft.idle.enabled = false
assert.deepEqual(plain(Defaults.shellDefaults()), expected)
const settings = library('SettingsCatalog')
for (const descriptor of settings.descriptors.filter(item => item.provider === 'shell'))
    assert.deepEqual(plain(descriptor.defaultValue), expected[descriptor.section][descriptor.key], descriptor.id)

// Run production reset/apply/discard methods with the persistence process stubbed.
const source = read('services/ShellSettingsStore.qml')
const store = vm.createContext({Defaults, ready: true, loading: false, saving: false, error: '', writeProc: {}})
vm.runInContext([...source.matchAll(/^    function [\s\S]*?^    }/gm)].map(match => match[0]).join('\n'), store)
store.command = action => [action]
store.values = store.defaults()
store.savedValues = store.defaults()
assert(store.validate(store.values))
store.savedValues.appearance.baseRadius = 20
store.reset()
assert.equal(store.values.appearance.baseRadius, 12)
assert.equal(store.savedValues.appearance.baseRadius, 20)
store.values.idle.enabled = false
assert.equal(store.savedValues.idle.enabled, true)
store.discard()
assert.equal(store.values.appearance.baseRadius, 20)
assert.equal(store.values.idle.enabled, true)
store.values.appearance.baseRadius = 16
store.values.topbar.clock = false
store.dirty = true
store.valid = true
store.apply(['appearance.baseRadius'])
assert.deepEqual(JSON.parse(store.writeProc.environment.HAKUSPACE_HIKAI_SETTINGS_JSON), {appearance: {baseRadius: 16}})
store.saving = false
store.dirty = false
store.migrationPending = true
store.values = store.defaults()
store.savedValues = store.defaults()
store.apply()
assert.deepEqual(JSON.parse(store.writeProc.environment.HAKUSPACE_HIKAI_SETTINGS_JSON), {})
store.saving = false
store.accept(JSON.stringify({ok: true, values: expected, needsMigration: true}))
assert.equal(store.migrationPending, true)
store.values.appearance.baseRadius = 99
assert.equal(store.validate(store.values), false)
assert.deepEqual(plain(store.defaults()), expected)
console.log('Config dependency, facade, catalog and defaults contracts passed')
