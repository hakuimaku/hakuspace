import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper
import "components/settings" as Settings

ShellRoot {
    id: root
    // Drive the real browser and settings store against disposable fixture media.
    property int phase: 0
    property int ticks: 0
    property int motionTicks: 0
    property Item motionButton: null
    property int cachePhase: 0
    property int expansionPhase: 0
    property real previousSidebarY: 0
    property real revealWindowWidth: 0
    property real revealWindowHeight: 0
    property string imageToken: ""
    readonly property string fixture: Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE")
    // Rebuild the same browser twice to exercise Quickshell's live-reload type cache.
    PersistentProperties {
        id: reloadMemory
        reloadableId: "wallpaper-browser-reload-regression"
        property int reloadCount: 0
        onLoaded: if (reloadCount > 0) root.phase = 100
    }
    FloatingWindow {
        visible: true
        id: window
        implicitWidth: settingsLayout.visible ? 1000 : 520; implicitHeight: 1080
        Wallpaper.WallpaperBrowser { id: browser; anchors.fill: parent }
        Item {
            id: settingsLayout
            anchors.fill: parent
            visible: false
            Settings.SettingsTopBar {
                id: navigation
                width: parent.width
                height: implicitHeight
                selected: "Wallpaper"
                onSelectedRequested: domain => selected = domain
            }
            Settings.SettingsSidebar { id: sections; width: 200; y: navigation.height; height: parent.height - y; page: settings }
            Settings.WallpaperSettingsPage { id: settings; x: sections.width; y: navigation.height; width: parent.width - x; height: parent.height - y }
        }
    }
    // Images apply through awww; the separate surface harness decodes native video.
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper browser failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Locate a real filter control without depending on the header's layout nesting.
    function findItem(parent, name) {
        if (parent.objectName === name) return parent
        for (var child of parent.children || []) {
            var found = findItem(child, name)
            if (found) return found
        }
        return null
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 250, "timeout " + WallpaperService.error + " " + WallpaperSettingsStore.error)
            if (phase >= 100) {
                if (!browser.interactionReady || browser.items.length !== 4) return
                var reel = browser.children.find(item => item.objectName === "wallpaperReel")
                if (phase !== 102 && (!reel.currentItem || reel.currentItem.opacity <= 0)) return
                if (phase === 100) {
                    root.check(Number.isFinite(reel.currentItem.scale) && Number.isFinite(reel.currentItem.z), "reload initializes path attributes")
                    browser.filter = "static"
                } else if (phase === 101) {
                    root.check(reel.count === 2, "reload filter rebuilds delegates")
                    browser.query = "missing-wallpaper"
                } else if (phase === 102) {
                    root.check(reel.count === 0, "empty filter removes delegates")
                    browser.query = ""
                    browser.filter = "static"
                } else {
                    root.check(reel.count === 2 && Number.isFinite(reel.currentItem.scale) && Number.isFinite(reel.currentItem.z), "recreated delegates retain valid transforms")
                    if (reloadMemory.reloadCount < 2) { reloadMemory.reloadCount++; Quickshell.reload(false); return }
                    console.info("Wallpaper browser reload checks passed")
                    Qt.quit()
                }
                root.phase++
                return
            }
            if (phase === 24) return
            if (phase >= 20) {
                if (++root.motionTicks < 7) return
                root.motionTicks = 0
                var pill = root.findItem(sections, "settings-section-indicator")
                var scroll = root.findItem(settings, "wallpaper-settings-scroll")
                if (phase === 20) {
                    root.check(settings.activeSection === "Proxy cache" && pill.targetItem.modelData === "Proxy cache" && pill.y > root.previousSidebarY + 1, "wallpaper sidebar pill moves to Proxy cache")
                    root.previousSidebarY = pill.y
                    settings.scrollToSection("Browser")
                } else if (phase === 21) {
                    root.check(settings.activeSection === "Browser" && pill.targetItem.modelData === "Browser" && pill.y > root.previousSidebarY + 1, "final wallpaper section can align and move the sidebar pill")
                    root.check(Math.abs(scroll.contentY - settings.sectionCards[2].y) < 1, "last section scrolls to the viewport top")
                    navigation.selected = "Info"
                } else if (phase === 22) {
                    var strip = root.findItem(navigation, "settings-domain-strip")
                    var indicator = root.findItem(navigation, "settings-domain-indicator")
                    root.check(navigation.domains[navigation.domains.length - 1] === "Info" && indicator.targetIndex === 4, "Info stays last and uses the final nav pill")
                    root.check(strip.width > 450 && indicator.width > 85.2 && strip.height === 40, "navigation pills are wider and taller")
                    navigation.selected = "Wallpaper"
                    settings.scrollToSection("Playback")
                } else {
                    root.check(settings.activeSection === "Playback" && pill.targetItem.modelData === "Playback", "sidebar returns to Playback")
                    console.info("Wallpaper settings sidebar/nav checks passed")
                    var artifact = Quickshell.env("HAKUSPACE_WALLPAPER_ARTIFACT_DIR")
                    if (artifact) {
                        root.phase = 24
                        root.check(settingsLayout.grabToImage(result => {
                            root.check(result.saveToFile(artifact + "/wallpaper-settings.png"), "save settled settings capture")
                            reloadMemory.reloadCount = 1
                            Quickshell.reload(false)
                        }), "capture settled settings")
                    } else { reloadMemory.reloadCount = 1; Quickshell.reload(false) }
                    return
                }
                root.phase++
                return
            }
            if (phase >= 7) {
                if (++root.motionTicks < 5) return
                root.motionTicks = 0
                var button = root.motionButton
                if (phase === 7) {
                    root.check(button.horizontalScale > 1 && Math.abs(button.radius - button.height / 2) < 0.1, "hover morph expands and rounds button")
                    root.check(button.hoverColor.toString() === button.idleColor.toString(), "hover retains the idle background")
                    button.externalPressed = true
                    if (settings.visible) {
                        WallpaperSettingsStore.setValue("playback", "profile", "original")
                        root.check(root.findItem(settings, "wallpaper-setting-indicator-profile").targetIndex === 2, "settings selection tracks the draft")
                    }
                } else if (phase === 8) {
                    root.check(button.horizontalScale < 1 && Math.abs(button.radius - 6) < 0.1, "press morph contracts button")
                    button.externalPressed = false
                } else if (phase === 9) {
                    root.check(button.horizontalScale > 1 && Math.abs(button.radius - button.height / 2) < 0.1, "release restores hover shape")
                    button.externalHovered = false
                } else {
                    root.check(Math.abs(button.horizontalScale - 1) < 0.001 && Math.abs(button.radius - 10) < 0.1 && button.border.width === 0 && button.expandedVisual, "idle restores borderless shape")
                    button.interactive = true
                    console.info("Wallpaper button morph checks passed")
                    if (root.motionButton.objectName === "wallpaper-kind-static") {
                        browser.visible = false
                        settingsLayout.visible = true
                        root.motionButton = root.findItem(settings, "wallpaper-setting-profile-screen")
                        root.check(!!root.motionButton, "settings uses the wallpaper morph control")
                        root.motionButton.interactive = false
                        root.motionButton.externalHovered = true
                        root.phase = 7
                        return
                    }
                    WallpaperSettingsStore.discard()
                    root.previousSidebarY = root.findItem(sections, "settings-section-indicator").y
                    settings.scrollToSection("Proxy cache")
                    root.phase = 20
                    return
                }
                root.phase++
                return
            }
            if (phase === 0) {
                if (!WallpaperSettingsStore.ready || !browser.interactionReady || browser.items.length < 4) return
                if (root.expansionPhase === 0) {
                    root.revealWindowWidth = window.width
                    root.revealWindowHeight = window.height
                    browser.filter = "video"
                    root.expansionPhase++
                    return
                }
                if (root.expansionPhase === 1) {
                    var reveal = root.findItem(browser, "wallpaper-quality-reveal")
                    root.check(browser.qualityReveal > 0 && browser.qualityReveal < 1 && reveal.height > 0 && reveal.height < 98, "Videos expands quality frame over multiple frames")
                    root.check(window.width === root.revealWindowWidth && window.height === root.revealWindowHeight, "quality reveal keeps drawing-window geometry stable")
                    browser.filter = "static"
                    root.expansionPhase++
                    return
                }
                if (root.expansionPhase === 2) { browser.filter = "video"; root.expansionPhase++; return }
                if (root.expansionPhase === 3) {
                    if (Math.abs(browser.qualityReveal - 1) > 0.001) return
                    root.check(root.findItem(browser, "wallpaper-quality").visible, "Videos settles with quality controls visible")
                    browser.filter = "static"
                    root.expansionPhase++
                    return
                }
                if (browser.qualityReveal > 0.001) return
                root.check(browser.items.length === 4, "discovery")
                root.check(browser.profile === "screen", "Screen is the default browser quality")
                root.check(browser.kinds.length === 2 && browser.filter === "static", "two tabs default to Images")
                root.check(!root.findItem(browser, "wallpaper-quality").visible, "Images hides quality controls")
                browser.filter = "video"
                root.check(browser.filteredItems.length === 2, "video filter")
                browser.filter = "static"
                browser.query = "forest"
                root.check(browser.filteredItems.length === 1, "search")
                root.check(WallpaperService.fileUrl(browser.selected.path).includes("%23"), "filename fragment escaped")
                browser.query = ""
                browser.filter = "static"
                browser.move(1)
                root.check(!WallpaperService.busy, "navigation does not prepare wallpaper")
                WallpaperSettingsStore.setValue("playback", "profile", "original")
                root.check(WallpaperSettingsStore.dirty, "draft dirty")
                WallpaperSettingsStore.discard()
                root.check(!WallpaperSettingsStore.dirty && WallpaperSettingsStore.values.playback.profile === "screen", "discard")
                WallpaperSettingsStore.setValue("proxy", "buildPolicy", "manual")
                WallpaperSettingsStore.apply()
            } else if (phase === 1) {
                if (WallpaperSettingsStore.saving) return
                root.check(!WallpaperSettingsStore.dirty && WallpaperSettingsStore.savedValues.proxy.buildPolicy === "manual", "apply persisted")
                root.check(WallpaperService.select(root.fixture + "/Videos/Wallpapers/clip.mp4", "low-memory", false), "manual select")
            } else if (phase === 2) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.proxyState === "error" && !WallpaperService.current.path, "missing manual proxy keeps current")
                root.check(WallpaperService.select(root.fixture + "/Pictures/Wallpapers/forest # one.png", "low-memory", false), "static select")
            } else if (phase === 3) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.kind === "static", "awww image commits without a native surface")
                root.check(WallpaperService.playbackState === "STOPPED", "image application leaves native preparation state")
                root.imageToken = WallpaperService.current.token
            } else if (phase === 4) {
                if (WallpaperService.busy || WallpaperService.cacheBusy) return
                if (root.cachePhase === 0) {
                    browser.profile = "low-memory"
                    browser.query = "forest"
                    root.findItem(browser, "wallpaper-build-all").clicked()
                    root.check(WallpaperService.cacheMessage === "Building video cache…", "batch build starts despite manual policy and image search")
                    root.cachePhase = 1
                    return
                }
                if (root.cachePhase === 1) {
                    root.check(WallpaperService.cacheMessage === "All videos ready" && WallpaperService.cacheMiB > 0, "batch produces video proxies")
                    root.check(WallpaperService.current.token === root.imageToken, "batch never applies a wallpaper")
                    root.findItem(browser, "wallpaper-clear-cache").clicked()
                    root.cachePhase = 2
                    return
                }
                root.check(WallpaperService.cacheMiB === 0 && WallpaperService.cacheMessage === "Unused video cache cleared", "menu clears unused proxies")
                root.check(WallpaperService.current.token === root.imageToken, "cache clear retains the active image")
                browser.query = ""
                browser.profile = "screen"
                root.check(!!WallpaperService.current.token, "native state committed")
                root.check(settings.canActivate("Reload"), "settings page contract")
                browser.visible = false
            } else if (phase === 5) {
                root.check(!!WallpaperService.current.token, "closing browser preserves renderer state")
                browser.visible = true
            } else if (phase === 6) {
                if (!browser.interactionReady || browser.refreshPending) return
                root.check(browser.items.length === 4, "reopen refresh")
                var typeIndicator = root.findItem(browser, "wallpaper-type-indicator")
                root.check(typeIndicator.targetIndex === 0 && Math.abs(typeIndicator.animatedStartIndex) < 0.01 && Math.abs(typeIndicator.animatedEndIndex - 1) < 0.01, "rapid filter changes keep the selection indicator aligned")
                var artifact = Quickshell.env("HAKUSPACE_WALLPAPER_ARTIFACT_DIR")
                if (artifact) browser.grabToImage(result => result.saveToFile(artifact + "/wallpaper-controls.png"))
                console.info("Wallpaper browser checks passed")
                root.motionButton = root.findItem(browser, "wallpaper-kind-static")
                root.check(!!root.motionButton, "filter morph target exists")
                root.motionButton.interactive = false
                root.motionButton.externalHovered = true
            }
            root.phase++
        }
    }
}
