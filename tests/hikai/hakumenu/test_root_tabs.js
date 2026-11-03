#!/usr/bin/env node
// Exercise production state methods without a desktop or backend collectors.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const source = fs.readFileSync(path.resolve(__dirname, '../../../src/home/.config/quickshell/hakuspace/services/UiState.qml'), 'utf8')
const state = vm.createContext({hakuPanelTab: 'hakumenu', hakuMenuMode: 'theme', hakuMenuQuery: '~', activePanel: 'hakumenu'})
vm.runInContext([...source.matchAll(/^    function (?:setHakuPanelTab|setHakuMenuMode|setHakuMenuQuery|closeHakuMenu)\([\s\S]*?^    }/gm)].map(match => match[0]).join('\n'), state)
assert.match(source, /property string hakuPanelTab: "hakumenu"/)
for (const mode of ['general', 'drun', 'theme']) {
    state.hakuMenuMode = mode
    for (let cycle = 0; cycle < 50; cycle++) {
        state.setHakuPanelTab('taskManager')
        assert.equal(state.hakuMenuMode, mode)
        state.setHakuMenuQuery('>blocked')
        assert.equal(state.hakuMenuQuery, '~')
        state.setHakuPanelTab('invalid')
        assert.equal(state.hakuPanelTab, 'taskManager')
        state.setHakuMenuMode('taskManager')
        assert.equal(state.hakuMenuMode, mode)
        state.setHakuPanelTab('hakumenu')
        assert.equal(state.hakuMenuMode, mode)
    }
}
state.setHakuPanelTab('taskManager')
state.closeHakuMenu()
assert.equal(state.hakuPanelTab, 'hakumenu')
assert.equal(state.hakuMenuMode, 'closed')
console.log('HakuMenu root tab state checks passed')
