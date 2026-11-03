import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"
import "components/hakumenu/HakuMenuGeometry.js" as Geometry

ShellRoot {
    id: root
    // Drive the real Dock, menu and full Task Manager through one ownership flow.
    property var screenModel: Quickshell.screens
    property var outputs: []
    property var target: null
    property int phase: 0
    property int ticks: 0
    property int phaseTicks: 0
    property int cycles: 0
    property string initialOrder: ""
    property int initialSubscribers: 0
    property real normalWidth: 0
    property int collectorPid: 0
    property bool trackingHandoff: false
    property var subscriberSequence: []
    property string removedOutput: ""
    // Record the full return interval, including frames hidden by the closing menu.
    property bool watchingReturn: false
    property var returnVisibility: []
    property int restoreChecks: 0
    property var retainedDockWindow: null
    // Compare hover motion with the resting phase before pointer entry.
    property real hoverPhase: 0
    // Track the center glow as it opens before checking its release.
    property real hoverGlowAtEntry: 0
    // Confirm that motion continues while the outgoing hint fades.
    property real fadePhase: 0
    readonly property bool reduced: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    readonly property var primary: outputs.find(item => item.modelData.name === "HEADLESS-1") || null
    readonly property var secondary: outputs.find(item => item.modelData.name === "HEADLESS-2") || null
    onPhaseChanged: phaseTicks = 0

    function check(ok, message) {
        if (ok) return
        console.error("Hikai Dock failed: menu phase=" + phase + " cycle=" + cycles + " " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        if (item.active === true && item.item) { var loaded = find(item.item, predicate); if (loaded) return loaded }
        var children = item.contentItem ? item.contentItem.data : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) { var result = find(child, predicate); if (result) return result }
        return null
    }
    function content(surface) { return find(surface.dock, item => typeof item.menuAnchor === "function") }
    function surfaceBody(surface) { return find(surface.dock, item => typeof item.baseFlareRadius === "number") }
    function returnControl(surface) { return find(surface.menu, item => item.objectName === "hakumenu-return-button") }
    function normalWindow(surface) { return content(surface).hostWindow }
    function morph(surface) { return find(surface.menu, item => typeof item.mHeight === "number") }
    function order() { return DockApps.renderedApps.map(item => item.key).join("|") }
    function move(x, y, button) {
        pointer.write([Math.round(x), Math.round(y), primary.modelData.width, primary.modelData.height, button || 0].join(" ") + "\n")
    }
    function click(item, button) {
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        var footer = item.objectName === "hakumenu-return-button"
        move((footer ? 0 : primary.dock.sideInset) + point.x,
            (footer ? 0 : primary.modelData.height - item.Window.window.height) + point.y, button || 272)
    }
    function open(mode) {
        var app = find(target.dock, item => item.label === "Applications")
        UiState.openHakuMenu(target.modelData.name, mode || (cycles % 3 === 0 ? "drun" : cycles % 3 === 1 ? "general" : "theme"),
            "dockbar", content(target).menuAnchor(app))
    }
    function settledMenu() {
        var motion = morph(target)
        var host = find(target.menu, item => typeof item.surfaceHeight === "number")
        var button = returnControl(target)
        var window = button ? button.Window.window : null
        return target.dock.menuOwned && target.menu.panelOpen && host && motion
            && Math.abs(motion.mHeight - host.surfaceHeight) < 0.01
            && window && window.width === target.modelData.width && window.height === target.modelData.height
            && target.closeFrames >= target.menuOpenFrame + 2
    }
    function returned() {
        var movement = find(target.dock, item => typeof item.phase === "string" && typeof item.moving === "boolean")
        return !target.dock.menuOwned && content(target).enabled && content(target).opacity === 1
            && normalWindow(target).visible && movement && !movement.moving
    }
    // Observe the original window and every visibility edge until the menu is released.
    function watchReturn() {
        returnVisibility = []
        restoreChecks = 0
        watchingReturn = true
        retainedDockWindow = normalWindow(target).contentItem.Window.window
    }
    // Reject a second hide/reveal even if the final Dock geometry looks correct.
    function checkReturn() {
        check(restoreChecks === 1 && returnVisibility.length === 1 && returnVisibility[0],
            "Dock restores once without a hide/reopen cycle")
        watchingReturn = false
    }
    function assertMenu() {
        var host = find(target.menu, item => typeof item.surfaceHeight === "number")
        var span = morph(target)
        var silhouette = find(target.menu, item => typeof item.earStartRadius === "number")
        var width = Geometry.targetWidth(target.modelData.width, UiState.hakuPanelTab, UiState.hakuMenuMode,
            ScreenGeometry.leftInset, ScreenGeometry.rightInset)
        check(target.menu.loadedCount === 1 && UiState.ownsInteraction("hakumenu", target.modelData.name), "one menu and keyboard owner")
        check(Math.abs(span.mEnd - span.mStart - width) < 0.01, "shared menu width")
        check(host.menuTop === target.modelData.height - ScreenGeometry.bottomInset && silhouette.y === host.menuTop,
            "slide and flare originate at the screen rail")
        check(silhouette.r === Theme.giantRadius && silhouette.earStartRadius === Theme.giantRadius
            && silhouette.earEndRadius === Theme.giantRadius, "normal maximum-radius flare")
        check(!target.dock.shown && !surfaceBody(target).visible && normalWindow(target).visible
            && normalWindow(target).mask.width === 0 && normalWindow(target).mask.height === 0,
            "stable Dock window has no paint or input while the menu is open")
        check(!content(target).enabled && content(target).opacity === 0 && !content(target).tooltipsEnabled, "normal Dock controls are suppressed")
        check(returnControl(target).enabled && returnControl(target).Window.window === span.Window.window,
            "return control shares the menu input window")
        check(returnControl(target).text === "" && Math.abs(returnControl(target).width - width) < 0.01
            && returnControl(target).height === host.controlHeight
            && !!find(returnControl(target), item => typeof item.progress === "number" && item.width === 28 && item.height === 14),
            "return control is full width with a large down icon")
        check(returnControl(target).targetBackground.a === 0
            && !!find(returnControl(target), item => item.count === 3), "transparent return control has three chevrons")
        for (var column = 0; column < 3; column++) {
            var arrow = find(returnControl(target), item => item.index === column && typeof item.progress === "number")
            check(arrow && Math.abs(arrow.x + arrow.width / 2 - width * (column + 0.5) / 3) < 0.01,
                "each chevron occupies its own horizontal column")
        }
        var page = find(target.menu, item => typeof item.miniLoaded === "boolean")
        check(page.parent.y + page.parent.height <= host.menuTop - host.controlHeight + 0.01,
            "menu content leaves room for the return footer")
        check(order() === initialOrder && SysStats._extendedSubscribers === initialSubscribers, "one app model and unchanged subscriptions")
        for (var output of outputs) if (output !== target) check(!output.dock.menuOwned && normalWindow(output).visible, "other outputs retain normal Dock")
    }
    function capture(name) {
        var directory = Quickshell.env("HAKUSPACE_DOCK_ARTIFACT_DIR")
        if (!directory) return
        screenshot.command = ["grim", "-o", target.modelData.name, directory + "/" + (name || "dock-menu") + ".png"]
        screenshot.running = true
    }
    Process { id: screenshot }
    Process { id: pointer; command: ["python3", Quickshell.env("HAKUSPACE_TEST_POINTER")]; running: true; stdinEnabled: true }
    Process { id: keyboard; command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]; running: true; stdinEnabled: true }
    // Observe every handoff edge rather than only its final subscriber count.
    Connections {
        target: TaskManagerService
        function onSubscribersChanged() {
            if (!root.trackingHandoff) return
            root.subscriberSequence = root.subscriberSequence.concat([TaskManagerService.subscribers])
            root.check(TaskManagerService.subscribers > 0, "handoff subscriber count reached zero")
        }
        function onCollectorPidChanged() {
            if (root.trackingHandoff) root.check(TaskManagerService.collectorPid === root.collectorPid, "handoff collector changed")
        }
    }
    Variants {
        model: root.screenModel
        Item {
            id: output
            required property var modelData
            property alias dock: dock
            property alias menu: menu
            property alias full: full
            // Pointer input follows a committed frame, including instant reduced-motion reveals.
            property int dockFrames: 0
            property int shownFrame: 0
            property int closeFrames: 0
            property int menuOpenFrame: 0
            property var dockBodyItem: null
            property var closeItem: null
            Connections {
                target: dock
                function onShownChanged() {
                    if (dock.shown) output.shownFrame = output.dockFrames
                    if (!root.watchingReturn || root.target !== output) return
                    root.returnVisibility = root.returnVisibility.concat([dock.shown])
                    if (dock.shown) Qt.callLater(function() {
                        if (!root || !root.watchingReturn || root.target !== output) return
                        var movement = root.find(dock, item => typeof item.phase === "string" && typeof item.moving === "boolean")
                        root.check(root.normalWindow(output).contentItem.Window.window === root.retainedDockWindow,
                            "return reuses the same Dock window")
                        root.check(!movement.moving && movement.height === dock.targetHeight && movement.width === dock.targetWidth,
                            "restored Dock is already full size before its first frame: " + movement.height + "/" + dock.targetHeight)
                        var host = root.find(output.menu, item => typeof item.safeZone === "function")
                        if (host) for (var index = 0; index < 4; index++)
                            root.check(host.safeZone(index).width === 0 && host.safeZone(index).height === 0,
                                "closing menu releases its input mask before Dock returns")
                        root.restoreChecks++
                    })
                }
                function onMenuOwnedChanged() { if (dock.menuOwned) output.menuOpenFrame = output.closeFrames }
            }
            Connections {
                target: menu
                function onPanelOpenChanged() { output.closeItem = menu.panelOpen ? root.returnControl(output) : null }
            }
            Connections {
                target: output.dockBodyItem ? output.dockBodyItem.Window.window : null
                function onFrameSwapped() { output.dockFrames++ }
            }
            Connections {
                target: output.closeItem ? output.closeItem.Window.window : null
                function onFrameSwapped() { output.closeFrames++ }
            }
            // A contrasting desktop makes both seam gaps and bridge contours visible.
            PanelWindow {
                screen: output.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                color: "#597987"
                mask: Region {}
            }
            RoundedScreen { modelData: output.modelData }
            DockBar { id: dock; modelData: output.modelData }
            HakuMenuPanel { id: menu; modelData: output.modelData }
            TaskManagerHost { id: full; modelData: output.modelData }
            Component.onCompleted: {
                dockBodyItem = root.surfaceBody(this)
                root.outputs.push(this)
            }
            Component.onDestruction: root.outputs = root.outputs.filter(item => item !== output)
        }
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            root.check(++root.ticks < 5600 && ++root.phaseTicks < 500, "timeout " + JSON.stringify({
                menu: UiState.activePanel, target: root.target ? root.target.modelData.name : "", progress: root.target ? root.target.dock.shown : false}))
            if (!root.primary && root.phase < 27) return
            if (!ShellSettingsStore.ready || TaskbarPins.busy || screenshot.running) return
            if (root.phase === 0) {
                AppState.dockbarManualState = true
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                root.target = root.primary
                if (!root.target.dock.shown || root.find(root.target.dock, item => typeof item.phase === "string" && typeof item.moving === "boolean").moving) return
                if (root.target.dockFrames <= root.target.shownFrame) return
                var app = root.find(root.target.dock, item => item.label === "Applications")
                var window = app.Window.window
                if (!window || window.width !== root.target.modelData.width - root.target.dock.sideInset * 2
                    || window.height !== root.target.dock.targetHeight + 180) return
                for (var output of root.outputs) {
                    var backing = root.normalWindow(output).contentItem.Window.window
                    if (!backing || backing.width !== output.modelData.width - output.dock.sideInset * 2
                        || backing.height !== output.dock.targetHeight + 180 || output.dockFrames <= output.shownFrame) return
                }
                root.initialOrder = root.order()
                root.initialSubscribers = SysStats._extendedSubscribers
                root.normalWidth = root.surfaceBody(root.target).width
                root.check(root.normalWidth > 0, "normal Dock width")
                var appbar = root.content(root.target)
                appbar.pendingPin = {action: "add", id: "menu-fixture", name: "Fixture"}
                appbar.pinMessage = "Pending feedback"
                appbar.terminationKey = "menu-fixture"
                appbar.reorderKey = "menu-fixture"
                root.click(app)
                root.phase = 1
            } else if (root.phase === 1) {
                if (!root.settledMenu()) return
                root.assertMenu()
                TaskbarPins.mutationFinished("add", "menu-fixture", true)
                root.check(!root.content(root.target).pendingPin && !root.content(root.target).pinMessage
                    && !root.content(root.target).terminationKey && !root.content(root.target).reorderKey
                    && !root.content(root.target).inputLifetime.externallyLeased, "late pin completion cannot restore cancelled feedback or gestures")
                var host = root.find(root.target.menu, item => typeof item.menuTop === "number")
                console.info("Dock menu geometry " + JSON.stringify({width: root.target.modelData.width, height: root.target.modelData.height,
                    normalDockWidth: root.normalWidth, menuWidth: host.targetMenuWidth, surfaceHeight: host.surfaceHeight,
                    contentHeight: host.menuHeight, footerHeight: host.controlHeight, attachmentY: host.menuTop,
                    railY: root.target.modelData.height - ScreenGeometry.bottomInset, radius: Theme.giantRadius}))
                root.capture()
                keyboard.write("text menu\n")
                root.phase = 2
            } else if (root.phase === 2) {
                if (UiState.hakuMenuQuery !== "menu") return
                var button = root.returnControl(root.target)
                root.hoverPhase = button.arrowPhase
                var point = button.mapToItem(null, button.width / 2, button.height / 2)
                root.move(point.x, point.y)
                root.phase = 3
            } else if (root.phase === 3) {
                if (root.phaseTicks < 10) return
                var hoveredButton = root.returnControl(root.target)
                if (root.phaseTicks === 10) {
                    root.check(hoveredButton.hovered && hoveredButton.targetBackground.a === 0,
                        "hover retains the transparent base behind the gradient")
                    root.check(root.reduced ? hoveredButton.arrowPhase === root.hoverPhase
                        : Math.abs(hoveredButton.arrowPhase - root.hoverPhase) > 0.01,
                        "chevrons slide on hover and stay still with reduced motion")
                    if (root.reduced) for (var column = 0; column < 3; column++) {
                        var arrow = root.find(hoveredButton, item => item.index === column && typeof item.progress === "number")
                        root.check(Math.abs(arrow.y + arrow.height / 2 - hoveredButton.height / 2) < 0.01,
                            "reduced-motion chevrons remain centered in each column")
                    }
                    var glow = root.find(hoveredButton, item => item.objectName === "hakumenu-return-glow")
                    root.check(glow && glow.visible && glow.opacity > 0 && hoveredButton.hoverReveal > 0,
                        "hover reveals the central gradient")
                    root.hoverGlowAtEntry = hoveredButton.hoverReveal
                    return
                }
                if (root.phaseTicks === 20) {
                    root.check(hoveredButton.hoverReveal >= root.hoverGlowAtEntry,
                        "hover gradient continues expanding from the center")
                    root.capture("dock-menu-hover")
                    root.fadePhase = hoveredButton.arrowPhase
                    var leave = hoveredButton.mapToItem(null, hoveredButton.width / 2, -40)
                    root.move(leave.x, leave.y)
                    return
                }
                if (root.phaseTicks === 30) {
                    root.check(!hoveredButton.hovered, "pointer has left the return button")
                    var leftArrow = root.find(hoveredButton, item => item.index === 0 && typeof item.progress === "number")
                    var rightArrow = root.find(hoveredButton, item => item.index === 2 && typeof item.progress === "number")
                    if (root.reduced) root.check(hoveredButton.hoverReveal === 0 && leftArrow.opacity === 0 && rightArrow.opacity === 0,
                        "reduced motion releases the hint immediately")
                    else {
                        root.check(hoveredButton.hoverReveal > 0 && hoveredButton.hoverReveal < root.hoverGlowAtEntry
                            && Math.max(leftArrow.opacity, rightArrow.opacity) > 0
                            && Math.max(leftArrow.opacity, rightArrow.opacity) <= hoveredButton.hoverReveal,
                            "outgoing arrows fade with the glow instead of disappearing on pointer exit")
                        root.check(Math.abs(hoveredButton.arrowPhase - root.fadePhase) > 0.01,
                            "downward motion continues until the fade finishes")
                    }
                    root.capture("dock-menu-fade")
                    return
                }
                if (root.phaseTicks < 50) return
                root.check(!hoveredButton.hovered && hoveredButton.arrowPhase === 1 / 6,
                    "leaving the footer stops and resets decorative motion")
                root.check(hoveredButton.hoverReveal === 0
                    && !root.find(hoveredButton, item => item.objectName === "hakumenu-return-glow").visible,
                    "leaving the footer finishes and hides the gradient")
                var restingArrow = root.find(hoveredButton, item => item.index === 1 && typeof item.progress === "number")
                root.check(restingArrow.opacity === 1 && Math.abs(restingArrow.y + restingArrow.height / 2 - hoveredButton.height / 2) < 0.01,
                    "fade completion leaves the resting center arrow without a position jump")
                root.check(UiState.activePanel === "hakumenu" && !UiState.appMenu && !root.content(root.target).reorderKey
                    && !root.content(root.target).terminationKey, "hidden icons reject context/gesture input")
                root.watchReturn()
                var edge = root.returnControl(root.target).mapToItem(null, 4, root.returnControl(root.target).height / 2)
                root.move(edge.x, edge.y, 272)
                root.phase = 4
            } else if (root.phase === 4) {
                if (!root.returned() || root.target.menu.loadedCount || !root.restoreChecks) return
                root.checkReturn()
                root.check(root.target.dock.shown, "always-visible return")
                console.info("Dock menu autohide evidence always PASS")
                ShellSettingsStore.setValue("dock", "visibilityMode", "autohide")
                root.move(10, 100)
                root.phase = 5
            } else if (root.phase === 5) {
                if (root.target.dock.shown) return
                root.move(root.primary.modelData.width / 2, root.primary.modelData.height - 1)
                root.phase = 6
            } else if (root.phase === 6) {
                if (!root.target.dock.shown || root.find(root.target.dock, item => typeof item.phase === "string" && typeof item.moving === "boolean").moving) return
                if (root.target.dockFrames <= root.target.shownFrame) return
                root.click(root.find(root.target.dock, item => item.label === "Applications"))
                root.phase = 7
            } else if (root.phase === 7) {
                if (!root.settledMenu()) return
                root.assertMenu()
                root.watchReturn()
                root.click(root.returnControl(root.target))
                root.phase = 8
            } else if (root.phase === 8) {
                if (!root.returned() || root.target.menu.loadedCount || !root.restoreChecks) return
                root.checkReturn()
                root.check(root.target.dock.shown, "Close keeps normal Dock under pointer")
                console.info("Dock menu autohide evidence close-button PASS")
                root.move(10, 100)
                root.phase = 9
            } else if (root.phase === 9) {
                if (root.target.dock.shown) return
                root.open()
                root.phase = 10
            } else if (root.phase === 10) {
                if (!root.settledMenu()) return
                root.move(12, 100)
                keyboard.write("key 1\n")
                root.phase = 11
            } else if (root.phase === 11) {
                if (UiState.activePanel === "hakumenu" || !root.returned() || root.target.dock.shown) return
                console.info("Dock menu autohide evidence Escape PASS")
                root.open()
                root.phase = 12
            } else if (root.phase === 12) {
                if (!root.settledMenu()) return
                var span = root.morph(root.target)
                root.move((span.mStart + span.mEnd) / 2, ScreenGeometry.bottomHostTop(root.target.modelData.height) - span.mHeight + 20)
                root.phase = 13
            } else if (root.phase === 13) {
                var span = root.morph(root.target)
                root.move((span.mStart + span.mEnd) / 2 + 20, ScreenGeometry.bottomHostTop(root.target.modelData.height) - span.mHeight + 20)
                root.phase = 131
            } else if (root.phase === 131) {
                root.move(15, 100)
                root.phase = 14
            } else if (root.phase === 14) {
                if (UiState.activePanel === "hakumenu" || !root.returned() || root.target.dock.shown) return
                console.info("Dock menu autohide evidence outside PASS")
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                root.open()
                root.phase = 15
            } else if (root.phase === 15) {
                if (!root.settledMenu()) return
                root.assertMenu()
                root.watchReturn()
                if (root.cycles % 3 === 0) UiState.returnFromHakuMenu()
                else if (root.cycles % 3 === 1) UiState.closeHakuMenu()
                else UiState.toggle("menu-fixture")
                root.phase = 16
            } else if (root.phase === 16) {
                if (!root.returned() || root.target.menu.loadedCount || !root.restoreChecks) return
                root.checkReturn()
                root.check(root.order() === root.initialOrder && SysStats._extendedSubscribers === root.initialSubscribers, "restore preserves model/order/subscriptions")
                root.check(!root.returnControl(root.target), "return footer is released with the menu")
                console.info("Dock menu cycle " + JSON.stringify({cycle: root.cycles, reduced: root.reduced, output: root.target.modelData.name,
                    dockShown: root.target.dock.shown, dockOwned: root.target.dock.menuOwned,
                    icons: root.content(root.target).enabled, dockWindow: root.normalWindow(root.target).visible}))
                if (++root.cycles < 50) {
                    root.target = root.cycles % 2 ? root.secondary : root.primary
                    root.open()
                    root.phase = 15
                } else {
                    root.target = root.primary
                    root.open()
                    root.phase = 17
                }
            } else if (root.phase === 17) {
                var motion = root.morph(root.target)
                var host = root.find(root.target.menu, item => typeof item.surfaceHeight === "number")
                if (!root.reduced && (!motion || motion.mHeight <= host.controlHeight)) return
                var page = root.find(root.target.menu, item => typeof item.miniLoaded === "boolean")
                root.check(page.parent.y + page.parent.height <= host.menuTop - host.controlHeight + 0.01,
                    "slide content never overlaps the return footer")
                var height = motion.mHeight
                UiState.closeHakuMenu()
                root.open("general")
                root.check(root.target.dock.menuOwned && root.target.menu.loadedCount === 1, "rapid reversal keeps one owner")
                if (!root.reduced) root.check(motion.mHeight === height, "rapid reversal preserves current slide height")
                root.phase = 18
            } else if (root.phase === 18) {
                if (!root.settledMenu()) return
                console.info("Dock menu reversal evidence PASS")
                UiState.setHakuPanelTab("taskManager")
                root.phase = 19
            } else if (root.phase === 19) {
                if (!TaskManagerService.ready || TaskManagerService.warmingUp) return
                var button = root.find(root.target.menu, item => item.objectName === "taskManagerMiniOpenFull")
                if (!button) return
                root.collectorPid = TaskManagerService.collectorPid
                root.subscriberSequence = [TaskManagerService.subscribers]
                root.trackingHandoff = true
                button.clicked()
                root.phase = 20
            } else if (root.phase === 20) {
                if (!root.target.full.active || !root.target.full.item.interactionReady || !root.returned() || root.target.menu.loadedCount) return
                root.check(TaskManagerService.collectorPid === root.collectorPid && TaskManagerService.subscribers === 1, "full collector continuity")
                root.trackingHandoff = false
                console.info("Dock menu handoff evidence " + JSON.stringify({pid: root.collectorPid, subscribers: root.subscriberSequence, returned: root.returned()}))
                UiState.closeTaskManager()
                root.phase = 21
            } else if (root.phase === 21) {
                if (TaskManagerService.subscribers || TaskManagerService.collectorRunning) return
                root.open()
                root.phase = 22
            } else if (root.phase === 22) {
                if (!root.settledMenu()) return
                AppState.dockbarManualState = false
                root.phase = 23
            } else if (root.phase === 23) {
                root.check(!UiState.activePanel && !root.target.dock.menuOwned && !root.normalWindow(root.target).visible,
                    "topology disable clears menu ownership and Dock input")
                AppState.dockbarManualState = true
                root.phase = 24
            } else if (root.phase === 24) {
                if (!root.target.dock.shown || root.find(root.target.dock, item => typeof item.phase === "string" && typeof item.moving === "boolean").moving) return
                root.open()
                root.phase = 25
            } else if (root.phase === 25) {
                if (!root.settledMenu()) return
                root.removedOutput = root.target.modelData.name
                root.screenModel = Quickshell.screens.filter(screen => screen.name !== root.removedOutput)
                root.target = null
                root.phase = 27
            } else if (root.phase === 27) {
                root.check(UiState.activePanel !== "hakumenu" && !ScreenGeometry.shownDockbars[root.removedOutput], "output teardown releases menu and Dock leases")
                console.info("Hikai Dock checks passed: screen-edge menu, hidden Dock, return footer, autohide, 50 cycles, reversal, handoff, output teardown")
                Qt.quit()
            }
        }
    }
}
