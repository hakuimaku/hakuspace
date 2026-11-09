#!/usr/bin/env node
// Unit and contract test for Emoji ActionMenu page and IPC routing.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const root = path.resolve(__dirname, '../../..')
const shell = path.join(root, 'src/home/.config/quickshell/hakuspace')

// 1. Verify ActionMenuSurface routing for emoji flow
const surfaceSource = fs.readFileSync(path.join(shell, 'components/actionmenu/ActionMenuSurface.qml'), 'utf8')
const surfaceCtx = vm.createContext({})
vm.runInContext([
    ...surfaceSource.matchAll(/^    function (?:pageUrlForFlow|defaultProfileForFlow)\([\s\S]*?^    }/gm)
].map(m => m[0]).join('\n'), surfaceCtx)

assert.equal(surfaceCtx.pageUrlForFlow('emoji'), 'pages/EmojiPage.qml')
assert.equal(surfaceCtx.defaultProfileForFlow('emoji'), 'emoji')

// 2. Verify NavigationIpc launcher handler handles emoji
const ipcSource = fs.readFileSync(path.join(shell, 'ipc/NavigationIpc.qml'), 'utf8')
assert.match(ipcSource, /mode === "emoji"/)
assert.match(ipcSource, /UiState\.openActionMenu\(Quickshell\.screens\[0\]\.name,\s*"emoji"\)/)

// 3. Verify EmojiPage.qml filter logic, grid setup, and history
const emojiPageSource = fs.readFileSync(path.join(shell, 'components/actionmenu/pages/EmojiPage.qml'), 'utf8')
assert.match(emojiPageSource, /title:\s*"Emoji Picker"/)
assert.match(emojiPageSource, /geometryProfile:\s*"emoji"/)
assert.match(emojiPageSource, /columnsCount:\s*8/)
assert.match(emojiPageSource, /rowsCount:\s*6/)
assert.match(emojiPageSource, /GridView/)
assert.match(emojiPageSource, /emoji_ctl\.sh",\s*"list"/)
assert.match(emojiPageSource, /emoji_ctl\.sh",\s*"history"/)
assert.match(emojiPageSource, /emoji_ctl\.sh",\s*"copy"/)

// Test filterEntries and history assembly logic isolated
const mockHistory = [
    '🎉', '🔥', '😀', '😂', '🥰', '😍', '😎', '🤔',
    '👍', '❤️', '✨', '🚀', '💡', '💯', '🙌', '👏'
]

const pageCtx = vm.createContext({
    searchQuery: '',
    _listFinished: true,
    _pendingEntries: [
        {
            emoji: '😀',
            category: 'Smileys & Emotion',
            subcategory: 'face-smiling',
            name: 'grinning face',
            keywords: 'cheerful | smile',
            searchBlob: 'grinning face cheerful | smile smileys & emotion face-smiling'
        },
        {
            emoji: '🚀',
            category: 'Travel & Places',
            subcategory: 'transport-air',
            name: 'rocket',
            keywords: 'launch | space',
            searchBlob: 'rocket launch | space travel & places transport-air'
        },
        {
            emoji: '🐱',
            category: 'Animals & Nature',
            subcategory: 'animal-mammal',
            name: 'cat face',
            keywords: 'kitten | pet',
            searchBlob: 'cat face kitten | pet animals & nature animal-mammal'
        }
    ],
    _pendingHistory: mockHistory,
    allEntries: [],
    historyEntries: [],
    filteredEntries: [],
    activeSection: 'history',
    historyIndex: 0,
    catalogIndex: 0,
    loading: true
})
pageCtx.root = pageCtx

vm.runInContext([
    ...emojiPageSource.matchAll(/^    function (?:assembleData|filterEntries)\(\) {[\s\S]*?^    }/gm)
].map(m => m[0]).join('\n'), pageCtx)

// Assemble data: creates 16 history entries for List 1, and 3 catalog entries for List 2
pageCtx.assembleData()
assert.equal(pageCtx.historyEntries.length, 16)
assert.equal(pageCtx.historyEntries[0].emoji, '🎉')
assert.equal(pageCtx.historyEntries[0].isHistory, true)
assert.equal(pageCtx.historyEntries[1].emoji, '🔥')
assert.equal(pageCtx.historyEntries[1].isHistory, true)

// List 2 contains all catalog entries without history prepended
assert.equal(pageCtx.filteredEntries.length, 3)
assert.equal(pageCtx.allEntries.length, 3)
assert.equal(pageCtx.filteredEntries[0].emoji, '😀')
assert.equal(pageCtx.activeSection, 'history')
assert.equal(pageCtx.historyIndex, 0)

// Query by name: 'rocket' - filters from allEntries into List 2 and activates catalog
pageCtx.searchQuery = 'rocket'
pageCtx.filterEntries()
assert.equal(pageCtx.filteredEntries.length, 1)
assert.equal(pageCtx.filteredEntries[0].emoji, '🚀')
assert.equal(pageCtx.activeSection, 'catalog')

// Query by keyword: 'smile'
pageCtx.searchQuery = 'smile'
pageCtx.filterEntries()
assert.equal(pageCtx.filteredEntries.length, 1)
assert.equal(pageCtx.filteredEntries[0].emoji, '😀')

// Query by category: 'animals'
pageCtx.searchQuery = 'animals'
pageCtx.filterEntries()
assert.equal(pageCtx.filteredEntries.length, 1)
assert.equal(pageCtx.filteredEntries[0].emoji, '🐱')

// Non-matching query
pageCtx.searchQuery = 'nonexistentxyz'
pageCtx.filterEntries()
assert.equal(pageCtx.filteredEntries.length, 0)

// Test empty history behavior: defaults to nothing in history, activeSection is catalog
const emptyCtx = vm.createContext({
    searchQuery: '',
    _listFinished: true,
    _pendingEntries: pageCtx.allEntries,
    _pendingHistory: [],
    allEntries: [],
    historyEntries: [],
    filteredEntries: [],
    activeSection: 'catalog',
    historyIndex: 0,
    catalogIndex: 0,
    loading: true
})
emptyCtx.root = emptyCtx

vm.runInContext([
    ...emojiPageSource.matchAll(/^    function (?:assembleData|filterEntries)\(\) {[\s\S]*?^    }/gm)
].map(m => m[0]).join('\n'), emptyCtx)

emptyCtx.assembleData()
assert.equal(emptyCtx.historyEntries.length, 0)
assert.equal(emptyCtx.activeSection, 'catalog')
assert.equal(emptyCtx.filteredEntries.length, 3)

// Test overflow history: maximum 16 items, oldest beyond 16 are omitted
const overflowHistory = [
    '01', '02', '03', '04', '05', '06', '07', '08',
    '09', '10', '11', '12', '13', '14', '15', '16',
    '17', '18', '19', '20'
]
const overflowCtx = vm.createContext({
    searchQuery: '',
    _listFinished: true,
    _pendingEntries: pageCtx.allEntries,
    _pendingHistory: overflowHistory,
    allEntries: [],
    historyEntries: [],
    filteredEntries: [],
    activeSection: 'history',
    historyIndex: 0,
    catalogIndex: 0,
    loading: true
})
overflowCtx.root = overflowCtx

vm.runInContext([
    ...emojiPageSource.matchAll(/^    function (?:assembleData|filterEntries)\(\) {[\s\S]*?^    }/gm)
].map(m => m[0]).join('\n'), overflowCtx)

overflowCtx.assembleData()
assert.equal(overflowCtx.historyEntries.length, 16)
assert.equal(overflowCtx.historyEntries[0].emoji, '01')
assert.equal(overflowCtx.historyEntries[15].emoji, '16')
assert.equal(overflowCtx.historyEntries.some(e => e.emoji === '17'), false)
assert.equal(overflowCtx.historyEntries.some(e => e.emoji === '20'), false)

console.log('ActionMenu emoji routing and filter unit tests passed!')
