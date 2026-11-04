import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "services"
import "components"
import "components/flare" as Flare

ShellRoot {
    id: root
    // Exercise both real output owners without changing installed preferences.
    property var outputs: []
    // Allow the final handoff probe to remove and restore a real output owner.
    property var screenModel: Quickshell.screens
    property string removedOutput: ""
    property int phase: 0
    property int ticks: 0
    // Run only the handoff path when unrelated integration guards are unavailable.
    readonly property bool handoffOnly: Quickshell.env("HAKUSPACE_TASKBAR_HANDOFF_TEST") === "1"
    property real topClientHeight: 0
    property var originalPins: []
    property var taskbarGeometry: []
    property var memory: QtObject { property string recordsJson: "[]"; property int nextKey: 1 }
    FloatingWindow {
        id: client
        screen: Quickshell.screens[0]
        visible: true
        maximized: true
        title: "Unified chrome reservation fixture"
        color: "#4a7188"
    }
    PersistentProperties {
        id: reloadMemory
        reloadableId: "chrome-reload-probe"
        property bool reloaded: false
    }
    Process { id: capture }
    // Reopen during the morph to catch transient input masks over the rail button.
    Timer {
        id: noteClicks
        interval: 80
        repeat: true
        property string command: ""
        property int remaining: 0
        onTriggered: {
            pointer.write(command)
            remaining--
            if (remaining === 0) stop()
        }
    }
    property int noteFocusRequests: 0
    // Count arrow activation separately from Escape and ordinary close paths.
    property int menuReturns: 0
    Connections {
        target: UiState
        function onTempNoteFocusRequested(screenName) { root.noteFocusRequests++ }
        function onHakuMenuReturnRequested(screenName) { root.menuReturns++ }
    }
    // Catch extra restore/hide pulses during menu close and immediate reopen.
    Connections {
        target: handoffProbe.appHosts.length ? handoffProbe.appHosts[0] : null
        function onOpacityChanged() { if (target.opacity === 1) handoffProbe.restores++ }
    }
    Process {
        id: pointer
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_POINTER")]
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.outputs.length ? root.outputs[0].modelData.name : ""})
        running: root.outputs.length === 2 && !reloadMemory.reloaded
        stdinEnabled: true
    }
    // Send real key events to the focused Sidebar or floating note.
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]
        running: !reloadMemory.reloaded
        stdinEnabled: true
    }
    // A private AppIndicator exercises the real QsMenuOpener and item-removal path.
    Process {
        id: trayFixture
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_TRAY_FIXTURE")]
        running: !reloadMemory.reloaded
    }
    // Traverse QML lists by index because menu models are not JavaScript iterables.
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
        var children = item.contentItem ? item.contentItem.children : item.children || []
        if (!item.contentItem && item.data && typeof item.data.length === "number") children = item.data
        for (var index = 0; index < children.length; ++index) {
            var result = find(children[index], predicate)
            if (result) return result
        }
        return null
    }
    // Identify existing component types without adding production test APIs.
    function module(item, name) { return find(item, value => String(value).indexOf(name + "_QMLTYPE") >= 0) }
    function check(ok, message) {
        if (ok) return
        console.error("Hikai Chrome failed: phase " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function host(output) { return find(output.taskbar, value => value.bottomChromeHost === true) }
    function lane(output) { return module(host(output), "StatusModules") }
    // Send real input in the stable full-output coordinate plane.
    function moveMenuPointer(x, y, button) {
        var output = outputs[0]
        pointer.write([Math.round(x), Math.round(y), output.modelData.width,
            output.modelData.height, button || 0].join(" ") + "\n")
    }
    function clickMenuItem(item) {
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        moveMenuPointer(point.x, point.y, 272)
    }
    // Check real overlay masks, fixed popup geometry and both status lanes.
    function checkTaskbarMenu(output, hidden) {
        var apps = content(output.taskbar)
        var status = lane(output)
        check(output.taskbar.menuOwned === hidden && apps.enabled === !hidden
            && apps.shown === !hidden && apps.opacity === (hidden ? 0 : 1), "Taskbar app ownership")
        check(status.visible && status.enabled && host(output).visible
            && host(output).mask.width === output.modelData.width, "status input remains live")
        if (!hidden) return
        var attached = find(output.menu, value => typeof value.taskbarReturnRect === "object")
        var button = find(output.menu, value => value.objectName === "hakumenu-return-button")
        var rect = attached.taskbarReturnRect
        check(button && button.enabled && button.Accessible.name === "Close HakuMenu", "accessible return control")
        check(rect.x >= status.leftStatusEnd && rect.x + rect.width <= status.rightStatusStart
            && rect.width === status.centerViewportWidth, "return stays inside live center lane")
        var point = button.mapToItem(null, 0, 0)
        check(point.x === rect.x && point.y === rect.y && button.height === ScreenGeometry.taskbarHeight
            && rect.y + rect.height === output.modelData.height, "return occupies physical Taskbar")
        check(ScreenGeometry.bottomHostControlHeight === 0 && attached.controlHeight === 0
            && attached.surfaceHeight === attached.menuHeight
            && attached.menuTop === output.modelData.height - ScreenGeometry.taskbarHeight, "popup geometry unchanged")
        var overlay = find(output.menu, value => value.contentItem && value.mask && value.mask.regions.length === 5)
        check(overlay, "explicit fifth return input region")
        var input = overlay.mask.regions[4]
        check(input.x === rect.x && input.y === rect.y && input.width === rect.width
            && input.height === rect.height, "return paint matches live input")
        for (var index = 0; index < 4; ++index) {
            var zone = overlay.mask.regions[index]
            check(zone.height === 0 || zone.y + zone.height <= attached.menuTop,
                "popup input cannot cover status modules")
        }
        check(!apps.tooltipsEnabled && !apps.pendingPin && !apps.pinMessage && !apps.terminationKey
            && !apps.reorderKey && !apps.inputLifetime.externallyLeased
            && !apps.inputLifetime.keyboardLease, "transient app input released")
    }
    function screenshot(name) {
        var directory = Quickshell.env("HAKUSPACE_DOCK_ARTIFACT_DIR")
        if (!directory) return
        capture.command = ["grim", "-o", outputs[0].modelData.name, directory + "/" + name + ".png"]
        capture.running = true
    }
    // Verify the actual maximized client catches a stale top or duplicate bottom zone.
    function checkTopology(bottom, dockbar) {
        check(ChromeLayout.taskbarMode === bottom, "canonical topology")
        check(ScreenGeometry.topBorderThickness === (bottom ? ScreenGeometry.borderThickness : 0)
            && ScreenGeometry.bottomInset === (bottom ? 0 : ScreenGeometry.borderThickness), "frame rail follows mode")
        for (var output of outputs) {
            check(output.bar.visible === !bottom, "TopBar visibility")
            var reservation = output.bar.data.find(value => Math.abs(value.exclusiveZone - Theme.topBarHeight) <= 1)
            check(reservation && reservation.visible === !bottom, "top reservation visibility: " + output.bar.data.map(value => String(value) + ":" + value.exclusiveZone + ":" + value.visible).join(","))
            check(output.taskbar.active === bottom && output.dock.enabledDock === (!bottom && dockbar), "independent owners")
            check(ChromeLayout.dockbarRequested === dockbar, "Dockbar request survives suppression")
            if (bottom) {
                var frame = find(output.rounded, value => value.contentItem && value.anchors.top && value.anchors.bottom && value.anchors.left && value.anchors.right)
                check(frame.exclusionMode === ExclusionMode.Ignore
                    && Math.abs(frame.height - output.modelData.height + ScreenGeometry.taskbarHeight) <= 1,
                    "frame counts Taskbar height exactly once: " + frame.height)
                check(host(output).anchors.top && Math.abs(host(output).height - output.modelData.height) <= 1,
                    "Taskbar drawable window uses a stable physical output plane")
            }
            var trigger = module(output.menu, "HakuMenuTopFlare")
            check(trigger && ChromeLayout.topEdgeHakuMenuEnabled === !bottom, "top edge follows topology")
            check(ScreenGeometry.taskbarReservation() === (bottom ? ScreenGeometry.taskbarHeight : 0)
                && ScreenGeometry.dockbarReservation(output.modelData.name) === 0, "separate fixed and optional reservations")
        }
        var expected = topClientHeight + (bottom ? Theme.topBarHeight - ScreenGeometry.taskbarHeight : 0)
        check(Math.abs(client.height - expected) <= 1, "maximized client: " + client.height + " expected=" + expected)
    }
    Variants {
        model: root.screenModel
        Item {
            id: output
            required property var modelData
            property alias bar: bar
            property alias rounded: rounded
            property alias taskbar: taskbar
            property alias dock: dock
            property alias menu: menu
            property alias center: center
            property alias osd: osd
            property alias popup: popup
            property alias navigation: navigation
            property alias note: note
            property alias settings: settings
            PanelWindow {
                screen: output.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                color: "#4a7188"
            }
            TopBar { id: bar; modelData: output.modelData }
            Taskbar { id: taskbar; modelData: output.modelData }
            DockBar { id: dock; modelData: output.modelData }
            RoundedScreen { id: rounded; modelData: output.modelData }
            HakuMenuPanel { id: menu; modelData: output.modelData }
            NotificationCenterPanel { id: center; modelData: output.modelData }
            NotificationPopup { id: popup; modelData: output.modelData }
            NavigationPanel { id: navigation; modelData: output.modelData }
            SettingsPanel { id: settings; modelData: output.modelData }
            LevelOsdOverlay { id: osd; modelData: output.modelData }
            TempNoteOverlay { id: note; modelData: output.modelData }
            TrayMenuPanel { modelData: output.modelData }
            Component.onCompleted: root.outputs.push(output)
            Component.onDestruction: root.outputs = root.outputs.filter(value => value !== output)
        }
    }
    // Exercise Taskbar handoff with real pointer/keyboard events and retained app hosts.
    Timer {
        id: handoffProbe
        interval: 50
        repeat: true
        property bool finished: false
        property int step: 0
        property int stepTicks: 0
        property int cycles: 0
        property int initialSubscribers: 0
        property int restores: 0
        property int restoresBeforeClose: 0
        property var appHosts: []
        property string appOrder: ""
        property var returnWindow: null
        property real hoverPhase: 0
        property real originalFont: 0
        // Let screenshots finish before input changes the frame being captured.
        property bool appClickSent: false
        property bool returnClickSent: false
        readonly property bool reduced: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
        onStepChanged: stepTicks = 0
        onTriggered: {
            root.check(++stepTicks < 160, "Taskbar handoff timeout at step " + step)
            if (capture.running) return
            var output = root.outputs[0]
            var other = root.outputs[1]
            var apps = root.content(output.taskbar)
            var button = root.find(output.menu, value => value.objectName === "hakumenu-return-button")
            if (step === 0) {
                root.checkTaskbarMenu(output, true)
                root.checkTaskbarMenu(other, false)
                appHosts = root.outputs.map(value => root.content(value.taskbar))
                initialSubscribers = SysStats._extendedSubscribers
                appOrder = DockApps.renderedApps.map(value => value.key).join("|")
                UiState.closeHakuMenu()
                root.moveMenuPointer(output.modelData.width / 2, output.modelData.height / 2)
            } else if (step === 1) {
                if (output.menu.loadedCount) return
                root.checkTaskbarMenu(output, false)
                root.screenshot("taskbar-handoff-baseline")
            } else if (step === 2) {
                if (!appClickSent) {
                    apps.pendingPin = {action: "add", id: "handoff-fixture", name: "Fixture"}
                    apps.pinMessage = "Pending feedback"
                    apps.terminationKey = "handoff-fixture"
                    apps.reorderKey = "handoff-fixture"
                    apps.inputLifetime.acquireExternalLease("dock-reorder")
                    apps.inputLifetime.beginKeyboardLease()
                    root.clickMenuItem(root.find(apps, value => value.label === "Applications"))
                    appClickSent = true
                    return
                }
                if (!output.menu.panelOpen || stepTicks < 10) return
                root.check(UiState.hakuMenuSource === "taskbar", "real App Menu click opens Taskbar HakuMenu")
                root.checkTaskbarMenu(output, true)
                root.checkTaskbarMenu(other, false)
                TaskbarPins.mutationFinished("add", "handoff-fixture", true)
                root.check(!apps.pinMessage, "late pin feedback stays cancelled")
                var attached = root.find(output.menu, value => typeof value.menuTop === "number")
                root.moveMenuPointer(output.modelData.width / 2, attached.menuTop - 16)
            } else if (step === 3) {
                if (stepTicks < 3) return
                hoverPhase = button.arrowPhase
                var edge = button.mapToItem(null, 4, button.height / 2)
                root.moveMenuPointer(edge.x, edge.y)
            } else if (step === 4) {
                if (stepTicks < 9) return
                root.check(output.menu.panelOpen && button.hovered && button.hoverReveal > 0,
                    "popup-to-return bridge retains menu and reveals glow")
                root.check(reduced ? button.arrowPhase === hoverPhase : Math.abs(button.arrowPhase - hoverPhase) > 0.01,
                    "shared arrows animate only without reduced motion")
                var glow = root.find(button, value => value.objectName === "hakumenu-return-glow")
                root.check(glow.visible && glow.opacity > 0, "shared hover glow")
                returnWindow = root.find(output.menu, value => value.contentItem && value.mask && value.mask.regions.length === 5)
                restoresBeforeClose = restores
                console.info("Taskbar handoff return rect " + JSON.stringify(
                    root.find(output.menu, value => typeof value.taskbarReturnRect === "object").taskbarReturnRect))
                root.screenshot("taskbar-handoff-hover")
            } else if (step === 5) {
                if (!returnClickSent) {
                    root.clickMenuItem(button)
                    returnClickSent = true
                    return
                }
                if (UiState.activePanel === "hakumenu") return
                root.check(root.menuReturns === 1, "real arrow click invokes return signal once")
                root.check(restores === restoresBeforeClose + 1, "arrow restores app icons exactly once")
                root.checkTaskbarMenu(output, false)
                root.check(returnWindow ? returnWindow.mask.regions[4].width === 0 && returnWindow.mask.regions[4].height === 0
                    : output.menu.loadedCount === 0,
                    "return releases its input immediately during closing paint")
                UiState.openHakuMenu(output.modelData.name, "general")
            } else if (step === 6) {
                if (!output.menu.panelOpen || stepTicks < 10) return
                root.checkTaskbarMenu(output, true)
                restoresBeforeClose = restores
                keyboard.write("key 1\n")
            } else if (step === 7) {
                if (UiState.activePanel === "hakumenu") return
                root.checkTaskbarMenu(output, false)
                root.check(root.menuReturns === 1, "Escape restores apps without return signal")
                root.check(restores === restoresBeforeClose + 1, "Escape restores app icons exactly once")
            } else if (step === 8) {
                restoresBeforeClose = restores
                UiState.openHakuMenu(output.modelData.name, ["drun", "general", "theme"][cycles % 3],
                    cycles % 2 ? "default" : "taskbar")
                UiState.setHakuPanelTab(cycles % 3 === 1 ? "taskManager" : "hakumenu")
            } else if (step === 9) {
                if (!output.menu.panelOpen || stepTicks < 10) return
                root.checkTaskbarMenu(output, true)
                root.checkTaskbarMenu(other, false)
                root.check(apps === appHosts[0] && root.content(other.taskbar) === appHosts[1]
                    && SysStats._extendedSubscribers === initialSubscribers
                    && DockApps.renderedApps.map(value => value.key).join("|") === appOrder,
                    "repeated handoff preserves hosts, model order and subscriptions")
                UiState.setHakuPanelTab("hakumenu")
                UiState.hakuMenuMode = ["theme", "drun", "general"][cycles % 3]
                if (cycles % 2) UiState.returnFromHakuMenu()
                else UiState.closeHakuMenu()
                UiState.openHakuMenu(output.modelData.name, "drun")
                UiState.closeHakuMenu()
            } else if (step === 10) {
                root.checkTaskbarMenu(output, false)
                root.check(restores === restoresBeforeClose + 2, "each requested close restores once without extra pulses")
                if (++cycles < 12) { step = 8; return }
                UiState.openHakuMenu(other.modelData.name, "theme")
            } else if (step === 11) {
                if (!other.menu.panelOpen) return
                root.checkTaskbarMenu(output, false)
                root.checkTaskbarMenu(other, true)
                UiState.openHakuMenu(output.modelData.name, "general")
                originalFont = Theme.fontSize
                Theme.fontSize += 6
            } else if (step === 12) {
                if (!output.menu.panelOpen || stepTicks < 10) return
                root.checkTaskbarMenu(output, true)
                root.checkTaskbarMenu(other, false)
                Theme.fontSize = originalFont
                var right = root.find(root.lane(output), value => value.objectName === "rightStatusModules")
                right.contentX = Math.max(0, right.contentWidth - right.width)
            } else if (step === 13) {
                if (stepTicks < 3) return
                var bell = root.find(root.module(root.lane(output), "NotificationGroup"),
                    value => typeof value.tooltip === "string" && value.tooltip.indexOf("Notifications") === 0)
                root.clickMenuItem(bell)
            } else if (step === 14) {
                if (!output.center.panelOpen) return
                root.checkTaskbarMenu(output, false)
                UiState.closeNotifications()
                UiState.openHakuMenu(output.modelData.name, "drun")
            } else if (step === 15) {
                if (!output.menu.panelOpen || stepTicks < 10) return
                root.clickMenuItem(root.module(root.lane(output), "Logo"))
            } else {
                if (!output.navigation.panelOpen) return
                root.checkTaskbarMenu(output, false)
                UiState.closeNavigation()
                UiState.openHakuMenu(output.modelData.name, "drun")
                console.info("Taskbar handoff passed: pointer return/glow, Escape, 12 cycles, tabs, two outputs, live lanes and status clicks")
                finished = true
                stop()
                return
            }
            step++
        }
    }
    Timer {
        interval: 650
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 180, "timeout")
            if (!ShellSettingsStore.ready || TaskbarPins.busy || capture.running || (outputs.length !== 2 && phase !== 51)) return
            var output = outputs[0]
            if (reloadMemory.reloaded) {
                root.check(output.bar.visible && !output.dock.shown && !UiState.activePanel, "shell reload restores clean topology")
                console.info("Hikai Chrome checks passed")
                Qt.quit()
                return
            }
            if (phase === 0) {
                root.topClientHeight = client.height
                root.originalPins = TaskbarPins.pins.slice()
                NotificationStore.start(root.memory)
                if (root.handoffOnly) {
                    AppState.taskbarManualState = true
                    phase = 4
                    return
                }
                root.checkTopology(false, false)
                AppState.waybarManualState = false
            } else if (phase === 1) {
                root.checkTopology(false, false)
                UiState.toggleNotifications(output.modelData.name,
                    ScreenGeometry.fallbackModuleAnchor(output.modelData.name, output.modelData.width - 50, 28))
                AppState.dockbarManualState = true
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
            } else if (phase === 2) {
                root.checkTopology(false, true)
                root.check(output.center.panelOpen, "Dockbar toggle preserves unrelated TopBar status surfaces")
                UiState.closeNotifications()
                AppState.dockbarManualState = false
            } else if (phase === 3) {
                root.checkTopology(false, false)
                ShellSettingsStore.setValue("dock", "visibilityMode", "autohide")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", false)
                AppState.taskbarManualState = true
            } else if (phase === 4) {
                if (!root.handoffOnly) root.checkTopology(true, false)
                for (var surface of outputs) {
                    var window = root.host(surface)
                    var background = root.find(surface.taskbar, value => value.objectName === "taskbar-surface")
                    root.check(window.width === surface.modelData.width && window.margins.left === 0
                        && window.margins.right === 0 && background.radius === 0 && background.border.width === 0
                        && background.y + background.height === window.height, "Taskbar owns a square surface at the physical bottom")
                    var lane = root.lane(surface)
                    root.check(lane && !module(lane, "CenterModule") && !module(lane, "CavaGroup"), "bottom has no center cluster")
                    var app = root.find(surface.taskbar, value => value.label === "Applications")
                    var rect = root.content(surface.taskbar).menuAnchor(app)
                    root.check(Math.abs(rect.y + rect.height / 2 - (surface.modelData.height - ScreenGeometry.taskbarHeight / 2)) <= 8, "App Menu lies inside bottom chrome")
                    var logo = root.module(lane, "Logo")
                    var logoRect = ScreenGeometry.itemRect(logo)
                    root.check(Math.abs(logoRect.y + logoRect.height / 2 - (surface.modelData.height - ScreenGeometry.taskbarHeight / 2)) <= 1, "status modules vertical center: " + JSON.stringify(logoRect) + " height=" + surface.modelData.height + " bar=" + ScreenGeometry.taskbarHeight)
                }
                var originalFont = Theme.fontSize
                Theme.fontSize = 36
                root.check(ScreenGeometry.taskbarHeight >= Theme.fontSize * 1.8, "canonical Full bar height fits large status modules")
                Theme.fontSize = originalFont
                WM.supported = true
                WM.workspaces = Array.from({length: 18}, (_, index) => ({key: String(index), name: String(index), active: index === 0, focused: index === 0, occupied: true, urgent: false, special: false}))
                WM.activeWindowTitle = "A very long focused window title for crowded chrome"
                TaskbarPins.pins = root.originalPins.concat(Array.from({length: 24}, (_, index) => ({id: "chrome-fixture-" + index, name: "Fixture " + index, icon: "application-x-executable"})))
            } else if (phase === 5) {
                var lane = root.lane(output)
                var viewport = root.find(root.host(output), value => value.contentWidth > value.width && value.interactive && value.height > 60)
                root.check(viewport && viewport.width > 0, "crowded apps scroll in a nonzero viewport")
                root.check(Math.abs(viewport.x + viewport.width / 2 - root.host(output).width / 2) < 0.01, "taskbar stays physically centered")
                root.check(viewport.x >= lane.leftStatusEnd && viewport.x + viewport.width <= lane.rightStatusStart, "status lanes do not overlap apps")
                root.screenshot("unified-crowded")
                var clock = root.module(lane, "ClockGroup")
                root.taskbarGeometry = outputs.map(function(surface) {
                    var window = root.host(surface)
                    var background = root.find(surface.taskbar, value => value.objectName === "taskbar-surface")
                    return {height: window.height, y: background.mapToItem(window.contentItem, 0, 0).y}
                })
                TooltipManager.show(clock, clock.tooltip, clock.tooltipComponent)
            } else if (phase === 6) {
                var tooltip = root.module(root.host(output), "TooltipLayer")
                var flare = root.module(tooltip, "FlareHost")
                if (TooltipManager.current && TooltipManager.activeBar === tooltip.windowRoot
                    && (!TooltipManager.shown || flare.currentHeight <= 0)) return
                root.check(TooltipManager.shown && TooltipManager.activeBar === tooltip.windowRoot && flare.currentHeight > 0,
                    "tooltip keeps bottom window ownership: shown=" + TooltipManager.shown + " owner=" + TooltipManager.activeBar
                    + " host=" + tooltip.windowRoot + " target=" + (TooltipManager.current ? TooltipManager.current.target : "none"))
                root.check(flare.attach === Flare.FlareHost.Bottom && tooltip.y - flare.currentHeight >= 0, "bottom tooltip opens upward inside host: attach=" + flare.attach + " expected=" + Flare.FlareHost.Bottom + " y=" + tooltip.y + " height=" + flare.currentHeight)
                outputs.forEach(function(surface, index) {
                    var window = root.host(surface)
                    var background = root.find(surface.taskbar, value => value.objectName === "taskbar-surface")
                    root.check(window.height === root.taskbarGeometry[index].height
                        && background.mapToItem(window.contentItem, 0, 0).y === root.taskbarGeometry[index].y,
                        "calendar tooltip cannot resize or shift the Taskbar surface")
                })
                root.screenshot("taskbar-calendar")
                UiState.openHakuMenu(output.modelData.name, "drun")
            } else if (phase === 7) {
                if (!handoffProbe.finished) { handoffProbe.start(); return }
                root.check(UiState.hakuMenuStyle === "bottomFlare" && output.menu.panelOpen && !output.dock.menuOwned, "Full default HakuMenu is attached")
                root.check(root.find(output.menu, value => value.controlsAtBottom === false), "Taskbar menu controls stay at the top")
                var attachedMenu = root.find(output.menu, value => value.bottomAttached === true && typeof value.menuHeight === "number")
                root.check(attachedMenu && attachedMenu.menuHeight === output.modelData.height * 0.4,
                    "Taskbar HakuMenu uses forty percent of the output height")
                root.screenshot("unified-hakumenu")
                if (root.handoffOnly) { phase = 50; return }
                AppState.dockbarManualState = true
                AppState.taskbarManualState = false
            } else if (phase === 8) {
                root.check(!UiState.activePanel && !UiState.hakuMenuAnchorRect && !TooltipManager.current, "style transfer clears transient anchors")
                UiState.openHakuMenu(output.modelData.name, "drun")
            } else if (phase === 9) {
                root.check(UiState.hakuMenuStyle === "topFlare" && !!UiState.hakuMenuAnchorRect, "TopBar default stays top-attached with Dockbar enabled")
                root.checkTopology(false, true)
                root.check(UiState.resolveHakuMenuPresentation("dockbar") === "bottomFlare"
                    && UiState.resolveHakuMenuPresentation("edge") === "topFlare", "simultaneous TopBar source mapping")
                AppState.taskbarManualState = true
                NotificationStore.records = [{key: 1, id: 1, summary: "Unified notification", body: "History fixture", appName: "fixture", actions: [], timestamp: Date.now(), screenName: output.modelData.name, popup: false}]
                var bell = root.module(root.lane(output), "NotificationGroup")
                UiState.toggleNotifications(output.modelData.name, ScreenGeometry.itemRect(bell))
            } else if (phase === 10) {
                root.checkTopology(true, true)
                var flare = root.module(output.center, "FlareHost")
                root.check(output.center.panelOpen && flare.currentHeight > 0 && flare.attach === Flare.FlareHost.Bottom, "Notification Center opens upward")
                root.check(ScreenGeometry.attachedBodyY(output.modelData.height, flare.currentHeight) + flare.currentHeight <= ScreenGeometry.chromeAttachmentY(output.modelData.height), "center stays above bar")
                root.check(output.center.safeZones[2].width < output.modelData.width, "center keeps panel-sized desktop input")
                UiState.closeNotifications()
                UiState.openNavigation(output.modelData.name, ScreenGeometry.itemRect(root.module(root.lane(output), "Logo")))
            } else if (phase === 11) {
                root.check(output.navigation.panelOpen && output.navigation.flareHeight > 0, "bottom Navigation opens")
                var nav = output.navigation
                root.check(Math.abs(nav.mapY(nav.controllerY, nav.circleDiameter) + nav.circleDiameter
                    - (output.modelData.height - nav.shellPadding)) < 0.01, "Navigation reaches the physical bottom-left corner")
                root.check(nav.regions.map(value => value.labelAngle).join(",") === "90,210,330", "Full bar reflects all three Navigation options")
                for (var index = 0; index < nav.regions.length; ++index)
                    root.check(nav.indexAt(nav.iconCenterX(index), nav.iconCenterY(index), false) === index,
                        "reflected Navigation glyph matches its hit target")
                root.screenshot("unified-navigation")
            } else if (phase === 12) {
                // Let the screenshot process finish before changing the captured surface.
                if (!output.navigation.sidebarExpanded) {
                    UiState.beginNavigationHandoff("sidebar")
                    return
                }
                root.check(output.navigation.sidebarExpanded, "Sidebar handoff")
                var rail = root.module(output.navigation, "SidebarSurface")
                if (Math.abs(rail.morphProgress - 1) > 0.0001) return
                root.check(rail.listTopPadding === 30 && rail.listBottomPadding === 30
                    && rail.preferredBodyHeight === 60 + 3 * rail.itemDiameter + 2 * rail.itemSpacing,
                    "Sidebar keeps its extra 20 px with balanced padding")
                var body = root.find(rail, value => value.color !== undefined && value.width === rail.bodyWidth
                    && value.height === rail.currentHeight + rail.joinOverlap)
                var first = root.find(rail, value => value.tooltip === "Quick Actions")
                var last = root.find(rail, value => value.tooltip === "Temp Note")
                var topPadding = first.mapToItem(rail, 0, 0).y - body.y
                var bottomPadding = body.y + body.height - last.mapToItem(rail, 0, last.height).y
                root.check(topPadding >= 30 && Math.abs(topPadding - bottomPadding) < 0.5,
                    "Sidebar controls have equal painted top/bottom padding: " + topPadding + "/" + bottomPadding
                    + " body=" + body.y + "/" + body.height + " rail=" + rail.bodyHeight + " progress=" + rail.morphProgress)
                root.screenshot("unified-sidebar")
                UiState.beginNavigationHandoff("dashboard")
            } else if (phase === 13) {
                if (Math.abs(output.navigation.dashboardMorphProgress - 1) > 0.0001) return
                root.check(output.navigation.dashboardVisuallyActive, "Dashboard handoff")
                var dashboard = root.module(output.navigation, "DashboardSurface")
                var avatar = root.module(dashboard, "DashboardAvatar")
                var profile = root.module(dashboard, "DashboardProfileRail")
                var clock = root.module(dashboard, "DashboardClockCard")
                var avatarPoint = avatar.mapToItem(null, 0, 0)
                var clockPoint = clock.mapToItem(null, 0, 0)
                root.check(Math.abs(avatarPoint.y - clockPoint.y) < 0.5, "Dashboard avatar and cards share an upright top row")
                root.check(profile.y > avatar.y + avatar.height, "Dashboard profile stays below its avatar")
                root.check(output.navigation.safeZones[7].y + output.navigation.safeZones[7].height
                    <= dashboard.attachmentSeam + Interaction.safeZoneMargin + 1, "Dashboard input envelope follows its upright body")
                var shell = root.module(dashboard, "DashboardFlareSurface")
                root.check(avatarPoint.y >= dashboard.attachmentSeam - shell.flareBodyHeight + dashboard.innerPadding - 0.5,
                    "Dashboard content stays inside the rounded upper silhouette: avatar=" + avatarPoint.y + " seam=" + dashboard.attachmentSeam
                    + " body=" + shell.flareBodyHeight + " progress=" + dashboard.morphProgress)
                root.screenshot("unified-dashboard")
                output.navigation.activateIndex(2, true)
            } else if (phase === 14) {
                root.check(UiState.activePanel === "settings", "Settings handoff")
                UiState.closeSettings()
                CenterState.show("volume")
            } else if (phase === 15) {
                var visual = output.osd.data.find(value => value.contentItem)
                var bridge = root.module(visual, "LevelOsdBridge")
                root.check(visual && visual.visible && bridge && bridge.attach === Flare.FlareHost.Top
                    && bridge.y === ScreenGeometry.topBorderThickness && bridge.currentHeight > 0 && output.osd.attachmentY === ScreenGeometry.topBorderThickness,
                    "Taskbar OSD attaches its Top Flare and Overlay to the rounded frame")
                root.screenshot("taskbar-top-osd")
                AppState.taskbarManualState = false
            } else if (phase === 16) {
                root.checkTopology(false, true)
                root.check(ShellSettingsStore.showCenter && ShellSettingsStore.showCava, "center preferences survive Full presentation")
                AppState.dockbarManualState = false
                WM.supported = false
                TaskbarPins.pins = root.originalPins
                ShellSettingsStore.reset()
            } else if (phase === 17) {
                root.checkTopology(false, false)
                NotificationStore.records = [1, 2].map(function(key) {
                    return {key: key, id: key, appName: "fixture", appIcon: "", desktopEntry: "",
                        summary: "Popup " + key, body: "Chrome-edge popup fixture", image: "", urgency: 1,
                        timestamp: Date.now(), expireTimeout: 0, resident: false, transient: false, actions: [],
                        live: true, popupEligible: true, popupScreenName: output.modelData.name,
                        read: false, dismissed: false, expired: false, closeReason: ""}
                })
            } else if (phase === 18) {
                if (output.popup.revealHeight < 1) return
                var body = root.find(output.popup, value => value.clip && value.radius === Theme.largeRadius + 4 && value.width > 400)
                root.check(body && Math.abs(body.y - Theme.topBarHeight) <= 1, "top popups reveal downward: body=" + (body ? body.y + "/" + body.height : "missing") + " seam=" + Theme.topBarHeight)
                AppState.taskbarManualState = true
            } else if (phase === 19) {
                var body = root.find(output.popup, value => value.clip && value.radius === Theme.largeRadius + 4 && value.width > 400)
                root.check(body && body.y === ScreenGeometry.topBorderThickness && output.popup.topOffset === ScreenGeometry.topBorderThickness, "Taskbar popups reveal from the rounded frame")
                var windows = output.popup.data.filter(value => value.contentItem)
                var visual = windows.find(value => value.anchors.left && value.anchors.right)
                var overlay = windows.find(value => !value.anchors.left && !value.anchors.right)
                var flare = root.module(visual, "FlareSurface")
                root.check(visual && overlay && overlay.anchors.top && overlay.anchors.bottom
                    && Math.abs(output.popup.popupStart + overlay.width / 2 - output.modelData.width / 2) < 0.5,
                    "popup Overlay is physically centered with a separate Top visual owner")
                root.check(flare && flare.attach === Flare.FlareHost.Top && flare.currentHeight === output.popup.revealHeight,
                    "popup Top Flare paints the complete revealed stack")
                root.check(output.popup.displayPopups.length === 2, "topology keeps notification lifecycle")
                root.screenshot("unified-popups")
                NotificationStore.toggleDnd()
            } else if (phase === 20) {
                root.check(!output.popup.hasLivePopups && NotificationStore.records.length === 2, "DND hides popups without erasing history")
                NotificationStore.toggleDnd()
                NotificationStore.clearAll()
                var tray = root.module(root.lane(output), "TrayMenuController")
                var anchor = root.module(root.lane(output), "Logo")
                var received = null
                var fake = {hasMenu: true, menu: null, display: function(window, x, y) { received = {window: window, x: x, y: y} }}
                tray.requestTrayMenu(fake, anchor)
                root.check(received && received.window === root.host(output), "native tray fallback uses owning bottom window")
                var point = anchor.mapToItem(null, 0, 0)
                root.check(received.x === point.x && received.y === point.y, "native fallback uses window-local coordinates")
                var activated = false
                tray.requestTrayMenu({hasMenu: false, secondaryActivate: function() { activated = true }}, anchor)
                root.check(activated, "menu-less tray item keeps secondary activation")
                var trayGroup = root.module(root.lane(output), "TrayGroup")
                var trayItem = SystemTray.items.values.find(value => value.id === "hakuspace-p1-short-menu-fixture")
                var trayAnchor = root.find(trayGroup, value => typeof value.requestTooltip === "function")
                root.check(trayItem && trayAnchor, "private tray item registered: " + SystemTray.items.values.map(value => value.id).join(","))
                tray.requestTrayMenu(trayItem, trayAnchor)
            } else if (phase === 21) {
                root.check(UiState.activePanel === "tray" && UiState.trayMenu, "real tray menu resolves into custom QML panel")
                var trayPanel = root.module(output, "TrayMenuPanel")
                var trayFlare = root.module(trayPanel, "FlareHost")
                root.check(trayPanel.panelOpen && trayFlare.currentHeight > 0 && trayFlare.attach === Flare.FlareHost.Bottom, "real tray opens upward from its captured icon")
                trayFixture.running = false
            } else if (phase === 22) {
                root.check(!UiState.trayMenu && UiState.activePanel !== "tray", "disappearing tray item clears panel ownership")
                UiState.openNavigation(output.modelData.name)
                AppState.taskbarManualState = false
            } else if (phase === 23) {
                root.check(!UiState.activePanel && !UiState.navigationAnchorRect && !UiState.navigationVisualScreenName,
                    "active Navigation transfer drops logical and visual ownership")
                root.check(!output.navigation.closing && !output.navigation.keyboardLease, "Navigation leaves no closing keyboard envelope")
                AppState.taskbarManualState = true
                UiState.toggleNotifications(output.modelData.name,
                    ScreenGeometry.itemRect(root.module(root.lane(output), "NotificationGroup")))
            } else if (phase === 24) {
                root.check(output.center.panelOpen, "Notification Center is open before style transfer")
                AppState.taskbarManualState = false
            } else if (phase === 25) {
                root.check(!UiState.notificationPanel && !UiState.activePanel, "active Notification Center transfer clears ownership")
                AppState.taskbarManualState = false
                AppState.dockbarManualState = false
                ShellSettingsStore.reset()
                pointer.write([Math.round(output.modelData.width / 2), Math.round(output.modelData.height / 2),
                    output.modelData.width, output.modelData.height, 0].join(" ") + "\n")
            } else if (phase >= 26 && phase < 50) {
                var step = (phase - 26) % 12
                var mode = phase < 38 ? "Topbar" : "Taskbar"
                var nav = output.navigation
                var rail = root.module(nav, "SidebarSurface")
                var editor = root.find(output.note, value => typeof value.insert === "function" && value.preeditText !== undefined)
                if (step === 0) {
                    AppState.taskbarManualState = phase >= 38
                    UiState.openNavigation(output.modelData.name)
                    UiState.beginNavigationHandoff("sidebar")
                } else if (step === 1) {
                    if (Math.abs(rail.morphProgress - 1) > 0.0001) return
                    var button = root.find(rail, value => value.text === rail.tools[2].icon && typeof value.clicked === "function")
                    root.check(button, mode + " Temp Note button is available")
                    var point = button.mapToItem(null, button.width / 2, button.height / 2)
                    noteClicks.command = [Math.round(point.x), Math.round(point.y), output.modelData.width,
                        output.modelData.height, 272].join(" ") + "\n"
                    pointer.write(noteClicks.command)
                    noteClicks.remaining = 2
                    noteClicks.start()
                } else if (step === 2) {
                    if (!output.note.interactionReady) return
                    root.check(nav.panelOpen && nav.sidebarExpanded && nav.sidebarKeyboardMode
                        && nav.sidebarSelectedIndex === 2 && editor && !editor.activeFocus
                        && !output.note.contentItem.Window.active,
                        mode + " clicking Temp Note keeps Sidebar focus without a second hover")
                    keyboard.write("key 103\n")
                } else if (step === 3) {
                    root.check(nav.panelOpen && nav.sidebarSelectedIndex === 1,
                        mode + " Up works immediately after opening Temp Note")
                    keyboard.write("key 108\n")
                } else if (step === 4) {
                    root.check(nav.sidebarSelectedIndex === 2, mode + " Down returns to Temp Note")
                    keyboard.write("key 106\n")
                } else if (step === 5) {
                    root.check(editor.activeFocus && nav.panelOpen,
                        mode + " Right transfers focus into the editor; requests=" + root.noteFocusRequests)
                    UiState.closeTempNote()
                    nav.focusSidebarRail(true)
                } else if (step === 6) {
                    keyboard.write("key 28\n")
                } else if (step === 7) {
                    if (!output.note.interactionReady) return
                    root.check(nav.panelOpen && nav.sidebarSelectedIndex === 2 && !editor.activeFocus,
                        mode + " Enter opens Temp Note while retaining Sidebar keyboard input")
                    keyboard.write("key 1\n")
                } else if (step === 8) {
                    root.check(!nav.panelOpen && UiState.tempNoteOpen,
                        mode + " Escape dismisses Sidebar while preserving the note")
                    UiState.openNavigation(output.modelData.name)
                    UiState.beginNavigationHandoff("sidebar")
                    root.module(nav, "SafeZoneController").releaseKeyboardLease()
                    pointer.write([Math.round(output.modelData.width / 2), Math.round(output.modelData.height / 2),
                        output.modelData.width, output.modelData.height, 0].join(" ") + "\n")
                } else if (step === 9) {
                    root.check(!nav.panelOpen && UiState.tempNoteOpen,
                        mode + " pointer exit dismisses Sidebar while preserving the note")
                    var point = editor.mapToItem(null, 80, 20)
                    pointer.write([Math.round(point.x), Math.round(point.y), output.modelData.width,
                        output.modelData.height, 272].join(" ") + "\n")
                } else if (step === 10) {
                    root.check(editor.activeFocus && output.note.contentItem.Window.active,
                        mode + " clicking the passive note activates its editor")
                    keyboard.write("key 107\ntext x\n")
                } else {
                    root.check(TextStore.scratchDraft.endsWith("x"), mode + " note receives typed input")
                    UiState.closeTempNote()
                    AppState.taskbarManualState = false
                }
            } else if (phase === 50) {
                AppState.taskbarManualState = true
                root.removedOutput = output.modelData.name
                UiState.openHakuMenu(root.removedOutput, "drun")
                root.screenModel = Quickshell.screens.filter(value => value.name !== root.removedOutput)
            } else if (phase === 51) {
                root.check(!UiState.activePanel && !ScreenGeometry.taskbarCenterRects[root.removedOutput],
                    "removed output releases menu and center lane")
                root.screenModel = Quickshell.screens
            } else {
                AppState.taskbarManualState = false
                if (!root.handoffOnly) root.checkTopology(false, false)
                reloadMemory.reloaded = true
                Quickshell.reload(false)
            }
            phase++
        }
    }
}
