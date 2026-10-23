import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"
import "components/wallpaper" as Wallpaper

ShellRoot {
    id: root
    // Exercise real background surfaces, frame handoff and modal input on private outputs.
    property int phase: 0
    property int ticks: 0
    property int holdTicks: 0
    property int keyPhase: 0
    property int introPhase: 0
    property string browsedPath: ""
    property string staticToken: ""
    readonly property string fixture: Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE")
    Variants { id: surfaces; model: Quickshell.screens; Wallpaper.WallpaperSurface {} }
    Variants { id: panels; model: Quickshell.screens; WallpaperBrowserPanel {} }
    Variants { id: settingsPanels; model: Quickshell.screens; SettingsPanel {} }
    Variants { id: bars; model: Quickshell.screens; TopBar {} }
    Variants { id: menus; model: Quickshell.screens; HakuMenuPanel {} }
    Variants { model: Quickshell.screens; RoundedScreen {} }
    FloatingWindow {
        id: fullscreenClient
        screen: Quickshell.screens[0]
        visible: false
        fullscreen: true
        title: "Wallpaper fullscreen lifecycle fixture"
    }
    Process {
        id: keyboard
        command: ["python3", root.fixture + "/../wayland_keyboard_fixture.py"]
        stdinEnabled: true
        running: true
    }
    Process {
        id: pointer
        command: ["python3", root.fixture + "/../wayland_pointer_fixture.py"]
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: Quickshell.screens[1].name})
        stdinEnabled: true
        running: false
    }
    Process {
        id: screenshot
        onExited: code => {
            root.check(code === 0, "capture attached flare and overlay")
            UiState.closeWallpaper()
        }
    }
    // A blue video pixel must cover the green awww image after remapping.
    Process {
        id: videoPixel
        command: ["sh", "-c", 'grim -o "$1" "$2" && magick "$2" -format "%[fx:p{960,900}.b > p{960,900}.g]" info:',
            "--", Quickshell.screens[0].name, root.fixture + "/native-pixel.png"]
        stdout: StdioCollector { id: pixelOut }
        onExited: code => root.check(code === 0, "capture native video stacking")
    }
    // Fail with native state so frame and process errors remain actionable.
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper surface failed at " + phase + ": " + message + " " + WallpaperService.error)
        Qt.exit(1)
        throw new Error(message)
    }
    // Find real controls without depending on their visual nesting.
    function findItem(parent, name) {
        if (parent.objectName === name) return parent
        for (var child of parent.children || []) {
            var found = findItem(child, name)
            if (found) return found
        }
        return null
    }
    // Send hover, click and held-button events to the requested output.
    function pointAt(item, button, down) {
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        var output = Quickshell.screens[1]
        pointer.write([Math.round(point.x), Math.round(point.y), output.width, output.height, button].join(" ")
            + (down === undefined ? "" : " " + down) + "\n")
    }
    // Wheel events use the same compositor path as a physical mouse.
    function wheelAt(item, steps) {
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        var output = Quickshell.screens[1]
        pointer.write("scroll " + [Math.round(point.x), Math.round(point.y), output.width, output.height, steps].join(" ") + "\n")
    }
    Timer {
        interval: 120; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 320, "timeout")
            if (phase === 0) {
                if (!WallpaperSettingsStore.ready || WallpaperService.busy) return
                WallpaperSettingsStore.setValue("playback", "unloadDelaySec", 1)
                WallpaperSettingsStore.apply()
            } else if (phase === 1) {
                if (WallpaperSettingsStore.saving) return
                WallpaperService.select(fixture + "/Pictures/Wallpapers/forest # one.png", "low-memory", false)
            } else if (phase === 2) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.kind === "static", "awww image handoff")
                root.check(surfaces.instances.every(surface => !surface.front && !surface.incoming && !surface.visible), "awww images allocate no native renderer")
                if (introPhase === 0) {
                    root.staticToken = WallpaperService.current.token
                    UiState.openHakuMenu(Quickshell.screens[1].name, "theme", "edge")
                    introPhase = 1
                    holdTicks = 0
                    return
                }
                if (introPhase === 1) {
                    if (++holdTicks < 6) return
                    keyboard.write("text ~wallpaper\n")
                    introPhase = 2
                    holdTicks = 0
                    return
                }
                if (introPhase === 2) {
                    if (++holdTicks < 3) return
                    root.check(UiState.hakuMenuMode === "theme", "Wallpaper option is in Theme tab")
                    keyboard.write("key 28\n")
                    introPhase = 3
                    return
                }
                if (UiState.activePanel !== "wallpaper") return
                var wallpaper = panels.instances.find(panel => panel.panelOpen)
                root.check(wallpaper.currentRect.y === wallpaper.attachmentY && wallpaper.currentRect.height === wallpaper.browserHeight, "sidebar opens at its own full-height attachment")
                root.check(Math.abs(wallpaper.currentRect.x + wallpaper.currentRect.width - wallpaper.modelData.width + ScreenGeometry.rightInset) < 1, "Theme action opens from the right edge without menu geometry")
                root.check(menus.instances.every(menu => !menu.panelOpen), "source menu releases input")
                holdTicks = 0
            } else if (phase === 3) {
                if (++holdTicks < 5) return
                var browser = panels.instances.find(panel => panel.panelOpen).browserItem
                if (keyPhase === 0) { pointer.environment = {HAKUSPACE_TEST_POINTER_OUTPUT: UiState.wallpaperScreenName}; pointer.running = true; browser.filter = "all"; browser.profile = "low-memory"; browser.forceActiveFocus(); keyboard.write("key 106 4\n") }
                else if (keyPhase === 1) { root.check(browser.filter === "static", "Ctrl Right changes type"); keyboard.write("key 108 4\n") }
                else if (keyPhase === 2) { root.check(browser.filter === "video", "Ctrl Down changes type"); keyboard.write("key 105 4\n") }
                else if (keyPhase === 3) { root.check(browser.filter === "static", "Ctrl Left changes type"); keyboard.write("key 103 4\n") }
                else if (keyPhase === 4) { root.check(browser.filter === "all", "Ctrl Up changes type"); keyboard.write("key 106 8\n") }
                else if (keyPhase === 5) { root.check(browser.profile === "screen", "Alt Right changes quality"); keyboard.write("key 108 8\n") }
                else if (keyPhase === 6) { root.check(browser.profile === "original", "Alt Down changes quality"); keyboard.write("key 105 8\n") }
                else if (keyPhase === 7) { root.check(browser.profile === "screen", "Alt Left changes quality"); keyboard.write("key 103 8\n") }
                else if (keyPhase === 8) { root.check(browser.profile === "low-memory", "Alt Up changes quality"); keyboard.write("key 33 4\n") }
                else if (keyPhase === 9) { keyboard.write("key 106 4\n") }
                else if (keyPhase === 10) { root.check(browser.filter === "static", "Ctrl arrow works in search"); keyboard.write("key 108 8\n") }
                else if (keyPhase === 11) { root.check(browser.profile === "screen", "Alt arrow works in search"); keyboard.write("key 103 8\nkey 105 4\n") }
                else if (keyPhase === 12) { browser.forceActiveFocus(); root.browsedPath = browser.selected.path; keyboard.write("key 108\n") }
                else if (keyPhase === 13) { root.check(browser.selected.path !== root.browsedPath, "Down scrolls the vertical carousel"); keyboard.write("key 103\n"); root.pointAt(root.findItem(browser, "wallpaper-kind-static"), 0) }
                else if (keyPhase === 14) {
                    root.check(browser.selected.path === root.browsedPath, "Up returns to the previous vertical card")
                    root.check(root.findItem(browser, "wallpaper-kind-static").hovered, "real pointer reaches the library tab before scrolling")
                    var reel = root.findItem(browser, "wallpaperReel")
                    root.wheelAt(reel, 1)
                }
                else if (keyPhase === 15) { root.check(browser.selected.path !== root.browsedPath, "mouse wheel scrolls down"); root.wheelAt(root.findItem(browser, "wallpaperReel"), -1) }
                else if (keyPhase === 16) { root.check(browser.selected.path === root.browsedPath, "mouse wheel scrolls up"); root.pointAt(root.findItem(browser, "wallpaper-kind-static"), 0) }
                else if (keyPhase === 17) { root.check(root.findItem(browser, "wallpaper-kind-static").hovered, "real pointer reaches the library tab"); root.pointAt(root.findItem(browser, "wallpaper-kind-static"), 272, 1) }
                else if (keyPhase === 18) { root.check(root.findItem(browser, "wallpaper-kind-static").pressed && root.findItem(browser, "wallpaper-kind-static").horizontalScale < 1, "real press contracts the button background"); root.pointAt(root.findItem(browser, "wallpaper-kind-static"), 272, 0) }
                else if (keyPhase === 19) { root.check(browser.filter === "static", "release selects the library tab"); root.pointAt(root.findItem(browser, "wallpaper-quality-original"), 272) }
                else if (keyPhase === 20) {
                    var indicator = root.findItem(browser, "wallpaper-quality-indicator")
                    root.check(browser.profile === "original" && indicator.animatedStartIndex > 0 && indicator.width > root.findItem(browser, "wallpaper-quality-original").width + 1, "quality selection stretches between cards")
                    root.pointAt(root.findItem(browser, "wallpaper-quality-original"), 272, 1)
                }
                else if (keyPhase === 21) { root.check(root.findItem(browser, "wallpaper-quality-original").pressed && root.findItem(browser, "wallpaper-quality-original").horizontalScale < 1, "selected quality card also morphs on press"); root.pointAt(root.findItem(browser, "wallpaper-quality-original"), 272, 0) }
                else if (keyPhase === 22) { browser.profile = "screen"; browser.filter = "all"; root.pointAt(root.findItem(browser, "wallpaperTitle"), 0) }
                if (keyPhase++ < 28) return
                root.check(browser.filter === "all" && browser.profile === "screen" && !WallpaperService.busy && WallpaperService.current.token === root.staticToken, "menu interactions never apply wallpaper")
                root.check(UiState.wallpaperScreenName === Quickshell.screens[1].name, "browser targets requested output")
                root.check(surfaces.instances.length === 2, "one renderer per output")
                for (var panel of panels.instances) {
                    root.check(panel.browserWidth <= 520 && panel.browserHeight > panel.browserWidth, "vertical sidebar geometry")
                    root.check(panel.panelOpen === (panel.modelData.name === Quickshell.screens[1].name), "per-output browser visibility")
                    root.check(panel.attachmentY === Theme.topBarHeight, "flare follows Rounded Screen ceiling")
                    root.check(panel.attachmentBottom === panel.modelData.height - ScreenGeometry.bottomInset, "bottom flare follows Rounded Screen floor")
                    if (panel.panelOpen) root.check(Math.abs(panel.currentRect.x + panel.currentRect.width - panel.modelData.width + ScreenGeometry.rightInset) < 1, "sidebar hugs the right screen frame")
                }
                for (var bar of bars.instances) {
                    var modules = bar.contentItem.children[0].children.find(item => item.objectName === "topbarModules")
                    root.check(!!modules && modules.visible, "TopBar module container stays visible")
                    root.check(root.findItem(modules, "leftStatusModules").visible && root.findItem(modules, "centerStatusModules").visible, "left and center TopBar modules remain visible")
                    root.check(root.findItem(modules, "rightStatusModules").visible === (bar.modelData.name !== Quickshell.screens[1].name), "only right modules hide on the wallpaper output")
                }
                var artifact = Quickshell.env("HAKUSPACE_WALLPAPER_ARTIFACT_DIR")
                for (var panel of panels.instances) {
                    if (panel.panelOpen && artifact) {
                        root.check(panel.browserItem.grabToImage(function(result) {
                            root.check(result.saveToFile(artifact + "/wallpaper-browser.png"), "save browser capture")
                        }), "capture browser")
                    }
                }
                if (artifact) {
                    screenshot.command = ["grim", "-o", Quickshell.screens[1].name, artifact + "/wallpaper-overlay.png"]
                    screenshot.running = true
                } else UiState.closeWallpaper()
            } else if (phase === 4) {
                if (UiState.activePanel === "wallpaper") return
                root.check(WallpaperService.current.token === root.staticToken, "close keeps exact renderer source")
                for (var bar of bars.instances)
                    root.check(!bar.wallpaperOverlayOpen, "TopBar modules restore after close")
                root.check(surfaces.instances.every(surface => !surface.front && !surface.visible), "browser close keeps the awww image unobstructed")
                WallpaperService.select(fixture + "/broken.png", "low-memory", false)
            } else if (phase === 5) {
                if (WallpaperService.busy) return
                root.check(!!WallpaperService.error && WallpaperService.current.token === root.staticToken, "failed awww image retains working wallpaper")
                WallpaperService.select(fixture + "/Videos/Wallpapers/clip.mp4", "low-memory", false)
            } else if (phase === 6) {
                if (WallpaperService.busy) return
                root.check(WallpaperService.current.kind === "video" && WallpaperService.proxyState === "ready", "video proxy native handoff")
                root.check(WallpaperService.current.render.height === 720, "720p proxy")
                holdTicks = 0
                fullscreenClient.visible = true
            } else if (phase === 7) {
                if (++holdTicks < 18) return
                for (var surface of surfaces.instances) {
                    var hidden = surface.modelData.name === Quickshell.screens[0].name
                    root.check(surface.unloaded === hidden && surface.front.unloaded === hidden, "fullscreen unload is per output")
                }
                fullscreenClient.visible = false
            } else if (phase === 8) {
                for (var surface of surfaces.instances) root.check(!surface.unloaded && !surface.front.unloaded, "decoder resumed")
                UiState.settingsGroup = "Wallpaper"
                UiState.openSettings(Quickshell.screens[0].name)
                holdTicks = 0
            } else if (phase === 9) {
                if (++holdTicks < 8) return
                for (var panel of settingsPanels.instances) {
                    if (panel.panelOpen) root.check(panel.selectedGroup === "Wallpaper", "wallpaper settings domain")
                }
                root.check(!WallpaperService.error, "native renderer error")
                UiState.closeSettings()
                WallpaperService.select(fixture + "/Pictures/Wallpapers/other.png", "screen", false)
            } else if (phase === 10) {
                if (WallpaperService.busy) return
                root.check(!WallpaperService.error && WallpaperService.current.kind === "static", "awww replaces native video")
                root.check(surfaces.instances.every(surface => !surface.front && !surface.incoming && !surface.visible), "image handoff releases every native decoder and window")
                WallpaperService.select(fixture + "/Videos/Wallpapers/clip.mp4", "screen", false)
                holdTicks = 0
            } else if (phase === 11) {
                if (WallpaperService.busy) return
                if (++holdTicks < 4) return
                root.check(WallpaperService.current.kind === "video" && WallpaperService.current.render.fps === 60, "Screen video keeps source 60 fps")
                root.check(surfaces.instances.every(surface => !!surface.front && surface.visible), "video remaps native windows above awww")
                videoPixel.running = true
            } else if (phase === 12) {
                if (videoPixel.running) return
                root.check(pixelOut.text.trim() === "1", "native video pixels cover the awww image")
                console.info("Wallpaper surface checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
