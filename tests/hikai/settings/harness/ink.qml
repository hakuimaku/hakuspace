import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"
import "components/settings" as Settings
import "components/dashboard" as Dashboard
import "components/settings/SettingsCatalog.js" as Catalog

ShellRoot {
    id: root
    // Drive only disposable surfaces, preferences and input devices from the runner.
    property var hosts: []
    property int phase: 0
    // Exercise interrupted morphs and output transfer before editing any drafts.
    property int animationPhase: 0
    // Compare reversal frames against the last sampled progress value.
    property real animationProgress: 0
    // Wait for Wayland's initial configure before measuring window geometry.
    property bool animationMapped: false
    // Exercise navigation before the opening morph reaches its endpoint.
    property bool earlySettingsInputChecked: false
    property int ticks: 0
    property int rounds: 0
    property int captures: 0
    property var captureRequest: null
    property int pointerPhase: 0
    property int togglePhase: 0
    property int fontPhase: 0
    property int fontListPhase: 0
    property bool originalWelcome: false
    property int sidebarHoverPhase: 0
    property bool dropdownOpeningObserved: false
    property bool dropdownClosingObserved: false
    property int dropdownClickPhase: 0
    property bool sessionChecked: false
    property int configChoicePhase: 0
    property int choicePhase: 0
    property int toolPhase: 0
    property int clipboardPhase: 0
    property int preferencePhase: 0
    property int nativePhase: 0
    property int dialogLease: 0
    property string originalAvatar: ""
    property QtObject notificationMemory: QtObject { property string recordsJson: "[]"; property int nextKey: 1 }
    property string configDraft: ""
    readonly property var host: hosts[0] || null
    readonly property var panel: host && host.loaders[1].active ? host.loaders[1].item : null
    readonly property var nav: host ? host.navigationItem : null
    readonly property var note: host && host.loaders[2].active ? host.loaders[2].item : null
    readonly property string output: host ? host.modelData.name : ""
    Process { id: keyboard; command: ["python3", Quickshell.env("INK_TEST_ROOT") + "/wayland_keyboard.py"]; stdinEnabled: true; running: true }
    Process { id: pointer; command: ["python3", Quickshell.env("INK_TEST_ROOT") + "/wayland_pointer.py"]; environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.output}); stdinEnabled: true; running: false }
    Process { id: fontFailure }
    Process { id: notificationSender; command: ["notify-send", "-t", "0", "Hikai UX", "A comfortable notification with a readable body."] }
    Process { id: dropdownCapture; property string filename: ""; command: ["grim", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/" + filename + ".png"] }
    Process { id: notificationCapture; command: ["grim", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/notifications-popup.png"] }
    Process { id: pointerCapture; command: ["grim", "-c", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/note-pointer.png"] }
    Variants {
        model: Quickshell.screens
        EphemeralSurfaces { id: instance; Component.onCompleted: root.hosts = root.hosts.concat([instance]) }
    }
    // Include the actual bar windows when checking live layout transfers.
    Variants {
        id: layoutTopbars
        model: Quickshell.env("INK_LAYOUT_BARS") === "1" ? Quickshell.screens : []
        TopBar {}
    }
    Variants {
        id: layoutTaskbars
        model: Quickshell.env("INK_LAYOUT_BARS") === "1" ? Quickshell.screens : []
        Taskbar {}
    }
    Variants {
        id: layoutFrames
        model: Quickshell.env("INK_LAYOUT_BARS") === "1" ? Quickshell.screens : []
        RoundedScreen {}
    }
    // The inactive bar stays mapped only while Settings needs fast layout switching.
    property var layoutDrawingWindows: []
    function checkLayoutWindows(settingsOpen) {
        if (Quickshell.env("INK_LAYOUT_BARS") === "1")
            check(layoutTopbars.instances.length === hosts.length && layoutTaskbars.instances.length === hosts.length, "layout probe includes both bars on every output")
        var windows = []
        for (var bar of layoutTopbars.instances) {
            check(bar.visible === (ChromeLayout.topStatusBarVisible || settingsOpen), "Topbar mapping follows Settings lifetime")
            check(bar.contentItem.visible === ChromeLayout.topStatusBarVisible, "inactive Topbar content is hidden")
            check(!!bar.mask.item === ChromeLayout.topStatusBarVisible, "inactive Topbar has an empty input region")
            if (settingsOpen) windows.push(bar.contentItem.Window.window)
        }
        for (var bar of layoutTaskbars.instances) {
            var window = bar.data.find(item => item.bottomChromeHost === true)
            check(window && window.visible === (bar.active || settingsOpen), "Taskbar mapping follows Settings lifetime")
            check(window.contentItem.visible === bar.active && window.mask.width === (bar.active ? window.width : 0), "inactive Taskbar is hidden and passes pointer input")
            if (settingsOpen) windows.push(window.contentItem.Window.window)
        }
        for (var frame of layoutFrames.instances) {
            var window = frame.data.find(item => item.contentItem && item.anchors.top && item.anchors.bottom && item.anchors.left && item.anchors.right)
            check(frame.settingsPlane === settingsOpen, "frame drawing plane follows Settings lifetime")
            if (settingsOpen) {
                check(window && window.width === frame.modelData.width && window.height === frame.modelData.height, "frame keeps a fixed output-sized drawing window during layout switching")
                windows.push(window.contentItem.Window.window)
            }
        }
        if (settingsOpen && !layoutDrawingWindows.length) layoutDrawingWindows = windows
        else if (settingsOpen) check(windows.every((window, index) => window && window === layoutDrawingWindows[index]), "layout switches preserve the same drawing windows")
        else layoutDrawingWindows = []
    }
    FloatingWindow {
        id: nativeWindow
        visible: false
        implicitWidth: 440; implicitHeight: 180
        color: Theme.surface
        TextInput { id: nativeInput; anchors.centerIn: parent; width: 360; height: 40; color: Theme.fg; font.pixelSize: 18; focus: true }
    }
    // Fail loudly so a QML assertion can never be mistaken for a passing probe.
    function check(ok, message) {
        if (ok) return
        console.error("Ink Settings failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Find production controls without depending on private child indices.
    function find(item, predicate) {
        if (!item) return null
        if (predicate(item)) return item
        var children = Array.from(item.children || [])
        for (var object of item.data || []) if (object.contentItem && !children.includes(object.contentItem)) children.push(object.contentItem)
        for (var child of children) {
            var match = find(child, predicate)
            if (match) return match
        }
        return null
    }
    // Capture only the test surface, keeping the user's desktop outside artifacts.
    function capture(name, nextAction) {
        ++captures
        captureRequest = {name: name, nextAction: nextAction}
        captureDelay.restart()
    }
    // Settle page transitions before recording a reviewable frame.
    Timer {
        id: captureDelay
        interval: 240
        onTriggered: {
            var body = root.find(root.panel.contentItem, item => item.radius !== undefined && item.children.some(child => child.currentPage !== undefined))
            root.check(body, "Settings body exists")
            var footer = root.find(root.panel.contentItem, item => item.actionWidth !== undefined && item.page !== undefined)
            var action = root.find(footer, item => item.settingsNavRole === "footer")
            root.check(footer && (footer.visible ? !!action : footer.height === 0), "global footer exists only for actionable status")
            body.grabToImage(result => {
                root.check(result.saveToFile(Quickshell.env("INK_ARTIFACT_DIR") + "/" + root.captureRequest.name + ".png"), "save screenshot")
                var action = root.captureRequest.nextAction
                root.captureRequest = null
                --root.captures
                if (action) action()
            })
        }
    }
    // Check live geometry and loader ownership throughout opening and closing.
    Timer {
        interval: 16; repeat: true
        running: root.phase === 1 && root.animationPhase < 6
        onTriggered: {
            // Inspect the first output without retaining a released surface.
            var panel = root.panel
            if (!panel) root.animationMapped = false
            if (panel && !root.animationMapped) {
                if (panel.width !== root.host.modelData.width || panel.height !== root.host.modelData.height) return
                root.animationMapped = true
            }
            if (panel) {
                // Locate the chassis independently of its private child index.
                var body = root.find(panel.contentItem, item => item.radius !== undefined && item.children.some(child => child.currentPage !== undefined))
                root.check(body, "animated Settings body exists")
                // Inspect the stable page layout inside the moving chassis.
                var interior = body.children.find(child => child.currentPage !== undefined)
                root.check(Math.abs(interior.width + 2 * interior.x - panel.targetBodyWidth) < 0.5
                    && Math.abs(interior.height + interior.y - panel.targetBodyHeight) < 0.5, "content keeps its final layout size during morph")
                root.check(interior.enabled === panel.panelOpen && interior.opacity === 1, "open content stays enabled and fully opaque throughout the morph")
                if (panel.revealProgress > 0.01 && panel.revealProgress < 0.99) {
                    root.check(panel.width === root.host.modelData.width && panel.height === root.host.modelData.height,
                        "Wayland geometry stays fixed: " + panel.width + "x" + panel.height)
                    root.check(!panel.releaseReady && panel.interactionReady === panel.panelOpen && panel.visible, "intermediate frames retain the surface and accept input only while open")
                    if (root.animationPhase === 2 && panel.panelOpen && !root.earlySettingsInputChecked) {
                        var session = root.find(interior, item => item.objectName === "settings-category-Power & Session")
                        root.check(session && session.enabled && panel.navigationEnabled, "sidebar input is ready before the animation finishes")
                        session.clicked()
                        root.check(panel.selectedCategory === "Power & Session", "category selection responds during the opening morph")
                        root.find(interior, item => item.objectName === "settings-category-Look").clicked()
                        root.earlySettingsInputChecked = true
                    }
                    root.check(Math.abs(body.x + body.width / 2 - panel.width / 2) < 0.001
                        && Math.abs(body.y + body.height / 2 - panel.height / 2) < 0.001,
                        "chassis expands in place without sliding from the corner")
                    root.check(panel.revealGeometry.path.length > 0,
                        "full-length diagonal remains connected throughout the morph")
                    root.check(Math.abs(panel.revealGeometry.center.x - panel.width / 2) < 0.001
                        && Math.abs(panel.revealGeometry.center.y - panel.height / 2) < 0.001,
                        "diagonal ends at the fixed screen center")
                }
            }
            if (root.animationPhase === 0) {
                if (!panel || panel.revealProgress < 0.2) return
                root.animationProgress = panel.morphProgress
                UiState.closeSettings()
                root.check(Math.abs(panel.morphProgress - root.animationProgress) < 0.001, "close preserves the current opening frame")
                ++root.animationPhase
            } else if (root.animationPhase === 1) {
                root.check(panel && !panel.panelOpen, "close keeps the original surface alive")
                if (panel.morphProgress > root.animationProgress * 0.7) return
                root.animationProgress = panel.morphProgress
                UiState.openSettings(root.output)
                root.check(root.panel === panel && Math.abs(panel.morphProgress - root.animationProgress) < 0.001, "reopen reverses without recreating or snapping")
                ++root.animationPhase
            } else if (root.animationPhase === 2) {
                if (!panel || !panel.interactionReady || panel.morphProgress !== 1) return
                root.check(root.earlySettingsInputChecked, "opening controls respond before the morph finishes")
                root.check(body.width === panel.targetBodyWidth && body.height === panel.targetBodyHeight, "open chassis reaches its final size")
                root.check(Math.abs(body.x + body.width / 2 - panel.width / 2) < 0.5
                    && Math.abs(body.y + body.height / 2 - panel.height / 2) < 0.5, "open chassis is centered")
                root.check(root.hosts.length > 1, "animation probe has two outputs")
                UiState.openSettings(root.hosts[1].modelData.name)
                ++root.animationPhase
            } else if (root.animationPhase === 3) {
                // Wait for the destination output's own Settings surface.
                var loader = root.hosts[1].loaders[1]
                if (panel || !loader.active || !loader.item.interactionReady || loader.item.morphProgress !== 1) return
                root.check(UiState.ownsInteraction("settings", root.hosts[1].modelData.name), "output transfer preserves keyboard ownership")
                UiState.closeSettings()
                ++root.animationPhase
            } else if (root.animationPhase === 4) {
                if (root.hosts.some(host => host.loaders[1].active)) return
                AppState.taskbarManualState = true
                UiState.openSettings(root.output)
                ++root.animationPhase
            } else if (panel && panel.interactionReady && panel.morphProgress === 1) {
                root.check(panel.revealPosition === 7 && panel.revealGeometry.anchor.y > panel.height / 2,
                    "bottom layout uses the bottom-left attachment")
                AppState.taskbarManualState = false
                console.info("Settings animation checks passed")
                ++root.animationPhase
            }
        }
    }
    // Observe actual dropdown transition frames during physical clicks.
    Timer {
        interval: 16; repeat: true
        running: !!root.panel && root.panel.interactionReady
        onTriggered: {
            if (!root.panel) return
            if (root.phase === 5 && root.panel.configPage) {
                var choice = root.find(root.panel.configPage, item => typeof item.choose === "function" && item.options !== undefined)
                if (!choice) return
                var popup = choice.data.find(object => object.objectName === "settings-choice-popup")
                if (popup.visible && popup.opacity > 0 && popup.opacity < 1) {
                    if (root.dropdownClickPhase === 2 || root.dropdownClickPhase === 3) root.dropdownOpeningObserved = true
                    if (root.dropdownClickPhase === 4) root.dropdownClosingObserved = true
                }
            }
        }
    }
    property bool layoutTransferred: false
    // Keep the applied layout when Settings transfers to another output.
    Timer {
        interval: 90; repeat: true
        running: root.phase === 1 && root.redesignStep === 13 && !root.layoutTransferred
        onTriggered: {
            var loader = root.hosts[1].loaders[1]
            if (!loader.active || !loader.item || !loader.item.interactionReady || root.panel) return
            root.check(AppState.taskbarManualState && !SettingsCoordinator.closeBlocked && !SettingsCoordinator.actionLabels.includes("Keep"), "applied layout survives output transfer without confirmation")
            root.layoutTransferred = true
            UiState.openSettings(root.output)
        }
    }
    property int redesignStep: 0
    property int settleTicks: 0
    property int initialRadius: 12
    property real expandedEditorHeight: 0
    property bool undoMotionObserved: false
    property bool undoReversalObserved: false
    property bool undoCaptured: false
    // Compact outputs keep feedback inside the body rather than beyond the monitor edge.
    Settings.SettingsUndoPopup {
        id: compactUndo
        width: 320; height: 300
        panelRect: Qt.rect(16, 16, 288, 268)
        requested: false
    }
    // Observe actual reveal frames without changing the drawing-window geometry.
    Timer {
        interval: 16; repeat: true
        running: root.phase === 1 && [1, 2, 300].includes(root.redesignStep)
        onTriggered: {
            if (!root.panel) return
            var popup = root.find(root.panel.contentItem, item => item.objectName === "settings-undo-popup")
            if (!popup || popup.revealedHeight <= 0 || popup.revealedHeight >= popup.extent) return
            root.check(root.panel.width === root.host.modelData.width && root.panel.height === root.host.modelData.height, "Undo animation keeps Wayland drawing geometry stable")
            root.undoMotionObserved = true
            if (root.redesignStep === 300 && !popup.requested && popup.revealedHeight < popup.extent * 0.8) {
                var height = popup.revealedHeight
                SettingsCoordinator.message = "Change undone"
                root.check(Math.abs(popup.revealedHeight - height) < 0.01, "Undo reopen preserves the current closing frame")
                root.undoReversalObserved = true
            }
        }
    }
    property bool initialClock: true
    // Compare the newly independent module gates with their persisted snapshots.
    property var initialModules: ({})
    // Track real animation frames and retain the editor owning an idle draft.
    property bool optionsOpeningObserved: false
    property bool optionsClosingObserved: false
    property bool argumentsOpeningObserved: false
    property real featureToggleY: 0
    property Item idleEditor: null
    // Restore the isolated RAM preference after exercising the numeric control.
    property int initialRamThreshold: 300
    // Observe the real popup transition and retain its viewport through reversal.
    property bool cacheOpeningObserved: false
    property bool cacheClosingObserved: false
    property Item cacheViewport: null
    Timer {
        interval: 16; repeat: true
        running: root.phase === 1 && root.redesignStep >= 170 && root.redesignStep <= 174
        onTriggered: {
            var popup = root.panel.wallpaperPage.data.find(item => item.objectName === "settings-wallpaper-cache-dialog")
            if (popup.revealProgress <= 0 || popup.revealProgress >= 1) return
            root.check(popup.visible && popup.contentItem.active && popup.contentItem.item, "cache content stays loaded throughout transitions")
            if (root.redesignStep === 170) root.cacheOpeningObserved = true
            if (root.redesignStep === 172) root.cacheClosingObserved = true
        }
    }
    Timer {
        interval: 16; repeat: true
        running: root.phase === 1 && [9, 10, 190, 310, 311].includes(root.redesignStep)
        onTriggered: {
            if ([9, 10, 310, 311].includes(root.redesignStep)) {
                var row = root.find(root.panel.shellPage, item => item.descriptor && item.descriptor.id === (root.redesignStep === 9 ? "cava-color" : "cava-position"))
                if (!row || row.progress <= 0 || row.progress >= 1) return
                root.check(row.height > 0 && row.height < row.expandedHeight && row.opacity > 0 && row.opacity < 1, "dependent rows resize and fade through intermediate frames")
                if (root.redesignStep === 9) root.optionsOpeningObserved = true
                if (root.redesignStep === 10) {
                    root.optionsClosingObserved = true
                    root.check(!row.enabled, "closing options stop accepting focus and input immediately")
                }
            } else {
                var field = root.find(root.panel.generalPage, item => item.placeholderText === "Extra arguments")
                if (field && field.parent.progress > 0 && field.parent.progress < 1) root.argumentsOpeningObserved = true
            }
        }
    }
    // Retain the pressed marker while exercising the real pointer and large intervals.
    property Item idleDragMarker: null
    property real idleDragScale: 0
    property var idleDragPoint: null
    // Check actual painted bounds rather than only the timeline's numeric scale.
    function checkIdlePreview(timeline) {
        var graph = find(timeline, item => item.objectName === "settings-idle-preview")
        check(graph && timeline.limit >= timeline.total, "timeline range covers every cumulative milestone")
        for (var stage of timeline.stages) {
            if (!stage.enabled) continue
            var marker = find(graph, item => item.objectName === "settings-idle-milestone-" + stage.key)
            var label = find(marker, item => item.objectName === "settings-idle-time-" + stage.key)
            var point = label.mapToItem(graph, 0, 0)
            check(marker.x >= 0 && marker.x + marker.width <= graph.width + 0.01, "milestone remains inside the preview")
            check(point.x >= -0.01 && point.x + label.width <= graph.width + 0.01, "time label remains inside the preview")
        }
    }
    // Exercise production controls and shared persistence after the navigation redesign.
    function redesignProbe() {
        var rail = find(panel.contentItem, item => item.categories !== undefined)
        var step = redesignStep
        if (step === 0) {
            check(panel.selectedCategory === "Look", "starts at Look")
            var wmLabel = find(panel.contentItem, item => item.objectName === "settings-wm-label")
            check(wmLabel && wmLabel.horizontalAlignment === Text.AlignHCenter && wmLabel.verticalAlignment === Text.AlignVCenter, "WM status text is centered within its chip")
            check(!compactUndo.outside && compactUndo.popupRect.x >= compactUndo.panelRect.x && compactUndo.popupRect.x + compactUndo.popupRect.width <= compactUndo.panelRect.x + compactUndo.panelRect.width && compactUndo.popupRect.y + compactUndo.popupRect.height <= compactUndo.panelRect.y + compactUndo.panelRect.height, "compact Undo stays inside its Settings body")
            check(rail.categories.join("|") === "Look|Shell|Wallpaper|Power & Session|Capture|Advanced|About", "seven stable categories")
            check(!find(panel.contentItem, item => item.text === "Apply"), "preferences have no Apply action")
            var topbar = find(panel.contentItem, item => item.searching !== undefined && item.results !== undefined)
            check(topbar && topbar.height === (topbar.width < 700 ? 108 : 62), "header reclaims the removed action row")
            check(!find(panel.contentItem, item => /Changed from default|Profiles…/.test(item.text || "")), "removed filter and profile actions are absent")
            check(!panel.shellPage && !panel.wallpaperPage, "hidden preference pages stay unloaded")
            initialRadius = ShellSettingsStore.savedValues.appearance.baseRadius
            SettingsCoordinator.set("radius", 20, true)
            SettingsCoordinator.set("radius", 18, true)
            check(ShellSettingsStore.baseRadius === 18 && ShellSettingsStore.savedValues.appearance.baseRadius === initialRadius, "slider previews before debounce")
            check(SettingsCoordinator.transaction.before === initialRadius, "rapid edits retain the original undo value")
        } else if (step === 1) {
            if (ShellSettingsStore.dirty) return false
            check(ShellSettingsStore.savedValues.appearance.baseRadius === 18, "debounced slider autosaves")
            var popup = find(panel.contentItem, item => item.objectName === "settings-undo-popup")
            if (!popup || popup.revealedHeight < popup.extent - 1) return false
            check(undoMotionObserved && popup.outside && popup.popupRect.y >= popup.panelRect.y + popup.panelRect.height - 1, "Undo morphs out below the bottom edge of Settings")
            if (!undoCaptured) { undoCaptured = true; dropdownCapture.filename = "settings-undo-bottom"; dropdownCapture.running = true; return false }
            if (dropdownCapture.running) return false
            SettingsCoordinator.undo()
        } else if (step === 2) {
            if (ShellSettingsStore.dirty) return false
            check(ShellSettingsStore.savedValues.appearance.baseRadius === initialRadius, "Undo persists the old radius")
            SettingsCoordinator.message = ""
            redesignStep = 299
        } else if (step === 300) {
            var popup = find(panel.contentItem, item => item.objectName === "settings-undo-popup")
            if (!undoReversalObserved || popup.revealedHeight < popup.extent - 1) return false
            fontFailure.command = ["touch", Quickshell.env("INK_TEST_ROOT") + "/font-save-failure"]; fontFailure.running = true
            redesignStep = 2
        } else if (step === 3) {
            SettingsCoordinator.set("font-family", "Fixture Mono B", true)
            SettingsCoordinator.set("font-size", 16, true)
        } else if (step === 4) {
            if (!SettingsStore.error) return false
            check(SettingsStore.fontsDirty && SettingsCoordinator.closeBlocked, "failed autosave retains draft and blocks close")
            check(SettingsStore.savedFontValues.size === 14, "failed write never confirms the draft")
            fontFailure.command = ["rm", Quickshell.env("INK_TEST_ROOT") + "/font-save-failure"]; fontFailure.running = true
        } else if (step === 5) {
            SettingsCoordinator.activateAction("Retry")
        } else if (step === 6) {
            if (SettingsStore.fontsDirty) return false
            check(!SettingsCoordinator.error && SettingsStore.savedFontValues.family === "Fixture Mono B" && SettingsStore.savedFontValues.size === 16, "Retry persists typography")
            capture("settings-look", function() { root.panel.selectCategory("Shell") })
        } else if (step === 7) {
            var shell = panel.shellPage
            var preview = find(shell, item => item.showLayoutControl !== undefined)
            check(shell && preview && !preview.showLayoutControl, "preview shares the scroll surface below the fixed layout selector")
            shell.scrollToSection("App Bar")
            check(preview.mapToItem(shell, 0, preview.height).y < shell.height / 2, "scrolling moves the large preview out of the content viewport")
            check(!find(shell, item => item.descriptor && item.descriptor.section === "topbar"), "Top Bar modules are not duplicated as preference rows")
            shell.reveal("shell.topbar.clock", "Top Bar")
            var clock = find(shell, item => item.descriptorId === "shell.topbar.clock")
            check(clock && clock.enabled && clock.activeFocus && shell.activeSection === "Top Bar", "search reveals and focuses the single Top Bar clock control")
            var keys = ["workspaces", "windowTitle", "cava", "center", "tray", "quickControls", "powerProfile", "wallpaperWorkspace", "recorder", "clock", "notifications"]
            var previous = null
            for (var key of keys) {
                var button = find(preview, item => item.descriptorId === "shell.topbar." + key)
                var point = button.mapToItem(preview, 0, 0)
                check(button.width >= 28 && point.x >= 0 && point.x + button.width <= preview.width + 1, "Top Bar toggle stays inside the preview")
                check(!previous || (point.x > previous.x && Math.abs(point.y - previous.y) < 1), "Top Bar toggles follow live module order on one row")
                check(Array.from(button.data).some(item => item.target === button && item.text.includes(button.moduleName)), "every module has a named tooltip")
                previous = point
            }
            for (var key of ["powerProfile", "wallpaperWorkspace", "recorder"]) initialModules[key] = SettingsCoordinator.read("shell.topbar." + key)
            initialClock = clock.selected
            preview.forceActiveFocus()
            pointer.running = true
            capture("settings-topbar-preview")
            redesignStep = 76
        } else if (step === 77) {
            var clock = find(panel.shellPage, item => item.descriptorId === "shell.topbar.clock")
            var point = clock.mapToItem(panel.contentItem, clock.width / 2, clock.height / 2)
            pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + host.modelData.width + " " + host.modelData.height + " 0\n")
        } else if (step === 78) {
            var clock = find(panel.shellPage, item => item.descriptorId === "shell.topbar.clock")
            var tooltip = Array.from(clock.data).find(item => item.target === clock && item.active !== undefined)
            if (!clock.hovered || !tooltip || !tooltip.visible) return false
            check(!clock.activeFocus && tooltip.text.includes(initialClock ? "On" : "Off"), "pointer hover reveals the current toggle state without keyboard focus")
            pointer.running = false
            clock.forceActiveFocus(); keyboard.write("key 57\n")
            for (var key of ["powerProfile", "wallpaperWorkspace", "recorder"]) {
                var button = find(panel.shellPage, item => item.descriptorId === "shell.topbar." + key)
                button.clicked()
                check(button.selected === !initialModules[key], "module preview toggles its own live draft")
            }
            redesignStep = 7
        } else if (step === 8) {
            if (ShellSettingsStore.savedValues.topbar.clock === initialClock) return false
            if (["powerProfile", "wallpaperWorkspace", "recorder"].some(key => ShellSettingsStore.savedValues.topbar[key] === initialModules[key])) return false
            check(!SettingsCoordinator.state("cava-color").visible, "Underbar Off collapses child controls")
            panel.shellPage.reveal("cava", "Cava Underbar")
            var toggle = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "cava")
            featureToggleY = toggle.mapToItem(panel.shellPage, 0, 0).y
            var dock = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "dockbar")
            var dockOption = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "shell.dock.visibilityMode")
            check(dock && dockOption && dock.y < dockOption.y, "Dockbar toggle precedes its provider-backed options")
            SettingsCoordinator.set("cava", true)
        } else if (step === 9) {
            if (SettingsCoordinator.busy || SettingsCoordinator.dirty) return false
            var toggle = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "cava")
            var option = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "cava-color")
            if (option.progress < 1) return false
            check(optionsOpeningObserved && SettingsCoordinator.state("cava-color").visible, "Underbar children animate open")
            check(option.y > toggle.y && Math.abs(option.y - toggle.y - toggle.height - toggle.parent.spacing) < 1, "revealed options stay immediately below their feature toggle")
            check(Math.abs(toggle.mapToItem(panel.shellPage, 0, 0).y - featureToggleY) < 1, "expansion keeps the toggle at its viewport position")
            SettingsCoordinator.set("cava-dynamic", true)
        } else if (step === 10) {
            var option = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "cava-position")
            if (!optionsClosingObserved) return false
            check(!SettingsCoordinator.state("cava-position").visible, "dynamic position hides fixed position")
            var progress = option.progress
            SettingsCoordinator.set("cava-dynamic", false)
            check(Math.abs(option.progress - progress) < 0.001, "reopening options preserves the current animation frame")
            redesignStep = 309
        } else if (step === 310) {
            var option = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "cava-position")
            if (SettingsCoordinator.dirty || option.progress < 1) return false
            check(option.visible && option.enabled, "interrupted collapse restores usable options")
            SettingsCoordinator.set("cava-dynamic", true)
        } else if (step === 311) {
            var option = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "cava-position")
            if (SettingsCoordinator.dirty || option.progress > 0) return false
            check(!option.visible && option.height === 0, "collapsed options release their layout space")
            SettingsCoordinator.set("dockbar", true)
            redesignStep = 10
        } else if (step === 11) {
            if (SettingsCoordinator.dirty) return false
            SettingsCoordinator.set("layout", "taskbar")
            check(!SettingsCoordinator.actionLabels.includes("Keep") && !SettingsCoordinator.closeBlocked, "changing layout requires no Keep confirmation")
        } else if (step === 12) {
            if (SettingsCoordinator.dirty) return false
            check(!SettingsCoordinator.state("dockbar").enabled && AppState.dockbarManualState, "Taskbar suppresses Dockbar without erasing the request")
            checkLayoutWindows(true)
            capture("settings-shell", function() { UiState.openSettings(root.hosts[1].modelData.name) })
        } else if (step === 13) {
            if (!layoutTransferred || SettingsCoordinator.dirty) return false
            check(AppState.taskbarManualState && AppState.dockbarManualState && !SettingsCoordinator.closeBlocked, "Taskbar remains applied after output transfer and preserves the Dockbar request")
            var topbar = find(panel.shellPage, item => item.text === "Top Bar")
            check(topbar && topbar.enabled, "layout selector remains usable after applying Taskbar")
            topbar.clicked()
            redesignStep = 129
        } else if (step === 130) {
            if (SettingsCoordinator.dirty || SettingsCoordinator.busy) return false
            check(!AppState.taskbarManualState && AppState.dockbarManualState && SettingsCoordinator.state("dockbar").enabled, "Top Bar applies directly and restores the requested Dockbar")
            check(!SettingsCoordinator.closeBlocked && !SettingsCoordinator.actionLabels.includes("Keep") && !SettingsCoordinator.footerStatus, "Top Bar requires no confirmation or countdown")
            checkLayoutWindows(true)
            panel.selectCategory("Power & Session")
            redesignStep = 13
        } else if (step === 14) {
            check(find(panel.generalPage, item => item.text === "Total time to suspend: 19 min"), "idle timeline displays absolute total")
            SettingsCoordinator.set("idle-keep-awake", true)
            pointer.running = true
            redesignStep = 139
        } else if (step === 140) {
            var timeline = find(panel.generalPage, item => item.stages !== undefined && item.dragLimit !== undefined)
            idleDragMarker = find(timeline, item => item.objectName === "settings-idle-milestone-dim")
            var point = idleDragMarker.mapToItem(panel.contentItem, idleDragMarker.width / 2, idleDragMarker.height / 2)
            pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + host.modelData.width + " " + host.modelData.height + " 272 1\n")
        } else if (step === 141) {
            var timeline = find(panel.generalPage, item => item.stages !== undefined && item.dragLimit !== undefined)
            if (!timeline.dragLimit) return false
            idleDragScale = timeline.dragLimit
            var graph = find(timeline, item => item.objectName === "settings-idle-preview")
            idleDragPoint = graph.mapToItem(panel.contentItem, 8 + 600 / idleDragScale * (graph.width - 32), idleDragMarker.y + idleDragMarker.height / 2)
            pointer.write(Math.round(idleDragPoint.x) + " " + Math.round(idleDragPoint.y) + " " + host.modelData.width + " " + host.modelData.height + " 0\n")
        } else if (step === 142) {
            var timeline = find(panel.generalPage, item => item.stages !== undefined && item.dragLimit !== undefined)
            if (timeline.policy.dimTimeout !== 600) return false
            var marker = find(timeline, item => item.objectName === "settings-idle-milestone-dim")
            var grab = find(marker, item => item.cursorShape === Qt.SizeHorCursor && item.pressed !== undefined)
            check(marker === idleDragMarker && grab && grab.pressed, "policy updates preserve the real marker pointer grab")
            check(timeline.total > idleDragScale && timeline.dragLimit === idleDragScale, "drag conversion stays stable while later milestones exceed the initial range")
            checkIdlePreview(timeline)
            pointer.write(Math.round(idleDragPoint.x) + " " + Math.round(idleDragPoint.y) + " " + host.modelData.width + " " + host.modelData.height + " 272 0\n")
            capture("settings-idle-preview-large")
        } else if (step === 143) {
            var timeline = find(panel.generalPage, item => item.stages !== undefined && item.dragLimit !== undefined)
            if (timeline.dragLimit || SettingsCoordinator.dirty) return false
            pointer.running = false
            for (var key of ["dim", "lock", "displayOff", "suspend"]) SettingsCoordinator.set("idle-" + key + "Timeout", 86400, true)
        } else if (step === 144) {
            if (SettingsCoordinator.dirty) return false
            var timeline = find(panel.generalPage, item => item.stages !== undefined && item.dragLimit !== undefined)
            check(timeline.total === 345600, "preview accepts the maximum cumulative interval")
            checkIdlePreview(timeline)
            for (var key of ["dim", "lock", "displayOff", "suspend"]) SettingsCoordinator.reset("idle-" + key + "Timeout")
        } else if (step === 145) {
            if (SettingsCoordinator.dirty) return false
            var timeline = find(panel.generalPage, item => item.stages !== undefined && item.dragLimit !== undefined)
            check(timeline.total === 1140 && timeline.dragLimit === 0, "normal interval editing leaves no stale drag scale")
            checkIdlePreview(timeline)
            redesignStep = 14
        } else if (step === 15) {
            if (SettingsCoordinator.dirty) return false
            check(find(panel.generalPage, item => item.text === "Paused by Keep Awake"), "runtime inhibitor is visible")
            var stage = find(panel.generalPage, item => item.text === "5 min" && item.settingsNavRole === "input")
            check(stage && stage.enabled && stage.font.pixelSize === Theme.fontSize, "Keep Awake leaves timer editing enabled with readable text size")
            check(stage.leftPadding >= Theme.spaceLg && stage.rightPadding >= Theme.spaceLg && stage.topPadding >= Theme.spaceSm && stage.bottomPadding >= Theme.spaceSm, "duration text has comfortable insets")
            var preset = find(stage.parent, item => item.text === "1 min" && item.settingsNavItem === true)
            check(preset && preset.border.width === 0, "duration presets use filled surfaces without outlines")
            preset.forceActiveFocus()
            check(find(preset, item => item.height === 1 && item.visible), "borderless buttons keep a visible keyboard focus indicator")
            idleEditor = stage
            SettingsCoordinator.set("idle-lockEnabled", false)
        } else if (step === 16) {
            if (SettingsCoordinator.dirty) return false
            check(ShellSettingsStore.savedValues.idle.lockTimeout === 120, "disabled idle stage retains its interval")
            check(idleEditor && find(panel.generalPage, item => item.text === "5 min" && item.settingsNavRole === "input") === idleEditor, "idle stage changes preserve existing editor instances")
            SettingsCoordinator.reset("idle-lockEnabled")
            SettingsCoordinator.set("idle-keep-awake", false)
            panel.generalPage.reveal("RAM_THRESHOLD_MB", "Session Exit")
            initialRamThreshold = SettingsCoordinator.read("RAM_THRESHOLD_MB")
            pointer.running = true
            redesignStep = 159
        } else if (step === 160) {
            if (SettingsCoordinator.dirty) return false
            var row = find(panel.generalPage, item => item.descriptor && item.descriptor.id === "RAM_THRESHOLD_MB")
            var slider = find(row.control.item, item => item.settingsNavEditing !== undefined)
            var number = find(row.control.item, item => item.settingsNavOwnsVertical === true)
            check(number && number.editable && slider && slider.visible && slider.from === 0 && slider.to === 2048, "RAM threshold restores a slider covering 0–2048 MB")
            var point = slider.mapToItem(panel.contentItem, slider.leftPadding + 1, slider.height / 2)
            pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + host.modelData.width + " " + host.modelData.height + " 272\n")
        } else if (step === 161) {
            if (SettingsCoordinator.dirty || SettingsStore.savedValues.RAM_THRESHOLD_MB !== 0) return false
            var row = find(panel.generalPage, item => item.descriptor && item.descriptor.id === "RAM_THRESHOLD_MB")
            var slider = find(row.control.item, item => item.settingsNavEditing !== undefined)
            var number = find(row.control.item, item => item.settingsNavOwnsVertical === true)
            number.down.indicator.clicked()
            check(SettingsCoordinator.read("RAM_THRESHOLD_MB") === 0, "RAM decrement stops at zero")
            var point = slider.mapToItem(panel.contentItem, slider.width - slider.rightPadding - 1, slider.height / 2)
            pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + host.modelData.width + " " + host.modelData.height + " 272\n")
        } else if (step === 162) {
            if (SettingsCoordinator.dirty || SettingsStore.savedValues.RAM_THRESHOLD_MB === 0) return false
            check(SettingsStore.savedValues.RAM_THRESHOLD_MB === 2048, "RAM slider reaches its exact maximum: " + SettingsStore.savedValues.RAM_THRESHOLD_MB)
            var row = find(panel.generalPage, item => item.descriptor && item.descriptor.id === "RAM_THRESHOLD_MB")
            var number = find(row.control.item, item => item.settingsNavOwnsVertical === true)
            number.up.indicator.clicked()
            check(SettingsCoordinator.read("RAM_THRESHOLD_MB") === 2048, "RAM increment stops at 2048 MB")
            check(!SettingsCoordinator.set("RAM_THRESHOLD_MB", -1) && !SettingsCoordinator.set("RAM_THRESHOLD_MB", 2049), "RAM editing rejects values outside the requested bounds")
            pointer.running = false
            number.contentItem.forceActiveFocus(); number.contentItem.selectAll()
            keyboard.write("key 6\nkey 6\nkey 8\nkey 28\n")
        } else if (step === 163) {
            if (SettingsCoordinator.dirty || SettingsStore.savedValues.RAM_THRESHOLD_MB !== 557) return false
            check(SettingsStore.savedValues.RAM_THRESHOLD_MB === 557, "RAM slider retains exact numeric entry")
            SettingsCoordinator.set("RAM_THRESHOLD_MB", initialRamThreshold, false)
        } else if (step === 164) {
            if (SettingsCoordinator.dirty) return false
            capture("settings-session-exit", function() { root.panel.selectCategory("Wallpaper") })
            redesignStep = 16
        } else if (step === 17) {
            check(!find(panel.wallpaperPage, item => item.objectName === "wallpaper-cache-list"), "main wallpaper scroll has no cache inventory")
            check(!find(panel.wallpaperPage, item => ["Instant", "Default", "Next action", "Restart Hikai", "Next sign-in"].includes(item.text)), "option descriptions replace the status badge row")
            var loop = find(panel.wallpaperPage, item => item.descriptor && item.descriptor.id === "wallpaper.playback.loop")
            var summary = find(loop, item => item.text === "Replay the wallpaper video when it ends.")
            check(summary && summary.visible && summary.wrapMode === Text.Wrap && summary.width > 0 && summary.width <= loop.width, "Loop video shows its readable, wrapping function description")
            var manage = find(panel.wallpaperPage, item => item.text === "Manage cache…")
            check(manage, "cache has a dedicated manager")
            manage.forceActiveFocus()
            manage.clicked()
            redesignStep = 169
        } else if (step === 170) {
            var popup = panel.wallpaperPage.data.find(item => item.objectName === "settings-wallpaper-cache-dialog")
            if (popup.revealProgress < 1) return false
            check(cacheOpeningObserved && popup.padding >= Theme.spaceXl && popup.background.border.width === 1, "cache manager opens with animation, padding and a subtle outline")
            var prepare = find(popup.contentItem, item => item.caption === "Prepare current")
            check(prepare && !prepare.enabled && prepare.parent.enabled && prepare.parent.reason.includes("not a video"), "disabled Prepare current retains a hoverable reason")
            if (WallpaperService.cacheBusy) return false
            WallpaperService.error = ""; WallpaperService.cacheMessage = "Cache is up to date"; WallpaperService.cacheBytes = 40 * 1048576
            WallpaperService.cacheEntries = Array.from({length: 20}, (_, index) => ({label: "A long prepared wallpaper name " + index, path: "/videos/" + index + ".mp4", bytes: 2097152, profile: "screen", render: {width: 1920, height: 1080, fps: 60}, active: index === 0}))
        } else if (step === 171) {
            var popup = panel.wallpaperPage.data.find(item => item.objectName === "settings-wallpaper-cache-dialog")
            var list = find(popup.contentItem, item => item.objectName === "wallpaper-cache-list")
            check(list.count === 20 && list.height <= 4 * (list.rowHeight + list.spacing) && list.contentHeight > list.height, "cache manager bounds long inventories")
            cacheViewport = popup.contentItem.item
            dropdownCapture.filename = "settings-wallpaper-cache"; dropdownCapture.running = true
            redesignStep = 1709
        } else if (step === 1710) {
            if (dropdownCapture.running) return false
            find(cacheViewport, item => item.objectName === "wallpaper-clear-unused").clicked()
        } else if (step === 1711) {
            var cache = find(cacheViewport, item => typeof item.cacheSize === "function")
            var confirm = cache.data.find(item => item.objectName === "wallpaper-clear-cache-dialog")
            if (confirm.revealProgress < 1) return false
            check(confirm.visible && confirm.padding >= Theme.spaceXl && confirm.background.border.width === 1, "cache deletion requires a padded, themed confirmation")
            confirm.reject()
        } else if (step === 1712) {
            var cache = find(cacheViewport, item => typeof item.cacheSize === "function")
            var confirm = cache.data.find(item => item.objectName === "wallpaper-clear-cache-dialog")
            if (confirm.visible) return false
            check(WallpaperService.cacheEntries.length === 20, "cancelling deletion preserves every cache entry")
            panel.wallpaperPage.data.find(item => item.objectName === "settings-wallpaper-cache-dialog").close()
            redesignStep = 171
        } else if (step === 172) {
            var popup = panel.wallpaperPage.data.find(item => item.objectName === "settings-wallpaper-cache-dialog")
            if (popup.revealProgress === 1) return false
            check(cacheClosingObserved && popup.visible && popup.contentItem.item === cacheViewport, "cache close retains its viewport through the exit animation")
            var progress = popup.revealProgress
            popup.open()
            check(popup.revealProgress === progress && popup.contentItem.item === cacheViewport, "reopening cache reverses from the current frame")
        } else if (step === 173) {
            var popup = panel.wallpaperPage.data.find(item => item.objectName === "settings-wallpaper-cache-dialog")
            if (popup.revealProgress < 1) return false
            popup.close()
        } else if (step === 174) {
            var popup = panel.wallpaperPage.data.find(item => item.objectName === "settings-wallpaper-cache-dialog")
            if (popup.visible) return false
            check(!popup.contentItem.active && !popup.contentItem.item, "cache viewport is released after closing")
            check(find(panel.wallpaperPage, item => item.text === "Manage cache…").activeFocus, "cache close restores the initiating button focus")
            WallpaperLibrary.items = [{label: "Bravo", path: "/bravo", kind: "static", previewVersion: "100"}, {label: "alpha", path: "/alpha", kind: "static", previewVersion: "300"}, {label: "charlie", path: "/charlie", kind: "static", previewVersion: "200"}, {label: "video", path: "/video", kind: "video", previewVersion: "400"}]
            WallpaperLibrary.filter = "static"; WallpaperLibrary.query = ""; WallpaperLibrary.selectedPath = "/bravo"
            find(panel.wallpaperPage, item => item.text === "Name Z–A").clicked()
        } else if (step === 175) {
            if (SettingsCoordinator.dirty) return false
            check(WallpaperLibrary.filteredItems.map(item => item.path).join("|") === "/charlie|/bravo|/alpha" && WallpaperLibrary.selectedPath === "/bravo", "descending browser sort updates the list while retaining selection")
            find(panel.wallpaperPage, item => item.text === "Newest first").clicked()
        } else if (step === 176) {
            if (SettingsCoordinator.dirty) return false
            check(WallpaperLibrary.filteredItems.map(item => item.path).join("|") === "/alpha|/charlie|/bravo" && WallpaperLibrary.selectedPath === "/bravo", "newest browser sort uses file timestamps while retaining selection")
            WallpaperLibrary.query = "br"
            check(WallpaperLibrary.filteredItems.length === 1 && WallpaperLibrary.selected.path === "/bravo", "sorting retains search and media filters")
            WallpaperLibrary.query = ""
            WallpaperSettingsStore.reload()
        } else if (step === 177) {
            if (WallpaperSettingsStore.loading) return false
            check(WallpaperSettingsStore.savedValues.browser.sort === "newest", "browser sort survives settings reload")
            find(panel.wallpaperPage, item => item.text === "Name A–Z").clicked()
        } else if (step === 178) {
            if (SettingsCoordinator.dirty) return false
            check(WallpaperLibrary.filteredItems.map(item => item.path).join("|") === "/alpha|/bravo|/charlie", "ascending browser sort ignores letter case")
            check(WallpaperLibrary.items[0].path === "/bravo", "browser sorting preserves source record order")
            console.info("Wallpaper browser sort and cache dialog checks passed")
            WallpaperLibrary.items = []
            SettingsCoordinator.set("wallpaper.playback.hardwareDecode", "software")
            redesignStep = 17
        } else if (step === 18) {
            if (WallpaperSettingsStore.dirty) return false
            check(SettingsCoordinator.restartRequired && SettingsCoordinator.categoryStatus("Wallpaper"), "saved decoder change exposes restart status")
            SettingsCoordinator.undo()
            panel.wallpaperPage.reveal("wallpaper.playback.loop", "Video playback")
            capture("settings-wallpaper", function() { root.panel.selectCategory("Capture") })
        } else if (step === 19) {
            if (WallpaperSettingsStore.dirty) return false
            check(!SettingsCoordinator.restartRequired, "Undo clears restart requirement")
            check(find(panel.generalPage, item => item.text === "Maximum frame rate"), "recorder FPS has a structured control")
            var path = find(panel.generalPage, item => item.label === "Screenshot folder" && item.value !== undefined)
            var pathInput = find(path, item => item.settingsNavRole === "input" && item.font !== undefined)
            check(pathInput && pathInput.font.pixelSize === Theme.fontSize - 1 && pathInput.verticalAlignment === TextInput.AlignVCenter && pathInput.leftPadding >= Theme.spaceLg && pathInput.rightPadding >= Theme.spaceLg, "path input keeps consistent typography, vertical centering and padding")
            var advanced = find(panel.generalPage, item => item.text === "Advanced recording options")
            check(advanced, "extra recording options have a local disclosure button")
            advanced.clicked()
            redesignStep = 189
        } else if (step === 190) {
            var field = find(panel.generalPage, item => item.placeholderText === "Extra arguments")
            if (!field || field.parent.progress < 1) return false
            var button = find(panel.generalPage, item => item.text === "Hide advanced options")
            check(argumentsOpeningObserved && field.parent.y === button.y + button.height + button.parent.spacing, "extra arguments animate directly under their disclosure button")
            button.clicked()
        } else if (step === 191) {
            var field = find(panel.generalPage, item => item.placeholderText === "Extra arguments")
            if (field.parent.progress > 0) return false
            check(!field.parent.visible && !field.parent.enabled, "hidden advanced arguments release space and focus")
            capture("settings-capture", function() { root.panel.selectCategory("Advanced") })
            redesignStep = 19
        } else if (step === 20) {
            if (!ConfigEditorStore.hasFile) return false
            check(ConfigEditorStore.selectedFileId === "wm/niri-custom.kdl", "active compositor config sorts first")
            ConfigEditorStore.setText("draft survives category switch\n")
            panel.selectCategory("Look")
        } else if (step === 21) {
            check(ConfigEditorStore.dirty, "category switch retains document draft")
            panel.selectCategory("Advanced")
        } else if (step === 22) {
            ConfigEditorStore.setText(Array.from({length: 120}, function(_, i) { return "line " + i }).join("\n"))
            var editor = find(panel.configPage, item => item.forceEditorFocus !== undefined)
            expandedEditorHeight = editor.height
            editor.forceEditorFocus(); keyboard.write("key 107 4\n")
            redesignStep = 199
        } else if (step === 200) {
            var editor = find(panel.configPage, item => item.forceEditorFocus !== undefined)
            check(!find(panel.configPage, item => ["Save & Reload", "Save only", "More actions…", "Validate"].includes(item.text)), "editor has no permanent action toolbar")
            check(editor.height >= expandedEditorHeight, "editor keeps its full viewport while scrolling")
            var nativeEditor = find(editor, item => item.settingsNavRole === "editor")
            var gutter = find(nativeEditor, item => item.firstLine !== undefined)
            var lineStart = nativeEditor.text.split("\n").slice(0, gutter.firstLine).join("\n").length + (gutter.firstLine > 0 ? 1 : 0)
            check(Math.abs(gutter.y - nativeEditor.positionToRectangle(lineStart).y) < 1, "line numbers align with native text layout after scrolling")
            capture("settings-advanced-editor", function() { keyboard.write("key 102 4\n") })
        } else if (step === 201) {
            ConfigEditorStore.setText("draft survives category switch\n")
            var editor = find(panel.configPage, item => item.forceEditorFocus !== undefined)
            editor.forceEditorFocus(); keyboard.write("key 37 4\n")
            redesignStep = 22
        } else if (step === 23) {
            check(panel.focusZoneIndex() === 2, "Ctrl+K leaves the code editor shortcut context intact")
            panel.configPage.requestReload()
            check(panel.configPage.confirmation === "reload", "dirty document reload is guarded")
            panel.configPage.cancelConfirmation()
            configDraft = ConfigEditorStore.text
            ConfigEditorStore.save("write")
        } else if (step === 24) {
            if (ConfigEditorStore.dirty) return false
            check(ConfigEditorStore.savedText === configDraft, "Save only persists document text")
            panel.configPage.requestReload()
            capture("settings-advanced")
        } else if (step === 25) {
            panel.focusZone(1); keyboard.write("key 37 4\n")
        } else if (step === 26) {
            var search = find(panel.contentItem, item => item.inputFocused !== undefined && typeof item.focusSearch === "function")
            if (!search.inputFocused) return false
            keyboard.write("text blue light\nkey 28\n")
        } else if (step === 27) {
            if (panel.selectedCategory !== "Power & Session") return false
            check(panel.highlightedId === "NIGHT_LIGHT_TEMPERATURE", "search navigates and highlights its row")
            check(panel.focusZoneIndex() === 2, "search focuses the target control")
            panel.focusZone(1); keyboard.write("key 64\n")
        } else if (step === 28) {
            check(panel.focusZoneIndex() === 2, "F6 cycles from sidebar to content")
            panel.selectCategory("Shell")
        } else if (step === 29) {
            var defaultRow = find(panel.shellPage, item => item.descriptor && item.descriptor.id === "shell.dock.iconSize")
            check(defaultRow && defaultRow.visible, "default preferences remain visible without the removed filter")
            panel.selectCategory("About")
            redesignStep = 101
        } else if (step === 102) {
            if (SettingsCoordinator.dirty) return false
            SettingsCoordinator.set("radius", 20, false)
            check(ShellSettingsStore.saving, "first slider value is in flight")
            SettingsCoordinator.set("radius", 21, true)
        } else if (step === 103) {
            if (SettingsCoordinator.dirty) return false
            check(ShellSettingsStore.savedValues.appearance.baseRadius === 21 && ShellSettingsStore.baseRadius === 21, "edits during a save survive and persist in order")
            SettingsCoordinator.reset("radius")
        } else if (step === 104) {
            if (SettingsCoordinator.dirty) return false
            redesignStep = 30
        } else if (step === 31) {
            if (!InfoStore.ready) return false
            check(find(panel.infoPage, item => item.text === "About"), "About title matches navigation")
            capture("settings-about")
        } else if (step === 32) {
            check(panel.targetBodyWidth === Math.min(1180, host.modelData.width - 64) && panel.targetBodyHeight === Math.min(750, host.modelData.height - 64), "Settings uses fixed dimensions within the output bounds")
            check(!find(panel.contentItem, item => item.cursorShape === Qt.SizeFDiagCursor || item.text === "◢"), "Settings has no resize handle or resize cursor")
            dialogLease = UiState.beginNativeDialog("settings")
            check(dialogLease > 0 && panel.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None, "native chooser releases exclusive keyboard lease")
            UiState.endNativeDialog(dialogLease)
            check(UiState.ownsInteraction("settings", output), "native chooser restores Settings ownership")
            panel.selectCategory("Advanced"); ConfigEditorStore.setText(ConfigEditorStore.text + "unsaved\n")
            panel.requestClose(); check(panel.confirmation === "close", "dirty document blocks close")
            panel.confirmation = ""; ConfigEditorStore.discard()
            originalWelcome = SettingsStore.savedValues.WELCOME_MSG
            SettingsCoordinator.set("WELCOME_MSG", !originalWelcome)
            panel.requestClose()
            return true
        }
        redesignStep++
        return false
    }
    // Every visible exclusive surface must agree with the shared output owner.
    function ownership() {
        var exclusive = 0
        for (var owner of hosts) for (var loader of owner.loaders) {
            if (!loader.active || !loader.item) continue
            var window = loader.item
            if (window.WlrLayershell && window.WlrLayershell.keyboardFocus === WlrKeyboardFocus.Exclusive) ++exclusive
        }
        check(exclusive <= 1, "at most one exclusive keyboard owner")
        if (UiState.interactionOwner === "tempNote") check(UiState.tempNoteOpen, "no invisible note owner")
    }
    Timer {
        interval: 90; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 450, "runtime timeout (animation phase " + root.animationPhase + ", redesign step " + root.redesignStep + ")")
            if (!root.host || root.captures || fontFailure.running || Avatar.busy || SettingsStore.loading || SettingsStore.saving || ShellSettingsStore.loading || ShellSettingsStore.saving || ConfigEditorStore.busy || WallpaperSettingsStore.loading || WallpaperSettingsStore.saving) return
            root.ownership()
            if (phase === 0) {
                WM.backendName = "niri"
                Theme.apply(JSON.stringify({accent: "#88c0d0", font: "monospace", fgDim: "#b39ab8"}))
                UiState.openSettings(root.output)
            } else if (phase === 1) {
                if (root.animationPhase < 6 || !root.panel || !root.panel.interactionReady || !SettingsStore.ready) return
                if (!root.redesignProbe()) return
                root.phase = 9
            } else if (phase === 10) {
                if (root.panel) return
                root.check(!SettingsStore.dirty && !ShellSettingsStore.dirty && SettingsStore.savedValues.WELCOME_MSG === !root.originalWelcome, "normal preference close waits for autosave without a prompt")
                root.checkLayoutWindows(false)
                if (Quickshell.env("INK_SETTINGS_ONLY") === "1") {
                    console.info("Ink Settings checks passed (Settings only)")
                    Qt.quit()
                    return
                }
                UiState.openNavigation(root.output, {x: 12, y: 0, width: 40, height: 32})
            } else if (phase === 11) {
                if (!root.nav) return
                UiState.beginNavigationHandoff("sidebar")
                root.nav.focusSidebarRail(true)
                keyboard.write("key 106\n")
            } else if (phase === 12) {
                var layer = root.find(root.nav, item => item.focusContent !== undefined && item.toolContent !== undefined)
                if (root.toolPhase === 0) {
                    if (!root.nav.sidebarToolOpen || !layer || layer.activeProgress < 0.99) return
                    root.check(root.nav.sidebarToolOpen, "Right opens the selected Sidebar tool")
                    keyboard.write("key 1\n")
                    ++root.toolPhase
                    return
                }
                if (root.toolPhase === 1) {
                    if (root.nav.sidebarToolOpen) return
                    root.check(root.nav.panelOpen && root.nav.sidebarKeyboardMode, "Escape returns from tool to rail")
                    keyboard.write("key 106\n")
                    ++root.toolPhase
                    return
                }
                if (!root.nav.sidebarToolOpen || !layer || layer.activeProgress < 0.99) return
                root.nav.toggleSidebarTool("tempNote", true)
            } else if (phase === 13) {
                if (!root.note || !root.note.interactionReady) return
                root.check(UiState.navigationMode === "closed" && (!root.nav || !root.nav.panelOpen), "note handoff dismisses Navigation")
                root.check(UiState.ownsInteraction("tempNote", root.output), "note owns keyboard after opening")
                keyboard.write("text ownership test\n")
            } else if (phase === 14) {
                if (!TextStore.scratchDraft.includes("ownership test")) return
                UiState.openSettings(root.output)
            } else if (phase === 15) {
                if (!root.panel || !root.panel.interactionReady) return
                if (root.pointerPhase === 0) root.check(root.note.panelOpen && !root.note.keyboardRequested, "pinned note releases its exclusive lease")
                var x = UiState.tempNoteRect.x + 60, y = UiState.tempNoteRect.y + 90
                if (root.pointerPhase === 0) { pointer.running = true; ++root.pointerPhase; return }
                if (root.pointerPhase === 1) { pointer.write(x + " " + y + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 1\n"); ++root.pointerPhase; return }
                if (root.pointerPhase === 2) { pointer.write(x + " " + y + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 0\n"); ++root.pointerPhase; return }
                if (root.pointerPhase === 3) { pointerCapture.running = true; ++root.pointerPhase; return }
                if (pointerCapture.running) return
                var search = root.find(root.panel.contentItem, item => item.inputFocused !== undefined && typeof item.focusSearch === "function")
                var point = search.mapToItem(root.panel.contentItem, search.width / 2, search.height / 2)
                if (root.pointerPhase === 4) {
                    root.check(UiState.ownsInteraction("tempNote", root.output), "real click returns focus to visible passive note")
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 1\n")
                    ++root.pointerPhase
                    return
                }
                if (root.pointerPhase === 5) {
                    pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + root.host.modelData.width + " " + root.host.modelData.height + " 272 0\n")
                    ++root.pointerPhase
                    return
                }
                root.check(UiState.ownsInteraction("settings", root.output) && search.inputFocused, "real click returns keyboard to Settings input")
                UiState.closeSettings()
                UiState.closeTempNote()
            } else if (phase === 16) {
                if (root.note) return
                UiState.openNavigation(root.output, {x: 12, y: 0, width: 40, height: 32})
            } else if (phase === 17) {
                if (!root.nav) return
                UiState.beginNavigationHandoff("sidebar")
                root.nav.openSidebarTool("clipboard", true)
                root.nav.toggleSidebarTool("tempNote", true)
            } else if (phase === 18) {
                if (!root.note || !root.note.interactionReady) return
                UiState.closeTempNote()
                UiState.openNavigation(root.output, {x: 12, y: 0, width: 40, height: 32})
            } else if (phase === 19) {
                if (!root.nav) return
                UiState.beginNavigationHandoff("sidebar")
                if (root.clipboardPhase === 0) {
                    root.nav.openSidebarTool("clipboard", true)
                    ++root.clipboardPhase
                    return
                }
                if (root.clipboardPhase === 1) {
                    var layer = root.find(root.nav, item => item.focusContent !== undefined && item.toolContent !== undefined)
                    if (!layer || layer.activeProgress < 0.99) return
                    root.check(root.nav.sidebarToolOpen, "Clipboard reopens after note handoff")
                    keyboard.write("key 105\n")
                    ++root.clipboardPhase
                    return
                }
                if (root.nav.sidebarToolOpen) return
                root.check(root.nav.panelOpen && root.nav.sidebarKeyboardMode, "Left returns Clipboard to rail")
                UiState.closeNavigation()
            } else if (phase === 20) {
                UiState.openTempNote(root.output)
            } else if (phase === 21) {
                if (!root.note) return
                keyboard.write("key 1\n")
            } else if (phase === 22) {
                if (UiState.tempNoteOpen) return
                root.check(UiState.interactionOwner === "", "early Escape releases note ownership")
                if (++root.rounds < 20) { root.phase = 20; return }
                UiState.openTempNote(root.hosts[1].modelData.name)
            } else if (phase === 23) {
                if (UiState.interactionOwner !== "tempNote") return
                root.check(UiState.tempNoteScreenName === root.hosts[1].modelData.name, "note transfers to second output")
                UiState.closeTempNoteIfScreen(root.output)
                root.check(UiState.tempNoteOpen, "stale output cannot close the new owner")
                UiState.closeTempNote()
                root.originalAvatar = Avatar.path
                ImageEditor.openAvatar(Quickshell.env("INK_TEST_ROOT") + "/avatar-wide.png", root.output)
            } else if (phase === 24) {
                if (!ImageEditor.ready) return
                ImageEditor.save("")
            } else if (phase === 25) {
                if (ImageEditor.busy || ImageEditor.sourcePath) return
                root.check(Avatar.path && Avatar.path !== root.originalAvatar && Avatar.revision > 0, "editor committed through the avatar controller")
                root.check(!Avatar.lastError, "avatar persistence completed")
                UiState.openSettings(root.hosts[1].modelData.name)
            } else if (phase === 26) {
                if (!root.hosts[1].loaders[1].active || !root.hosts[1].loaders[1].item.interactionReady) return
                var second = root.hosts[1].loaders[1].item
                root.check(second.panelOpen && (!root.panel || !root.panel.panelOpen), "Settings transfers to second output")
                root.captureSecond(second)
                UiState.closeSettings()
            } else if (phase === 27) {
                NotificationStore.start(root.notificationMemory)
            } else if (phase === 28) {
                if (!NotificationStore.server.objectAt(0)) return
                notificationSender.running = true
            } else if (phase === 29) {
                var popup = root.host.loaders[7].item
                if (NotificationStore.count !== 1 || !popup || popup.revealTarget <= 0 || Math.abs(popup.revealHeight - popup.revealTarget) > 0.5) return
                notificationCapture.running = true
                UiState.openTempNote(root.output)
            } else if (phase === 30) {
                if (notificationCapture.running || !root.note || !root.note.interactionReady) return
                UiState.toggleNotifications(root.output, {x: root.host.modelData.width - 80, y: 0, width: 40, height: 36})
            } else if (phase === 31) {
                var center = root.host.loaders[4].item
                var flare = root.find(center, item => item.naturalContentHeight !== undefined && item.horizontalPadding !== undefined)
                if (!flare || flare.currentHeight < flare.naturalContentHeight + flare.verticalPadding * 2 - 1) return
                root.check(root.note.panelOpen && !root.note.keyboardRequested && UiState.ownsInteraction("notifications", root.output), "Notification Center takes the note keyboard lease")
                notificationCapture.command = ["grim", "-o", root.output, Quickshell.env("INK_ARTIFACT_DIR") + "/notifications-center.png"]
                notificationCapture.running = true
            } else if (phase === 32) {
                if (notificationCapture.running) return
                NotificationStore.toggleDnd()
                root.check(NotificationStore.dnd, "DND remains functional")
                NotificationStore.toggleDnd()
                UiState.closeNotifications()
                root.check(UiState.interactionOwner === "" && UiState.tempNoteOpen, "closing notifications never revives a stale note lease")
                UiState.closeTempNote()
                NotificationStore.clearAll()
            } else {
                if (root.hosts.some(owner => owner.loaders.slice(0, 8).some(loader => loader.active))) return
                root.check(!SettingsStore.dirty && !ConfigEditorStore.dirty, "all drafts settled")
                console.info("Ink Settings checks passed")
                Qt.quit()
                return
            }
            ++root.phase
        }
    }
    // Capture the final output independently of the first host's released Settings tree.
    function captureSecond(second) {
        check(UiState.ownsInteraction("settings", second.modelData.name), "second output owns Settings input")
    }
}
