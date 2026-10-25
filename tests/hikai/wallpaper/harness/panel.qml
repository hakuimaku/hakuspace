import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"
import "components/base" as Base

ShellRoot {
    id: root
    // Exercise the real presentation owners on two private outputs.
    property int phase: -6
    property int ticks: 0
    property int hold: 0
    property bool capturingSection: false
    property bool sawSettingsOpen: false
    property bool sawSettingsClose: false
    property int cacheDraftValue: 0
    property int layout: 0
    property int births: 0
    property int deaths: 0
    property bool sawClosing: false
    property bool sawFold: false
    property bool sawOrbit: false
    property bool sawEarlyOrbit: false
    property bool sawCircularReveal: false
    property bool capturedCircle: false
    property bool sawZoomBeforeFade: false
    property bool sawFarZoom: false
    property bool sawClosePulse: false
    property bool sawSlowFade: false
    property bool sawPulseOverlap: false
    property bool sawImmediatePulse: false
    property double fadeStartedAt: 0
    property bool sawSlowFold: false
    property bool capturedPulse: false
    property double quickCloseAt: 0
    property bool sawWorkspaceSlideIn: false
    property bool sawWorkspaceSlideOut: false
    property int scrollStage: 0
    property string scrollSelection: ""
    property int scrollIndex: 0
    property int scrollDirection: 1
    property int repeatedMoves: 0
    property bool sawLeftCurve: false
    property bool sawRightCurve: false
    property string orbitSelection: ""
    property string selectedPath: ""
    property var libraryItems: null
    readonly property var output: Quickshell.screens[1]
    readonly property var quick: quicks.instances[1]
    readonly property var workspace: workspaces.instances[1]
    readonly property string artifact: Quickshell.env("HAKUSPACE_WALLPAPER_ARTIFACT_DIR")
    PersistentProperties {
        id: memory
        reloadableId: "wallpaper-presentation-regression"
        property bool reloaded: false
        onLoaded: if (reloaded) root.phase = 20
    }
    // A bright desktop fixture checks contrast and exposes gaps at frame joins.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#82bfd2" }
                    GradientStop { position: 1; color: "#d3dfac" }
                }
            }
        }
    }
    Variants { id: bars; model: Quickshell.screens; TopBar {} }
    Variants { id: tasks; model: Quickshell.screens; Taskbar {} }
    Variants { id: docks; model: Quickshell.screens; DockBar {} }
    Variants { id: frames; model: Quickshell.screens; RoundedScreen {} }
    Variants {
        id: quicks
        model: Quickshell.screens
        Base.LifecycleLoader {
            required property var modelData
            id: quickLoader
            requested: UiState.wallpaperQuickActive && UiState.wallpaperScreenName === modelData.name
            WallpaperQuickOverlay {
                modelData: quickLoader.modelData
                Component.onCompleted: ++root.births
                Component.onDestruction: ++root.deaths
            }
        }
    }
    Variants {
        id: workspaces
        model: Quickshell.screens
        Base.LifecycleLoader {
            required property var modelData
            id: workspaceLoader
            requested: UiState.wallpaperWorkspaceActiveFor(modelData.name)
            WallpaperWorkspace { modelData: workspaceLoader.modelData }
        }
    }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_WALLPAPER_FIXTURE") + "/../wayland_keyboard.py"]
        stdinEnabled: true
        running: true
    }
    Process {
        id: capture
        onExited: code => {
            root.check(code === 0, "capture presentation")
            if (UiState.wallpaperWorkspaceActive) keyboard.write("key 1\n")
            else UiState.closeWallpaper()
        }
    }
    // Fail with the current state instead of masking broken ownership with a timeout.
    function check(ok, message) {
        if (ok) return
        console.error("Wallpaper presentation failed at " + phase + ": " + message)
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
    // Validate actual label bounds and padding rather than fixed button widths.
    function checkToolbar(item, browser) {
        if (!item.visible) return
        if (item.description !== undefined) {
            var label = item.children.find(child => child.objectName === "wallpaper-button-content")
            var position = item.mapToItem(browser, 0, 0)
            root.check(position.x >= 8 && position.x + item.width <= browser.width - 8, "toolbar control stays inside its row: " + item.description)
            root.check(position.y >= 3 && position.y + item.height <= browser.topPanelHeight - 3, "toolbar keeps vertical padding: " + item.description)
            root.check(!!label && (item.width - label.implicitWidth) / 2 >= item.horizontalPadding - 0.5, "toolbar label keeps horizontal padding: " + item.description)
        }
        for (var child of item.children || []) checkToolbar(child, browser)
    }
    function screenshot(name) {
        if (!artifact) return
        capture.command = ["grim", "-o", output.name, artifact + "/" + name + ".png"]
        capture.running = true
    }
    // A short frame probe verifies zero lift and a stable Wayland drawing plane.
    FrameAnimation {
        running: !!root.quick && root.quick.active
        onTriggered: {
            var panel = root.quick.item
            if (panel.expansion < 1 && (panel.width !== root.output.width || panel.height !== root.output.height)) return
            root.check(panel.width === root.output.width && panel.height === root.output.height, "stable fullscreen host " + panel.width + "x" + panel.height + " vs " + root.output.width + "x" + root.output.height)
            var reel = root.find(panel.browserItem, "wallpaperReel")
            if (reel.introRunning) {
                root.sawOrbit = true
                if (panel.expansion > 0 && panel.expansion < 1) root.sawEarlyOrbit = true
                if (!root.orbitSelection) root.orbitSelection = WallpaperLibrary.selectedPath
                root.check(WallpaperLibrary.selectedPath === root.orbitSelection, "opening orbit does not change selection")
                root.check(!WallpaperService.busy, "opening orbit never prepares video")
                var selectedCard = reel.currentItem
                if (selectedCard && selectedCard.revealProgress > 0 && selectedCard.revealProgress < 0.98) {
                    var circle = root.find(selectedCard, "wallpaper-reveal-circle")
                    root.check(!!circle && circle.width === circle.height && circle.radius === circle.width / 2,
                        "opening selection reveals through a circular mask during the orbit")
                    var center = circle.mapToItem(selectedCard, circle.width / 2, circle.height / 2)
                    root.check(Math.abs(center.x - selectedCard.width / 2) < 0.5 && Math.abs(center.y - selectedCard.height / 2) < 0.5,
                        "circular reveal stays centered on the selected wallpaper")
                    root.sawCircularReveal = true
                    if (root.artifact && !root.capturedCircle && selectedCard.revealProgress > 0.2 && selectedCard.revealProgress < 0.65) {
                        root.capturedCircle = true
                        root.check(panel.browserItem.grabToImage(result => root.check(result.saveToFile(root.artifact + "/circular-open.png"), "save circular reveal screenshot")), "capture circular reveal")
                    }
                }
            }
            if (panel.closing && panel.stackSpread > 0 && panel.stackSpread < 1) {
                root.sawFold = true
                root.check(panel.expansion === 1, "side cards fold before fading")
                var elapsed = Date.now() - root.quickCloseAt
                if (root.phase === 6 && elapsed >= 100 && elapsed <= 180) {
                    root.check(panel.stackSpread > 0.9, "fold starts slowly before its final acceleration")
                    root.sawSlowFold = true
                }
            }
            if (panel.closing && panel.selectedPulse > 1) {
                root.check(panel.expansion === 1 && panel.quickOpacity === 1,
                    "selection pulses alongside the fold before the opaque zoom: " + JSON.stringify({spread: panel.stackSpread, expansion: panel.expansion, opacity: panel.quickOpacity}))
                if (panel.stackSpread > 0) root.sawPulseOverlap = true
                if (root.phase === 6 && Date.now() - root.quickCloseAt < 80 && panel.stackSpread > 0.9) root.sawImmediatePulse = true
                root.check(reel.currentItem.pulse > 1 && reel.currentItem.scale > reel.currentItem.targetScale,
                    "central wallpaper grows for the closing pulse")
                root.sawClosePulse = true
                if (root.artifact && root.phase === 6 && !root.capturedPulse && panel.selectedPulse > 1.055) {
                    root.capturedPulse = true
                    root.check(panel.browserItem.grabToImage(result => root.check(result.saveToFile(root.artifact + "/close-pulse.png"), "save closing pulse screenshot")), "capture closing pulse")
                }
            }
            if (panel.closing && panel.expansion > 0 && panel.expansion < 1) {
                root.sawClosing = true
                root.check(panel.stackSpread === 0 && root.sawFold, "fade follows the completed fold")
                root.check(!panel.releaseReady && !reel.introRunning, "closing retains its owner and stops the orbit")
                root.check(panel.selectedPulse === 1, "zoom follows the completed pulse")
                if (panel.browserItem.scale > 0.4) {
                    root.check(panel.browserItem.contentOpacity === 1, "zoom stays opaque until sixty percent of its travel")
                    root.sawZoomBeforeFade = true
                }
                if (panel.browserItem.scale < 0.08) root.sawFarZoom = true
                for (var card of reel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible)) {
                    var center = card.mapToItem(reel, card.width / 2, card.height / 2)
                    root.check(Math.abs(center.x - reel.width / 2) < 1, "both sides collapse to the center")
                }
            }
            if (panel.closing && panel.quickOpacity > 0 && panel.quickOpacity < 1) {
                root.check(panel.stackSpread === 0 && panel.browserItem.scale <= 0.4 && !panel.releaseReady,
                    "fade overlaps the remaining zoom toward zero after sixty percent travel")
                root.sawSlowFade = true
                if (!root.fadeStartedAt) root.fadeStartedAt = Date.now()
            }
            root.check(reel.selectedLift === 0, "simple never lifts the selected card")
            if (reel.currentItem) {
                for (var card of reel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible))
                    root.check(card.opacity === 1, "simple cards remain opaque at both ends")
                if (!reel.introRunning && reel.introProgress === 1)
                    root.check(!root.find(reel.currentItem, "wallpaper-circular-reveal").active, "settled selection releases the circular mask")
            }
            if (reel.currentItem && !reel.moving) {
                root.check(Math.abs(reel.currentItem.y + reel.currentItem.height / 2 - reel.height / 2) < 1, "selected card shares the horizontal center line")
            }
        }
    }
    // The body and gallery translate together while their geometry remains fixed.
    FrameAnimation {
        running: !!root.workspace && root.workspace.active
        onTriggered: {
            var owner = root.workspace.item
            if (owner.width !== root.output.width || owner.height !== root.output.height) return
            root.check(tasks.instances.every(task => task.active === ChromeLayout.taskbarMode), "workspace animation never disables Taskbars")
            root.check(bars.instances.every(bar => bar.visible === ChromeLayout.topStatusBarVisible), "workspace animation never hides TopBars")
            root.check(docks.instances.every(dock => dock.enabledDock === ChromeLayout.dockbarActive), "workspace animation never disables Docks")
            var browser = owner.browserItem
            var body = root.find(browser, "wallpaperBottomPanel")
            var reel = root.find(browser, "wallpaperReel")
            if (!owner.closing && owner.expansion > 0 && owner.expansion < 1) {
                root.check(WallpaperLibrary.initialized && !browser.loading, "workspace waits for the initial scan before moving")
                root.check(!!reel.currentItem, "workspace has a selected delegate before moving")
                for (var card of reel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible)) {
                    var image = root.find(card, "wallpaperThumbnail")
                    root.check(image.status === Image.Ready || image.status === Image.Error || !image.source.toString(), "workspace waits for visible thumbnail decodes before moving")
                }
            }
            // Check the filled outline during motion, not only its bounding rectangle.
            body.containsMode = Shape.FillContains
            if (reel.currentItem) {
                for (var card of reel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible)) {
                    root.check(card.opacity === 1, "workspace thumbnails never fade during navigation")
                    for (var corner of [[0, 0], [card.width, 0], [0, card.height], [card.width, card.height]]) {
                        var point = card.mapToItem(browser, corner[0], corner[1])
                        if (point.x < 0 || point.x >= browser.width || point.y < 0 || point.y >= browser.height || point.y >= browser.height - browser.bottomBarHeight + browser.bottomSlide) continue
                        root.check(body.contains(body.mapFromItem(browser, point.x, point.y)), "visible wallpaper corners stay inside the background during motion: " + JSON.stringify({index:card.index,x:point.x,y:point.y}))
                    }
                    var center = card.mapToItem(reel, card.width / 2, card.height / 2)
                    var distance = Math.abs(center.x - reel.width / 2)
                    if (distance > reel.farOffset + 1 && distance < reel.edgeOffset - 1) {
                        var fraction = (distance - reel.farOffset) / (reel.edgeOffset - reel.farOffset)
                        var chordY = reel.pathCenterY(reel.farScale) + fraction * (reel.edgeY - reel.pathCenterY(reel.farScale))
                        if (Math.abs(center.y - chordY) > 3) {
                            if (center.x < reel.width / 2) root.sawLeftCurve = true
                            else root.sawRightCurve = true
                        }
                    }
                }
            }
            var top = root.find(browser, "wallpaperTopPanel")
            var bottomBar = root.find(browser, "wallpaperBottomBar")
            var details = root.find(browser, "wallpaper-settings-popover")
            var tabs = root.find(browser, "wallpaper-media-tabs")
            root.check(tabs.y === body.y + browser.panelPadding, "media tabs follow the trapezoid header during slide")
            root.check(top.y === browser.topSlide && browser.topInputItem.y === top.y, "top surface and all controls slide together")
            root.check(Math.abs(bottomBar.y - body.y - body.height) < 1, "bottom rail and gallery stay joined during slide")
            root.check(Math.abs(reel.y - (root.output.height - browser.bottomBarHeight - browser.bottomPanelHeight + browser.bottomSlide)) < 1, "wallpapers follow the bottom slide")
            if (details.visible) {
                root.check(details.y === browser.topPanelHeight + browser.topSlide, "settings viewport follows the top slide")
                root.check(details.panelHeight === Math.max(0, Math.min(details.displayedSection === "cache" ? 480 : 680, details.availableHeight)), "settings keeps its content height during slide")
                var settingsCard = root.find(details, "wallpaper-settings-card")
                root.check(Math.abs(settingsCard.y - (details.gap - (settingsCard.height + details.gap) * (1 - details.progress))) < 1, "settings card slides inside its clipped viewport")
                if (details.progress > 0 && details.progress < 1) {
                    root.check(details.editorLoaded, "settings retains its editor throughout slide")
                    if (browser.settingsSection) root.sawSettingsOpen = true
                    else root.sawSettingsClose = true
                }
            }
            if (owner.expansion === 0) {
                root.check(top.y + top.currentHeight + ScreenGeometry.roundedRadius <= 0 && browser.topInputItem.y + browser.topInputItem.height <= 0, "all top visuals start and end outside the screen")
                root.check(body.y >= root.output.height && bottomBar.y >= root.output.height, "all bottom visuals start and end outside the screen")
                if (reel.currentItem) root.check(reel.currentItem.mapToItem(browser, 0, 0).y >= root.output.height - 1, "raised wallpaper slides completely offscreen")
                if (details.visible) root.check(details.y + details.height <= 0, "settings slides completely offscreen")
            }
            root.check(Math.abs(body.y - (root.output.height - browser.bottomBarHeight - body.height + browser.bottomSlide)) < 1, "panel slides with a fixed silhouette")
            root.check(reel.spread === 1 && reel.opacity === 1, "workspace slide does not fold or fade the gallery")
            root.check(body.height > 0 && reel.height === browser.bottomPanelHeight + browser.bottomBarHeight, "gallery uses the bottom rail height during slide")
            if (owner.expansion > 0 && owner.expansion < 1) {
                if (owner.closing) root.sawWorkspaceSlideOut = true
                else root.sawWorkspaceSlideIn = true
            }
        }
    }
    Timer {
        interval: 80; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 420, "timeout: " + JSON.stringify({busy: WallpaperService.busy, error: WallpaperService.error, current: WallpaperService.current.path, selected: selectedPath, library: WallpaperLibrary.selectedPath}))
            if (!WallpaperSettingsStore.ready || !ShellSettingsStore.ready || capture.running || capturingSection) return
            if (phase === -6) {
                UiState.openWallpaperQuick(output.name)
            } else if (phase === -5) {
                if (!quick.active || quick.item.expansion !== 1) return
                root.check(sawEarlyOrbit && sawCircularReveal, "cold quick circle and orbit overlap the initial reveal")
                UiState.closeWallpaper()
            } else if (phase === -4) {
                if (quick.active) return
                Theme.fontFamily = "monospace"
                UiState.openWallpaperWorkspace(output.name)
                UiState.closeWallpaper()
            } else if (phase === -3) {
                if (workspace.active) return
                root.check(!UiState.wallpaperWorkspaceActive, "pre-frame dismissal releases its owner without a binding loop")
            } else if (phase === -2) {
                // Both bar presentations keep the launcher beside Screen Recorder.
                var rightBar = bars.instances[1]
                var topbarTooltip = rightBar.contentItem.children.find(child => child.minimumTooltipWidth !== undefined)
                root.check(topbarTooltip && topbarTooltip.minimumTooltipWidth === 0 && topbarTooltip.maxTooltipWidth === 500,
                    "regular TopBar keeps its original tooltip width")
                var taskbarWindow = tasks.instances[1].data.find(child => child.bottomChromeHost)
                root.check(!!taskbarWindow, "Taskbar has its status module host")
                var launcher = null
                var taskbarLauncher = null
                for (var host of [rightBar, taskbarWindow]) {
                    var button = find(host.contentItem, "wallpaper-workspace-launcher")
                    var recorder = find(host.contentItem, "screen-recorder-module")
                    root.check(button && recorder && button.parent === recorder.parent && button.x + button.width <= recorder.x,
                        "wallpaper launcher sits immediately left of Screen Recorder on both bars")
                    root.check(button.screenName === output.name, "wallpaper launcher belongs to its output")
                    if (host === rightBar) launcher = button
                    else taskbarLauncher = button
                }
                taskbarLauncher.clicked()
                root.check(UiState.wallpaperWorkspaceActiveFor(output.name), "Taskbar launcher opens mode 2 on its own output")
                launcher.clicked()
                root.check(UiState.wallpaperWorkspaceActiveFor(output.name), "TopBar launcher opens mode 2 on its own output")
            } else if (phase === -1) {
                if (!workspace.active || workspace.item.expansion !== 1) return
                root.check(sawWorkspaceSlideIn, "cold direct workspace open animates")
                var reel = find(workspace.item.browserItem, "wallpaperReel")
                if (scrollStage === 0) {
                    scrollSelection = WallpaperLibrary.selectedPath
                    sawLeftCurve = false
                    sawRightCurve = false
                    scrollStage = 1
                    keyboard.write("key 106\n")
                    return
                }
                if (scrollStage === 1) {
                    if (WallpaperLibrary.selectedPath === scrollSelection || Math.abs(reel.currentItem.mapToItem(reel, reel.cardWidth / 2, 0).x - reel.width / 2) > 1) return
                    root.check(sawLeftCurve && sawRightCurve, "both carousel edges traverse curves during real key navigation")
                    scrollStage = 2
                    keyboard.write("key 105\n")
                    return
                }
                if (scrollStage === 2) {
                    if (WallpaperLibrary.selectedPath !== scrollSelection || Math.abs(reel.currentItem.mapToItem(reel, reel.cardWidth / 2, 0).x - reel.width / 2) > 1) return
                    scrollStage = 3
                    scrollIndex = WallpaperLibrary.selectedIndex
                    hold = 0
                    return
                }
                if (scrollStage === 3) {
                    if (hold > 0 && hold <= 14) {
                        root.check(WallpaperLibrary.selectedIndex === (scrollIndex + scrollDirection + WallpaperLibrary.filteredItems.length) % WallpaperLibrary.filteredItems.length,
                            "each rapid native arrow selects immediately in either direction")
                        ++repeatedMoves
                    } else root.check(WallpaperLibrary.selectedIndex === scrollIndex, "native navigation has no delayed selection writes")
                    scrollIndex = WallpaperLibrary.selectedIndex
                    if (++hold <= 14) {
                        scrollDirection = hold % 4 === 0 ? -1 : 1
                        keyboard.write("key " + (scrollDirection > 0 ? 106 : 105) + "\n")
                        return
                    }
                    if (hold <= 18) return
                    root.check(repeatedMoves === 14 && reel.currentIndex === WallpaperLibrary.selectedIndex, "all rapid native arrows are handled and settle")
                    scrollStage = 4
                }
                root.check(!WallpaperService.busy, "curved navigation never applies wallpaper")
                WallpaperLibrary.filter = "video"
                workspace.item.browserItem.settingsSection = "cache"
                root.screenshot("workspace-cold")
                if (!artifact) UiState.closeWallpaper()
            } else if (phase === 0) {
                if (workspace.active) return
                sawWorkspaceSlideIn = false
                sawWorkspaceSlideOut = false
                AppState.taskbarManualState = layout === 1
                AppState.dockbarManualState = true
                root.check(!quick.active && !workspace.active, "closed visuals unloaded")
                sawFold = false
                sawOrbit = false
                sawEarlyOrbit = false
                orbitSelection = ""
                UiState.openWallpaperQuick(output.name)
            } else if (phase === 1) {
                if (!quick.active || quick.item.expansion !== 1 || !quick.item.browserItem.interactionReady) return
                root.check(WallpaperLibrary.items.length === 10, "shared library loaded once")
                root.check(tasks.instances.every(task => task.active === (layout === 1)), "simple keeps normal Taskbar")
                root.check(docks.instances.every(dock => dock.enabledDock === (layout === 0)), "simple keeps normal Dock")
                var modules = find(quick.item.browserItem, "wallpaperReel")
                if (!quick.item.introStarted || modules.introPending || modules.introRunning) return
                root.check(sawOrbit && modules.introProgress === 1, "quick opening completes one decorative turn " + JSON.stringify({saw: sawOrbit, progress: modules.introProgress, pending: modules.introPending}))
                root.check(sawEarlyOrbit, "quick orbit starts before the reveal finishes")
                root.check(!!modules.currentItem && modules.currentItem.visible && modules.currentItem.opacity > 0, "selected thumbnail is rendered")
                var cards = modules.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible && item.opacity > 0)
                for (var card of cards) {
                    root.check(Math.abs(card.y + card.height / 2 - modules.height / 2) < 1, "all quick cards share center Y")
                }
                root.check(modules.width < output.width && modules.cardWidth > 600, "simple has a larger bounded carousel")
                root.check(modules.cardStep < modules.cardWidth * modules.nearScale, "simple cards overlap into a stack")
                var tabs = find(quick.item.browserItem, "wallpaper-kind-static").parent
                root.check(tabs.color.a === 1, "type tabs have an opaque surface")
                root.check(modules.pathItemCount === 5 && modules.selectedLift === 0, "five horizontal simple cards")
                root.check(!find(quick.item.browserItem, "wallpaperTitle"), "simple has no sidebar title")
                WallpaperLibrary.filter = "static"
                WallpaperLibrary.query = "forest"
                root.check(WallpaperLibrary.filteredItems.length === 1, "search filters shared items")
                WallpaperLibrary.query = ""
                WallpaperLibrary.filter = "video"
                if (layout === 1) WallpaperLibrary.query = "extra"
                WallpaperLibrary.move(1)
                libraryItems = WallpaperLibrary.items
                selectedPath = WallpaperLibrary.selectedPath
                root.check(!WallpaperService.busy, "navigation never applies or prepares")
                quick.item.browserItem.forceActiveFocus()
                keyboard.write("key 28 4\n")
                hold = 0
            } else if (phase === 2) {
                if (!UiState.wallpaperWorkspaceActive || !workspace.active || workspace.item.expansion !== 1 || quick.active) return
                root.check(!quick.active, "retired quick owner released")
                root.check(WallpaperLibrary.selectedPath === selectedPath && WallpaperLibrary.filter === "video", "mode switch preserves selection and filter")
                root.check(WallpaperLibrary.query === (layout === 1 ? "extra" : "") && WallpaperLibrary.items === libraryItems, "mode switch retains query without rescanning")
                root.check(tasks.instances.every(task => task.active === (layout === 1)), "workspace leaves normal Taskbars active")
                root.check(docks.instances.every(dock => dock.enabledDock === (layout === 0)), "workspace leaves normal Docks enabled")
                root.check(bars.instances.every(bar => bar.visible === (layout === 0)), "workspace leaves normal TopBars visible")
                root.check(frames.instances.every(frame => frame.taskbarInset === ScreenGeometry.taskbarReservation()), "workspace preserves normal screen frame geometry")
                var top = find(workspace.item.browserItem, "wallpaperTopPanel")
                var bottom = find(workspace.item.browserItem, "wallpaperBottomPanel")
                root.check(top.start === ScreenGeometry.leftInset && top.end === output.width - ScreenGeometry.rightInset, "top flare follows frame rails")
                root.check(top.rf === ScreenGeometry.roundedRadius, "top flare uses Rounded Screen radius")
                root.check(top.currentHeight === Theme.topBarHeight, "top overlay has exactly TopBar height")
                root.check(bottom.topWidth < bottom.width && sawWorkspaceSlideIn, "rounded trapezoid slides up into place")
                root.check(bottom.upperCornerRadius > 0 && bottom.flareRadius > 0, "panel has rounded shoulders and frame flares")
                root.check(bottom.flareTop === bottom.height - bottom.flareRadius && bottom.sideRise === bottom.height, "side flares rise above the bar join")
                root.check(bottom.x === ScreenGeometry.leftInset && bottom.width === output.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset, "flare joins coincide with screen rails")
                var bottomBar = find(workspace.item.browserItem, "wallpaperBottomBar")
                root.check(bottomBar.height === ScreenGeometry.taskbarHeight && bottomBar.y + bottomBar.height === output.height, "bottom overlay fills Taskbar height to physical screen edge")
                root.check(Math.abs(bottom.y + bottom.height - bottomBar.y) < 1, "gallery joins bottom overlay without a gap")
                root.check(workspace.item.exclusiveZone === 0 && workspace.item.exclusionMode === ExclusionMode.Ignore, "workspace never reserves screen space")
                root.check(workspace.item.WlrLayershell.layer === WlrLayer.Overlay, "workspace stacks above normal chrome")
                root.check(!workspace.item.data.some(item => ["wallpaperTopReservation", "wallpaperBottomReservation"].includes(item.objectName)), "workspace has no bar reservation windows")
                root.check(Math.abs(workspace.item.browserItem.bottomPanelHeight - output.height * 0.15) < 1, "gallery retains its fifteen-percent base height")
                for (var action of ["wallpaper-shuffle", "wallpaper-refresh", "wallpaper-settings", "wallpaper-playback", "wallpaper-cache", "wallpaper-apply", "wallpaper-video-quality", "wallpaper-save-preferences"])
                    root.check(!!find(workspace.item.browserItem, action), "workspace control: " + action)
                var applyButton = find(workspace.item.browserItem, "wallpaper-apply")
                var baselineY = applyButton.mapToItem(workspace.item.browserItem, 0, applyButton.height / 2).y
                for (var name of ["wallpaperSearch", "wallpaper-video-quality", "wallpaper-save-preferences", "wallpaper-shuffle", "wallpaper-refresh", "wallpaper-playback", "wallpaper-cache", "wallpaper-settings"]) {
                    var item = find(workspace.item.browserItem, name)
                    root.check(Math.abs(item.mapToItem(workspace.item.browserItem, 0, item.height / 2).y - baselineY) < 1, "one toolbar baseline: " + name)
                }
                root.checkToolbar(workspace.item.browserItem.topInputItem, workspace.item.browserItem)
                var title = find(workspace.item.browserItem, "wallpaper-selected-title")
                root.check(Math.abs(title.x + title.width / 2 - output.width / 2) < 1 && Array.from(title.text).length <= 48, "selected wallpaper name is centered and character bounded")
                var tabs = find(workspace.item.browserItem, "wallpaper-media-tabs")
                root.check(!find(workspace.item.browserItem, "wallpaperWorkspacePreview"), "workspace leaves the desktop center clear")
                var reel = find(workspace.item.browserItem, "wallpaperReel")
                root.check(reel.currentItem.mapToItem(workspace.item.browserItem, 0, 0).y >= tabs.y + tabs.height + workspace.item.browserItem.panelPadding - 1, "wallpapers sit below the media tabs with padding")
                root.check(reel.selectedScale > 1 && reel.selectedLift > 0 && reel.presentation === "workspace", "workspace selection is larger and raised")
                root.check(Math.abs(reel.currentItem.mapToItem(workspace.item.browserItem, 0, 0).y - bottom.y - workspace.item.browserItem.panelTopPadding) < 1, "raised selection keeps padding inside the rounded upper edge")
                root.check(reel.selectedScale > reel.nearScale && reel.nearScale > reel.farScale, "gallery thumbnails shrink away from the center")
                root.check(reel.currentItem.cornerRadius > 0 && !reel.clip, "workspace artwork uses rounded clipping")
                root.check(!WallpaperService.busy, "workspace never applies while browsing")
                root.check(reel.cardStep >= reel.cardWidth * (reel.nearScale + reel.selectedScale) / 2 && reel.cardGap <= 8, "workspace is a closely spaced row without overlap")
                root.check(reel.cardWidth >= 350, "workspace thumbnails use the available lower area")
                root.check(reel.z > bottomBar.z, "wallpapers paint above the bottom rail")
                var gallery = reel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible && item.opacity > 0)
                for (var card of gallery) {
                    var left = card.mapToItem(workspace.item.browserItem, 0, 0)
                    var right = card.mapToItem(workspace.item.browserItem, card.width, card.height)
                    var fraction = Math.max(0, Math.min(1, (left.y - bottom.y) / bottom.height))
                    var halfWidth = (bottom.topWidth + (bottom.width - bottom.topWidth) * fraction) / 2
                    root.check(left.x >= output.width / 2 - halfWidth - 1 && right.x <= output.width / 2 + halfWidth + 1, "thumbnail corners stay within the background silhouette")
                    root.check(right.y > bottomBar.y && right.y <= output.height - reel.contentPadding + 1, "thumbnails use the bottom rail with screen padding")
                    var expectedLift = reel.selectedLift * (card.targetScale - reel.farScale) / (reel.selectedScale - reel.farScale)
                    root.check(Math.abs(output.height - reel.contentPadding - right.y - expectedLift) < 1, "larger thumbnails have a higher bottom edge")
                }

                if (hold === 0) {
                    sawSettingsOpen = false
                    sawSettingsClose = false
                    var savedProfile = WallpaperSettingsStore.savedValues.playback.profile
                    var profile = savedProfile === "low-memory" ? "screen" : "low-memory"
                    find(workspace.item.browserItem, "wallpaper-quality-" + profile).clicked()
                    root.check(find(workspace.item.browserItem, "wallpaper-quality-" + profile).selected, "quality uses direct selection buttons")
                    root.check(WallpaperSettingsStore.dirty && WallpaperSettingsStore.savedValues.playback.profile === savedProfile, "quality stays a draft until Save preferences")
                    WallpaperSettingsStore.discard()
                    var previousPath = WallpaperLibrary.selectedPath
                    find(workspace.item.browserItem, "wallpaper-shuffle").clicked()
                    root.check(WallpaperLibrary.selectedPath !== previousPath && !WallpaperService.busy, "shuffle changes selection without applying")
                    WallpaperLibrary.selectIndex(WallpaperLibrary.filteredItems.findIndex(item => item.path === selectedPath))
                    find(workspace.item.browserItem, "wallpaper-playback").clicked()
                    root.check(workspace.item.browserItem.settingsSection === "playback", "Video Playback opens inline")
                    var decoder = find(workspace.item.browserItem, "wallpaper-setting-hardwareDecode-software")
                    root.check(!!decoder && decoder.visible, "shared playback controls are available")
                    decoder.clicked()
                    root.check(WallpaperSettingsStore.values.playback.hardwareDecode === "software", "inline playback edits the shared draft")
                    WallpaperSettingsStore.discard()
                    find(workspace.item.browserItem, "wallpaper-cache").clicked()
                    root.check(workspace.item.browserItem.settingsSection === "cache", "Cache opens inline")
                    root.check(find(workspace.item.browserItem, "wallpaper-clear-unused").visible, "existing cache actions are available")
                    root.check(!find(workspace.item.browserItem, "wallpaper-setting-hardwareDecode-software").visible, "cache hides unrelated sections")
                    hold = 1
                    return
                }
                var popup = find(workspace.item.browserItem, "wallpaper-settings-popover")
                if (hold === 1) {
                    if (popup.progress !== 1 || popup.animating) return
                    cacheDraftValue = WallpaperSettingsStore.values.proxy.maxCacheMiB + 64
                    WallpaperSettingsStore.setValue("proxy", "maxCacheMiB", cacheDraftValue)
                    hold = 2
                    if (artifact) {
                        root.capturingSection = true
                        var browser = workspace.item.browserItem
                        root.check(find(browser, "wallpaper-settings-popover").grabToImage(result => {
                            root.check(result.saveToFile(artifact + "/cache-" + layout + ".png"), "capture cache controls")
                            browser.settingsSection = ""
                            root.capturingSection = false
                        }), "request cache capture")
                        return
                    }
                    workspace.item.browserItem.settingsSection = ""
                    return
                }
                if (hold === 2) {
                    if (popup.progress === 1) return
                    root.check(popup.progress > 0 && popup.editorLoaded && popup.displayedSection === "cache", "cache close retains content until slide completes")
                    var progress = popup.progress
                    var editor = find(popup, "wallpaper-settings-scroll")
                    workspace.item.browserItem.settingsSection = "cache"
                    root.check(popup.progress === progress && find(popup, "wallpaper-settings-scroll") === editor, "cache reopen reverses the same editor without a jump")
                    root.check(WallpaperSettingsStore.values.proxy.maxCacheMiB === cacheDraftValue, "cache reopen preserves its draft")
                    hold = 3
                    return
                }
                if (hold === 3) {
                    if (popup.progress !== 1 || popup.animating) return
                    find(popup, "wallpaper-section-close").clicked()
                    hold = 4
                    return
                }
                if (popup.progress !== 0 || popup.editorLoaded || popup.displayedSection) return
                root.check(sawSettingsOpen && sawSettingsClose, "cache menu animates on independent open and close")
                root.check(WallpaperSettingsStore.values.proxy.maxCacheMiB === cacheDraftValue, "unloading the cache editor preserves unsaved preferences")
                WallpaperSettingsStore.discard()
                root.screenshot("workspace-" + layout)
                workspace.item.browserItem.forceActiveFocus()
                if (!artifact) keyboard.write("key 1\n")
            } else if (phase === 3) {
                if (workspace.active) return
                if (!quick.active) {
                    root.check(UiState.wallpaperPresentation === "closed" && sawWorkspaceSlideOut, "Escape slides workspace down before release")
                    root.check(WallpaperLibrary.selectedPath === selectedPath, "workspace close retains browsing state")
                    root.check(tasks.instances.every(task => task.active === (layout === 1)), "normal Taskbars remain active after close")
                    root.check(bars.instances.every(bar => bar.visible === (layout === 0)), "normal TopBars remain visible after close")
                    orbitSelection = ""
                    UiState.openWallpaperQuick(output.name)
                    return
                }
                if (quick.item.expansion !== 1 || find(quick.item.browserItem, "wallpaperReel").introRunning) return
                root.screenshot("simple-" + layout)
                if (!artifact) UiState.closeWallpaper()
            } else if (phase === 4) {
                if (layout === 0 ? quick.item.selectedPulse <= 1 : quick.item.quickOpacity >= 1) return
                var previous = quick.item
                var progress = previous.expansion
                var opacity = previous.quickOpacity
                var pulse = previous.selectedPulse
                var scale = previous.quickScale
                UiState.toggleWallpaperQuick(output.name)
                root.check(quick.item === previous && quick.item.expansion === progress && quick.item.quickOpacity === opacity && quick.item.selectedPulse === pulse && quick.item.quickScale === scale,
                    "reopen reverses the pulse or final fade without snapping")
            } else if (phase === 5) {
                if (!quick.active || quick.item.expansion !== 1 || quick.item.stackSpread !== 1 || quick.item.selectedPulse !== 1 || quick.item.quickOpacity !== 1 || quick.item.quickScale !== 1) return
                root.check(WallpaperLibrary.selectedPath === selectedPath, "interrupted close retains session")
                quickCloseAt = Date.now()
                sawFarZoom = false
                sawZoomBeforeFade = false
                sawClosePulse = false
                sawSlowFade = false
                sawPulseOverlap = false
                sawImmediatePulse = false
                fadeStartedAt = 0
                sawSlowFold = false
                UiState.closeWallpaper()
            } else if (phase === 6) {
                if (quick.active || workspace.active) return
                root.check(UiState.wallpaperPresentation === "closed", "close releases state and visuals")
                root.check(Date.now() - quickCloseAt >= 800 && Date.now() - quickCloseAt < 1200 && sawSlowFold && sawClosePulse && sawPulseOverlap && sawImmediatePulse && sawFarZoom && sawZoomBeforeFade && sawSlowFade && Date.now() - fadeStartedAt >= 250,
                    "quick close pulses immediately with the fold, connects into zoom and fades slowly: " + JSON.stringify({elapsed: Date.now() - quickCloseAt, slowFold: sawSlowFold, pulse: sawClosePulse, immediate: sawImmediatePulse, overlap: sawPulseOverlap, zoom: sawFarZoom, fade: sawSlowFade, fadeElapsed: Date.now() - fadeStartedAt}))
                if (++layout < 2) { sawClosing = false; sawFold = false; phase = 0; return }
                orbitSelection = ""
                UiState.openWallpaperQuick(output.name)
            } else if (phase === 7) {
                if (!quick.active || quick.item.expansion !== 1) return
                UiState.openWallpaperWorkspace(Quickshell.screens[0].name)
            } else if (phase === 8) {
                if (quick.active || !workspaces.instances[0].active || workspaces.instances[0].item.expansion !== 1) return
                root.check(UiState.wallpaperWorkspaceActiveFor(Quickshell.screens[0].name) && !UiState.wallpaperWorkspaceActiveFor(output.name), "transfer replaces output ownership")
                root.check(tasks.instances.every(task => task.active), "output transfer preserves both underlying Taskbars")
                var wide = workspaces.instances[0].item.browserItem
                root.checkToolbar(wide.topInputItem, wide)
                var wideReel = find(wide, "wallpaperReel")
                var wideBody = find(wide, "wallpaperBottomPanel")
                root.check(Math.abs(wideReel.currentItem.mapToItem(wide, 0, 0).y - wideBody.y - wide.panelTopPadding) < 1, "raised selection also fits the wider output")
                root.check(wideReel.currentItem.mapToItem(wide, wideReel.cardWidth, wideReel.cardWidth * 9 / 16).y > Quickshell.screens[0].height - ScreenGeometry.taskbarHeight, "wider output also uses the bottom rail")
                UiState.closeWallpaper()
            } else if (phase === 9) {
                if (workspaces.instances[0].active) return
                root.check(births === deaths, "all quick visual owners released")
                orbitSelection = ""
                UiState.openWallpaperQuick(output.name)
            } else if (phase === 10) {
                if (!quick.active || quick.item.expansion !== 1) return
                var openingReel = find(quick.item.browserItem, "wallpaperReel")
                var side = openingReel.currentItem.parent.children.find(item => item.wallpaper !== undefined && !item.chosen && item.visible)
                var beforeClose = side.mapToItem(openingReel, side.width / 2, side.height / 2)
                UiState.closeWallpaper()
                var afterClose = side.mapToItem(openingReel, side.width / 2, side.height / 2)
                root.check(Math.abs(beforeClose.x - afterClose.x) < 1 && !openingReel.introRunning, "closing freezes an interrupted orbit without a jump")
            } else if (phase === 11) {
                if (!quick.active || quick.item.expansion <= 0 || quick.item.expansion >= 1) return
                memory.reloaded = true
                Quickshell.reload(false)
                return
            } else if (phase === 20) {
                root.check(!quick.active && !workspace.active && UiState.wallpaperPresentation === "closed", "reload releases interrupted owner")
                UiState.openWallpaperQuick(output.name)
            } else if (phase === 21) {
                if (!quick.active || quick.item.expansion !== 1 || !quick.item.browserItem.interactionReady) return
                WallpaperLibrary.filter = "static"
                WallpaperLibrary.query = "forest"
                selectedPath = WallpaperLibrary.selectedPath
                root.check(!!WallpaperLibrary.selected && WallpaperLibrary.selected.label.includes("forest"), "search selects a surviving wallpaper before Enter")
                quick.item.browserItem.forceActiveFocus()
                keyboard.write("key 28\n")
            } else if (phase === 22) {
                if (WallpaperService.busy || WallpaperService.current.path !== selectedPath) return
                root.check(WallpaperService.current.kind === "static", "Enter explicitly applies the selected image")
                root.check(UiState.wallpaperCloseRequested || UiState.wallpaperPresentation === "closed", "mode 1 closes as soon as Apply is accepted")
            } else if (phase === 23) {
                if (quick.active) return
                console.info("Wallpaper presentation checks passed")
                Qt.quit()
            }
            ++phase
        }
    }
}
