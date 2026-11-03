#!/usr/bin/env node
// Check structured snapshots, search and ID-only activation without desktop actions.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const vm = require('node:vm')
const {execFile} = require('node:child_process')
const {promisify} = require('node:util')

// Read the real backend seed and frontend functions in a disposable HOME.
const root = path.resolve(__dirname, '../../..')
const shell = path.join(root, 'src/home/.config/quickshell/hakuspace')
const source = fs.readFileSync(path.join(shell, 'components/hakumenu/GeneralList.qml'), 'utf8')
const service = fs.readFileSync(path.join(shell, 'services/GeneralMenuService.qml'), 'utf8')
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'haku-general-js-'))
// Run the real snapshot producer before exercising QML JavaScript.
async function check() {
    try {
        const config = path.join(temporary, 'general.json')
        fs.copyFileSync(path.join(root, 'src/home/hakucfg/config/hakumenu-general.json'), config)
        const {stdout: output} = await promisify(execFile)('python3', ['-B', path.join(root, 'src/core/backend/user/general_menu_ctl.py'), 'list'],
            {encoding: 'utf8', env: {...process.env, HOME: temporary, HAKUSPACE_GENERAL_MENU_FILE: config}})
        const calls = [] // Capture requests without launching a process.
        const context = vm.createContext({items: [], revision: '', error: '', busy: false, pendingRefresh: false,
            operation: 'list', controller: {}, Env: {binDir: '/fixture/bin'},
            Quickshell: {env: () => '/fixture/home', shellPath: relative => '/source/' + relative}})
        context.root = context
        vm.runInContext([...service.matchAll(/^    function [\s\S]*?^    }/gm)].map(match => match[0]).join('\n'), context)
        assert.equal(context.accept(output, 0), true)
        assert.equal(context.items.length, 7)
        assert.equal(context.items[2].icon, '')
        const plain = value => JSON.parse(JSON.stringify(value))
        const revision = context.revision
        const command = plain(context.command('run', ['literal-$(touch /tmp/no)']))
        assert.equal(command.at(-1), 'literal-$(touch /tmp/no)')
        assert.equal(command.at(-2), 'run')
        assert.equal(context.add({label: 'Quoted', commandText: 'printf "two words"'}, 'browser'), true)
        assert.equal(context.controller.command.at(-1), revision)
        assert.equal(context.controller.command.at(-2), '--expected-revision')
        assert.equal(JSON.parse(context.controller.command.at(-3)).afterId, 'browser')
        assert.equal(context.update('browser', {label: 'New'}), true)
        assert.equal(context.remove('browser'), true)
        assert.equal(context.move('browser', 0), true)
        assert.deepEqual(plain(context.controller.command.slice(-5)), ['move', 'browser', '0', '--expected-revision', revision])
        context.busy = true
        assert.equal(context.remove('browser'), false)
        context.refresh()
        assert.equal(context.pendingRefresh, true)
        context.busy = false
        context.pendingRefresh = false
        context.operation = 'update'
        assert.equal(context.accept('{"ok":false,"error":"conflict"}', 1), false)
        assert.equal(context.pendingRefresh, true)
        assert.equal(context.items.length, 7)
        assert.equal(context.revision, revision)
        assert.equal(context.accept('broken', 1), false)
        assert.equal(context.items.length, 7)
        context.revision = ''
        assert.equal(context.remove('browser'), false)

        const catalog = vm.createContext({})
        vm.runInContext(fs.readFileSync(path.join(shell, 'config/UiCatalog.js'), 'utf8').replace(/^\.pragma library\s*$/m, ''), catalog)
        const list = vm.createContext({query: '', visible: true, editorRequested: false, editorEntry: null, itemEditor: null,
            actionRowId: '', deleteRowId: '', actionError: '', pendingDeleteId: '', selectionHint: -1,
            GeneralMenuService: {items: JSON.parse(output).items, busy: false, run: id => { calls.push(id); return true }},
            UiState: {hakuMenuScreenName: 'fixture-output'},
            UiCatalog: catalog, Qt: {LeftButton: 1, RightButton: 2},
            Quickshell: {execDetached: command => calls.push(plain(command))},
            generalList: {currentIndex: -1}, launched: () => calls.push('launched')})
        list.root = list
        vm.runInContext([...source.matchAll(/^    function [\s\S]*?^    }/gm)].map(match => match[0]).join('\n'), list)
        const customExpression = source.match(/readonly property var customItems: ([\s\S]*?)\n    readonly property var staticItems:/)[1]
        const staticExpression = source.match(/readonly property var staticItems: ([\s\S]*?)\n    property color rowHoverColor/)[1]
        Object.defineProperty(list, 'customItems', {get: () => vm.runInContext(customExpression, list)})
        Object.defineProperty(list, 'staticItems', {get: () => vm.runInContext(staticExpression, list)})
        list.visibleItems = list.filteredItems()
        assert.equal(list.customItems.length, 6)
        assert.equal(list.staticItems.length, 7)
        assert.equal(list.visibleItems.length, 13)
        assert.equal(list.visibleItems[6].sectionStart, true)
        assert.equal(list.visibleItems[0].id, 'code-editor')
        assert.equal(list.visibleItems[6].id, 'static-wifi')
        list.GeneralMenuService.items[0].label = 'Whatever'
        assert.equal(list.customItems.some(row => row.id === 'app-menu'), false)
        list.GeneralMenuService.items.push({...list.GeneralMenuService.items[0], id: 'visible-app-menu', label: 'App Menu'})
        assert.equal(list.customItems.some(row => row.id === 'visible-app-menu'), true)
        list.rowClicked(1, 2)
        assert.equal(list.actionRowId, 'browser')
        assert.deepEqual(calls, [])
        list.rowClicked(0, 2)
        assert.equal(list.actionRowId, 'code-editor')
        list.rowClicked(6, 2)
        assert.equal(list.actionRowId, '')
        list.activateIndex(1)
        list.activateIndex(6)
        assert.deepEqual(calls, ['browser', 'launched', ['nm-connection-editor'], 'launched'])
        list.GeneralMenuService.items.push({...list.GeneralMenuService.items[2], id: 'duplicate'})
        list.GeneralMenuService.items.push({...list.GeneralMenuService.items[2], id: 'disabled', enabled: false})
        list.query = '> browser'
        list.visibleItems = list.filteredItems()
        assert.deepEqual(plain(list.visibleItems.map(row => row.id)), ['browser', 'duplicate'])
        assert.equal(list.visibleItems.some(row => row.sectionStart), false)
        list.activateIndex(1)
        assert.equal(calls.at(-2), 'duplicate')
        list.GeneralMenuService.run = () => false
        const count = calls.length
        list.activateIndex(0)
        list.activateIndex(-1)
        assert.equal(calls.length, count)
        list.query = 'Wifi'
        list.visibleItems = list.filteredItems()
        assert.equal(list.visibleItems.length, 1)
        assert.equal(list.visibleItems[0].sectionStart, false)
        assert.doesNotMatch(source, /cleanLabel|pendingItems|parsedItems|hm_general\.sh|Process\s*\{|\.raw\b/)
        assert(catalog.hakuMenuGeneralItems.every(row => row.id.startsWith('static-')))
        list.UiState.openTaskManagerFromHakuMenu = () => calls.push(['taskManager', list.UiState.hakuMenuScreenName])
        list.UiState.openSettings = screen => calls.push(['settings', screen])
        list.launched = () => { calls.push('launched'); list.UiState.hakuMenuScreenName = '' }
        list.query = 'Task Manager'
        list.visibleItems = list.filteredItems()
        assert.equal(list.visibleItems[0].id, 'static-task-manager')
        assert.equal(list.visibleItems[0].mutable, false)
        list.activateIndex(0)
        assert.deepEqual(calls.at(-1), ['taskManager', 'fixture-output'])
        list.query = 'Settings'
        list.visibleItems = list.filteredItems()
        assert.equal(list.visibleItems[0].id, 'static-settings')
        list.activateIndex(0)
        assert.deepEqual(calls.slice(-2), ['launched', ['settings', 'fixture-output']])

        // Check the browser shortcut without opening the user's real browser.
        const editorSource = fs.readFileSync(path.join(shell, 'components/hakumenu/GeneralItemEditor.qml'), 'utf8')
        const urls = []
        const editorContext = vm.createContext({Qt: {openUrlExternally: url => urls.push(url)}})
        vm.runInContext(editorSource.match(/^    function openIconCatalog[\s\S]*?^    }/m)[0], editorContext)
        vm.runInContext(editorSource.match(/^    function firstIcon[\s\S]*?^    }/m)[0], editorContext)
        for (const [input, expected] of [['ab', 'a'], ['󰖩', '󰖩'], [' 󰖩 ', '󰖩'], ['', ''], ['\udb80', '']])
            assert.equal(editorContext.firstIcon(input), expected)
        editorContext.openIconCatalog()
        assert.deepEqual(urls, ['https://www.nerdfonts.com/cheat-sheet'])
        assert.match(editorSource, /onClicked: root\.openIconCatalog\(\)/)
        console.log('General menu snapshot, service CRUD and ID activation tests passed.')
    } finally {
        fs.rmSync(temporary, {recursive: true, force: true})
    }
}
check().catch(error => { console.error(error); process.exitCode = 1 })
