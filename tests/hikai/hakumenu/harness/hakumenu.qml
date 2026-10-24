import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // Drive real input against disposable output surfaces and launcher fixtures.
    property var outputs: []
    property int phase: 0
    property int ticks: 0
    property int clientClicks: 0
    property string launched: ""
    property var expectedAnchor: null
    property real floatingWidth: 0
    property real clientHeight: 0
    property bool reversed: false
    property var transferOutput: null
    property int revealAttempts: 0
    property int initialEnterAttempts: 0
    property var crowdedAnchor: null
    property bool crowdedReady: false
    property bool openingProbeObserved: false
    property bool openingInputObserved: false
    property var openingPanel: phase === 12 || phase === 13 ? floating() : null
    property int tooltipClicks: 0
    readonly property var output: outputs.find(function(surface) { return surface.modelData.name === "HEADLESS-1" }) || outputs[0] || null
    // Isolate tooltip gestures from unrelated fullscreen-client checks on a live desktop.
    Component.onCompleted: if (Quickshell.env("HAKUSPACE_DOCK_TOOLTIP") === "1") {
        phase = 40
        toggleDock()
    }
    FloatingWindow {
        id: client
        screen: Quickshell.screens.find(function(screen) { return screen.name === "HEADLESS-1" }) || Quickshell.screens[0]
        title: "HakuMenu client fixture"
        visible: true
        maximized: true
        color: "#597987"
        MouseArea { anchors.fill: parent; onClicked: root.clientClicks++ }
    }
    FloatingWindow {
        id: fullscreenClient
        screen: client.screen
        title: "HakuMenu fullscreen fixture"
        fullscreen: true
        visible: false
        color: "#597987"
        MouseArea { anchors.fill: parent; onClicked: root.clientClicks++ }
    }
    Process {
        id: pointer
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_POINTER")]
        running: true; stdinEnabled: true
        stderr: StdioCollector { id: pointerError }
        onExited: code => root.check(code === 0, "pointer: " + pointerError.text)
    }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]
        running: true; stdinEnabled: true
        stderr: StdioCollector { id: keyboardError }
        onExited: code => root.check(code === 0, "keyboard: " + keyboardError.text)
    }
    Process { id: writer; onExited: code => root.check(code === 0, "fixture process") }
    Process { id: captureProcess; onExited: code => root.check(code === 0, "screenshot capture") }
    FileView {
        path: Quickshell.env("HAKUSPACE_TEST_LAUNCH_LOG")
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onTextChanged: root.launched = text().trim()
    }
    // Locate composed controls through their existing Qt object tree.
    function content(host) {
        return find(host, function(item) { return typeof item.activationSource === "string" && typeof item.menuAnchor === "function" })
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active === true && item.item) {
            var loaded = find(item.item, predicate)
            if (loaded) return loaded
        }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var index = 0; index < children.length; ++index) {
            var result = find(children[index], predicate)
            if (result) return result
        }
        return null
    }
    // Fail the process with an actionable input phase.
    function check(ok, message) {
        if (ok) return
        console.error("Hikai HakuMenu failed: phase " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Send coordinates local to the virtual pointer's first mapped output.
    function move(x, y, button) {
        pointer.write([Math.round(x), Math.round(y), output.modelData.width, output.modelData.height, button || 0].join(" ") + "\n")
    }
    function key(code) { keyboard.write("key " + code + "\n") }
    function type(text) { keyboard.write("text " + text + "\n") }
    function search() { return find(output.menu, function(item) { return item.objectName === "hakumenu-searchInput" && item.activeFocus }) }
    function floating(surface) { return find((surface || output).menu, function(item) { return typeof item.morphProgress === "number" }) }
    function appHost(surface) { return ChromeLayout.taskbarMode ? (surface || output).taskbar : (surface || output).dock }
    function appMenu(surface) { return find(appHost(surface), function(item) { return item.label === "Applications" }) }
    // Dock windows have side margins and a bounded bottom host; item maps include scrolling.
    function clickAppMenu() {
        var item = appMenu()
        expectedAnchor = root.content(appHost()).menuAnchor(item)
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        var window = item.Window.window
        move((ChromeLayout.taskbarMode ? 0 : output.dock.sideInset) + point.x, output.modelData.height - window.height + point.y, 272)
    }
    // Stress focus restoration while the floating menu reverses its animation.
    Timer {
        id: tooltipBurst
        interval: 100
        repeat: true
        onTriggered: {
            var tooltips = root.dockTooltips()
            root.check(tooltips.length <= 1, "rapid menu toggles never leave competing Dock tooltips")
            if (root.output.dock.hakuMenuDockLease)
                root.check(tooltips.length === 0, "floating menu suppresses Dock tooltips")
            if (++root.tooltipClicks <= 12) root.clickAppMenu()
            else {
                stop()
                UiState.closeHakuMenu()
                var trash = root.find(root.output.dock, function(item) { return item.label === "Trash" })
                var point = trash.mapToItem(null, trash.width / 2, trash.height / 2)
                root.move(root.output.dock.sideInset + point.x, root.output.modelData.height - root.output.dock.targetHeight - 180 + point.y)
            }
        }
    }
    // Collect visible Dock tooltips through the real composed object tree.
    function dockTooltips() {
        var tooltips = []
        find(output.dock, function(item) {
            if (item.immediate === true && item.target && typeof item.target.iconLift === "number" && item.visible)
                tooltips.push(item)
            return false
        })
        return tooltips
    }
    function toggleDock() {
        writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash", Quickshell.env("HAKUSPACE_TEST_DOCKBAR_CTL"), "--toggle"]
        writer.running = true
    }
    // Exercise Taskbar file watching independently of compact Dockbar state.
    function toggleTaskbar() {
        writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash", Quickshell.env("HAKUSPACE_TEST_TASKBAR_CTL"), "--toggle"]
        writer.running = true
    }
    // Probe the first fully revealed frame while the opening bounce still runs.
    Connections {
        target: root.openingPanel
        function onRevealProgressChanged() {
            if (root.phase === 13 && !root.openingProbeObserved && root.floating().revealProgress === 1) openingProbe.restart()
        }
    }
    Timer {
        id: openingProbe
        interval: 16
        onTriggered: {
            root.openingProbeObserved = true
            var panel = root.floating()
            var searchBox = root.find(panel, function(item) { return item.objectName === "hakumenu-searchBox" })
            var row = root.find(panel, function(item) { return typeof item.disabledOpacity === "number" && item.modelData && item.modelData.name })
            root.check(panel.morphProgress > 1 && panel.interactionReady && root.search(),
                "fully revealed menu accepts input before the opening bounce finishes")
            root.check(searchBox.enabled && searchBox.opacity === 1 && row && row.enabled && row.opacity === 1,
                "revealed controls never wait for a disabled-opacity fade")
            var tab = root.find(panel, function(item) { return typeof item.clicked === "function" && item.text === "󰀻" })
            var point = tab.mapToItem(null, tab.width / 2, tab.height / 2)
            root.move(point.x, point.y, 272)
            openingClick.start()
        }
    }
    Timer {
        id: openingClick
        interval: 40
        onTriggered: {
            root.check(UiState.hakuMenuMode === "general", "tab click works during the settling bounce")
            root.type("dock")
            openingKeys.start()
        }
    }
    Timer {
        id: openingKeys
        interval: 40
        onTriggered: {
            root.check(UiState.hakuMenuQuery === "dock" && UiState.hakuMenuMode === "drun", "typing works as soon as content is revealed")
            UiState.setHakuMenuQuery("")
            root.openingInputObserved = true
        }
    }
    // Reverse before the close can finish, preserving the current scalar and seed.
    Timer {
        id: reverse
        interval: 80
        onTriggered: {
            var panel = root.floating()
            var progress = panel.morphProgress
            root.check(progress > 0 && progress < 1, "close is in progress before reversal")
            UiState.toggleHakuMenu(root.output.modelData.name, "drun", "dockbar", root.expectedAnchor)
            root.check(panel.morphProgress === progress, "reopen does not reset the scalar")
            root.reversed = true
        }
    }
    function done() { console.info("Hikai HakuMenu checks passed"); Qt.quit() }
    // Keep optional visual evidence inside an explicitly selected artifact directory.
    function capture(name) {
        var directory = Quickshell.env("HAKUSPACE_HAKUMENU_ARTIFACT_DIR")
        if (!directory) return
        captureProcess.command = ["grim", "-o", output.modelData.name, directory + "/" + name + ".png"]
        captureProcess.running = true
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: surface
            required property var modelData
            property alias menu: menu
            property alias taskbar: taskbar
            property alias dock: dock
            RoundedScreen { modelData: surface.modelData }
            Taskbar { id: taskbar; modelData: surface.modelData }
            DockBar { id: dock; modelData: surface.modelData }
            HakuMenuPanel { id: menu; modelData: surface.modelData }
            Component.onCompleted: root.outputs.push(surface)
        }
    }
    Timer {
        interval: 600
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 85, "timeout")
            if (!root.output || !ShellSettingsStore.ready || TaskbarPins.busy || writer.running || captureProcess.running) return
            var width = root.output.modelData.width
            var height = root.output.modelData.height
            if (root.phase === 0) {
                root.toggleTaskbar()
                root.move(width / 2, 1)
            }
            else if (root.phase === 1) {
                if (UiState.activePanel !== "hakumenu") {
                    root.check(!ChromeLayout.topEdgeHakuMenuEnabled, "Taskbar top hover stays disabled")
                    root.check(++root.initialEnterAttempts <= 3, "bottom App Menu receives pointer input on " + root.output.modelData.name)
                    root.clickAppMenu()
                    return
                }
                root.check(UiState.hakuMenuStyle === "bottomFlare" && UiState.hakuMenuMode === "drun" && root.search(),
                    "bottom App Menu opens Drun with search focus: " + root.output.modelData.name + " / " + UiState.hakuMenuScreenName + " / " + UiState.hakuMenuMode)
                var content = root.find(root.output.menu, function(item) { return item.controlsAtBottom === false && item.panelOpen })
                root.check(content && !content.controlsAtBottom, "Taskbar Flare controls stay at the top")
                var attached = root.find(root.output.menu, function(item) { return item.bottomAttached === true && typeof item.menuHeight === "number" })
                root.check(attached && attached.menuHeight === height * 0.4, "Taskbar attached menu occupies forty percent of the screen height")
                root.capture("bottomFlare")
                root.toggleDock()
            } else if (root.phase === 2) {
                root.check(UiState.hakuMenuMode === "drun", "Right selects Drun")
                root.type(">")
            } else if (root.phase === 3) {
                root.check(UiState.hakuMenuMode === "general" && UiState.hakuMenuQuery === ">", "typed General prefix")
                root.key(14)
                root.type("~")
            } else if (root.phase === 4) {
                root.check(UiState.hakuMenuMode === "theme" && UiState.hakuMenuQuery === "~", "typed Theme prefix")
                root.key(105)
            } else if (root.phase === 5) {
                root.check(UiState.hakuMenuMode === "drun", "Left selects Drun")
                root.key(1)
            } else if (root.phase === 6) {
                root.check(UiState.activePanel === "", "Escape closes legacy menu")
                UiState.openHakuMenu(root.output.modelData.name, "drun")
            } else if (root.phase === 7) root.type("dock launch fixture")
            else if (root.phase === 8) {
                root.check(UiState.hakuMenuMode === "drun" && UiState.hakuMenuQuery === "dock launch fixture", "ordinary typed query selects Drun")
                root.key(108)
                root.key(103)
                root.key(28)
            } else if (root.phase === 9) {
                root.check(root.launched === "launched" && UiState.activePanel === "", "keyboard selection launches a DesktopEntry and closes")
                fullscreenClient.visible = true
                UiState.openHakuMenu(root.output.modelData.name, "theme")
            } else if (root.phase === 10) {
                root.check(root.search() && UiState.hakuMenuStyle === "bottomFlare", "legacy caller focuses menu over fullscreen")
                root.key(1)
            } else if (root.phase === 11) {
                root.check(UiState.activePanel === "", "fullscreen Escape closes")
                if (Quickshell.env("HAKUSPACE_HAKUMENU_TOP_ONLY") === "1") { root.done(); return }
                fullscreenClient.visible = false
                root.toggleTaskbar()
                root.move(width / 2, height - 1)
            } else if (root.phase === 12) {
                if (!root.output.dock.shown) {
                    var hover = root.find(root.output.dock, function(item) { return typeof item.hovered === "boolean" && item.point !== undefined })
                    root.check(++root.revealAttempts <= 3, "Dock reveal after fullscreen: "
                        + root.output.modelData.name + " " + width + "x" + height
                        + " enabled=" + AppState.taskbarManualState + " fullscreen=" + fullscreenClient.visible
                        + " active=" + UiState.activePanel + " owner=" + UiState.hakuMenuScreenName
                        + " hover=" + (hover ? hover.hovered + " " + hover.point.position : "missing")
                        + " others=" + root.outputs.map(function(surface) { return surface.modelData.name + ":" + surface.dock.shown }))
                    root.move(width / 2 + root.revealAttempts, height - 1)
                    return
                }
                root.check(UiState.activePanel === "" && root.output.dock.shown, "bottom edge opens only Dock")
                root.clientHeight = client.height
                root.clickAppMenu()
            } else if (root.phase === 13) {
                var panel = root.floating()
                if (!panel.interactionReady || !root.openingInputObserved) return
                root.check(UiState.hakuMenuStyle === "dockFloating" && UiState.hakuMenuMode === "drun", "App Menu opens dockFloating Drun")
                root.check(root.search(), "floating search focuses after the morph: " + panel.morphProgress)
                root.check(Math.abs(UiState.hakuMenuAnchorRect.x - root.expectedAnchor.x) < 1
                    && Math.abs(UiState.hakuMenuAnchorRect.y - root.expectedAnchor.y) < 1, "captured lifted artwork anchor is screen-local")
                root.check(root.output.dock.hakuMenuDockLease && root.output.dock.shown, "owning Dock stays shown")
                root.check(panel.finalRect.x + panel.finalRect.width / 2 === width / 2
                    && panel.finalRect.y + panel.finalRect.height === height - ScreenGeometry.bottomInset - ScreenGeometry.dockbarHeight - panel.floatingGap,
                    "floating card rests above Dock with a gap")
                root.check(client.height === root.clientHeight, "floating menu reserves no client space")
                root.floatingWidth = panel.finalRect.width
                root.capture("dockFloating-drun")
                root.move(root.expectedAnchor.x + root.expectedAnchor.width / 2,
                    root.expectedAnchor.y + root.expectedAnchor.height / 2, 272)
            } else if (root.phase === 14) {
                root.check(UiState.activePanel === "" && !UiState.hakuMenuAnchorRect && !root.output.dock.hakuMenuDockLease, "second App Menu click closes and releases ownership")
                root.move(width / 2, height - 1)
            } else if (root.phase === 15) root.clickAppMenu()
            else if (root.phase === 16) {
                if (!root.floating().interactionReady) return
                root.check(root.floating().interactionReady, "floating reopens")
                UiState.closeHakuMenu()
                reverse.start()
            } else if (root.phase === 17) {
                if (!root.floating().interactionReady) return
                root.check(root.reversed && root.floating().interactionReady, "mid-close reopen settles")
                var content = root.find(root.floating(), function(item) { return typeof item.controlsAtBottom === "boolean" })
                var list = root.find(content, function(item) { return item.objectName === "hakumenu-mainList" })
                root.check(!content.controlsAtBottom && list.y > content.controlsY + content.topRowHeight, "floating controls sit above the content")
                root.key(105)
            } else if (root.phase === 18) {
                root.check(UiState.hakuMenuMode === "general" && root.floating().finalRect.width === root.floatingWidth, "General keeps the floating chassis stable")
                root.type(">")
            } else if (root.phase === 19) {
                root.check(UiState.hakuMenuMode === "general" && UiState.hakuMenuStyle === "dockFloating", "General prefix keeps presentation")
                root.key(14)
                root.type("~")
            } else if (root.phase === 20) {
                root.check(UiState.hakuMenuMode === "theme" && root.floating().finalRect.width === root.floatingWidth,
                    "Theme keeps the floating chassis stable: mode=" + UiState.hakuMenuMode
                    + " width=" + root.floating().finalRect.width + " initial=" + root.floatingWidth + " output=" + width)
                var content = root.find(root.floating(), function(item) { return typeof item.controlsAtBottom === "boolean" })
                var state = root.find(content, function(item) { return item.objectName === "hakumenu-stateRegion" })
                root.check(state.visible && state.y > content.controlsY + content.topRowHeight, "Theme state column starts below the controls")
                root.capture("dockFloating-theme")
                root.key(105)
            } else if (root.phase === 21) root.type("dock launch fixture")
            else if (root.phase === 22) root.key(28)
            else if (root.phase === 23) {
                root.check(root.launched.split("\n").length === 2 && UiState.activePanel === "", "floating Enter launches and closes")
                root.toggleDock()
            } else if (root.phase === 24) {
                UiState.openHakuMenu(root.output.modelData.name, "general", "dockbar", root.expectedAnchor)
                root.check(!UiState.activePanel, "disabled Dockbar rejects floating activation")
                root.move(width / 2, 1)
            } else if (root.phase === 25) {
                root.check(!AppState.dockbarManualState && UiState.hakuMenuStyle === "topFlare" && root.search(),
                    "top hover opens topFlare with Dockbar OFF")
                root.capture("topFlare-dockbar-off")
                UiState.openHakuMenu(root.output.modelData.name, "general")
            } else if (root.phase === 26) {
                root.check(root.search() && UiState.hakuMenuStyle === "topFlare" && !!UiState.hakuMenuAnchorRect
                    && !root.output.dock.shown, "default caller stays top-attached with Dockbar OFF")
                root.toggleDock()
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                ShellSettingsStore.setValue("dock", "iconSize", 72)
                ShellSettingsStore.setValue("roundedScreen", "borderThickness", 6)
            } else if (root.phase === 27) {
                root.transferOutput = root.outputs.find(function(surface) { return surface !== root.output }) || root.output
                root.expectedAnchor = root.content(root.transferOutput.dock).menuAnchor(root.appMenu(root.transferOutput))
                root.check(root.expectedAnchor.width === 72 && root.expectedAnchor.height === 72, "anchor follows icon size")
                UiState.openHakuMenu(root.transferOutput.modelData.name, "drun", "dockbar", root.expectedAnchor)
            } else if (root.phase === 28) {
                if (!root.floating(root.transferOutput).interactionReady) return
                root.check(root.floating(root.transferOutput).interactionReady && root.transferOutput.dock.hakuMenuDockLease, "requested output owns the floating card and lease")
                if (root.transferOutput !== root.output) root.check((!root.floating() || !root.floating().visible) && !root.output.dock.hakuMenuDockLease, "other output has no ghost or lease")
                root.check(UiState.hakuMenuAnchorRect.x >= 0 && UiState.hakuMenuAnchorRect.x < root.transferOutput.modelData.width, "second output anchor excludes its desktop-global origin")
                root.expectedAnchor = root.content(root.output.dock).menuAnchor(root.appMenu())
                UiState.openHakuMenu(root.output.modelData.name, "drun", "dockbar", root.expectedAnchor)
            } else if (root.phase === 29) {
                if (!root.floating().interactionReady) return
                root.check(root.floating().interactionReady && root.output.dock.hakuMenuDockLease, "ownership transfers back")
                if (root.transferOutput !== root.output) root.check((!root.floating(root.transferOutput) || !root.floating(root.transferOutput).visible), "old output resets immediately")
                fullscreenClient.visible = true
            } else if (root.phase === 30) {
                root.check(root.search(), "floating menu stays focused over fullscreen")
                root.type("x")
                root.move(10, 100)
            } else if (root.phase === 31) {
                root.check(UiState.activePanel === "hakumenu", "typing lease survives pointer exit")
                var rect = root.floating().finalRect
                root.move(rect.x + rect.width / 2, rect.y + 20)
            } else if (root.phase === 32) {
                var rect = root.floating().finalRect
                root.move(rect.x + rect.width / 2 + 20, rect.y + 20)
            } else if (root.phase === 33) root.move(10, height - 20, 272)
            else if (root.phase === 34) {
                root.check(UiState.activePanel === "" && root.clientClicks === 1,
                    "pointer exit closes and transparent outside remains clickable: panel=" + UiState.activePanel + " clicks=" + root.clientClicks)
                fullscreenClient.visible = false
                ShellSettingsStore.discard()
                UiState.openHakuMenu(root.output.modelData.name, "drun", "dockbar", {x: NaN, y: 0, width: 10, height: 10})
            } else if (root.phase === 35) {
                root.check(!UiState.activePanel && (!root.floating() || !root.floating().visible), "invalid Dockbar anchor rejects floating activation")
            } else if (root.phase === 36) {
                root.check(UiState.activePanel === "" && !root.output.dock.hakuMenuDockLease, "floating Escape releases lease")
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                AppState.taskbarManualState = true
            } else if (root.phase === 37) {
                if (!root.crowdedReady) {
                    SysStats.mounts = Array.from({length: 30}, function(value, index) { return {target: "/media/Drive" + index, percent: 37} })
                    root.crowdedReady = true
                    return
                }
                var viewport = root.find(root.content(root.output.taskbar), function(item) { return typeof item.contentX === "number" && typeof item.contentWidth === "number" && item.height > 60 })
                root.check(viewport && viewport.contentWidth > viewport.width, "crowded Taskbar scrolls inside its bounded surface: " + (viewport ? viewport.contentWidth + "/" + viewport.width : "missing") + " mounts=" + SysStats.mounts.length)
                root.crowdedAnchor = root.content(root.output.taskbar).menuAnchor(root.appMenu())
                viewport.contentX = 8
            } else if (root.phase === 38) {
                var anchor = root.content(root.output.taskbar).menuAnchor(root.appMenu())
                var viewport = root.find(root.content(root.output.taskbar), function(item) { return typeof item.contentX === "number" && typeof item.contentWidth === "number" && item.height > 60 })
                root.check(Math.abs(root.crowdedAnchor.x - anchor.x - 8) < 0.01,
                    "artwork anchor follows scrolled content: " + root.crowdedAnchor.x + " -> " + anchor.x + " scroll=" + viewport.contentX)
                root.clickAppMenu()
            } else if (root.phase === 39) {
                var bottom = root.find(root.output.menu, function(item) { return String(item).indexOf("HakuMenuBottomFlare_QMLTYPE") >= 0 })
                if (!bottom || !bottom.panelOpen || !root.search()) return
                root.check(UiState.hakuMenuStyle === "bottomFlare", "crowded Full bar opens bottom Flare")
                var span = root.find(bottom, function(item) { return typeof item.mStart === "number" && typeof item.mEnd === "number" })
                root.check(span && Math.abs((span.mStart + span.mEnd) / 2 - width / 2) < 0.5,
                    "Full bar App Menu opens HakuMenu at the physical screen center")
                root.check(Math.abs(UiState.hakuMenuAnchorRect.x - root.expectedAnchor.x) < 1, "crowded Dock click captures the actual scrolled anchor")
                root.move(root.expectedAnchor.x + root.expectedAnchor.width / 2,
                    root.expectedAnchor.y + root.expectedAnchor.height / 2, 272)
            } else if (root.phase === 40) {
                root.check(UiState.activePanel === "", "second Full bar App Menu click closes bottom Flare")
                SysStats.mounts = []
                ShellSettingsStore.discard()
                AppState.taskbarManualState = false
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                tooltipBurst.start()
            } else if (root.phase === 41) {
                if (tooltipBurst.running) return
                var tooltips = root.dockTooltips()
                root.check(tooltips.length === 1 && tooltips[0].text === "Trash",
                    "menu click burst leaves only the hovered icon tooltip: " + tooltips.map(function(item) { return item.text }).join(", "))
                var trash = root.find(root.output.dock, function(item) { return item.label === "Trash" })
                var point = trash.mapToItem(null, trash.width / 2, trash.height / 2)
                root.move(root.output.dock.sideInset + point.x, height - root.output.dock.targetHeight - 180 + point.y, 274)
            } else if (root.phase === 42) {
                var trash = root.find(root.output.dock, function(item) { return item.label === "Trash" })
                root.check(trash.activeFocus, "middle click focuses the Dock without launching Trash")
                root.appMenu().forceActiveFocus(Qt.ActiveWindowFocusReason)
            } else if (root.phase === 43) {
                var tooltips = root.dockTooltips()
                root.check(tooltips.length === 1 && tooltips[0].text === "Trash",
                    "restoring menu focus cannot resurrect its tooltip over another hovered icon: " + tooltips.map(function(item) { return item.text }).join(", "))
                root.key(15)
            } else if (root.phase === 44) {
                var tooltips = root.dockTooltips()
                root.check(tooltips.length === 1 && tooltips[0].target.activeFocus && tooltips[0].text !== "Trash",
                    "Tab shows only the keyboard-selected tooltip while the pointer stays over Trash: "
                        + tooltips.map(function(item) { return item.text + " focused=" + item.target.activeFocus }).join(", "))
                var trash = root.find(root.output.dock, function(item) { return item.label === "Trash" })
                var point = trash.mapToItem(null, trash.width / 2 + 4, trash.height / 2)
                root.move(root.output.dock.sideInset + point.x, height - root.output.dock.targetHeight - 180 + point.y)
            } else if (root.phase === 45) {
                var tooltips = root.dockTooltips()
                root.check(tooltips.length === 1 && tooltips[0].text === "Trash", "pointer motion replaces the keyboard tooltip")
                root.move(width / 2, 1)
            } else if (root.phase === 46) {
                root.check(ChromeLayout.dockbarActive && root.search() && UiState.hakuMenuStyle === "topFlare",
                    "top hover opens topFlare with Dockbar ON")
                root.capture("topFlare-dockbar-on")
                UiState.closeHakuMenu()
                AppState.taskbarManualState = true
                root.move(10, 100)
            } else if (root.phase === 47) {
                root.move(width / 2, 1)
            } else if (root.phase === 48) {
                root.check(!UiState.activePanel && !ChromeLayout.dockbarActive && AppState.dockbarManualState,
                    "Taskbar suppresses both Dockbar and top hover without erasing request")
                UiState.openHakuMenu(root.output.modelData.name, "drun")
            } else if (root.phase === 49) {
                root.check(root.search() && UiState.hakuMenuStyle === "bottomFlare", "Taskbar default opens bottomFlare")
                root.done()
            }
            root.phase++
        }
    }
}
