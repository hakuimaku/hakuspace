import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // Drive the real panel while keeping mutations inside the runner's private home.
    property int phase: 0
    property int ticks: 0
    property bool capturing: false
    property string captureName: ""
    property var captureAction: null
    property string chosenFont: ""
    property int consumerIndex: 0
    // Preserve each navigation edge's originating button for reverse morph checks.
    property var themeSeed: null
    property var nestedSeed: null
    // Exercise held mouse presses across every visible Theme category.
    property int themeIndex: 0
    // Sample rendered fade states in both directions of submenu navigation.
    property string observedPhase: "closed"
    property real phaseStartedAt: 0
    property int fadeOutFrames: 0
    property int fadeInFrames: 0
    property int forwardFadeChecks: 0
    property int backFadeChecks: 0
    // Cover every reachable submenu and each way a running transition can be interrupted.
    property int navigationIndex: 0
    property int interruptionIndex: 0
    // Observe the first hover after returning, including intermediate movement frames.
    property var mousePill: null
    property real mouseMoveStartedAt: 0
    property int mouseTweenFrames: 0
    // Move one pixel per event to catch pointer thresholds that never accumulate.
    property real slowPointerX: 0
    property real slowPointerY: 0
    property real slowPointerEndY: 0
    readonly property var navigationCases: [
        { flow: "theme", index: 0, title: "Change Font" },
        { flow: "theme", index: 1, title: "Change Font Size" },
        { flow: "theme", index: 2, title: "Change Accent Color" },
        { flow: "theme", index: 3, title: "Niri Animation" },
        { flow: "record", index: 1, title: "Select Microphone" },
        { flow: "power", index: 5, title: "Exit Session" },
        { flow: "niriAnimation", index: 0, title: "Window Open Animation" },
        { flow: "niriAnimation", index: 1, title: "Window Close Animation" }
    ]
    readonly property var interruptionCases: [
        { direction: "forward", action: "reopen", title: "Change Font Size", depth: 2 },
        { direction: "back", action: "reopen", title: "Change Theme", depth: 1 },
        { direction: "forward", action: "switch", flow: "record", title: "Screen Recording", depth: 1 },
        { direction: "back", action: "switch", flow: "power", title: "Power Menu", depth: 1 },
        { direction: "forward", action: "close", depth: 0 },
        { direction: "back", action: "close", depth: 0 },
        { direction: "opening", action: "reopen", title: "Change Theme", depth: 1 },
        { direction: "opening", action: "switch", flow: "clipboard", title: "Clipboard History", depth: 1 },
        { direction: "opening", action: "close", depth: 0 }
    ]
    readonly property var consumers: ["record", "power", "exit", "clipboard", "shortcut", "niriAnimation"]
    readonly property var surface: find(panel.contentItem, item => item.navStack !== undefined)
    readonly property var page: surface && surface.navStack.length ? surface.navStack[surface.navStack.length - 1].pageItem : null
    ActionMenuPanel { id: panel; modelData: Quickshell.screens[0] }
    Process { id: keyboard; command: ["python3", Quickshell.env("THEME_TEST_ROOT") + "/wayland_keyboard.py"]; stdinEnabled: true; running: true }
    Process { id: pointer; command: ["python3", Quickshell.env("THEME_TEST_ROOT") + "/wayland_pointer.py"]; stdinEnabled: true; running: true }

    // Fail with a phase number so assertions remain visible in captured logs.
    function check(ok, message) {
        if (ok) return
        console.error("Theme Action Menu failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        for (var child of item.children || []) {
            var result = find(child, predicate)
            if (result) return result
        }
        return null
    }
    // Capture the panel surface without recording other desktop content.
    function capture(name, action) {
        capturing = true
        captureName = name
        captureAction = action
        captureDelay.restart()
    }
    function openTheme() { UiState.openActionMenu(panel.modelData.name, "theme") }

    // Compare the reverse carrier's destination with the button that opened its page.
    function checkReturnSeed(seed) {
        root.check(Math.abs(surface.morphSeedScreenX - seed.screenX) < 1
            && Math.abs(surface.morphSeedScreenY - seed.screenY) < 1
            && Math.abs(surface.morphSeedWidth - seed.width) < 1
            && Math.abs(surface.morphSeedHeight - seed.height) < 1,
            "reverse morph returns to " + seed.label + " at " + seed.screenX + "," + seed.screenY
            + "; got " + surface.morphSeedScreenX + "," + surface.morphSeedScreenY)
    }

    // Verify that the visible selection settles at the reverse carrier's destination.
    function checkPillPosition(seed) {
        var pill = root.find(root.page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
        var point = pill.mapToItem(null, 0, 0)
        root.check(Math.abs(point.x - seed.screenX) < 1 && Math.abs(point.y - seed.screenY) < 1
            && Math.abs(pill.width - seed.width) < 1 && Math.abs(pill.height - seed.height) < 1,
            seed.label + " pill settles at its original bounds")
    }

    // Compare painted selection bounds to the untransformed target after layout and scrolling.
    function checkSelectionGeometry(page) {
        var pill = root.find(page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
        if (!pill || !pill.shown) return
        var target = pill.targetItem
        var point = target.parent.mapToItem(pill.parent, target.x, target.y)
        root.check(Math.abs(pill.x - point.x) < 1 && Math.abs(pill.y - point.y) < 1
            && Math.abs(pill.width - target.width) < 1 && Math.abs(pill.height - target.height) < 1,
            page.title + " selection matches its layout target")
    }

    // Send real pointer events to the private output, including held button states.
    function pointAt(item, button, state) {
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " "
            + panel.modelData.width + " " + panel.modelData.height + " " + button
            + (state === undefined ? "" : " " + state) + "\n")
    }

    // Record settled controls after the selection pill finishes moving.
    Timer {
        id: captureDelay
        interval: Math.round(HAnimation.spatial * HAnimation.trailFactor) + 50
        onTriggered: root.surface.grabToImage(result => {
            var pill = root.find(root.page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
            if (pill && pill.shown) root.check(pill.opacity > 0.99, "settled page restores the selection pill")
            root.checkSelectionGeometry(root.page)
            root.check(result.saveToFile(Quickshell.env("THEME_ARTIFACT_DIR") + "/" + root.captureName + ".png"), "save frame")
            var action = root.captureAction
            root.captureAction = null
            root.capturing = false
            if (action) action()
        })
    }

    // Observe animation frames without changing production timing or pill geometry.
    Timer {
        interval: 16; repeat: true; running: true
        onTriggered: {
            if (!root.surface) return
            var phase = root.surface.phase
            if (phase !== root.observedPhase) {
                root.observedPhase = phase
                root.phaseStartedAt = Date.now()
            }
            if (phase === "morphing-forward" || phase === "morphing-back") {
                var carrier = root.find(root.surface, item => item.morphX !== undefined)
                root.check(Qt.colorEqual(carrier.color, Theme.surface), "carrier keeps a neutral background")
                root.check(!root.find(carrier, item => item.text !== undefined && item.text.length > 0), "carrier does not duplicate button text")
                for (var page of [root.surface.activeMorphParent, root.surface.activeMorphChild]) {
                    var pill = root.find(page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
                    if (!pill) continue
                    if (pill.opacity > 0.01 && pill.opacity < 0.99) ++root.fadeOutFrames
                    if (Date.now() - root.phaseStartedAt > pill.fadeDuration + 60) {
                        root.check(pill.opacity < 0.01, "selection pill fades out during " + phase)
                        var selected = pill.targetItem
                        if (selected && selected.contentForeground !== undefined) {
                            root.check(Qt.colorEqual(selected.contentForeground, selected.danger ? "#ff6b6b" : Theme.fg),
                                "hidden pill restores readable foreground")
                        }
                        if (phase === "morphing-forward") ++root.forwardFadeChecks
                        else ++root.backFadeChecks
                    }
                }
            } else if (phase === "ready") {
                var current = root.find(root.page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
                if (current && current.shown && current.opacity > 0.01 && current.opacity < 0.99) ++root.fadeInFrames
                if (root.phase === 53 && current === root.mousePill && root.page.selectedIndex === 2
                    && (Math.abs(current.y - current.targetY) > 1 || Math.abs(current.height - current.targetHeight) > 1)) ++root.mouseTweenFrames
            }
        }
    }

    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 1150, "runtime timeout")
            if (root.capturing || ShellSettingsStore.loading) return
            if (root.phase !== 0 && panel.panelOpen && root.surface.phase !== "ready") return
            var page = root.page
            if (root.phase === 0) {
                WM.backendName = "hyprland"
                root.openTheme()
            } else if (root.phase === 1) {
                if (Quickshell.env("THEME_POINTER_ONLY") === "1") { root.phase = 50; return }
                root.check(page && page.items.length === 3, "Hikai offers font, size and accent only")
                root.check(page.items.every(item => item.id !== "rofi" && item.id !== "waybar"), "no Classic theme entries")
                var button = root.find(page, item => item.label === "Font family")
                var label = root.find(button, item => item.text === "Font family" && item.font !== undefined)
                root.check(button && label && label.font.pixelSize === Theme.fontSize && button.radius === Theme.radius, "shared typography and radius")
                root.check(button.targetBackground.a === 0, "shared pill owns selection background")
                root.capture("theme", function() { keyboard.write("key 28\n") })
            } else if (root.phase === 2) {
                if (!page || page.title !== "Change Font" || page.loading) return
                root.check(page.filteredFonts.length > 1, "fonts load through the theme controller")
                var search = root.find(page, item => item.Accessible && item.Accessible.name === "Search fonts")
                root.check(search && search.font.pixelSize === Theme.fontSize - 1, "font search uses shell text sizing")
                search.text = "no-such-font-fixture"
                root.check(page.filteredFonts.length === 0, "font search can be empty")
                search.text = ""
                page.forceActiveFocus()
                keyboard.write("key 108\n")
            } else if (root.phase === 3) {
                if (page.selectedIndex !== 1) return
                root.chosenFont = page.filteredFonts[1]
                root.capture("theme-font", function() { keyboard.write("key 28\n") })
            } else if (root.phase === 4) {
                if (panel.panelOpen || Theme.fontFamily !== root.chosenFont) return
                root.openTheme()
            } else if (root.phase === 5) {
                page.activateIndex(1)
            } else if (root.phase === 6) {
                root.check(page.title === "Change Font Size" && root.surface.canGoBack, "size submenu opens")
                root.capture("theme-size", function() { keyboard.write("key 1\n") })
            } else if (root.phase === 7) {
                if (root.surface.canGoBack) return
                root.check(page.items.length === 3, "Escape returns to theme categories")
                page.activateIndex(1)
            } else if (root.phase === 8) {
                var size = root.find(page, item => item.label === "16 px")
                root.check(size, "readable font size labels")
                size.clicked()
            } else if (root.phase === 9) {
                if (panel.panelOpen || Theme.fontSize !== 16) return
                root.openTheme()
            } else if (root.phase === 10) {
                page.activateIndex(2)
            } else if (root.phase === 11) {
                root.check(page.title === "Change Accent Color", "accent submenu opens")
                var hex = root.find(page, item => item.Accessible && item.Accessible.name === "Custom accent color")
                root.check(hex && hex.clip && hex.font.pixelSize === Theme.fontSize - 1, "custom accent input keeps shell styling and clips text")
                root.capture("theme-accent", function() { hex.text = "#7288AE"; hex.accepted() })
            } else if (root.phase === 12) {
                if (panel.panelOpen || Theme.accent.toLowerCase() !== "#7288ae") return
                WM.backendName = "niri"
                root.openTheme()
            } else if (root.phase === 13) {
                root.check(page.items.length === 4 && page.items[3].id === "niriAnimation", "Niri option is contextual")
                root.capture("theme-niri", function() {
                    page.selectedIndex = 3
                    WM.backendName = "hyprland"
                    root.check(page.items.length === 3 && page.selectedIndex === 2, "context changes keep selection in range")
                    WM.backendName = "niri"
                    UiState.closeActionMenu()
                })
            } else if (root.phase === 14) {
                if (panel.panelOpen) return
                root.openTheme()
            } else if (root.phase === 15) {
                page.selectedIndex = 3
                var origin = root.find(page, item => item.label === "Niri Animation")
                root.themeSeed = origin.getSurfaceGeometry()
                page.activateCurrent()
            } else if (root.phase === 16) {
                if (page.loading) return
                root.check(page.title === "Niri Animation" && page.modes.length === 2, "nested navigation fixture loads")
                var nested = root.find(page, item => item.label === "Window Open Animation")
                root.nestedSeed = nested.getSurfaceGeometry()
                page.activateCurrent()
            } else if (root.phase === 17) {
                root.check(root.surface.navStack.length === 3, "three navigation layers are retained")
                root.surface.popPage()
                root.checkReturnSeed(root.nestedSeed)
            } else if (root.phase === 18) {
                root.surface.popPage()
                root.checkReturnSeed(root.themeSeed)
            } else if (root.phase === 19) {
                root.check(page.title === "Change Theme" && page.selectedIndex === 3, "nested return restores the original selection")
                root.capture("theme-nested-return", function() { UiState.closeActionMenu() })
            } else if (root.phase === 20) {
                if (panel.panelOpen) return
                // Smoke shared page/surface consumers without executing their actions.
                UiState.openActionMenu(panel.modelData.name, root.consumers[root.consumerIndex])
            } else if (root.phase === 21) {
                if (!page || page.loading) return
                root.check(page.width > 0 && page.height > 0, "shared consumer has content bounds")
                root.check(page.width <= root.surface.width && page.height <= root.surface.height, "shared consumer fits its surface")
                if (root.consumers[root.consumerIndex] === "power") { root.phase = 28; return }
                root.capture("consumer-" + root.consumers[root.consumerIndex], function() { UiState.closeActionMenu() })
            } else if (root.phase === 22) {
                if (panel.panelOpen) return
                if (++root.consumerIndex < root.consumers.length) { root.phase = 20; return }
                WM.backendName = "hyprland"
                root.openTheme()
            } else if (root.phase === 23) {
                var button = root.find(page, item => item.label === page.items[root.themeIndex].label)
                root.pointAt(button, 0)
            } else if (root.phase === 24) {
                if (page.selectedIndex !== root.themeIndex) return
                root.capture("theme-origin-" + root.themeIndex, function() {
                    var pill = root.find(root.page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
                    var point = pill.mapToItem(null, 0, 0)
                    root.themeSeed = { screenX: point.x, screenY: point.y, width: pill.width, height: pill.height, label: root.page.items[root.themeIndex].label }
                    root.pointAt(pill.targetItem, 272, 1)
                })
            } else if (root.phase === 25) {
                var pressed = root.find(page, item => item.label === page.items[root.themeIndex].label)
                if (!pressed.pressed || pressed.scale >= 1) return
                root.pointAt(pressed, 272, 0)
            } else if (root.phase === 26) {
                if (!root.surface.canGoBack) return
                keyboard.write("key 1\n")
            } else if (root.phase === 27) {
                root.checkReturnSeed(root.themeSeed)
                root.check(page.selectedIndex === root.themeIndex, "return keeps the originating category selected")
                root.capture("theme-return-" + root.themeIndex, function() {
                    root.checkPillPosition(root.themeSeed)
                    if (++root.themeIndex < root.page.items.length) { root.phase = 23; return }
                    root.check(root.fadeOutFrames > 0 && root.fadeInFrames > 0
                        && root.forwardFadeChecks > 0 && root.backFadeChecks > 0, "pills fade in and out across forward and reverse morphs")
                    WM.backendName = "niri"
                    root.phase = 32
                })
                return
            } else if (root.phase === 28) {
                page.selectedIndex = 5
                root.capture("consumer-power", function() {
                    var powerPill = root.find(root.page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
                    var powerPoint = powerPill.mapToItem(null, 0, 0)
                    root.themeSeed = { screenX: powerPoint.x, screenY: powerPoint.y, width: powerPill.width, height: powerPill.height, label: "Logout" }
                    root.pointAt(powerPill.targetItem, 272, 1)
                })
            } else if (root.phase === 29) {
                var powerButton = root.find(page, item => item.targetItem !== undefined && item.syncTarget !== undefined).targetItem
                if (!powerButton.pressed || powerButton.scale >= 1) return
                root.pointAt(powerButton, 272, 0)
            } else if (root.phase === 30) {
                root.check(root.surface.currentProfile === "exitReport", "Logout morph changes the surface profile")
                root.surface.popPage()
                root.checkReturnSeed(root.themeSeed)
            } else if (root.phase === 31) {
                root.check(root.surface.currentProfile === "powerHorizontal" && page.selectedIndex === 5, "reverse morph restores Power layout")
                root.capture("consumer-power-return", function() { root.checkPillPosition(root.themeSeed); UiState.closeActionMenu() })
                root.phase = 22
                return
            } else if (root.phase === 32) {
                if (panel.panelOpen) { UiState.closeActionMenu(); return }
                UiState.openActionMenu(panel.modelData.name, root.navigationCases[root.navigationIndex].flow)
            } else if (root.phase === 33) {
                if (page.loading) return
                var firstPill = root.find(page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
                root.pointAt(firstPill.targetItem, 0)
            } else if (root.phase === 34) {
                page.forceActiveFocus()
                var entry = root.navigationCases[root.navigationIndex]
                keyboard.write("key 102\n" + ("key " + (entry.flow === "power" ? 106 : 108) + "\n").repeat(entry.index))
            } else if (root.phase === 35) {
                var entry = root.navigationCases[root.navigationIndex]
                if (page.selectedIndex !== entry.index) return
                root.capture("matrix-origin-" + root.navigationIndex, function() {
                    var pill = root.find(root.page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
                    var point = pill.mapToItem(null, 0, 0)
                    root.themeSeed = { screenX: point.x, screenY: point.y, width: pill.width, height: pill.height, label: "matrix " + root.navigationIndex }
                    if (root.navigationIndex % 3 === 0) root.pointAt(pill.targetItem, 272)
                    else if (root.navigationIndex % 3 === 1) keyboard.write("key 28\n")
                    else pointer.write("10 10 " + panel.modelData.width + " " + panel.modelData.height + " 274\n")
                })
            } else if (root.phase === 36) {
                if (root.surface.navStack.length < 2) return
                if (page.loading) return
                root.check(page.title === root.navigationCases[root.navigationIndex].title,
                    "matrix " + root.navigationIndex + " opens " + root.navigationCases[root.navigationIndex].title + "; got " + page.title)
                root.check(root.surface.navStack[0].pageItem.selectedIndex === root.navigationCases[root.navigationIndex].index,
                    "stationary pointer does not change the source selection")
                page.forceActiveFocus()
                keyboard.write("key 107\n")
            } else if (root.phase === 37) {
                root.capture("matrix-child-" + root.navigationIndex, function() { keyboard.write("key 1\n") })
            } else if (root.phase === 38) {
                if (root.surface.canGoBack) return
                root.check(root.surface.navStack.length === 1, "Escape returns one navigation edge")
                root.check(page.selectedIndex === root.navigationCases[root.navigationIndex].index, "stationary pointer preserves the return selection")
                root.checkReturnSeed(root.themeSeed)
                root.capture("matrix-return-" + root.navigationIndex, function() {
                    root.checkPillPosition(root.themeSeed)
                    console.log("PASS navigation: " + JSON.stringify(root.navigationCases[root.navigationIndex]))
                    root.phase = ++root.navigationIndex < root.navigationCases.length ? 32 : 39
                })
                return
            } else if (root.phase === 39) {
                if (panel.panelOpen) { UiState.closeActionMenu(); return }
                root.openTheme()
                if (root.interruptionCases[root.interruptionIndex].direction === "opening") interruptTimer.restart()
            } else if (root.phase === 40) {
                if (root.interruptionCases[root.interruptionIndex].direction === "opening") { root.phase = 42; return }
                page.activateIndex(1)
                if (root.interruptionCases[root.interruptionIndex].direction === "forward") interruptTimer.restart()
            } else if (root.phase === 41) {
                if (root.interruptionCases[root.interruptionIndex].direction === "back") {
                    root.surface.popPage()
                    interruptTimer.restart()
                }
            } else if (root.phase === 42) {
                var entry = root.interruptionCases[root.interruptionIndex]
                if (entry.action === "close") {
                    if (panel.panelOpen) return
                    root.check(root.surface.navStack.length === 0, "interrupted close releases all pages")
                    console.log("PASS interruption: " + JSON.stringify(entry))
                    root.phase = ++root.interruptionIndex < root.interruptionCases.length ? 39 : 43
                    return
                }
                root.check(page.title === entry.title && root.surface.navStack.length === entry.depth, "interrupted transition restores the right page")
                root.check(root.surface.openProgress === 1 && root.surface.openOpacity === 1 && root.surface.openScale === 1,
                    "reopened layer completes its opening reveal")
                root.capture("interruption-" + root.interruptionIndex, function() {
                    console.log("PASS interruption: " + JSON.stringify(root.interruptionCases[root.interruptionIndex]))
                    root.phase = ++root.interruptionIndex < root.interruptionCases.length ? 39 : 43
                })
                return
            } else if (root.phase === 43) {
                root.phase = 50
                return
            } else if (root.phase === 50) {
                if (!page || page.title !== "Change Theme") {
                    if (panel.panelOpen) { UiState.closeActionMenu(); return }
                    root.openTheme()
                    return
                }
                page.activateIndex(1)
            } else if (root.phase === 51) {
                if (!root.surface.canGoBack) return
                root.surface.popPage()
            } else if (root.phase === 52) {
                if (root.surface.canGoBack) return
                root.mousePill = root.find(page, item => item.targetItem !== undefined && item.syncTarget !== undefined)
                root.check(root.mousePill.absoluteInitialized, "returning page initializes selection before its first hover")
                root.mouseMoveStartedAt = Date.now()
                root.pointAt(root.find(page, item => item.label === "Accent color"), 0)
            } else if (root.phase === 53) {
                if (Date.now() - root.mouseMoveStartedAt < HAnimation.selectionMorphDuration + 100) return
                root.check(page.selectedIndex === 2 && root.mouseTweenFrames > 0, "first mouse hover interpolates instead of snapping")
                root.capture("mouse-first-hover-after-return", null)
            } else if (root.phase === 54) {
                root.pointAt(root.find(page, item => item.label === "Font family"), 0)
            } else if (root.phase === 55) {
                root.pointAt(root.find(page, item => item.label === "Accent color"), 0)
                root.capture("mouse-rapid-reversal", null)
            } else if (root.phase === 56) {
                root.check(page.selectedIndex === 2, "rapid pointer reversal settles on its last row")
                var selectedPoint = root.mousePill.targetItem.mapToItem(null, root.mousePill.targetItem.width / 2, root.mousePill.targetItem.height / 2)
                var first = root.find(page, item => item.label === "Font family")
                root.slowPointerX = selectedPoint.x
                root.slowPointerY = selectedPoint.y
                root.slowPointerEndY = first.mapToItem(null, first.width / 2, first.height / 2).y
                slowPointerTimer.start()
            } else if (root.phase === 57) {
                if (slowPointerTimer.running) return
                root.check(page.selectedIndex === 0, "one-pixel pointer events select the row reached by slow motion")
                root.capture("mouse-slow-hover", function() {
                    console.log("PASS pointer: intermediate frames=" + root.mouseTweenFrames + ", rapid reversal and one-pixel motion")
                    console.log("Theme Action Menu checks passed")
                    Qt.quit()
                })
                return
            }
            ++root.phase
        }
    }

    // Interrupt real running animations instead of forcing their progress values.
    Timer {
        id: interruptTimer
        interval: 100
        onTriggered: {
            var entry = root.interruptionCases[root.interruptionIndex]
            if (entry.action === "switch") UiState.openActionMenu(panel.modelData.name, entry.flow)
            else {
                UiState.closeActionMenu()
                if (entry.action === "reopen") reopenTimer.restart()
            }
        }
    }
    Timer { id: reopenTimer; interval: 100; onTriggered: root.openTheme() }
    Timer {
        id: slowPointerTimer
        interval: 8; repeat: true
        onTriggered: {
            root.slowPointerY = Math.max(root.slowPointerEndY, root.slowPointerY - 1)
            pointer.write(Math.round(root.slowPointerX) + " " + Math.round(root.slowPointerY) + " "
                + panel.modelData.width + " " + panel.modelData.height + " 0\n")
            if (root.slowPointerY <= root.slowPointerEndY) stop()
        }
    }
}
