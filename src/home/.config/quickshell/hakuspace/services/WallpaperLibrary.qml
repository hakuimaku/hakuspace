pragma Singleton
import QtQuick
import Quickshell.Io
import "WallpaperStackModel.js" as StackModel

QtObject {
    id: root
    // Retain lightweight browsing state while either presentation is unloaded.
    property var items: []
    property var layerSelections: ({})
    property int layerRevision: 0
    property string pendingSelectPath: ""
    property string query: ""
    signal layerCycled(string groupKey, int step)
    property string filter: WallpaperSettingsStore.savedValues.browser.filter
    // Each media type retains its category for this session only.
    property string staticCategory: ""
    property string videoCategory: ""
    readonly property string activeCategory: filter === "video" ? videoCategory : staticCategory
    // Empty category is the All selector, independent of the media filter.
    readonly property var staticCategories: categoriesFor("static")
    readonly property var videoCategories: categoriesFor("video")
    readonly property var categories: filter === "video" ? videoCategories : staticCategories
    onStaticCategoriesChanged: if (!staticCategories.includes(staticCategory)) staticCategory = ""
    onVideoCategoriesChanged: if (!videoCategories.includes(videoCategory)) videoCategory = ""
    property string selectedPath: ""
    property string loadError: ""
    property bool refreshPending: false
    property bool initialized: false
    readonly property bool loading: listing.running
    // Keep PathView's model independent of layerSelections so cycling layers never resets the carousel.
    readonly property var filteredItems: StackModel.buildStacks(
        items, filter, activeCategory, query, WallpaperSettingsStore.savedValues.browser.sort)
    readonly property int selectedIndex: filteredItems.findIndex(item => item.path === selectedPath
        || (item.layers && item.layers.some(layer => layer.path === selectedPath)))
    readonly property string selectedGroupKey: selectedIndex >= 0 ? (filteredItems[selectedIndex].groupKey || "") : ""
    readonly property var selected: selectedIndex >= 0 ? resolveStack(filteredItems[selectedIndex], layerRevision) : null

    // Resolve from the native JS stack in filteredItems so delegates never depend on QVariantList conversion.
    function resolveStack(stack, _revision) {
        if (!stack) return null
        var source = stack.groupKey ? (filteredItems.find(item => item.groupKey === stack.groupKey) || stack) : stack
        return StackModel.resolveStack(source, layerSelections)
    }

    // Derive named categories from media records without rescanning the filesystem.
    function categoriesFor(kind) {
        var kindItems = items.filter(item => item.kind === kind)
        var hasRoot = kindItems.some(item => !item.category || item.category === "[Root]")
        var named = Array.from(new Set(kindItems.filter(item => item.category && item.category !== "[Root]")
            .map(item => item.category))).sort((a, b) => a.localeCompare(b))
        return [""].concat(hasRoot ? ["[Root]"] : []).concat(named)
    }
    // Apply category navigation to the current media type without persisting it.
    function setCategory(category) {
        if (!categories.includes(category)) return
        if (filter === "video") videoCategory = category
        else staticCategory = category
    }

    // Coalesce scans without interrupting a running backend request.
    function refresh() {
        initialized = true
        if (listing.running) { refreshPending = true; return }
        loadError = ""
        listing.command = WallpaperService.command(["list", "--json"])
        listing.running = true
    }

    // Keep a surviving selection; otherwise prefer a freshly saved edit or the active wallpaper.
    function resetSelection() {
        if (pendingSelectPath) {
            var pendingStack = filteredItems.find(item => item.path === pendingSelectPath
                || (item.layers && item.layers.some(layer => layer.path === pendingSelectPath)))
            if (pendingStack) {
                var targetPath = pendingSelectPath
                pendingSelectPath = ""
                if (pendingStack.path !== targetPath) {
                    var nextMap = Object.assign({}, layerSelections)
                    nextMap[pendingStack.groupKey] = targetPath
                    layerSelections = nextMap
                    layerRevision++
                }
                selectedPath = targetPath
                return
            }
        }
        var existing = filteredItems.find(item => item.path === selectedPath
            || (item.layers && item.layers.some(layer => layer.path === selectedPath)))
        if (existing) {
            var resolvedExisting = StackModel.resolveStack(existing, layerSelections)
            if (resolvedExisting && resolvedExisting.path !== selectedPath) selectedPath = resolvedExisting.path
            return
        }
        var active = filteredItems.find(item => item.path === WallpaperService.current.path
            || (item.layers && item.layers.some(layer => layer.path === WallpaperService.current.path)))
        var fallback = active ? StackModel.resolveStack(active, layerSelections)
            : filteredItems.length ? StackModel.resolveStack(filteredItems[0], layerSelections) : null
        selectedPath = fallback ? fallback.path : ""
    }
    function selectIndex(index) {
        if (index >= 0 && index < filteredItems.length) {
            var resolved = StackModel.resolveStack(filteredItems[index], layerSelections)
            selectedPath = resolved ? resolved.path : filteredItems[index].path
        }
    }
    function move(step) {
        if (filteredItems.length) selectIndex((selectedIndex + step + filteredItems.length) % filteredItems.length)
    }
    // Cycle the visible top layer within a stacked wallpaper group without replacing filteredItems.
    function cycleLayer(groupKey, step) {
        if (!groupKey || !step) return false
        var baseStack = filteredItems.find(item => item.groupKey === groupKey)
        if (!baseStack || !baseStack.layers || baseStack.layers.length < 2) return false
        var resolved = StackModel.resolveStack(baseStack, layerSelections)
        var nextIndex = (resolved.activeLayerIndex + step + baseStack.layers.length) % baseStack.layers.length
        var nextLayer = baseStack.layers[nextIndex]
        if (!nextLayer) return false
        var wasSelected = selectedGroupKey === groupKey
        layerCycled(groupKey, step)
        var nextMap = Object.assign({}, layerSelections)
        nextMap[groupKey] = nextLayer.path
        layerSelections = nextMap
        layerRevision++
        if (wasSelected) selectedPath = nextLayer.path
        return true
    }
    function siblingsInDir(dirPath) {
        var paths = []
        var stems = []
        for (var i = 0; i < items.length; ++i) {
            var item = items[i]
            if (!item || item.kind !== "static") continue
            var parts = StackModel.splitPath(item.path)
            if (parts.dir === dirPath) {
                paths.push(item.path)
                stems.push(parts.stem)
            }
        }
        return {paths: paths, stems: stems}
    }

    // Browsing never prepares video; only this explicit action selects a source.
    function applySelected() {
        return !!selected && WallpaperService.select(selected.path, WallpaperSettingsStore.savedValues.playback.profile, false)
    }
    onFilteredItemsChanged: resetSelection()

    // The backend returns one finite JSON list per scan.
    property Process listing: Process {
        stdout: StdioCollector { id: listOut }
        stderr: StdioCollector { id: listErr }
        onExited: code => {
            if (code !== 0) root.loadError = listErr.text.trim() || "Could not load wallpapers"
            else {
                try {
                    var records = JSON.parse(listOut.text)
                    if (!Array.isArray(records)) throw new Error("Expected a wallpaper list")
                    if (root.pendingSelectPath) {
                        var match = records.find(item => item.path === root.pendingSelectPath)
                        if (match) {
                            var nextMap = Object.assign({}, root.layerSelections)
                            nextMap[StackModel.groupKeyFor(match)] = match.path
                            root.layerSelections = nextMap
                            root.layerRevision++
                        }
                    }
                    root.items = records
                    WallpaperService.warm(root.items)
                } catch (error) { root.loadError = "Invalid wallpaper list" }
            }
            if (root.refreshPending) { root.refreshPending = false; root.refresh() }
        }
    }
}
