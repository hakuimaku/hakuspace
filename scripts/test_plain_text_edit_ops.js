const assert = require('node:assert/strict')
const ops = require('../src/home/.config/quickshell/hakuspace/components/editor/PlainTextEditOps.js')

function apply(text, change) {
    if (!change.changed) return text
    return text.slice(0, change.rangeStart) + change.replacement + text.slice(change.rangeEnd)
}

function comment(text, start, end, file = 'a.conf', cursor = end) {
    return ops.toggleComment(text, start, end, cursor, ops.profileForFile(file))
}

for (const [file, marker] of Object.entries({
    'wm/hyprland-custom.lua': '--', 'wm/niri-custom.kdl': '//',
    'config/kitty.conf': '#', 'config/shell.fish': '#', 'a.sh': '#',
    'a.bash': '#', 'a.zsh': '#', 'a.json': '//', 'a.jsonc': '//',
    'config/taskbar-pin-apps': '//', 'config/waybar/foo/config': '//'
})) assert.equal(ops.profileForFile(file).lineComment, marker, file)
for (const file of ['a.css', 'a.rasi']) assert.equal(ops.profileForFile(file).blockStart, '/* ')
assert.equal(ops.profileForFile('unknown').lineComment, undefined)

let source = '\talpha\n    beta\n\t\tgamma'
let change = comment(source, 0, source.length, 'a.lua')
let result = '\t-- alpha\n    -- beta\n\t-- \tgamma'
assert.equal(apply(source, change), result)
assert.equal(apply(result, comment(result, change.selectionStart, change.selectionEnd, 'a.lua')), source)
assert.equal(apply(source, comment(source, 1, source.length, 'a.lua')), result)
assert.equal(apply('\n\talpha\n    beta', comment('\n\talpha\n    beta', 0, 16, 'a.lua')), '\n\t-- alpha\n    -- beta')
assert.equal(apply('\talpha\nbeta', comment('\talpha\nbeta', 0, 11)), '\t# alpha\n# beta')
assert.equal(apply('  # value', comment('  # value', 0, 0)), '  value')
assert.equal(apply('#value', comment('#value', 0, 0)), 'value')
assert.equal(apply('#  value', comment('#  value', 0, 0)), ' value')
assert.equal(apply('# one\ntwo', comment('# one\ntwo', 0, 9)), '# # one\n# two')
assert.equal(apply('one\n\nthree', comment('one\n\nthree', 0, 10)), '# one\n\n# three')
assert.equal(apply('a\nb', comment('a\nb', 0, 2)), '# a\nb')
assert.equal(apply('a\r\nb', comment('a\r\nb', 0, 3)), '# a\r\nb')
assert.equal(apply('', comment('', 0, 0)), '')
assert.equal(apply('value', comment('value', 2, 2, 'unknown')), 'value')
assert.equal(apply('a\nb', comment('a\nb', 0, 3, 'a.css')), '/* a\nb */')
assert.equal(apply('/* a\nb */', comment('/* a\nb */', 0, 9, 'a.css')), 'a\nb')

change = ops.indent('one\n  two\nthree', 0, 9, 9, '    ', false)
assert.equal(apply('one\n  two\nthree', change), '    one\n      two\nthree')
assert.deepEqual([change.selectionStart, change.selectionEnd], [4, 17])
assert.equal(apply('    one\n      two', ops.indent('    one\n      two', 0, 17, 17, '    ', true)), 'one\n  two')
assert.equal(apply('\tfoo', ops.indent('\tfoo', 0, 0, 0, '    ', true)), 'foo')
assert.equal(apply('foo', ops.indent('foo', 2, 2, 2, '    ', false)), 'fo    o')

for (const [position, expected] of [[0, 'b\nc'], [2, 'a\nc'], [4, 'a\nb']])
    assert.equal(apply('a\nb\nc', ops.lineCommand('a\nb\nc', position, position, position, 'delete')), expected)
assert.equal(ops.lineCommand('a\nb', 0, 0, 0, 'moveUp').changed, false)
assert.equal(ops.lineCommand('a\nb', 2, 2, 2, 'moveDown').changed, false)
change = ops.lineCommand('a\nb\nc', 2, 3, 2, 'moveUp')
assert.equal(apply('a\nb\nc', change), 'b\na\nc')
assert.deepEqual([change.selectionStart, change.selectionEnd, change.cursorPosition], [0, 1, 0])
assert.equal(apply('a\nb\nc', ops.lineCommand('a\nb\nc', 0, 3, 3, 'moveDown')), 'c\na\nb')
assert.equal(apply('a\nb', ops.lineCommand('a\nb', 2, 2, 2, 'duplicateUp')), 'a\nb\nb')
assert.equal(apply('a\nb', ops.lineCommand('a\nb', 2, 2, 2, 'duplicateDown')), 'a\nb\nb')
assert.equal(apply('a', ops.lineCommand('a', 0, 0, 0, 'duplicateDown')), 'a\na')
assert.deepEqual(ops.selectLine('a\nb', 2, 2, 2), { changed: true, selectionOnly: true, selectionStart: 2, selectionEnd: 3, cursorPosition: 3 })
assert.equal(apply('    foo', ops.newline('    foo', 7, 7)), '    foo\n    ')
console.log('PlainTextEditOps fixtures passed')
