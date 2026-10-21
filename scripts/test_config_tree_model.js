const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')

const path = 'src/home/.config/quickshell/hakuspace/components/settings/ConfigTreeModel.js'
const context = vm.createContext({})
vm.runInContext(fs.readFileSync(path, 'utf8'), context, { filename: path })
const files = [
    'wm/z.lua', 'wm/nested/deep/b.lua', 'wm/nested/a.lua',
    'wm/alpha.lua', 'config/kitty.conf'
].map(id => ({ id, group: id.split('/')[0] }))
const rows = JSON.parse(JSON.stringify(context.rows(files, 'wm')))
assert.deepEqual(rows.map(row => [row.type, row.label, row.depth, row.fileId]), [
    ['directory', 'nested', 0, ''],
    ['directory', 'deep', 1, ''],
    ['file', 'b.lua', 2, 'wm/nested/deep/b.lua'],
    ['file', 'a.lua', 1, 'wm/nested/a.lua'],
    ['file', 'alpha.lua', 0, 'wm/alpha.lua'],
    ['file', 'z.lua', 0, 'wm/z.lua']
])
assert.deepEqual(rows.map(row => row.isLast), [false, false, true, true, false, true])
assert.deepEqual(rows[2].ancestorLast, [false, false])
assert.deepEqual(rows[3].ancestorLast, [false])
assert.deepEqual(JSON.parse(JSON.stringify(context.rows(files, 'config'))).map(row => row.fileId), ['config/kitty.conf'])
for (const [id, title] of [
    ['wm/hyprland-custom.lua', 'Hyprland'], ['wm/niri-custom.kdl', 'Niri'],
    ['wm/mango-custom.conf', 'MangoWM'], ['config/cava-layer', 'Cava Underbar'],
    ['config/hypridle.conf', 'Hypridle'], ['config/rofi/config.rasi', 'Rofi'],
    ['config/taskbar-pin-apps', 'Pinned Apps'], ['config/custom_tool.conf', 'Custom Tool'],
    ['config/.env', '.env']
]) assert.equal(context.title(id), title)
console.log('Config tree model fixtures passed')
