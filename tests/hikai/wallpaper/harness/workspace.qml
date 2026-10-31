import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    // Exercise real component geometry without a compositor or the user's settings.
    property int phase: -2
    property int ticks: 0
    property int index: 0
    property int settle: 0
    property int curveFrames: 0
    property int cacheDraft: 0
    property real qualityStart: 0
    property string originalAccent: ""
    property int repeatedMoves: 0
    property int finalSelection: 0
    property int tabMove: 0
    property bool sawQualityMorph: false
    property bool sawLivelyFade: false
    property bool sawControlCompression: false
    property bool sawControlRebound: false
    property real modeBadgeWidth: 0
    property real searchStart: 0
    property real leftToolsWidth: 0
    property var qualityTarget: null
    property bool sawOpen: false
    property bool sawClose: false
    property bool sawSettingsMorph: false
    property bool sawSettingsFade: false
    property bool capturing: false
    property var closingEditor: null
    property var closingPage: null
    // Check each category lane in both layouts before the existing workspace probes.
    property int categoryCase: 0
    // Restore the full fixture after measuring centered short category groups.
    property var categoryItems: []
    // Observe a real variable-width pill transition in each presentation.
    property bool categoryMorphPending: false
    property bool sawCategoryMorph: false
    property real categoryStartX: 0
    property real categoryStartWidth: 0
    readonly property var cases: [
        [1024, 14, "static"], [1024, 14, "video"], [1024, 18, "static"], [1024, 18, "video"],
        [1280, 14, "static"], [1280, 14, "video"], [1280, 18, "static"], [1280, 18, "video"],
        [1920, 14, "static"], [1920, 14, "video"], [1920, 18, "static"], [1920, 18, "video"]]
    FloatingWindow {
        id: testWindow
        screen: Quickshell.screens.find(screen => screen.width === 1920) || Quickshell.screens[0]
        implicitWidth: 1920; implicitHeight: 1080
        visible: true
        color: "white"
        Wallpaper.WallpaperBrowser {
            id: browser
            width: 1920; height: 1080
            presentation: "workspace"
            refreshOnShow: false
        }
    }
    // Send real keys only in the private Wayland runtime variant.
    Process {
        id: categoryKeyboard
        command: ["python3", Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/../wayland_keyboard.py"]
        stdinEnabled: true
        running: Quickshell.env("QT_QPA_PLATFORM") === "wayland"
    }
    // Rename only the private fixture folder before refreshing its category records.
    Process {
        id: categoryFilesystem
        command: ["mv", "--", Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/Pictures/Wallpapers/RuntimeCategory",
            Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/Pictures/Wallpapers/RuntimeRenamed"]
        onExited: code => {
            root.check(code === 0, "rename private wallpaper category")
            WallpaperLibrary.refresh()
            root.phase = -8
        }
    }
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper workspace failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children || []) {
            var found = find(child, name)
            if (found) return found
        }
        return null
    }
    // Exercise shared category state, selection fallbacks and composed browsing filters.
    function checkCategories() {
        // Use duplicate basenames, uncategorized roots and Unicode folder names.
        var records = [
            {path: "root", kind: "static", category: "", label: "Root"},
            {path: "anime-a", kind: "static", category: "Anime", label: "Mountain", previewVersion: "1"},
            {path: "anime-b", kind: "static", category: "Anime", label: "Night", previewVersion: "2"},
            {path: "nature", kind: "static", category: "Nature", label: "Mountain"},
            {path: "unicode", kind: "static", category: "日本", label: "Chill"},
            {path: "long", kind: "static", category: "Ảnh chill để code lúc 3 giờ sáng", label: "Chill"},
            {path: "wide", kind: "static", category: "Architecture-and-Minimal-Monochrome", label: "Chill"},
            {path: "video-root", kind: "video", category: "", label: "Root"},
            {path: "video-anime", kind: "video", category: "Anime", label: "Mountain"},
            {path: "space-a", kind: "video", category: "Space", label: "Earth"},
            {path: "space-b", kind: "video", category: "Space", label: "Moon"}]
        // Settings and active selection are restored after these isolated state assertions.
        var saved = WallpaperSettingsStore.savedValues
        var current = WallpaperService.current
        var snapshot = JSON.stringify(saved)
        records.forEach(item => item.thumbnail = Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/preview.png")
        WallpaperLibrary.items = records
        WallpaperLibrary.initialized = true
        browser.filter = "static"
        check(WallpaperLibrary.categories[0] === "" && WallpaperLibrary.categories.length === 6
            && !WallpaperLibrary.categories.includes("Space"), "Images categories come only from static records, All first")
        check(browser.filteredItems.length === 7, "All includes root and categorized Images")
        WallpaperLibrary.selectedPath = "anime-b"
        WallpaperLibrary.setCategory("Anime")
        check(WallpaperLibrary.selectedPath === "anime-b" && browser.filteredItems.length === 2, "category preserves a surviving selection")
        browser.query = "mountain"
        check(browser.filteredItems.length === 1 && browser.selected.path === "anime-a"
            && WallpaperLibrary.activeCategory === "Anime", "media, category and query compose")
        browser.query = "missing"
        check(!browser.filteredItems.length && WallpaperLibrary.selectedPath === "" && !browser.selected, "empty category search clears selection safely")
        browser.query = ""
        for (var order of ["name-desc", "newest", "name"]) {
            WallpaperSettingsStore.savedValues = Object.assign({}, saved, {browser: Object.assign({}, saved.browser, {sort: order})})
            check(browser.filteredItems[0].path === (order === "name" ? "anime-a" : "anime-b")
                && browser.filteredItems.length === 2 && WallpaperLibrary.activeCategory === "Anime", "sort stays inside category: " + order)
        }
        for (var i = 0; i < 20; ++i) {
            browser.shuffle()
            check(browser.selected.kind === "static" && browser.selected.category === "Anime", "shuffle stays inside category")
        }
        WallpaperService.current = {path: "anime-b"}
        WallpaperLibrary.setCategory("Nature")
        check(WallpaperLibrary.selectedPath === "nature", "missing selection falls back to the first category item")
        WallpaperLibrary.setCategory("Anime")
        check(WallpaperLibrary.selectedPath === "anime-b", "active wallpaper wins over the first category item")
        WallpaperLibrary.setCategory("Nature")
        browser.filter = "video"
        check(JSON.stringify(WallpaperLibrary.categories) === JSON.stringify(["", "Anime", "Space"]), "Lively categories exclude Images folders")
        WallpaperLibrary.setCategory("Space")
        browser.filter = "static"
        check(WallpaperLibrary.activeCategory === "Nature", "Images remembers its category")
        browser.filter = "video"
        check(WallpaperLibrary.activeCategory === "Space", "Lively remembers its category")
        WallpaperLibrary.items = records.slice()
        check(WallpaperLibrary.activeCategory === "Space", "refresh preserves an existing category")
        WallpaperLibrary.items = records.filter(item => item.category !== "Space")
        check(WallpaperLibrary.activeCategory === "" && WallpaperLibrary.staticCategory === "Nature"
            && browser.filteredItems.length === 2, "deleted category falls back to All for only its media type")
        WallpaperLibrary.items = records.filter(item => item.kind === "static")
        check(WallpaperLibrary.categories.length === 1 && !browser.filteredItems.length && !browser.selected, "missing media kind remains safe")
        WallpaperLibrary.items = []
        check(WallpaperLibrary.staticCategory === "" && WallpaperLibrary.videoCategory === ""
            && WallpaperLibrary.categories.length === 1 && !browser.filteredItems.length, "empty library has only All")
        check(browser.handleShortcut({key: Qt.Key_Left, modifiers: Qt.AltModifier, accepted: false})
            && WallpaperLibrary.activeCategory === "", "Alt category navigation remains safe with only All")
        check(!find(browser, "wallpaper-prev-category").enabled && !find(browser, "wallpaper-next-category").enabled,
            "both category arrows disable when only All exists")
        WallpaperLibrary.items = records
        browser.filter = "static"
        WallpaperLibrary.setCategory("日本")
        browser.presentation = "quick"
        browser.presentation = "workspace"
        check(WallpaperLibrary.activeCategory === "日本" && browser.filteredItems.length === 1, "Quick to Workspace shares category")
        browser.presentation = "quick"
        check(WallpaperLibrary.activeCategory === "日本", "Workspace to Quick shares category")
        check(!WallpaperLibrary.loading && !WallpaperLibrary.refreshPending, "category navigation never starts discovery")
        WallpaperSettingsStore.savedValues = saved
        WallpaperService.current = current
        check(JSON.stringify(WallpaperSettingsStore.savedValues) === snapshot, "category navigation never persists settings")
        // Category keys and buttons stop at the ends while preserving media and query.
        var requestSerial = WallpaperService.requestSerial
        for (var presentation of ["quick", "workspace"]) {
            browser.presentation = presentation
            for (var kind of ["static", "video"]) {
                browser.filter = kind
                WallpaperLibrary.setCategory("")
                browser.query = "mountain"
                for (var key of [Qt.Key_Left, Qt.Key_Right, Qt.Key_Down, Qt.Key_Up]) {
                    // Derive the next category independently from the browser's dispatcher.
                    var categories = WallpaperLibrary.categories
                    var step = [Qt.Key_Left, Qt.Key_Up].includes(key) ? -1 : 1
                    var expected = categories[Math.max(0, Math.min(categories.length - 1, categories.indexOf(WallpaperLibrary.activeCategory) + step))]
                    var event = {key: key, modifiers: Qt.AltModifier, accepted: false}
                    check(browser.handleShortcut(event) && event.accepted && WallpaperLibrary.activeCategory === expected,
                        "Alt arrow selects the adjacent category: " + presentation + "/" + kind)
                    check(browser.filter === kind && browser.query === "mountain" && !WallpaperLibrary.loading
                        && WallpaperService.requestSerial === requestSerial,
                        "category shortcut preserves media/search and never scans or applies: " + JSON.stringify({presentation: presentation,
                            kind: kind, filter: browser.filter, query: browser.query, loading: WallpaperLibrary.loading,
                            requestSerial: WallpaperService.requestSerial}))
                }
                // Repeated navigation cannot cycle past the first or last category.
                for (var direction of [1, -1]) {
                    var arrow = find(browser, direction > 0 ? "wallpaper-next-category" : "wallpaper-prev-category")
                    for (var press = 0; press < WallpaperLibrary.categories.length + 1; ++press) arrow.clicked()
                    check(WallpaperLibrary.activeCategory === (direction > 0 ? WallpaperLibrary.categories[WallpaperLibrary.categories.length - 1] : "")
                        && !arrow.enabled, "category arrow stops and disables at its boundary")
                    check(browser.filter === kind && browser.query === "mountain" && WallpaperService.requestSerial === requestSerial,
                        "category buttons never change media, search or current wallpaper")
                }
            }
        }
        browser.query = ""
        browser.filter = "static"
        browser.presentation = "quick"
        WallpaperLibrary.setCategory("")
    }
    // Fit short groups around the selector center instead of the viewport's left edge.
    function checkCategoryCentering() {
        var lane = find(browser, "wallpaper-category-lane")
        var buttons = find(lane, "wallpaper-category-").parent
        check(Math.abs(buttons.mapToItem(lane, buttons.width / 2, 0).x - lane.width / 2) < 0.5,
            "category group is centered in " + browser.presentation)
    }
    // Compare in the scrolling content's coordinates, independent of centering and scroll.
    function categoryPillSettled() {
        var pill = find(browser, "wallpaper-category-indicator")
        if (!pill || !pill.targetItem || pill.opacity < 0.99) return false
        var target = pill.targetItem.mapToItem(pill.parent, 0, 0)
        return Math.abs(pill.x - target.x) < 0.5 && Math.abs(pill.y - target.y) < 0.5
            && Math.abs(pill.width - pill.targetItem.width) < 0.5 && Math.abs(pill.height - pill.targetItem.height) < 0.5
    }
    // Check bounded labels, scroll range and real separation from media tabs and cards.
    function checkCategoryGeometry() {
        var lane = find(browser, "wallpaper-category-lane")
        var scroll = find(lane, "wallpaper-category-scroll")
        var tabs = find(browser, "wallpaper-kind-static").parent
        var reel = find(browser, "wallpaperReel")
        var pill = find(lane, "wallpaper-category-indicator")
        var previous = find(lane, "wallpaper-prev-category")
        var next = find(lane, "wallpaper-next-category")
        var categoryIndex = WallpaperLibrary.categories.indexOf(WallpaperLibrary.activeCategory)
        check(previous.visible && next.visible && previous.enabled === (categoryIndex > 0)
            && next.enabled === (categoryIndex < WallpaperLibrary.categories.length - 1), "category arrows reflect list boundaries")
        check(previous.x + previous.width + Theme.gap <= scroll.x + 0.5
            && scroll.x + scroll.width + Theme.gap <= next.x + 0.5, "category arrows flank the scrolling viewport")
        check(previous.activeFocusOnTab && next.activeFocusOnTab && previous.Accessible.name.length > 0
            && next.Accessible.name.length > 0, "category arrows expose keyboard focus and accessible names")
        check(categoryPillSettled() && pill.targetItem.modelData === WallpaperLibrary.activeCategory,
            "category pill matches the selected chip after layout or scrolling")
        check(lane.mapToItem(browser, 0, 0).y >= tabs.mapToItem(browser, 0, tabs.height).y,
            "category lane follows media tabs")
        check(scroll.clip, "category viewport clips overflow")
        if (categoryCase < 4) {
            check(scroll.contentWidth > scroll.width, "many categories scroll horizontally")
            scroll.contentX = scroll.contentWidth - scroll.width
            check(scroll.contentX > 0, "category viewport reaches overflow names")
        } else {
            check(scroll.contentWidth === scroll.width, "short categories need no scrolling")
            checkCategoryCentering()
        }
        for (var category of WallpaperLibrary.categories) {
            var button = find(lane, "wallpaper-category-" + category)
            var label = find(button, "wallpaper-category-label")
            check(button.width >= 64 && button.width <= 220 && label.elide === Text.ElideRight
                && label.text === (category || "All"), "bounded category label: " + category)
            check(button.Accessible.role === Accessible.PageTab && button.Accessible.name === (category || "All")
                && button.Accessible.selected === button.selected && button.activeFocusOnTab, "accessible category control")
            check(button.idleColor.a === 0 && button.selectedColor.a === 0 && button.hoverColor.a === 0,
                "shared morph pill owns category backgrounds")
            check(button.foregroundColor.toString() === String(Theme.fgMuted)
                && button.selectedForegroundColor.toString() === String(Theme.onAccentColor)
                && button.targetForeground.toString() === String(button.selected ? Theme.onAccentColor : Theme.fgMuted),
                "category labels stay dim and neutral outside the unchanged pill style")
        }
        if (browser.workspace) {
            check(!!reel.currentItem && lane.y + lane.height + browser.panelPadding <= reel.currentItem.mapToItem(browser, 0, 0).y + 1,
                "workspace reserves category space above the raised card: " + JSON.stringify({laneBottom: lane.y + lane.height,
                    cardTop: reel.currentItem ? reel.currentItem.mapToItem(browser, 0, 0).y : null}))
        } else check(lane.mapToItem(browser, 0, lane.height).y < reel.y, "quick categories do not overlap carousel")
    }
    // Check actual label bounds, including compact icon actions and long filenames.
    function labels(item, title) {
        if (!item.visible) return
        if (item.description !== undefined) {
            var label = item.children.find(child => child.objectName === "wallpaper-button-content")
            var point = item.mapToItem(browser, 0, 0)
            check(point.x >= 8 && point.x + item.width <= browser.width - 8, "control stays inside toolbar: " + item.description)
            check(point.y >= 3 && point.y + item.height <= browser.topPanelHeight - 3, "vertical padding: " + item.description)
            check(!!label && (item.width - label.implicitWidth) / 2 >= item.horizontalPadding - 0.5, "label padding: " + item.description)
            check(point.x + item.width <= title.x - 4 || point.x >= title.x + title.width + 4, "control does not overlap centered name")
        }
        for (var child of item.children || []) labels(child, title)
    }
    // Match every visible card corner to the actual filled chassis while scrolling.
    function contained() {
        var body = find(browser, "wallpaperBottomPanel")
        var reel = find(browser, "wallpaperReel")
        body.containsMode = Shape.FillContains
        if (!reel.currentItem) return
        ++curveFrames
        for (var card of reel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible)) {
            check(card.opacity === 1 && card.cornerRadius > 0, "curved cards remain opaque and rounded")
            for (var corner of [[0, 0], [card.width, 0], [0, card.height], [card.width, card.height]]) {
                var point = card.mapToItem(browser, corner[0], corner[1])
                if (point.x < 0 || point.x >= browser.width || point.y >= browser.height || point.y >= browser.height - browser.bottomBarHeight) continue
                check(body.contains(body.mapFromItem(browser, point.x, point.y)), "scrolling wallpaper stays in the background")
            }
        }
    }
    FrameAnimation {
        running: (root.phase === -1 && root.categoryMorphPending) || root.phase === 2 || root.phase === 10 || root.phase === 12 || root.phase === 20 || root.phase === 24 || root.phase === 25
        onTriggered: {
            if (root.phase === -1) {
                var pill = root.find(browser, "wallpaper-category-indicator")
                var target = pill.targetItem.mapToItem(pill.parent, 0, 0)
                if (Math.abs(pill.x - root.categoryStartX) > 0.5 && Math.abs(pill.x - target.x) > 0.5
                    && Math.abs(pill.width - root.categoryStartWidth) > 0.5 && Math.abs(pill.width - pill.targetItem.width) > 0.5)
                    root.sawCategoryMorph = true
                return
            }
            if (root.phase === 24 || root.phase === 25) {
                var controls = root.find(browser, "wallpaper-quick-controls")
                if (controls.navigationScale < 0.99) root.sawControlCompression = true
                if (controls.navigationScale > 1.001) root.sawControlRebound = true
                return
            }
            if (root.phase === 2) {
                var opacity = root.find(browser, "wallpaper-lively-controls").opacity
                if (opacity > 0.45 && opacity < 1) root.sawLivelyFade = true
                return
            }
            if (root.phase === 20) {
                var popup = root.find(browser, "wallpaper-settings-popover")
                if (popup.sectionOpacity > 0 && popup.sectionOpacity < 1) root.sawSettingsFade = true
                if (popup.panelHeight > 480 && popup.panelHeight < Math.min(680, popup.availableHeight)) {
                    if (!root.sawSettingsMorph) root.capture("settings-morph")
                    root.sawSettingsMorph = true
                }
                return
            }
            root.contained()
            if (root.phase === 12) {
                var pill = root.find(browser, "wallpaper-quality-indicator")
                if (!root.sawQualityMorph && Math.abs(pill.x - root.qualityStart) > 1 && Math.abs(pill.x - root.qualityTarget.mapToItem(pill.parent, 0, 0).x) > 1) {
                    root.sawQualityMorph = true
                    root.capture("quality-morph")
                }
            }
        }
    }
    function capture(name) {
        var directory = Quickshell.env("HAKUSPACE_WALLPAPER_ARTIFACT_DIR")
        if (!directory) return
        capturing = true
        // Native capture includes Qt's popup overlay outside the browser item.
        if (name === "cache-local-tooltip" && Quickshell.env("QT_QPA_PLATFORM") === "wayland") {
            screenshot.command = ["grim", "-o", testWindow.screen.name, directory + "/" + name + ".png"]
            screenshot.running = true
            return
        }
        check(browser.grabToImage(result => {
            root.check(result.saveToFile(directory + "/" + name + ".png"), "save screenshot")
            root.capturing = false
        }), "request screenshot")
    }
    Process {
        id: screenshot
        onExited: code => { root.check(code === 0, "capture native popup overlay"); root.capturing = false }
    }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            root.check(++ticks < 600, "timeout")
            if (!WallpaperSettingsStore.ready || !ShellSettingsStore.ready || capturing) return
            var popup = find(browser, "wallpaper-settings-popover")
            if (popup.progress > 0 && popup.progress < 1) {
                root.check(popup.editorLoaded, "editor retained during slide")
                if (browser.settingsSection) sawOpen = true
                else sawClose = true
            }
            if (phase === -2) {
                checkCategories()
                categoryItems = WallpaperLibrary.items
                phase = -1
            } else if (phase === -1) {
                if (++settle < 4) return
                if (!categoryPillSettled()) return
                if (categoryCase < 2) {
                    if (!categoryMorphPending) {
                        var pill = find(browser, "wallpaper-category-indicator")
                        categoryStartX = pill.x
                        categoryStartWidth = pill.width
                        sawCategoryMorph = false
                        categoryMorphPending = true
                        WallpaperLibrary.setCategory("Architecture-and-Minimal-Monochrome")
                        return
                    }
                    root.check(sawCategoryMorph, "category pill morphs position and width in " + browser.presentation)
                    categoryMorphPending = false
                }
                checkCategoryGeometry()
                if (++categoryCase < 8) {
                    if (categoryCase === 4)
                        WallpaperLibrary.items = categoryItems.filter(item => !item.category || item.category === "Anime")
                    if (categoryCase === 6) browser.filter = "video"
                    browser.presentation = categoryCase % 2 ? "workspace" : "quick"
                    browser.width = categoryCase % 4 < 2 ? 1024 : 1920
                    WallpaperLibrary.setCategory("")
                    settle = 0
                    return
                }
                if (Quickshell.env("QT_QPA_PLATFORM") === "wayland") {
                    WallpaperLibrary.items = categoryItems
                    browser.presentation = "quick"
                    browser.filter = "video"
                    find(browser, "wallpaper-category-").forceActiveFocus()
                    categoryKeyboard.write("key 15\nkey 28\n")
                    phase = -3
                    return
                }
                WallpaperLibrary.items = []
                browser.presentation = "workspace"
                phase = 0
            } else if (phase === -3) {
                if (WallpaperLibrary.activeCategory !== "Anime") return
                root.check(!WallpaperService.busy && browser.selected.kind === "video", "Tab and Enter select category without applying")
                find(browser, "wallpaper-category-").forceActiveFocus()
                categoryKeyboard.write("key 57\n")
                phase = -4
            } else if (phase === -4) {
                if (WallpaperLibrary.activeCategory !== "") return
                root.check(!WallpaperService.busy, "Space selects All without applying")
                categoryKeyboard.write("key 106 4\n")
                phase = -5
            } else if (phase === -5) {
                if (browser.filter !== "static") return
                root.check(WallpaperLibrary.activeCategory === "", "media shortcuts remain available from category controls")
                find(browser, "wallpaper-category-").forceActiveFocus()
                categoryKeyboard.write("key 106 8\n")
                phase = -10
            } else if (phase === -10) {
                if (WallpaperLibrary.activeCategory !== "Anime") return
                root.check(find(browser, "wallpaper-category-Anime").activeFocus, "Alt category navigation moves focused chip with selection")
                find(browser, "wallpaperSearch").forceActiveFocus()
                browser.query = "mountain"
                categoryKeyboard.write("key 106 8\n".repeat(WallpaperLibrary.categories.length + 1))
                settle = 0
                phase = -11
            } else if (phase === -11) {
                if (WallpaperLibrary.activeCategory !== WallpaperLibrary.categories[WallpaperLibrary.categories.length - 1]) return
                root.check(browser.filter === "static" && browser.query === "mountain" && !WallpaperService.busy,
                    "Alt from search stops at the last category without changing media, search or current wallpaper")
                root.check(!find(browser, "wallpaper-next-category").enabled, "next category arrow disables at the final tab")
                // Wait for the selected-chip positioning timer to settle before checking its bounds.
                if (++settle < 4) return
                var chip = find(browser, "wallpaper-category-" + WallpaperLibrary.activeCategory)
                var lane = find(browser, "wallpaper-category-lane")
                var viewport = find(lane, "wallpaper-category-scroll")
                var position = chip.mapToItem(viewport, 0, 0)
                root.check(position.x >= -0.5 && position.x + chip.width <= viewport.width + 0.5,
                    "Alt navigation reveals an overflow category")
                categoryKeyboard.write("key 105 8\n".repeat(WallpaperLibrary.categories.length + 1))
                phase = -12
            } else if (phase === -12) {
                if (WallpaperLibrary.activeCategory !== "") return
                root.check(!find(browser, "wallpaper-prev-category").enabled && !WallpaperService.busy,
                    "repeated Alt-left stops at All and disables the previous arrow")
                browser.query = ""
                WallpaperLibrary.setCategory("")
                // Return focus from the search probe before the existing card-navigation checks.
                find(browser, "wallpaperReel").forceActiveFocus()
                WallpaperLibrary.refresh()
                phase = -6
            } else if (phase === -6) {
                if (WallpaperLibrary.loading) return
                root.check(WallpaperLibrary.categories.includes("RuntimeCategory")
                    && !WallpaperLibrary.categories.includes("Nested"), "real refresh discovers only first-level media")
                root.check([WallpaperLibrary.staticCategories, WallpaperLibrary.videoCategories].every(categories =>
                    !categories.includes(".HiddenCategory") && !categories.includes(".thumbnails")
                    && !categories.includes("WrongMedia") && categories.every(category => !category.startsWith("."))),
                    "real backend excludes hidden categories and wrong-root media for both kinds")
                root.check(WallpaperLibrary.items.every(item => !item.category.startsWith(".")
                    && !item.path.includes("/.HiddenCategory/") && !item.path.includes("/.thumbnails/")
                    && !item.path.includes("/WrongMedia/")), "All contains no hidden or wrong-root records")
                WallpaperLibrary.setCategory("RuntimeCategory")
                root.check(browser.filteredItems.length === 1 && browser.selected.category === "RuntimeCategory", "real category selects its file")
                WallpaperLibrary.refresh()
                phase = -7
            } else if (phase === -7) {
                if (WallpaperLibrary.loading) return
                root.check(WallpaperLibrary.activeCategory === "RuntimeCategory"
                    && browser.selected.category === "RuntimeCategory", "real refresh retains category and selection")
                categoryFilesystem.running = true
                phase = -9
            } else if (phase === -8) {
                if (WallpaperLibrary.loading || categoryFilesystem.running) return
                root.check(WallpaperLibrary.activeCategory === "" && WallpaperLibrary.categories.includes("RuntimeRenamed")
                    && !WallpaperLibrary.categories.includes("RuntimeCategory") && !!browser.selected,
                    "renamed folder refresh regenerates categories and falls back safely")
                browser.presentation = "workspace"
                phase = 0
            } else if (phase === 0) {
                Theme.fontFamily = "monospace"
                var records = []
                for (var kind of ["static", "video"]) {
                    for (var i = 0; i < 5; ++i) records.push({path: kind === "static" && i === 0 ? Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/preview.png" : kind + i, kind: kind,
                        label: "Wallpaper 🌸 Tiếng Việt · a very long filename repeated for bounded title testing " + i,
                        metadata: kind === "video" ? {width: 3840, height: 2160, fps: 59.94, fileSize: 15728640, codec: "h264", durationMs: 65500} : null,
                        thumbnail: Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/preview.png"})
                }
                WallpaperLibrary.items = records
                WallpaperLibrary.initialized = true
                phase = 1
            } else if (phase === 1) {
                if (index >= cases.length) {
                    root.check(sawLivelyFade, "Lively controls fade between active and dimmed states")
                    browser.filter = "static"
                    WallpaperLibrary.selectIndex(0)
                    UiState.wallpaperPresentation = "workspace"
                    UiState.activePanel = "wallpaper"
                    find(browser, "wallpaper-title-tooltip").active = true
                    phase = 14
                    return
                }
                browser.width = cases[index][0]
                Theme.fontSize = cases[index][1]
                browser.filter = cases[index][2]
                settle = 0
                phase = 2
            } else if (phase === 2) {
                if (++settle < 8 || !browser.openingReady) return
                var title = find(browser, "wallpaper-selected-title")
                root.check(title.width >= 60 && Math.abs(title.x + title.width / 2 - browser.width / 2) < 1, "name remains centered and visible: " + JSON.stringify({case: cases[index], width:title.width, x:title.x}))
                root.check(Array.from(title.text).length <= 48 && title.text.endsWith("…"), "Unicode title has a bounded character count")
                labels(browser.topInputItem, title)
                var lively = browser.filter === "video"
                var metadataTip = find(browser, "wallpaper-title-tooltip")
                root.check(metadataTip.text === browser.selectedTooltip && !metadataTip.text.includes("very long filename"), "name tooltip displays metadata instead of repeating the title")
                if (lively) {
                    for (var detail of ["3840 × 2160", "59.94 FPS", "15 MiB", "H264", "1:06", "Playback quality:"])
                        root.check(metadataTip.text.includes(detail), "video metadata: " + detail)
                }
                var group = find(browser, "wallpaper-lively-controls")
                root.check(group.visible && group.enabled === lively && group.opacity === (lively ? 1 : 0.45), "lively controls stay visible but dim and lock on images")
                for (var name of ["wallpaper-playback", "wallpaper-cache"])
                    root.check(find(browser, name).visible && find(browser, name).enabled === lively, "lively action state: " + name)
                var quality = find(browser, "wallpaper-video-quality")
                root.check(quality.visible === (browser.width >= 1440) && quality.enabled === lively, "quality visibility and disabled state")
                for (var name of ["wallpaper-settings", "wallpaper-close", "wallpaper-apply"])
                    root.check(find(browser, name).enabled, "general action remains available on images: " + name)
                var mode = find(browser, "wallpaper-mode-label")
                root.check(mode.text === (lively ? "Lively Wallpaper" : "Image Wallpaper"), "mode caption is explicit")
                var badge = find(browser, "wallpaper-mode-badge")
                var search = find(browser, "wallpaperSearch")
                root.check(mode.width + 0.5 >= mode.implicitWidth && mode.mapToItem(browser, mode.width, 0).x + badge.parent.spacing <= search.mapToItem(browser, 0, 0).x + 0.5,
                    "mode caption fits before search: " + JSON.stringify({modeWidth:mode.width,natural:mode.implicitWidth,modeEnd:mode.mapToItem(browser,mode.width,0).x,searchX:search.mapToItem(browser,0,0).x}))
                if (index % 2 === 0) {
                    modeBadgeWidth = badge.width
                    searchStart = search.mapToItem(browser, 0, 0).x
                    leftToolsWidth = badge.parent.width
                } else root.check(badge.width === modeBadgeWidth && search.mapToItem(browser, 0, 0).x === searchStart
                    && badge.parent.width === leftToolsWidth, "media tab does not shift the mode label or left toolbar")
                root.check(find(browser, "wallpaper-mode-icon").font.family === "JetBrainsMono Nerd Font", "dedicated Nerd Font icon")
                for (var name of ["wallpaper-shuffle", "wallpaper-refresh"])
                    root.check(find(browser, name).caption.length > 0 && find(browser, name).icon.length > 0 && find(browser, name).showTooltip, "library button has a visible label and tooltip")
                root.check(find(browser, "wallpaper-mode-tooltip").target === badge && badge.wallpaperTooltipTarget
                    && find(browser, "wallpaper-search-tooltip").target === search && search.wallpaperTooltipTarget,
                    "mode and search use workspace tooltips")
                for (var name of ["wallpaper-quality-original", "wallpaper-save-preferences", "wallpaper-playback", "wallpaper-cache",
                    "wallpaper-settings", "wallpaper-close", "wallpaper-apply"])
                    root.check(find(browser, name).showTooltip, "toolbar action has a tooltip: " + name)
                var left = find(browser, "wallpaper-title-left-separator")
                var right = find(browser, "wallpaper-title-right-separator")
                root.check(Math.abs(left.x + left.width / 2 + right.x + right.width / 2 - browser.width) < 0.1, "title separators are symmetric about the screen center: " + JSON.stringify({left:left.x,right:right.x,width:browser.width,titleX:title.x,titleWidth:title.width}))
                root.check(find(browser, "wallpaper-tooltip-layer").minimumTooltipWidth === right.x - (left.x + left.width),
                    "metadata tooltip requests the full separator span: " + JSON.stringify({requested:find(browser, "wallpaper-tooltip-layer").minimumTooltipWidth, left:left.x, right:right.x, title:title.width}))
                if (!lively) {
                    var profile = WallpaperSettingsStore.values.playback.profile
                    find(browser, "wallpaper-quality-original").clicked()
                    find(browser, "wallpaper-cache").clicked()
                    root.check(WallpaperSettingsStore.values.playback.profile === profile && browser.settingsSection === "", "disabled lively actions cannot mutate image mode")
                }
                var tabs = find(browser, "wallpaper-media-tabs")
                root.check(tabs.width >= 320 && tabs.height >= 44, "media tabs have larger hitboxes")
                var lane = find(browser, "wallpaper-kind-static").parent
                root.check(lane.radius === 0 && lane.color.a === 0, "media tabs have no pill background or upper radius")
                root.check(find(browser, "wallpaper-type-top-border").height === 2, "selected media tab has a top border")
                var body = find(browser, "wallpaperBottomPanel")
                var reel = find(browser, "wallpaperReel")
                body.containsMode = Shape.FillContains
                for (var corner of [[0, 0], [tabs.width, 0], [0, tabs.height], [tabs.width, tabs.height]])
                    root.check(body.contains(body.mapFromItem(tabs, corner[0], corner[1])), "media tabs stay inside the trapezoid")
                root.check(reel.currentItem.mapToItem(browser, 0, 0).y >= tabs.y + tabs.height + browser.panelPadding - 1, "wallpapers sit below tabs with padding")
                capture("layout-" + index)
                ++index; phase = 1
            } else if (phase === 14) {
                if (!browser.selectedMetadata.width) return
                var metadata = browser.selectedMetadata
                root.check(metadata.fileSize > 0 && metadata.codec === "png" && metadata.fps === 0, "image metadata comes from the original source")
                root.check(browser.selectedTooltip.includes("Original: " + metadata.width + " × " + metadata.height)
                    && browser.selectedTooltip.includes("Size:") && !browser.selectedTooltip.includes("FPS")
                    && !browser.selectedTooltip.includes("Playback quality:"), "image tooltip includes dimensions and size without video options")
                settle = 0; phase = 15
            } else if (phase === 15) {
                if (++settle < 20 || !TooltipManager.shown) return
                root.check(TooltipManager.current.text === browser.selectedTooltip, "visible tooltip updates to the probed image metadata")
                var tooltipLayer = find(browser, "wallpaper-tooltip-layer")
                root.check(Math.abs((tooltipLayer.menuStart + tooltipLayer.menuEnd) / 2 - browser.width / 2) < 0.5, "metadata tooltip is centered on the bounded title box")
                var leftDivider = find(browser, "wallpaper-title-left-separator")
                var rightDivider = find(browser, "wallpaper-title-right-separator")
                root.check(Math.abs((tooltipLayer.menuEnd - tooltipLayer.menuStart) - (rightDivider.x - leftDivider.x - leftDivider.width)) < 0.5,
                    "metadata tooltip fills the space between title separators")
                capture("metadata-image")
                phase = 17
            } else if (phase === 17) {
                WallpaperLibrary.selectIndex(1)
                phase = 16
            } else if (phase === 16) {
                if (!browser.selectedTooltip.includes("Metadata unavailable")) return
                root.check(!browser.selectedMetadata.width && !browser.selectedTooltip.includes("Original:"), "failed source probe cannot display the previous image metadata")
                find(browser, "wallpaper-title-tooltip").active = false
                TooltipManager.dismiss()
                UiState.wallpaperPresentation = "closed"
                phase = 9
            } else if (phase === 9) {
                browser.width = 1920; Theme.fontSize = 14; browser.filter = "video"
                WallpaperLibrary.move(1)
                settle = 0; phase = 10
            } else if (phase === 10) {
                contained()
                if (++settle < 7) return
                root.check(curveFrames > 0, "curved motion was sampled")
                settle = 0; phase = 11
            } else if (phase === 11) {
                if (++settle < 12) return
                var pill = find(browser, "wallpaper-quality-indicator")
                originalAccent = Theme.accentDark
                Theme.accentDark = "#d8b530"
                root.check(pill.color.toString() === String(Theme.accent), "quality pill follows a live accent change")
                qualityStart = pill.x
                var value = WallpaperSettingsStore.values.playback.profile === "original" ? "screen" : "original"
                qualityTarget = find(browser, "wallpaper-quality-" + value)
                qualityTarget.clicked()
                phase = 12
            } else if (phase === 12) {
                var pill = find(browser, "wallpaper-quality-indicator")
                var target = qualityTarget.mapToItem(pill.parent, 0, 0)
                if (Math.abs(pill.x - target.x) > 0.5 || Math.abs(pill.width - qualityTarget.width) > 0.5) return
                root.check(sawQualityMorph, "quality selection morphs between actual button bounds")
                Theme.accentDark = originalAccent
                WallpaperSettingsStore.discard()
                UiState.wallpaperPresentation = "workspace"
                UiState.activePanel = "wallpaper"
                TooltipManager.show(find(browser, "wallpaper-settings"), "Wallpaper settings")
                phase = 13
            } else if (phase === 13) {
                if (!TooltipManager.shown) return
                var tooltip = find(browser, "wallpaper-tooltip-layer")
                root.check(!!tooltip && tooltip.horizontalPadding === 22 && tooltip.visible, "workspace uses the TopBar tooltip renderer")
                TooltipManager.dismiss()
                UiState.wallpaperPresentation = "quick"
                TooltipManager.show(find(browser, "wallpaper-settings"), "blocked")
                root.check(!TooltipManager.current, "quick mode does not opt into workspace tooltips")
                UiState.wallpaperPresentation = "workspace"
                TooltipManager.show(browser, "blocked")
                root.check(!TooltipManager.current, "unrelated targets stay blocked while workspace owns the shell")
                UiState.activePanel = ""
                TooltipManager.show(browser, "normal topbar context")
                root.check(TooltipManager.current.target === browser, "normal TopBar tooltip context remains supported")
                TooltipManager.dismiss()
                UiState.wallpaperPresentation = "closed"
                phase = 3
            } else if (phase === 3) {
                browser.width = 1920; Theme.fontSize = 14; browser.filter = "video"
                browser.settingsSection = "cache"
                phase = 4
            } else if (phase === 4) {
                if (popup.progress !== 1 || popup.animating || WallpaperService.cacheBusy) return
                WallpaperService.cacheBytes = 20 * 2097152
                WallpaperService.cacheTotalBytes = WallpaperService.cacheBytes + 1048576
                WallpaperService.cachePreviewBytes = 1048576
                WallpaperService.cacheEntries = Array.from({length: 20}, (_, index) => ({
                    path: "/videos/wallpaper-" + index + ".mp4", proxyPath: "/cache/" + index + ".mp4",
                    label: "Wallpaper 🌸 · a very long cached video name repeated to check elision " + index,
                    profile: "low-memory", bytes: 2097152, active: index === 0, pending: false, sourceChanged: false,
                    render: {width: 1280, height: 720, fps: 24}}))
                phase = 28
            } else if (phase === 28) {
                var list = find(popup, "wallpaper-cache-list")
                if (!list.currentItem) return
                root.check(list.count === 20 && list.height <= 4 * (list.rowHeight + list.spacing) && list.contentHeight > list.height,
                    "long cache inventories stay in a bounded scrollable list")
                root.check(find(popup, "wallpaper-cache-usage").text.includes("40 MiB") && find(popup, "wallpaper-cache-usage").text.includes("20 prepared copies"), "cache usage and prepared count are visible")
                var title = find(list.currentItem, "wallpaper-cache-entry-title")
                var detail = find(list.currentItem, "wallpaper-cache-entry-details")
                root.check(title.width > 0 && title.x + title.width <= title.parent.width + 0.5 && title.elide === Text.ElideRight,
                    "long source names fit beside their build status")
                root.check(detail.text.includes("720p") && detail.text.includes("1280 × 720") && detail.text.includes("24 FPS") && detail.text.includes("2 MiB"),
                    "built copy shows profile, resolution, frame rate and disk size")
                root.check(find(list.currentItem, "wallpaper-cache-entry-state").text === "In use", "active cached copy is marked as in use")
                var viewport = find(popup, "wallpaper-settings-scroll")
                viewport.contentY = Math.min(list.mapToItem(viewport.contentItem, 0, 0).y, viewport.contentHeight - viewport.height)
                capture("cache-open")
                phase = 29
            } else if (phase === 29) {
                cacheDraft = WallpaperSettingsStore.values.proxy.maxCacheMiB + 64
                WallpaperSettingsStore.setValue("proxy", "maxCacheMiB", cacheDraft)
                closingEditor = find(popup, "wallpaper-settings-scroll")
                closingPage = closingEditor.parent.parent
                browser.settingsSection = ""
                phase = 5
            } else if (phase === 5) {
                if (popup.progress === 1) return
                root.check(popup.progress > 0 && popup.editorLoaded, "cache closes with a slide")
                var progress = popup.progress
                browser.settingsSection = "cache"
                root.check(popup.progress === progress && find(popup, "wallpaper-settings-scroll") === closingEditor, "cache close reverses without replacing its editor")
                phase = 6
            } else if (phase === 6) {
                if (popup.progress !== 1 || popup.animating) return
                browser.settingsSection = "playback"
                phase = 20
            } else if (phase === 20) {
                if (popup.animating) return
                root.check(popup.displayedSection === "playback" && sawSettingsMorph && sawSettingsFade, "section switch morphs the panel height and fades its content")
                root.check(closingPage.sectionFilter === "playback" && closingPage.visible && WallpaperSettingsStore.values.proxy.maxCacheMiB === cacheDraft, "section morph retains the settings page and cache draft")
                browser.settingsSection = "cache"
                phase = 21
            } else if (phase === 21) {
                if (popup.animating) return
                root.check(popup.displayedSection === "cache" && popup.panelHeight === 480, "cache morph settles at its own height")
                var cacheButton = find(popup, "wallpaper-clear-unused")
                var localTooltip = find(cacheButton, "wallpaper-settings-tooltip-loader").item
                root.check(cacheButton.useSettingsTooltip && !cacheButton.wallpaperTooltipTarget && !!localTooltip, "cache action owns a Settings tooltip")
                UiState.wallpaperPresentation = "workspace"; UiState.activePanel = "wallpaper"
                TooltipManager.show(cacheButton, "blocked cache flare")
                root.check(!TooltipManager.current, "cache popup actions do not route through the TopBar flare")
                localTooltip.immediate = true; localTooltip.active = true
                settle = 0; phase = 22
            } else if (phase === 22) {
                if (++settle < 3) return
                var localTooltip = find(find(popup, "wallpaper-clear-unused"), "wallpaper-settings-tooltip-loader").item
                root.check(localTooltip.visible && !TooltipManager.current, "local cache tooltip is visible without a TopBar flare")
                capture("cache-local-tooltip")
                phase = 23
            } else if (phase === 23) {
                find(find(popup, "wallpaper-clear-unused"), "wallpaper-settings-tooltip-loader").item.active = false
                UiState.wallpaperPresentation = "closed"
                browser.filter = "static"
                root.check(browser.settingsSection === "", "images closes lively-only settings")
                phase = 7
            } else if (phase === 7) {
                if (popup.progress !== 0 || popup.editorLoaded || popup.displayedSection) return
                root.check(sawOpen && sawClose, "both menu slide directions were observed")
                root.check(WallpaperSettingsStore.values.proxy.maxCacheMiB === cacheDraft, "switching back to images preserves the cache draft")
                WallpaperSettingsStore.discard()
                browser.presentation = "quick"
                WallpaperLibrary.selectIndex(0)
                settle = 0; repeatedMoves = 0; phase = 24
            } else if (phase === 24 || phase === 26) {
                var reel = find(browser, "wallpaperReel")
                if (++settle <= 15) {
                    var previous = WallpaperLibrary.selectedIndex
                    var direction = settle % 4 === 0 ? -1 : 1
                    browser.handleShortcut({key: direction > 0 ? Qt.Key_Right : Qt.Key_Left, modifiers: Qt.NoModifier, accepted: false})
                    root.check(WallpaperLibrary.selectedIndex === (previous + direction + browser.filteredItems.length) % browser.filteredItems.length,
                        "every rapid arrow selects immediately, including direction changes")
                    ++repeatedMoves
                    return
                }
                root.check(repeatedMoves === 15, "no rapid navigation is discarded in " + browser.presentation)
                finalSelection = WallpaperLibrary.selectedIndex
                settle = 0; phase = phase === 24 ? 25 : 27
            } else if (phase === 25 || phase === 27) {
                if (++settle < 10) return
                checkCategoryCentering()
                root.check(WallpaperLibrary.selectedIndex === finalSelection, "finishing motion cannot overwrite the latest requested wallpaper")
                root.check(find(browser, "wallpaperReel").currentIndex === WallpaperLibrary.selectedIndex, "carousel settles on the shared selection")
                root.check(find(browser, "wallpaper-quick-controls").navigationScale === 1, "control bounce returns to its original scale")
                if (phase === 25) {
                    root.check(sawControlCompression && sawControlRebound, "quick search and tabs compress and rebound on navigation")
                    browser.presentation = "workspace"
                    WallpaperLibrary.selectIndex(0)
                    settle = 0; repeatedMoves = 0; phase = 26
                    return
                }
                // Different library sizes expose stale PathView offsets after a tab swap.
                var records = []
                for (var kind of ["static", "video"]) {
                    for (var i = 0; i < (kind === "static" ? 9 : 6); ++i)
                        records.push({path: kind + i, kind: kind, label: kind + i,
                            thumbnail: Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/preview.png"})
                }
                WallpaperLibrary.items = records
                browser.presentation = "quick"
                tabMove = 0; settle = 0; phase = 30
            } else if (phase === 30) {
                var reel = find(browser, "wallpaperReel")
                if (++settle < 6) return
                root.check(find(browser, "wallpaper-kind-video").text === "Lively", "both modes label the video tab Lively")
                root.check(reel.currentIndex === WallpaperLibrary.selectedIndex && !!reel.currentItem
                    && reel.currentItem.wallpaper.path === WallpaperLibrary.selectedPath
                    && Math.abs(reel.currentItem.x + reel.currentItem.width / 2 - reel.width / 2) < 1,
                    "selected wallpaper is centered after tab navigation: " + JSON.stringify({mode: browser.presentation,
                        step: tabMove, selected: WallpaperLibrary.selectedIndex, current: reel.currentIndex, offset: reel.offset,
                        x: reel.currentItem ? reel.currentItem.x + reel.currentItem.width / 2 : -1, center: reel.width / 2}))
                if (tabMove === 16) {
                    if (browser.presentation === "quick") {
                        browser.presentation = "workspace"
                        tabMove = 0
                    } else {
                        browser.reveal = 0
                        phase = 8
                        return
                    }
                }
                var operation = tabMove++ % 4
                if (operation === 0) {
                    WallpaperLibrary.selectIndex(4)
                    browser.filter = "video"
                    browser.move(1)
                    root.check(WallpaperLibrary.selectedIndex === 1, "navigation immediately after opening Lively")
                } else if (operation === 1) {
                    browser.filter = "static"
                    browser.move(-1)
                    root.check(WallpaperLibrary.selectedIndex === 8, "navigation immediately after returning to Images")
                } else {
                    var previous = WallpaperLibrary.selectedIndex
                    var direction = operation === 2 ? 1 : -1
                    browser.move(direction)
                    root.check(WallpaperLibrary.selectedIndex === (previous + direction + reel.count) % reel.count,
                        "tab switching preserves immediate arrow direction")
                }
                settle = 0
            } else if (phase === 8) {
                var tabs = find(browser, "wallpaper-media-tabs")
                root.check(browser.topInputItem.y + browser.topInputItem.height <= 0 && tabs.y >= browser.height, "both headers slide fully offscreen")
                console.info("Wallpaper workspace checks passed")
                Qt.quit()
            }
        }
    }
}
