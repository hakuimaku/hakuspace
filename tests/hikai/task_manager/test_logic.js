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
assert.deepEqual(logic.processRows(rows, '', 'cpu', true, ['2:1']).map(row => row.pid), [2, 5, 9], 'pinned process 2 must precede higher CPU process 5')
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

// Preserve the current owner's origin and route fresh HakuMenu entries to the top.
const uiSource = fs.readFileSync(path.join(shell, 'services/UiState.qml'), 'utf8')
const entry = {
    activePanel: '', taskManagerOpen: false, taskManagerScreenName: '', taskManagerRevealPosition: 8,
    hakuMenuScreenName: 'B', Quickshell: {screens: [{name: 'A'}, {name: 'B'}]},
    TaskManagerService: {beginHandoff() {}}, taskManagerFocusRequested() {},
    closeNavigation() { this.activePanel = '' }, closeHakuMenu() { this.activePanel = '' },
    closeTaskManager() { this.taskManagerOpen = false; this.taskManagerScreenName = '' }
}
vm.runInNewContext(['openTaskManager', 'openTaskManagerFromHakuMenu'].map(name =>
    uiSource.match(new RegExp('^    function ' + name + '\\([^]*?^    }', 'm'))[0]).join('\n'), entry)
for (const position of [1, 2, 3, 4, 5, 6, 7, 8]) {
    entry.openTaskManager('A', position)
    assert.equal(entry.taskManagerRevealPosition, position)
    entry.closeTaskManager()
}
for (const invalid of [undefined, null, 0, 9, 1.5, '2']) {
    entry.openTaskManager('A', invalid)
    assert.equal(entry.taskManagerRevealPosition, 8)
    entry.closeTaskManager()
}
entry.openTaskManagerFromHakuMenu()
assert.equal(entry.taskManagerScreenName, 'B')
assert.equal(entry.taskManagerRevealPosition, 2)
entry.openTaskManager('B', 8)
assert.equal(entry.taskManagerRevealPosition, 2, 'refocusing must retain the current entry edge')
console.info('Task Manager entry anchor checks passed')

// Verify Glass Grid Focus Card state transitions, reset contract, and presentation fallbacks.
const glassGridSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskManagerGlassGrid.qml'), 'utf8')
const resetFn = glassGridSource.match(/function resetVisualState\(\) \{[\s\S]*?\n    \}/)[0]
const selectFn = glassGridSource.match(/function selectMetric\(metricId\) \{[\s\S]*?\n    \}/)[0]
const focusState = {
    _current: 'memory',
    get currentFocusMetric() { return this._current },
    set currentFocusMetric(v) { this._current = v },
    get focusedMetric() { return this._current },
    get displayMetric() { return this._current },
    morphFromMetric: 'memory',
    morphToMetric: 'memory',
    pendingMetric: '',
    incomingMetric: '',
    transitionActive: false,
    focusMorphProgress: 1.0,
    _manualMorphActive: false,
    _suppressFocusSignal: false,
    focusMorphAnim: {running: false, stop() {}},
    _beginStackedFocusMorph(m) {
        this._current = m
    },
    root: null
}
focusState.root = focusState
vm.runInNewContext(resetFn + '\n' + selectFn, focusState)
assert.equal(focusState.focusedMetric, 'memory', 'default focus must be memory')
focusState.selectMetric('gpu')
assert.equal(focusState.focusedMetric, 'gpu', 'click GPU must focus gpu')
focusState.selectMetric('network')
assert.equal(focusState.focusedMetric, 'network', 'click Network must focus network')
focusState.selectMetric('cpu')
assert.equal(focusState.focusedMetric, 'network', 'CPU must not participate in focusedMetric')
focusState.selectMetric('memory')
assert.equal(focusState.focusedMetric, 'memory', 'click Memory must focus memory')
focusState.selectMetric('gpu')
focusState.resetVisualState()
assert.equal(focusState.focusedMetric, 'memory', 'reopen resetVisualState must restore memory')
assert.equal(focusState.displayMetric, 'memory', 'reopen resetVisualState must restore displayMetric')

const visualsSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskManagerVisuals.qml'), 'utf8')
const dashPairFn = visualsSource.match(/function dashPairBytes\(used, total\) \{[\s\S]*?\n    \}/)[0]
const leftWidthFn = visualsSource.match(/function leftPaneWidth\(totalWidth\) \{[\s\S]*?\n    \}/)[0]
const visualsScope = {Logic: logic}
vm.runInNewContext(dashPairFn + '\n' + leftWidthFn, visualsScope)
assert.equal(visualsScope.dashPairBytes(null, null), '—')
assert.equal(visualsScope.dashPairBytes(0, 0), '—', 'must never render 0 B / 0 B')
assert.equal(visualsScope.dashPairBytes(NaN, 1024), '—', 'must never render NaN')
assert.equal(visualsScope.dashPairBytes(1024 ** 3, 2 * 1024 ** 3), '1.0 GiB / 2.0 GiB')
assert.ok(visualsScope.leftPaneWidth(944) >= 308 && visualsScope.leftPaneWidth(944) <= 332, 'default 980px left pane width')
assert.equal(visualsScope.leftPaneWidth(2000), 332, 'left pane width upper clamp')

const processRowSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskProcessRow.qml'), 'utf8')
assert.ok(!processRowSource.includes('accentName'), 'obsolete accentName API must not remain in TaskProcessRow.qml')
const processPaneSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskProcessPane.qml'), 'utf8')
assert.ok(!processPaneSource.includes('accentName'), 'obsolete accentName binding must not remain in TaskProcessPane.qml')

// Verify shared motion tokens in config/Motion.qml and services/HAnimation.qml.
const motionQml = fs.readFileSync(path.join(shell, 'config/Motion.qml'), 'utf8')
const hanimQml = fs.readFileSync(path.join(shell, 'services/HAnimation.qml'), 'utf8')
assert.match(motionQml, /sidebarToolOpenDuration:\s*560/)
assert.match(motionQml, /sidebarToolCloseDuration:\s*400/)
assert.match(motionQml, /taskManagerFocusMorphDuration:\s*520/)
assert.match(motionQml, /taskDropdownOpenDuration:\s*340/)
assert.match(motionQml, /taskDropdownCloseDuration:\s*300/)
assert.match(motionQml, /taskDetailsFoldDuration:\s*440/)
assert.match(motionQml, /taskConfirmationMorphDuration:\s*400/)
assert.match(motionQml, /taskBarFillDuration:\s*180/)
for (const prop of [
    'taskManagerFocusMorphDuration', 'taskManagerFocusMorphCurve',
    'taskDropdownOpenDuration', 'taskDropdownOpenCurve',
    'taskDropdownCloseDuration', 'taskDropdownCloseCurve',
    'taskDetailsFoldDuration', 'taskDetailsFoldCurve',
    'taskConfirmationMorphDuration', 'taskConfirmationMorphCurve',
    'taskBarFillDuration'
]) {
    assert.ok(hanimQml.includes(prop), `HAnimation.qml must expose ${prop}`)
}

// Verify TaskManagerMotion.js pure math helpers and absence of magic duration constants.
const motion = {}
const motionJsSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskManagerMotion.js'), 'utf8')
vm.runInNewContext(motionJsSource.replace(/^\.pragma library\s*$/m, ''), motion)
assert.equal(motion.openDuration, undefined, 'TaskManagerMotion.js must not hardcode openDuration')
assert.equal(motion.closeDuration, undefined, 'TaskManagerMotion.js must not hardcode closeDuration')
assert.equal(motion.segment(0.0, 0.28, 0.88), 0)
assert.equal(motion.segment(0.88, 0.28, 0.88), 1)
assert.ok(Math.abs(motion.segment(0.58, 0.28, 0.88) - 0.5) < 1e-6)
assert.equal(motion.lerp(10, 50, 0.25), 20)
const rectMid = motion.lerpRect({x: 0, y: 100, width: 140, height: 90}, {x: 0, y: 20, width: 300, height: 160}, 0.5)
assert.deepEqual({...rectMid}, {x: 0, y: 60, width: 220, height: 125})
assert.equal(motion.reversibleDuration(560, 0.25, 1.0, false), 420)
assert.equal(motion.reversibleDuration(560, 0.25, 1.0, true), 0)

// Verify Motion V2 structural contracts across Task Manager QML files.
const overlaySource = fs.readFileSync(path.join(shell, 'components/TaskManagerOverlay.qml'), 'utf8')
for (const obsolete of ['seedProgress', 'railProgress', 'bodyProgress', 'processProgress',
    'taskManagerSeedRail', 'taskManagerRevealViewport', 'taskManagerWeaveBottomEdge']) {
    assert.ok(!overlaySource.includes(obsolete), `TaskManagerOverlay.qml must remove obsolete ${obsolete}`)
}
assert.ok(overlaySource.includes('HAnimation.sidebarToolOpenDuration'), 'Overlay must reuse Temp Note open duration')
assert.ok(overlaySource.includes('HAnimation.sidebarToolCloseDuration'), 'Overlay must reuse Temp Note close duration')
assert.ok(overlaySource.includes('HAnimation.sidebarToolOpenCurve'), 'Overlay must reuse Temp Note open curve')
assert.ok(overlaySource.includes('HAnimation.sidebarToolCloseCurve'), 'Overlay must reuse Temp Note close curve')

const focusLayerCardSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskFocusLayerCard.qml'), 'utf8')
assert.ok(!focusLayerCardSource.includes('focusCardInkSeam'), 'TaskFocusLayerCard.qml must remove Ink Handoff seam')
assert.ok(!focusLayerCardSource.includes('focusCardHandoffViewport'), 'TaskFocusLayerCard.qml must remove Ink Handoff viewport')
assert.ok(!focusLayerCardSource.includes('visible: !root.visualSuppressed'),
    'TaskFocusLayerCard.qml must NOT disable presentation visibility during morph so Canvas stays render-hot')
assert.ok(focusLayerCardSource.includes('focusCardVisualLayer'), 'TaskFocusLayerCard.qml must define focusCardVisualLayer')
assert.ok(glassGridSource.includes('taskFocusLayer'), 'TaskManagerGlassGrid.qml must define taskFocusLayer')
assert.ok(glassGridSource.includes('taskFocusSlot'), 'TaskManagerGlassGrid.qml must define taskFocusSlot')
assert.ok(glassGridSource.includes('focusCardA') && glassGridSource.includes('focusCardB'),
    'TaskManagerGlassGrid.qml must define persistent double-buffer cards focusCardA and focusCardB')
assert.ok(!glassGridSource.includes('outgoingMorphCard'),
    'TaskManagerGlassGrid.qml must remove outgoingMorphCard in Stacked Focus Morph')

// Verify Atomic Sample contract in TaskWaterGauge.qml
const waterGaugeSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskWaterGauge.qml'), 'utf8')
assert.ok(waterGaugeSource.includes('property var sample: null'), 'TaskWaterGauge.qml must define property var sample')
const applySampleFn = waterGaugeSource.match(/function _applySample\(s\) \{[\s\S]*?\n    \}/)[0]

const gaugeScope = {
    activeMetricId: '',
    displayValue: 0.0,
    _hasActiveSample: false,
    canvas: { requestPaintCalls: 0, requestPaint() { this.requestPaintCalls++ } },
    telemetryAnim: {
        running: false,
        from: 0,
        to: 0,
        stopped: 0,
        started: 0,
        stop() { this.running = false; this.stopped++ },
        start() { this.running = true; this.started++ }
    },
    root: { reducedMotion: false }
}
vm.runInNewContext(applySampleFn, gaugeScope)

// 1. Initial GPU sample at 29%
gaugeScope._applySample({ metricId: 'gpu', value: 29, available: true })
assert.equal(gaugeScope.activeMetricId, 'gpu')
assert.equal(gaugeScope.displayValue, 29, 'initial sample must snap immediately')
assert.equal(gaugeScope.telemetryAnim.started, 0, 'initial sample must not trigger animation')

// 2. Cross-metric switch: GPU (29) -> Memory (49)
gaugeScope._applySample({ metricId: 'memory', value: 49, available: true })
assert.equal(gaugeScope.activeMetricId, 'memory')
assert.equal(gaugeScope.displayValue, 49, 'cross-metric switch must snap immediately to 49')
assert.equal(gaugeScope.telemetryAnim.started, 0, 'cross-metric switch must NOT animate')

// 3. Same-metric telemetry update: Memory (49) -> Memory (51)
gaugeScope._applySample({ metricId: 'memory', value: 51, available: true })
assert.equal(gaugeScope.activeMetricId, 'memory')
assert.equal(gaugeScope.telemetryAnim.started, 1, 'same-metric update must animate')
assert.equal(gaugeScope.telemetryAnim.from, 49)
assert.equal(gaugeScope.telemetryAnim.to, 51)

// 4. Cross-metric switch: Memory (80) -> GPU (20)
gaugeScope.displayValue = 80
gaugeScope._applySample({ metricId: 'gpu', value: 20, available: true })
assert.equal(gaugeScope.activeMetricId, 'gpu')
assert.equal(gaugeScope.displayValue, 20, 'Memory 80 to GPU 20 must snap immediately to 20')
assert.equal(gaugeScope.telemetryAnim.started, 1, 'cross-metric must not start telemetryAnim')

// 5. Same-value cross-metric switch: Memory (50) -> GPU (50)
gaugeScope.activeMetricId = 'memory'
gaugeScope.displayValue = 50
gaugeScope._applySample({ metricId: 'gpu', value: 50, available: true })
assert.equal(gaugeScope.activeMetricId, 'gpu')
assert.equal(gaugeScope.displayValue, 50, 'same-value cross-metric switch must snap to 50')

const presentationSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskMetricPresentation.qml'), 'utf8')
assert.ok(presentationSource.includes('readonly property var gaugeSample'),
    'TaskMetricPresentation.qml must define atomic gaugeSample')
assert.ok(presentationSource.includes('sample: root.gaugeSample'),
    'TaskMetricPresentation.qml must pass sample: root.gaugeSample to TaskWaterGauge')

const dropdownSource = fs.readFileSync(
    path.join(shell, 'components/taskmanager/glassgrid/TaskDropdown.qml'), 'utf8')
assert.match(dropdownSource, /enter\s*:\s*Transition/)
assert.match(dropdownSource, /exit\s*:\s*Transition/)
assert.ok(dropdownSource.includes('HAnimation.taskDropdownOpenDuration'))
assert.ok(dropdownSource.includes('HAnimation.taskDropdownCloseDuration'))

const qmlFiles = [
    path.join(shell, 'components/TaskManagerOverlay.qml'),
    path.join(shell, 'components/taskmanager/TaskManagerContent.qml'),
    ...fs.readdirSync(path.join(shell, 'components/taskmanager/glassgrid'))
        .filter(name => name.endsWith('.qml'))
        .map(name => path.join(shell, 'components/taskmanager/glassgrid', name))
]
for (const file of qmlFiles) {
    const src = fs.readFileSync(file, 'utf8')
    const base = path.basename(file)
    assert.ok(!/Behavior\s+on\s+opacity/.test(src), `${base} must not use Behavior on opacity`)
    assert.ok(!/property\s*:\s*["']opacity["']/.test(src), `${base} must not animate opacity property`)
    assert.ok(!/property\s*:\s*["']reveal["']/.test(src), `${base} must not animate legacy reveal fade`)
    assert.ok(!/opacity\s*:\s*root\.reveal/.test(src), `${base} must not bind opacity to reveal`)
    assert.ok(!/Behavior\s+on\s+scale/.test(src), `${base} must not animate scale`)
    assert.ok(!/property\s*:\s*["']scale["']/.test(src), `${base} must not animate scale property`)
    assert.ok(!/Easing\.(?:OutCubic|InCubic|InOutCubic)/.test(src), `${base} must use Easing.BezierSpline instead of cubic easing`)
    const scaleMatches = src.match(/(?:hoverScaleDelta|pressScaleDelta)\s*:\s*([0-9.]+)/g) || []
    for (const match of scaleMatches) {
        const val = Number(match.split(':')[1].trim())
        assert.equal(val, 0, `${base} must disable button scale delta (${match})`)
    }
}
console.info('Task Manager Glass Grid logic and motion checks passed')

// Keep obsolete CPU tooltip and selection-rail motion out of production tokens.
for (const token of ['taskTooltipStemDuration', 'taskTooltipUnfurlDuration', 'taskTooltipSlideDuration', 'taskTooltipCurve', 'taskSelectionRailDuration', 'taskSelectionRailCurve']) {
    assert.ok(!motionQml.includes(token) && !hanimQml.includes(token), token + ' must be removed')
}
