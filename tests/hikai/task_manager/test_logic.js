const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

// Exercise the same filtering, sorting and formatting functions used by the view.
const logic = {}
vm.runInNewContext(fs.readFileSync(path.join(__dirname,
    '../../../src/home/.config/quickshell/hakuspace/components/taskmanager/TaskManagerLogic.js'), 'utf8'), logic)
const rows = [
    {key: '9:1', pid: 9, name: 'Beta', cmdline: 'beta --flag', user: 'alice', rss: 100, cpuPercent: null, cpuTotalPercent: null},
    {key: '2:1', pid: 2, name: 'Alpha', cmdline: '/bin/alpha', user: 'bob', rss: 200, cpuPercent: 250, cpuTotalPercent: 10},
    {key: '5:1', pid: 5, name: 'Gamma', cmdline: 'gamma', user: 'alice', rss: 50, cpuPercent: 10, cpuTotalPercent: 20}
]
assert.deepEqual(logic.processRows(rows, '', 'cpu', true).map(row => row.pid), [5, 2, 9])
assert.deepEqual(logic.processRows(rows, ' ALICE ', 'memory', true).map(row => row.pid), [9, 5])
assert.deepEqual(logic.processRows(rows, 'flag', 'name', false).map(row => row.pid), [9])
assert.deepEqual(logic.processRows(rows, '2', 'pid', false).map(row => row.pid), [2])
assert.deepEqual(logic.processRows(rows, '', 'name', false).map(row => row.pid), [2, 9, 5])
assert.deepEqual(rows.map(row => row.pid), [9, 2, 5], 'sort must not mutate the shared source')
assert.equal(logic.bytes(null), 'Unavailable')
assert.equal(logic.bytes(1024 ** 3), '1.0 GiB')
assert.equal(logic.metric(null, '%'), 'Unavailable')
assert.equal(logic.metric(250, '%'), '250.0%')
assert.equal(logic.metric(100 / 12, '%'), '8.3%')
assert.equal(logic.gpuUsage({usage: 38, status: 'available'}), '38.0%')
assert.equal(logic.gpuUsage({usage: null, status: 'permissionDenied'}), 'Permission denied')
assert.equal(logic.gpuUsage({usage: null, status: 'unsupported'}), 'Unsupported')
assert.equal(logic.gpuUsage({usage: null, status: 'unavailable'}), 'Unavailable')
console.info('Task Manager process logic passed')

// Exercise the production maintenance gate with only the new floating surface open.
const shell = path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace')
const host = fs.readFileSync(path.join(shell, 'components/MemoryMaintenanceHost.qml'), 'utf8')
const blockerBody = host.match(/readonly property var blockers: \{([\s\S]*?)\n    }/)[1]
const scope = {
    externalBusy: false, loadedCount: 0, LockState: {}, ShellTransitionState: {chromeEnabled: true},
    UiState: {taskManagerOpen: true}, WindowNavigator: {sessionWindows: []}, ImageEditor: {},
    SettingsCoordinator: {}, ConfigEditorStore: {}, TextStore: {}, Avatar: {}, WallpaperService: {},
    WallpaperLibrary: {}, IdleService: {}
}
assert.deepEqual(Array.from(vm.runInNewContext('(function() {' + blockerBody + '})()', scope)), ['surface'])
scope.UiState.taskManagerOpen = false
assert.deepEqual(Array.from(vm.runInNewContext('(function() {' + blockerBody + '})()', scope)), [])

// Check the launcher catalog resolves to the new utility key.
const catalog = {}
vm.runInNewContext(fs.readFileSync(path.join(shell, 'config/UiCatalog.js'), 'utf8').replace(/^\.pragma library\s*$/m, ''), catalog)
assert.equal(catalog.sidebarTools.find(tool => tool.key === 'taskManager').label, 'Task Manager')
console.info('Task Manager maintenance gate and launcher passed')

// Dispatch the actual Sidebar handler into an independent floating utility.
const navigation = fs.readFileSync(path.join(shell, 'components/NavigationPanel.qml'), 'utf8')
const dispatch = navigation.match(/^    function toggleSidebarTool[\s\S]*?^    }/m)[0]
const calls = []
const launcher = {
    activeSidebarTool: 'clipboard', sidebarKeyboardMode: true, modelData: {name: 'B'},
    lifetime: {reset() { calls.push('reset') }}, UiState: {openTaskManager(screen) { calls.push(screen) }}
}
vm.runInNewContext(dispatch, launcher)
launcher.toggleSidebarTool('taskManager', true)
assert.deepEqual(calls, ['reset', 'B'])
assert.equal(launcher.activeSidebarTool, '')
assert.equal(launcher.sidebarKeyboardMode, false)
console.info('Task Manager Sidebar dispatch passed')
