import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/wallpaper" as Wallpaper
import "components/settings" as Settings

ShellRoot {
    id: root
    // Exercise picker, preparation and maintenance against private fixture media.
    property int phase: 0
    property int ticks: 0
    property string imageToken: ""
    property int captures: 0
    readonly property string fixture: Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE")
    PersistentProperties {
        id: reloadMemory
        reloadableId: "wallpaper-browser-reload-regression"
        property int reloadCount: 0
        onLoaded: if (reloadCount > 0) root.phase = 100
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: settings.visible ? 1000 : 520
        implicitHeight: 1080
        Wallpaper.WallpaperBrowser { id: browser; anchors.fill: parent; visible: !settings.visible }
        Settings.WallpaperSettingsPage { id: settings; anchors.fill: parent; visible: false; advanced: true }
    }
    // Fail the process with the current preparation error for actionable output.
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper browser failed at " + phase + ": " + message + " " + WallpaperService.error)
        Qt.exit(1)
        throw new Error(message)
    }
    // Locate semantic controls independently of their layout nesting.
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
            root.check(++root.ticks < 350, "timeout")
            if (!WallpaperSettingsStore.ready || WallpaperSettingsStore.loading || WallpaperSettingsStore.saving || root.captures) return
            if (phase >= 100) {
                if (WallpaperService.busy || WallpaperService.cacheBusy || WallpaperService.statusDelay.running
                        || WallpaperService.statusWriter.running || WallpaperService.accent.running || WallpaperService.canceller.running) return
                if (!browser.interactionReady || browser.items.length !== 4) return
                var reel = root.findItem(browser, "wallpaperReel")
                if (phase !== 102 && (!reel.currentItem || reel.currentItem.opacity <= 0)) return
                if (phase === 100) {
                    root.check(Number.isFinite(reel.currentItem.scale) && Number.isFinite(reel.currentItem.z), "reload initializes path attributes")
                    browser.filter = "video"
                } else if (phase === 101) {
                    root.check(reel.count === 2, "reload rebuilds video delegates")
                    browser.query = "missing-wallpaper"
                } else if (phase === 102) {
                    root.check(reel.count === 0, "empty filter removes delegates")
                    browser.query = ""
                    browser.filter = "static"
                } else {
                    root.check(reel.count === 2 && Number.isFinite(reel.currentItem.scale), "reload recreates valid delegates")
                    if (reloadMemory.reloadCount < 2) { ++reloadMemory.reloadCount; Quickshell.reload(false); return }
                    console.info("Wallpaper browser reload checks passed")
                    Qt.quit()
                }
                ++root.phase
                return
            }
            if (phase === 0) {
                if (!browser.interactionReady || browser.items.length !== 4) return
                root.check(browser.profile === "screen" && browser.filter === "static", "saved defaults")
                for (var name of ["wallpaper-quality", "wallpaper-build-all", "wallpaper-clear-cache"])
                    root.check(!root.findItem(browser, name), "maintenance is absent from picker: " + name)
                browser.query = "forest"
                root.check(browser.filteredItems.length === 1 && WallpaperService.fileUrl(browser.selected.path).includes("%23"), "search and escaped filenames")
                root.check(browser.applySelected(), "single Apply action selects the image")
            } else if (phase === 1) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.kind === "static", "image commits through existing renderer API")
                root.imageToken = WallpaperService.current.token
                browser.query = ""
                browser.filter = "video"
                browser.move(1)
                root.check(!WallpaperService.busy, "browsing does not start preparation")
                WallpaperSettingsStore.setValue("playback", "profile", "low-memory")
                root.check(browser.profile === "screen", "unsaved preferences do not leak into picker")
                WallpaperSettingsStore.apply()
            } else if (phase === 2) {
                if (WallpaperService.busy) return
                root.check(browser.profile === "low-memory", "picker follows saved quality")
                root.imageToken = WallpaperService.current.token
                root.check(browser.applySelected(), "Apply automatically prepares video with on-select policy")
            } else if (phase === 3) {
                if (!WallpaperService.candidate.token) return
                root.check(WallpaperService.candidate.kind === "video" && WallpaperService.candidate.proxyPath !== WallpaperService.candidate.path, "automatic preparation produced a smaller video")
                root.check(WallpaperService.current.token === root.imageToken, "image stays committed until video surfaces are ready")
                WallpaperService.fail("Preparation probe complete")
                WallpaperSettingsStore.setValue("proxy", "buildPolicy", "manual")
                WallpaperSettingsStore.apply()
            } else if (phase === 4) {
                if (WallpaperService.busy) return
                settings.visible = true
                root.findItem(settings, "wallpaper-prepare-library").clicked()
            } else if (phase === 5) {
                if (WallpaperService.busy || WallpaperService.cacheBusy || WallpaperService.cacheMessage !== "All videos ready") return
                root.check(WallpaperService.cacheMiB > 0, "Settings prepares the library even with manual policy")
                root.check(WallpaperService.current.token === root.imageToken, "maintenance never applies a different wallpaper")
                root.findItem(settings, "wallpaper-clear-unused").clicked()
            } else if (phase === 6) {
                if (WallpaperService.cacheBusy) return
                root.check(WallpaperService.cacheMiB === 0, "Settings clears unused video copies")
                root.check(WallpaperService.current.token === root.imageToken, "cache maintenance preserves the selected image")
                settings.visible = false
                browser.filter = "static"
                browser.query = ""
            } else if (phase === 7) {
                if (!browser.interactionReady || browser.refreshPending) return
                root.check(browser.items.length === 4, "reopening refreshes the library")
                var width = window.width, height = window.height
                browser.filter = "video"
                browser.filter = "static"
                root.check(window.width === width && window.height === height, "filter changes keep drawing-window geometry stable")
                root.captures++
                browser.grabToImage(result => {
                    var directory = Quickshell.env("HAKUSPACE_WALLPAPER_ARTIFACT_DIR")
                    if (directory) root.check(result.saveToFile(directory + "/wallpaper-picker.png"), "save picker screenshot")
                    --root.captures
                })
            } else {
                if (WallpaperService.busy || WallpaperService.cacheBusy || WallpaperService.statusDelay.running
                        || WallpaperService.statusWriter.running || WallpaperService.accent.running) return
                console.info("Wallpaper browser checks passed")
                ++reloadMemory.reloadCount
                Quickshell.reload(false)
                return
            }
            ++root.phase
        }
    }
}
