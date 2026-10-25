import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    // Exercise real component geometry without a compositor or the user's settings.
    property int phase: 0
    property int ticks: 0
    property int index: 0
    property int settle: 0
    property int curveFrames: 0
    property int cacheDraft: 0
    property real qualityStart: 0
    property string originalAccent: ""
    property int repeatedMoves: 0
    property int finalSelection: 0
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
        running: root.phase === 2 || root.phase === 10 || root.phase === 12 || root.phase === 20 || root.phase === 24 || root.phase === 25
        onTriggered: {
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
            root.check(++ticks < 500, "timeout")
            if (!WallpaperSettingsStore.ready || !ShellSettingsStore.ready || capturing) return
            var popup = find(browser, "wallpaper-settings-popover")
            if (popup.progress > 0 && popup.progress < 1) {
                root.check(popup.editorLoaded, "editor retained during slide")
                if (browser.settingsSection) sawOpen = true
                else sawClose = true
            }
            if (phase === 0) {
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
                originalAccent = Theme.accent
                Theme.accent = "#d8b530"
                root.check(pill.color.toString() === Theme.accent, "quality pill follows a live accent change")
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
                Theme.accent = originalAccent
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
                root.check(find(popup, "wallpaper-settings-scroll") === closingEditor, "section morph keeps the same editor and draft")
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
                browser.reveal = 0
                phase = 8
            } else if (phase === 8) {
                var tabs = find(browser, "wallpaper-media-tabs")
                root.check(browser.topInputItem.y + browser.topInputItem.height <= 0 && tabs.y >= browser.height, "both headers slide fully offscreen")
                console.info("Wallpaper workspace checks passed")
                Qt.quit()
            }
        }
    }
}
