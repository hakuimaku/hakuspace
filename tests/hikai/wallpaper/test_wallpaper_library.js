// Validate WallpaperLibrary category and filtering logic in Hikai mode.
const assert = require('node:assert/strict')

// Replicate the WallpaperLibrary pure helper contracts.
function categoriesFor(items, kind) {
    const kindItems = items.filter(item => item.kind === kind)
    const hasRoot = kindItems.some(item => !item.category || item.category === '[Root]')
    const named = Array.from(new Set(kindItems.filter(item => item.category && item.category !== '[Root]')
        .map(item => item.category))).sort((a, b) => a.localeCompare(b))
    return [''].concat(hasRoot ? ['[Root]'] : []).concat(named)
}

function filteredItems(items, kind, activeCategory, query = '', sort = 'name') {
    return items.filter(item => item.kind === kind
        && (activeCategory === ''
            || (activeCategory === '[Root]' ? (!item.category || item.category === '[Root]') : item.category === activeCategory))
        && item.label.toLowerCase().includes(query.trim().toLowerCase())).sort((a, b) => {
        const byName = a.label.toLowerCase().localeCompare(b.label.toLowerCase()) || a.path.localeCompare(b.path)
        if (sort === 'newest') return Number(b.previewVersion || 0) - Number(a.previewVersion || 0) || byName
        return sort === 'name-desc' ? -byName : byName
    })
}

// 1. Both root and subcategories exist
const mixedItems = [
    {path: '/wallpapers/root1.png', label: 'Root 1', kind: 'static', category: '[Root]'},
    {path: '/wallpapers/root2.png', label: 'Root 2', kind: 'static', category: ''},
    {path: '/wallpapers/Anime/a.png', label: 'Anime 1', kind: 'static', category: 'Anime'},
    {path: '/wallpapers/Nature/n.png', label: 'Nature 1', kind: 'static', category: 'Nature'},
    {path: '/videos/root_clip.mp4', label: 'Root Video', kind: 'video', category: '[Root]'},
    {path: '/videos/Space/s.mp4', label: 'Space Video', kind: 'video', category: 'Space'},
]

const staticCats = categoriesFor(mixedItems, 'static')
assert.deepEqual(staticCats, ['', '[Root]', 'Anime', 'Nature'])

const videoCats = categoriesFor(mixedItems, 'video')
assert.deepEqual(videoCats, ['', '[Root]', 'Space'])

// 2. All selector returns all items of that kind
const allStatic = filteredItems(mixedItems, 'static', '')
assert.equal(allStatic.length, 4)
assert.deepEqual(allStatic.map(i => i.label), ['Anime 1', 'Nature 1', 'Root 1', 'Root 2'])

// 3. [Root] selector returns only root items
const rootStatic = filteredItems(mixedItems, 'static', '[Root]')
assert.equal(rootStatic.length, 2)
assert.deepEqual(rootStatic.map(i => i.label), ['Root 1', 'Root 2'])

const rootVideo = filteredItems(mixedItems, 'video', '[Root]')
assert.equal(rootVideo.length, 1)
assert.equal(rootVideo[0].label, 'Root Video')

// 4. Subcategory selector returns only that subcategory
const animeStatic = filteredItems(mixedItems, 'static', 'Anime')
assert.equal(animeStatic.length, 1)
assert.equal(animeStatic[0].label, 'Anime 1')

// 5. When NO root items exist for a kind, [Root] does NOT appear
const noRootItems = [
    {path: '/wallpapers/Anime/a.png', label: 'Anime 1', kind: 'static', category: 'Anime'},
    {path: '/wallpapers/Nature/n.png', label: 'Nature 1', kind: 'static', category: 'Nature'},
]
assert.deepEqual(categoriesFor(noRootItems, 'static'), ['', 'Anime', 'Nature'])
assert.deepEqual(categoriesFor(noRootItems, 'video'), [''])

// 6. When ONLY root items exist (no subfolders), [Root] appears
const onlyRootItems = [
    {path: '/wallpapers/image1.png', label: 'Img 1', kind: 'static', category: '[Root]'},
    {path: '/wallpapers/image2.png', label: 'Img 2', kind: 'static'},
]
assert.deepEqual(categoriesFor(onlyRootItems, 'static'), ['', '[Root]'])
const onlyRootFiltered = filteredItems(onlyRootItems, 'static', '[Root]')
assert.equal(onlyRootFiltered.length, 2)

// 7. Empty collection
assert.deepEqual(categoriesFor([], 'static'), [''])
assert.deepEqual(categoriesFor([], 'video'), [''])
assert.deepEqual(filteredItems([], 'static', '[Root]'), [])

// 8. Search query composition with [Root]
assert.equal(filteredItems(mixedItems, 'static', '[Root]', 'root 1').length, 1)
assert.equal(filteredItems(mixedItems, 'static', '[Root]', 'anime').length, 0)

console.log('All WallpaperLibrary [Root] category tests passed!')
