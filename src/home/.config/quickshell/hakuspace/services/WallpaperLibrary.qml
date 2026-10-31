pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    // Retain lightweight browsing state while either presentation is unloaded.
    property var items: []
    property string query: ""
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
    // Sort a filtered copy so changing order preserves source records and selection paths.
    readonly property var filteredItems: {
        var order = WallpaperSettingsStore.savedValues.browser.sort
        return items.filter(item => item.kind === filter
            && (activeCategory === "" || item.category === activeCategory)
            && item.label.toLowerCase().includes(query.trim().toLowerCase())).sort(function(a, b) {
            var byName = a.label.toLowerCase().localeCompare(b.label.toLowerCase()) || a.path.localeCompare(b.path)
            if (order === "newest") return Number(b.previewVersion || 0) - Number(a.previewVersion || 0) || byName
            return order === "name-desc" ? -byName : byName
        })
    }
    readonly property int selectedIndex: filteredItems.findIndex(item => item.path === selectedPath)
    readonly property var selected: filteredItems[selectedIndex] || null

    // Derive named categories from media records without rescanning the filesystem.
    function categoriesFor(kind) {
        return [""].concat(Array.from(new Set(items.filter(item => item.kind === kind && item.category)
            .map(item => item.category))).sort((a, b) => a.localeCompare(b)))
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

    // Keep a surviving selection; otherwise prefer the active wallpaper.
    function resetSelection() {
        if (filteredItems.some(item => item.path === selectedPath)) return
        var active = filteredItems.find(item => item.path === WallpaperService.current.path)
        selectedPath = active ? active.path : filteredItems.length ? filteredItems[0].path : ""
    }
    function selectIndex(index) {
        if (index >= 0 && index < filteredItems.length) selectedPath = filteredItems[index].path
    }
    function move(step) {
        if (filteredItems.length) selectIndex((selectedIndex + step + filteredItems.length) % filteredItems.length)
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
                    root.items = records
                    WallpaperService.warm(root.items)
                } catch (error) { root.loadError = "Invalid wallpaper list" }
            }
            if (root.refreshPending) { root.refreshPending = false; root.refresh() }
        }
    }
}
