import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "services"
import "components"
import "components/base" as Base
import "components/wallpaper" as Wallpaper
import "components/settings" as Settings

ShellRoot {
    id: root
    // Real per-output windows exercise reservation and lifecycle contracts in isolation.
    property var outputs: []
    readonly property bool expectV3: Quickshell.env("HAKUSPACE_LEFTBAR_EXPECT_V3") !== "0"
    property real hoverWidth: 0
    property real hoverHeight: 0
    property real hoverPaintHeight: 0
    property int phase: 0
    onPhaseChanged: console.info("Leftbar phase " + phase)
    property int ticks: 0
    property int switches: 0
    property int matrixIndex: 0
    property bool dndBefore: false
    property int monthBefore: 0
    property var frameDecorations: ({})
    property int frameSettleTicks: 0
    property string navScreen: ""
    property var navAnchor: null
    property int gateChecks: 0
    property bool sawWorkspaceReturnFade: false
    property bool sawWorkspaceHiddenBeforeMidpoint: false
    property bool sawDashboardWorkspaceReturn: false
    property bool sawWallpaperTooltipFadeIn: false
    property bool sawWallpaperTooltipFadeOut: false
    property bool sawWallpaperLeadingFadeOut: false
    property bool sawWallpaperLeadingFadeIn: false
    property int navReleaseChecks: 0
    property int keyboardSelection: -1
    property int workspaceKeyIndex: 0
    // Native arrows must browse in either search-focus state; Tab only toggles focus.
    readonly property var workspaceKeyCases: [[105, -1, true], [106, 1, true], [103, -1, true], [108, 1, true], [15, 0, false],
        [105, -1, false], [106, 1, false], [103, -1, false], [108, 1, false], [15, 0, true]]
    property int reloadSettleTicks: 0
    property int startupSettleTicks: 0
    property int referenceSettleTicks: 0
    property int tooltipSettleTicks: 0
    property real normalRailWidth: 0
    property int desktopClicks: 0
    property int cardinalityIndex: 0
    property int nativeCardIndex: -1
    property real categoryStartY: 0
    property bool sawCategoryMorph: false
    property var records: []
    property var client: null
    property var baseline: ({})
    property var memory: QtObject { property string recordsJson: "[]"; property int nextKey: 1 }
    TextMetrics { id: categoryArrowMetrics }
    Component.onDestruction: WallpaperService.shutdown()
    function check(ok, message) {
        if (ok) return
        console.error("Leftbar failed at " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Compare painted selection and label bounds in the same native coordinate space.
    function checkMediaIndicator(browser) {
        var indicator = named(browser, "wallpaper-type-indicator")
        var button = named(browser, "wallpaper-kind-" + browser.filter)
        var lane = button.parent.parent
        check(indicator.parent === button.parent && button.pressScaleDelta === 0 && button.pressXScaleDelta === 0,
            "workspace media labels and selection share one stable origin during presses")
        check(Math.abs(lane.radius - button.radius - button.parent.x) < 0.5
            && Math.abs(indicator.radius - button.radius) < 0.5,
            "media pill corners follow the outer frame inset")
        var arrow = named(browser, "wallpaper-prev-category")
        check(Math.abs(lane.mapToItem(browser, lane.width / 2, 0).x - arrow.mapToItem(browser, arrow.width / 2, 0).x) < 0.5,
            "media frame shares the category arrow's center axis")
        var painted = indicator.mapToItem(browser, 0, 0)
        var target = button.mapToItem(browser, 0, 0)
        check(Math.abs(painted.x - target.x) < 0.5 && Math.abs(painted.y - target.y) < 0.5
            && Math.abs(indicator.width - button.width) < 0.5 && Math.abs(indicator.height - button.height) < 0.5,
            "media pill aligns with its selected label: " + JSON.stringify({painted: painted, target: target,
                pillWidth: indicator.width, pillHeight: indicator.height, buttonWidth: button.width, buttonHeight: button.height}))
    }
    function find(item, type) {
        if (!item) return null
        if (String(item).indexOf(type + "_QMLTYPE") >= 0) return item
        if (item.active === true && item.item) { var loaded = find(item.item, type); if (loaded) return loaded }
        var children = item.contentItem ? item.contentItem.children : item.children || []
        try {
            if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        } catch (error) {}
        for (var index = 0; index < children.length; index++) {
            var result = find(children[index], type)
            if (result) return result
        }
        return null
    }
    function named(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        var children = item.contentItem ? item.contentItem.children : item.children || []
        for (var child of children) { var found = named(child, name); if (found) return found }
        return null
    }
    // Leading modules retain their footprint while wallpaper owns one output.
    function checkWallpaperLeadingModules(output, hidden) {
        var logo = root.named(output.bar.contentItem, "leftbar-logo-slot")
        var workspaces = root.named(output.bar.contentItem, "leftbar-workspace-lane")
        root.check(!!logo && logo.opacity === (hidden ? 0 : 1) && logo.enabled === !hidden,
            "wallpaper hides and disables only the owning output's logo")
        root.check(!!workspaces && workspaces.opacity === (hidden ? 0 : 1) && workspaces.enabled === !hidden,
            "wallpaper hides and disables only the owning output's workspace lane")
    }
    // Check actual paint rectangles independently from their transparent pointer wrappers.
    function checkDensity(output) {
        var rail = ScreenGeometry.leftBarWidth
        var gutter = ScreenGeometry.leftVisualGutter
        var quick = root.find(output.bar.contentItem, "SettingsGroup")
        var tray = root.find(output.bar.contentItem, "TrayGroup")
        var capsule = root.named(quick, "quick-controls-capsule")
        var hit = root.named(quick, "quick-controls-hit")
        if (capsule.visible) {
            var paint = capsule.mapToItem(output.bar.contentItem, 0, 0, capsule.width, capsule.height)
            var target = hit.mapToItem(output.bar.contentItem, 0, 0, hit.width, hit.height)
            root.check(paint.width <= rail - gutter * 2, "capsule paint respects exterior gutters")
            root.check(paint.x >= gutter - 0.5 && Math.abs(paint.x - (rail - paint.x - paint.width)) <= 1, "capsule gutters are centered")
            root.check(target.width >= 36 && target.height >= quick.verticalControlHeight + quick.verticalEdgePadding * 2 + ScreenGeometry.leftModuleHoverExtent * 2, "capsule retains its independent pointer wrapper")
            root.check(paint.y >= target.y - 0.5 && paint.y + paint.height <= target.y + target.height + 0.5, "capsule hover stays inside its hit wrapper")
            var controls = []
            for (var name of ["quick-brightness", "quick-volume", "quick-battery"]) {
                var control = root.named(quick, name)
                if (control.visible) {
                    root.check(control.height === ScreenGeometry.leftTouchSize - 12
                        && control.width === ScreenGeometry.leftTouchSize, "quick icon centers are four pixels closer")
                    controls.push(control.mapToItem(output.bar.contentItem, 0, 0, control.width, control.height))
                }
            }
            var previousRows = controls.length * (ScreenGeometry.leftTouchSize - 8)
            var previousInset = (Math.max(ScreenGeometry.leftVisualSize, previousRows) - previousRows) / 2
                + (ScreenGeometry.leftTouchSize - 8 - ScreenGeometry.leftIconSize) / 2
            var firstCenter = Math.min(...controls.map(rect => rect.y + rect.height / 2))
            var lastCenter = Math.max(...controls.map(rect => rect.y + rect.height / 2))
            root.check(Math.abs(firstCenter - paint.y - ScreenGeometry.leftIconSize / 2 - capsule.hoverExpansion - previousInset - 4) < 1
                && Math.abs(paint.y + paint.height - lastCenter - ScreenGeometry.leftIconSize / 2 - capsule.hoverExpansion - previousInset - 4) < 1,
                "capsule top and bottom insets each grow four pixels")
            console.info("Density " + JSON.stringify({font: Theme.fontSize, rail: rail, output: output.modelData.name, capsule: paint, hit: target}))
        }
        function visit(item) {
            if (!item) return
            if (item.visualItem && item.interactionItem && item.compactVisual === true && !String(item).startsWith("Workspaces_")) {
                var paint = item.visualItem.mapToItem(output.bar.contentItem, 0, 0, item.visualItem.width, item.visualItem.height)
                var target = item.interactionItem.mapToItem(output.bar.contentItem, 0, 0, item.interactionItem.width, item.interactionItem.height)
                root.check(paint.width <= rail - gutter * 2 && paint.x >= gutter - 0.5, "ordinary pill keeps visible gutters")
                root.check(Math.abs(paint.x - (rail - paint.x - paint.width)) <= 1, "ordinary pill remains centered")
                root.check(target.width >= 36 && target.height >= (item.parent === tray ? 28 : 36), "module retains its scoped pointer dimensions")
                if (item.parent === tray) root.check(item.height === ScreenGeometry.leftTouchSize - 8, "tray removes four pixels from each vertical inset")
                root.check(paint.y >= target.y - 0.5 && paint.y + paint.height <= target.y + target.height + 0.5, "hover remains inside the reserved slot")
            }
            for (var child of item.children || []) visit(child)
        }
        visit(output.bar.contentItem)
        var clock = root.find(output.bar.contentItem, "ClockGroup")
        root.check(root.named(clock, "leftbar-clock-time").font.pixelSize === Theme.fontSize - 4, "stacked clock is eight pixels smaller than its previous size")
        root.check(tray.spacing === Math.max(2, Math.ceil(Theme.fontSize / 7)), "vertical tray spacing stays compact")
        var title = root.find(output.bar.contentItem, "WindowTitle")
        root.check(title.visualItem.width <= rail - gutter * 2, "title chassis retains visual gutters")
        var workspace = root.find(output.bar.contentItem, "Workspaces")
        root.check(workspace.dot === 20 && workspace.activeW === 50, "workspace markers keep the requested old style")
        if (workspace.visible && workspace.items.length) {
            var dot = root.named(workspace, "workspace-dot-0")
            var active = root.named(workspace, "workspace-active-indicator")
            var dotRect = dot.mapToItem(output.bar.contentItem, 0, 0, dot.width, dot.height)
            var activeRect = active.mapToItem(output.bar.contentItem, 0, 0, active.width, active.height)
            root.check(dot.width === 20 && dot.height === 20 && active.width === 20 && Math.abs(active.height - 50) < 1, "painted workspace markers retain 20/50 geometry")
            root.check(Math.abs(dotRect.x + dotRect.width / 2 - rail / 2) < 0.5 && Math.abs(activeRect.x + activeRect.width / 2 - rail / 2) < 0.5, "workspace dots and active pill share the rail center")
            console.info("Workspace density " + JSON.stringify({count: workspace.items.length, dot: dotRect, active: activeRect}))
        }
    }
    // Navigation owns the upper logo/workspace group; title and controls remain usable.
    function checkNavigationGate(output, hidden) {
        var workspace = root.named(output.bar.contentItem, "leftbar-workspace-lane")
        var navigationOpen = UiState.activePanel === "navigation" && UiState.navigationScreenName === output.modelData.name
        var beforeMidpoint = hidden && !navigationOpen && output.navigation.closing && output.navigation.closeProgress < 0.5
        var workspaceHidden = navigationOpen || beforeMidpoint
        if (beforeMidpoint) root.sawWorkspaceHiddenBeforeMidpoint = true
        root.check(workspace.visible && workspace.enabled === !workspaceHidden && workspace.opacity >= 0 && workspace.opacity <= 1,
            "workspace input stays hidden until navigation has closed halfway")
        if (workspaceHidden || !hidden)
            root.check(workspace.opacity === (workspaceHidden ? 0 : 1), "workspace reaches its open or settled opacity: " + JSON.stringify({screen: output.modelData.name, hidden: workspaceHidden, opacity: workspace.opacity, visual: hidden}))
        else if (workspace.opacity > 0 && workspace.opacity < 1) {
            root.sawWorkspaceReturnFade = true
            if (output.navigation.closingFromDashboard) root.sawDashboardWorkspaceReturn = true
        }
        var title = root.find(output.bar.contentItem, "WindowTitle")
        var bottom = root.named(output.bar.contentItem, "leftbar-bottom-lane")
        for (var lane of [title, bottom]) root.check(lane.visible && lane.opacity === 1 && lane.enabled,
            "Navigation preserves title and bottom controls")
        root.check(root.find(output.bar.contentItem, "Logo").visible === !hidden, "Navigation owns only the original logo visual")
    }
    // Font ink rectangles reveal spacing hidden by rotated Text layout bounds.
    function checkTitle(output) {
        var title = root.find(output.bar.contentItem, "WindowTitle")
        var icon = title.iconPaintedBounds, text = title.textPaintedBounds
        var gap = text.y - icon.y - icon.height
        root.check(Math.abs(gap - 14) < 1, "painted icon-title gap is fourteen pixels: " + gap)
        root.check(title.height <= title.maximumLength && text.y + text.height <= title.height + 1, "content-sized title fits its budget")
        root.check(title.height <= title.preferredVerticalHeight + 1, "short titles do not retain an empty budget box")
        root.check(root.named(title, "vertical-window-title-icon").rotation === 0
            && root.named(title, "vertical-window-title-text").rotation === 90, "title keeps upright icon and rotated single line")
        console.info("Title ink " + JSON.stringify({font: Theme.fontSize, icon: icon, text: text, gap: gap, height: title.height, budget: title.maximumLength}))
    }
    // Record the physical main backing separately from the unchanged radial controller.
    function navigationGeometry(output) {
        var navigation = output.navigation
        var flare = root.find(navigation, "FlareSurface")
        var left = flare.attach === 1
        var title = root.find(output.bar.contentItem, "WindowTitle")
        return {depth: navigation.flareHeight, targetDepth: navigation.flareTargetHeight, leftAttached: left,
            x: left ? flare.x : navigation.flareStart, y: left ? navigation.flareStart : flare.y,
            span: navigation.flareEnd - navigation.flareStart,
            titleOpacity: title.opacity, titleEnabled: title.enabled,
            workspaceOpacity: root.named(output.bar.contentItem, "leftbar-workspace-lane").opacity,
            workspaceEnabled: root.named(output.bar.contentItem, "leftbar-workspace-lane").enabled,
            owner: UiState.navigationVisualScreenName, panelOpen: navigation.panelOpen, closing: navigation.closing,
            closeProgress: navigation.closeProgress,
            logoBase: navigation.logoBaseWidth, anchor: navigation.capturedAnchorRect, safeZones: navigation.safeZones}
    }
    function notificationGeometry(window, flare) {
        var content = find(flare, "FlareContent")
        var item = content && content.activeLoader ? content.activeLoader.item : null
        var point = item ? item.mapToItem(window.contentItem, 0, 0) : null
        return {windowWidth: window.width, windowHeight: window.height, contentHeight: flare.naturalContentHeight,
            usableBottom: window.modelData.height - ScreenGeometry.bottomReservation(window.modelData.name),
            anchor: window.localAnchorRect, openedAtLeft: window.openedAtLeft, attach: flare.attach, x: flare.x, y: flare.start,
            span: flare.end - flare.start, depth: flare.currentHeight, targetDepth: flare.naturalDepth,
            contentX: point ? point.x : null, contentY: point ? point.y : null, zones: window.safeZones}
    }
    function wallpaperGeometry(window) {
        var browser = window.browserItem
        return {depth: window.expansion, targetDepth: 1,
            infoSlide: browser && browser.infoSlide !== undefined ? browser.infoSlide : null,
            gallerySlide: browser && browser.gallerySlide !== undefined ? browser.gallerySlide : null}
    }
    // Reopen during the visual close to exercise the existing reversal contract.
    Timer {
        id: wallpaperReopen
        interval: 80
        property string screenName: ""
        onTriggered: UiState.openWallpaperWorkspace(screenName)
    }
    Timer {
        id: earlyNavigationClose
        interval: 60
        onTriggered: { UiState.closeNavigation(); navigationReopen.start() }
    }
    Timer {
        id: navigationReopen
        interval: 80
        onTriggered: UiState.openNavigation(root.navScreen, root.navAnchor)
    }
    FrameAnimation {
        running: (root.phase >= 180 && root.phase <= 192) || [196, 197].includes(root.phase)
        onTriggered: {
            for (var output of root.outputs) root.checkNavigationGate(output, UiState.navigationVisualScreenName === output.modelData.name)
            root.gateChecks++
        }
    }
    // Sample actual popup opacity during hover entry and exit.
    FrameAnimation {
        running: [71, 713, 7135].includes(root.phase)
        onTriggered: {
            var output = root.outputs.find(item => item.modelData.name === root.client.screen.name)
            var tooltip = root.find(output.wallpaper.browserItem, "SettingsTooltip")
            if (!tooltip || !tooltip.visible || tooltip.opacity <= 0 || tooltip.opacity >= 1) return
            if (tooltip.active) root.sawWallpaperTooltipFadeIn = true
            else root.sawWallpaperTooltipFadeOut = true
        }
    }
    // Observe the moving category pill between native input and its settled target.
    FrameAnimation {
        running: root.phase === 712
        onTriggered: {
            var output = root.outputs.find(item => item.modelData.name === root.client.screen.name)
            if (!output) return
            var pill = root.named(output.wallpaper.browserItem, "wallpaper-category-indicator")
            if (pill && Math.abs(pill.y - root.categoryStartY) > 0.5 && Math.abs(pill.y - pill.targetY) > 0.5)
                root.sawCategoryMorph = true
        }
    }
    // Observe leading modules fading out and in during wallpaper workspace transitions.
    FrameAnimation {
        running: [7, 7202, 7203, 8].includes(root.phase)
        onTriggered: {
            var screen = UiState.wallpaperScreenName || (root.client ? root.client.screen.name : "")
            var output = root.outputs.find(item => item.modelData.name === screen)
            if (!output) return
            var logo = root.named(output.bar.contentItem, "leftbar-logo-slot")
            var workspaces = root.named(output.bar.contentItem, "leftbar-workspace-lane")
            if (!logo || !workspaces) return
            if (logo.opacity > 0 && logo.opacity < 1 && workspaces.opacity > 0 && workspaces.opacity < 1) {
                if (root.phase === 7) root.sawWallpaperLeadingFadeOut = true
                if ([7202, 7203, 8].includes(root.phase)) root.sawWallpaperLeadingFadeIn = true
            }
        }
    }
    AnimationRecorder {
        id: recorder
        directory: Quickshell.env("HAKUSPACE_LEFTBAR_ARTIFACT_DIR")
        onFailed: message => root.check(false, message)
    }
    function capture(name, outputName) {
        if (Quickshell.env("HAKUSPACE_LEFTBAR_REFERENCE_ONLY") === "1") {
            var current = root.outputs.find(output => output.modelData.name === client.screen.name)
            var bar = root.find(current, ChromeLayout.taskbarMode ? "Taskbar" : "TopBar")
            var clock = root.find(bar.contentItem, "ClockGroup")
            console.info("Reference clock " + JSON.stringify({name: name, rect: clock ? ScreenGeometry.itemRect(clock) : null}))
        }
        screenshot.command = ["grim", "-o", outputName || client.screen.name, Quickshell.env("HAKUSPACE_LEFTBAR_ARTIFACT_DIR") + "/" + name + ".png"]
        screenshot.running = true
    }
    PersistentProperties {
        id: reloadMemory
        reloadableId: "leftbar-runtime-reloads"
        property int count: 0
        onLoaded: if (count > 0) root.phase = 98
    }
    Process { command: ["python3", Quickshell.env("HAKUSPACE_LEFTBAR_TRAY")]; running: true }
    Process { id: diskWriter }
    Process { id: screenshot }
    FloatingWindow {
        id: previewWindow
        screen: Quickshell.screens[0]
        implicitWidth: 640; implicitHeight: 410
        visible: [14, 141, 142].includes(root.phase)
        color: Theme.surface
        Settings.ShellBarPreview { id: preview; anchors.fill: parent; anchors.margins: 20 }
    }
    Process {
        id: pointer
        command: ["python3", Quickshell.env("HAKUSPACE_LEFTBAR_POINTER")]
        environment: ({HAKUSPACE_TEST_POINTER_OUTPUT: root.client ? root.client.screen.name : ""})
        running: !!root.client && [70, 700, 7005, 701, 7011, 7012, 70125, 718, 7180, 719, 71, 713, 7135, 714, 7145, 715, 716, 717, 710, 711, 712, 133, 134, 135, 136, 137, 138, 139, 140, 143, 144, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192].includes(root.phase) && Quickshell.env("HAKUSPACE_LEFTBAR_POINTER") !== ""
        stdinEnabled: true
    }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_LEFTBAR_KEYBOARD")]
        running: true
        stdinEnabled: true
    }
    Process {
        id: clientProbe
        command: ["quickshell", "ipc", "--pid", Quickshell.env("HAKUSPACE_LEFTBAR_CLIENT_PID"), "call", "leftbarClient", "geometry"]
        stdout: StdioCollector { id: clientGeometry }
        onExited: code => {
            if (code !== 0) return
            try { root.client = JSON.parse(clientGeometry.text) } catch (error) {}
        }
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: if (!clientProbe.running) clientProbe.running = true
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: output
            required property var modelData
            property alias bar: bar
            property alias dock: dock
            property alias navigation: navigation
            property alias wallpaper: wallpaper
            property alias tray: tray
            property alias notifications: notifications
            property alias menu: menu
            TopBar { modelData: output.modelData }
            LeftBar { id: bar; modelData: output.modelData }
            Taskbar { modelData: output.modelData }
            DockBar { id: dock; modelData: output.modelData }
            RoundedScreen { modelData: output.modelData }
            NavigationPanel { id: navigation; modelData: output.modelData }
            TrayMenuPanel { id: tray; modelData: output.modelData }
            NotificationCenterPanel { id: notifications; modelData: output.modelData }
            HakuMenuPanel { id: menu; modelData: output.modelData }
            WallpaperQuickOverlay { id: wallpaper; modelData: output.modelData; presentation: "workspace" }
            Component.onCompleted: root.outputs.push(output)
        }
    }
    Timer {
        interval: 600; running: true; repeat: true
        onTriggered: {
            root.check(++root.ticks < 180, "bounded runtime timeout")
            if (!ShellSettingsStore.ready || root.outputs.length !== 2 || screenshot.running || !root.client) return
            var first = root.outputs.find(output => output.modelData.name === client.screen.name)
            if (root.phase === 0) {
                NotificationStore.start(root.memory)
                ShellSettingsStore.setValue("chrome", "statusEdge", "left")
                if (Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_ONLY") === "1")
                    ShellSettingsStore.setValue("appearance", "colorMode", Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_THEME") || "dark")
                AppState.taskbarManualState = false
                root.records = []
                for (var index = 0; index < 9; index++) root.records.push({path: "fixture-" + index, label: "Wallpaper " + index,
                    thumbnail: Quickshell.env("HAKUSPACE_LEFTBAR_FIXTURE"), kind: "static", category: index < 5 ? "Nature" : "Anime"})
                WallpaperLibrary.items = root.records
                WallpaperLibrary.initialized = true
                WallpaperLibrary.filter = "static"
                WallpaperLibrary.selectIndex(4)
                WM.activeWindowClass = "kitty"
                WM.activeWindowTitle = "Long Unicode 日本語 tiêu đề · workspace editing and navigation"
                if (Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_ONLY") === "1") { Theme.fontSize = Number(Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_FONT")) || 14; root.phase = 61; return }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_FRAME_ONLY") === "1") { root.phase = 160; return }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_NAV_ONLY") === "1") { root.phase = 179; return }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_TYPOGRAPHY_ONLY") === "1" || Quickshell.env("HAKUSPACE_LEFTBAR_TITLE_ONLY") === "1") { root.phase = 193; return }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_REFERENCE_ONLY") === "1") {
                    ShellSettingsStore.setValue("chrome", "statusEdge", "top")
                    root.phase = 79
                    return
                }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_BELL_ONLY") === "1") {
                    AppState.dockbarManualState = true
                    ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                    ShellSettingsStore.setValue("dock", "exclusiveSpace", true)
                    root.phase = 46
                    return
                }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_MATRIX_ONLY") === "1") { root.phase = 130; return }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_FLARE_ONLY") === "1") {
                    root.switches = 30
                    AppState.dockbarManualState = true
                    ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                    ShellSettingsStore.setValue("dock", "exclusiveSpace", true)
                    root.phase = 8
                    return
                }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_EDGE_ONLY") === "1") { root.phase = 10; return }
            } else if (root.phase === 46) {
                var current = root.outputs[Math.floor(root.matrixIndex % 4 / 2)]
                Theme.fontSize = root.matrixIndex % 2 ? 21 : 14
                ShellSettingsStore.setValue("dock", "exclusiveSpace", root.matrixIndex < 8)
                NotificationStore.records = root.matrixIndex % 2 ? [0, 1, 2, 3].map(index => ({key: index + 1, id: index + 1, summary: "Fixture " + index,
                    body: "", appName: "fixture", actions: [], timestamp: Date.now(), screenName: current.modelData.name, popup: false})) : []
                NotificationStore.dnd = root.matrixIndex % 2 === 1
                var bell = root.find(root.find(current.bar.contentItem, "NotificationGroup"), "TopModule")
                if (Math.floor(root.matrixIndex / 4) % 2) {
                    var clock = root.find(current.bar.contentItem, "ClockGroup")
                    TooltipManager.show(clock.interactionItem, "", clock.tooltipComponent)
                } else {
                    TooltipManager.show(bell.interactionItem, bell.tooltip + (root.matrixIndex % 2
                        ? "\nThông báo · お知らせ\nNội dung dài để kiểm tra giới hạn popup gần Dock" : ""))
                }
                root.phase = 47
                return
            } else if (root.phase === 47) {
                var current = root.outputs[Math.floor(root.matrixIndex % 4 / 2)]
                var tip = root.find(current.bar.contentItem, "TooltipLayer")
                var flare = root.find(tip, "FlareHost")
                if (!TooltipManager.shown || Math.abs(flare.currentHeight - flare.naturalDepth) > 1) return
                console.info("Bell geometry " + JSON.stringify({anchor: flare.localizedAnchorRect,
                    start: flare.start, end: flare.end, depth: flare.currentHeight, contentHeight: flare.naturalContentHeight,
                    output: {name: current.modelData.name, width: current.modelData.width, height: current.modelData.height},
                    font: Theme.fontSize, edge: ChromeLayout.statusEdge, dock: ScreenGeometry.bottomReservation(current.modelData.name),
                    count: NotificationStore.count, dnd: NotificationStore.dnd}))
                if (root.expectV3) {
                    root.check(flare.end <= current.modelData.height - ScreenGeometry.bottomReservation(current.modelData.name) + 1, "full bell silhouette clears Dock")
                    root.check(flare.naturalContentHeight + 24 <= flare.end - flare.start + 1, "tooltip fits its vertical aperture")
                    root.check(Math.abs(flare.end - (current.modelData.height - ScreenGeometry.bottomReservation(current.modelData.name))) < 1, "bottom tooltip hugs the actual Rounded Screen / Dock edge")
                    console.info("Bottom tooltip edge " + JSON.stringify({caseIndex: root.matrixIndex, end: flare.end, bounds: tip.sideBounds,
                        kind: Math.floor(root.matrixIndex / 4) % 2 ? "calendar" : "notifications"}))
                }
                root.capture("bell-tooltip-" + root.matrixIndex, current.modelData.name)
                root.phase = 48
                return
            } else if (root.phase === 48) {
                TooltipManager.dismiss()
                if (++root.matrixIndex < 16) { root.phase = 46; return }
                console.info("Leftbar runtime checks passed")
                Qt.quit()
                return
            } else if (root.phase === 1) {
                if (SystemTray.items.values.length < 6) return
                var expectedWidth = first.modelData.width - ScreenGeometry.reservedLeft - ScreenGeometry.rightInset
                if (Math.abs(client.width - expectedWidth) >= 2) {
                    console.info("Initial reservation settle " + JSON.stringify({actual: client.width, expected: expectedWidth, font: Theme.fontSize, rail: ScreenGeometry.leftBarWidth}))
                    root.check(++root.startupSettleTicks < 10, "compositor applies exactly one left reservation after configure")
                    return
                }
                root.check(ChromeLayout.leftBarMode && ChromeLayout.dockbarActive === AppState.dockbarManualState, "left topology")
                for (var output of root.outputs) {
                    root.check(output.bar.visible && output.bar.width === output.modelData.width && output.bar.height === output.modelData.height, "stable drawing plane")
                    var title = root.find(output.bar.contentItem, "WindowTitle")
                    var rect = ScreenGeometry.itemRect(title)
                    var modules = root.find(output.bar.contentItem, "LeftStatusModules")
                    root.check(rect.y + rect.height + 12 <= modules.lanes.bottomY + 1, "title clears bottom controls")
                    root.check(output.bar.exclusiveZone === 0 && ScreenGeometry.leftBarWidth <= 48, "narrow normal rail")
                    root.check(!root.find(output.bar.contentItem, "CenterModule") && !root.find(output.bar.contentItem, "CavaGroup"), "no center UI demand")
                    root.check(ScreenGeometry.reservedLeft === ScreenGeometry.leftBarWidth && ScreenGeometry.leftInset === 4, "single reservation and physical border")
                    var workspaces = root.find(output.bar.contentItem, "Workspaces")
                    workspaces.visible = true
                    workspaces.items = [{name: "1", active: true, focused: true, urgent: false}, {name: "2", special: true, urgent: false}, {name: "3", urgent: true}]
                    root.check(workspaces.vertical && workspaces.implicitHeight > workspaces.implicitWidth, "vertical workspace footprint")
                }
                root.check(Math.abs(client.width - (first.modelData.width - ScreenGeometry.reservedLeft - ScreenGeometry.rightInset)) < 2, "compositor applied one left reservation")
                root.check(first.dock.targetWidth <= ScreenGeometry.dockWidthLimit(first.modelData.width), "Dock width remains symmetrically capped")
                console.info("Leftbar reservation " + JSON.stringify({output: first.modelData.name, width: first.modelData.width,
                    height: first.modelData.height, left: ScreenGeometry.reservedLeft, right: ScreenGeometry.rightInset,
                    clientWidth: client.width, clientHeight: client.height, bottom: ScreenGeometry.bottomInset}))
                root.baseline = {clientHeight: client.height}
                root.capture("leftbar-idle")
                var recorderModule = root.find(first.bar.contentItem, "RecorderGroup")
                root.hoverWidth = recorderModule.width
                root.hoverHeight = recorderModule.height
                root.hoverPaintHeight = recorderModule.visualItem.height
                recorderModule.hovered = true
                AppState.dockbarManualState = true
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", true)
            } else if (root.phase === 2) {
                root.check(first.dock.shown && ScreenGeometry.dockbarReservation(first.modelData.name) > 0, "Dock exclusive publication")
                root.check(Math.abs(client.height - (root.baseline.clientHeight - ScreenGeometry.dockbarReservation(first.modelData.name) + ScreenGeometry.frameBottomReservation)) < 2, "bottom reservation is not added twice: " + client.height + " expected " + (first.modelData.height - ScreenGeometry.topBorderThickness - ScreenGeometry.dockbarHeight))
                console.info("Leftbar dock reservation " + JSON.stringify({output: first.modelData.name,
                    bottom: ScreenGeometry.dockbarReservation(first.modelData.name), clientHeight: client.height,
                    clientHeightDelta: root.baseline.clientHeight - client.height}))
                root.capture("leftbar-dock")
                var hoveredModule = root.find(first.bar.contentItem, "RecorderGroup")
                if (root.expectV3) {
                    root.checkDensity(first)
                    root.checkTitle(first)
                    var logo = root.find(first.bar.contentItem, "Logo")
                    root.check(logo.visualItem.width === ScreenGeometry.leftVisualSize && logo.visualItem.height === ScreenGeometry.leftVisualSize
                        && logo.interactionItem.width >= 36, "compact logo paint keeps its full stable hit target")
                    root.check(hoveredModule.width === root.hoverWidth && hoveredModule.height === root.hoverHeight
                        && hoveredModule.visualHeight > root.hoverPaintHeight && hoveredModule.visualHeight <= hoveredModule.height, "Y hover expands the chassis without reflow or width changes")
                    root.check(!root.find(first.bar.contentItem, "ClockGroup").compact && root.find(first.bar.contentItem, "ClockGroup").vertical, "full clock presentation")
                }
                hoveredModule.hovered = false
                var logo = root.find(first.bar.contentItem, "Logo")
                recorder.start("navigation-open", first.bar, function() {
                    return root.navigationGeometry(first)
                })
                UiState.openNavigation(first.modelData.name, ScreenGeometry.itemRect(logo.visualItem))
                UiState.navigationMode = "handoff-sidebar"
            } else if (root.phase === 3) {
                if (!recorder.ready) return
                recorder.finish()
                if (root.expectV3) {
                    root.checkNavigationGate(first, true)
                    for (var output of root.outputs.filter(output => output !== first)) root.checkNavigationGate(output, false)
                    root.check(first.navigation.regions[1].labelAngle === 330 && first.navigation.regions[2].labelAngle === 90, "Sidebar wedge faces its right rail")
                    for (var index = 0; index < first.navigation.regions.length; index++) {
                        var angle = first.navigation.regions[index].labelAngle * Math.PI / 180
                        root.check(first.navigation.indexAt(first.navigation.circleRadius * (1 + 0.8 * Math.cos(angle)),
                            first.navigation.circleRadius * (1 + 0.8 * Math.sin(angle)), false) === index, "visible wedge matches pointer hit")
                    }
                }
                root.check(first.navigation.horizontalSidebar && first.navigation.sidebarBodyWidth > first.navigation.sidebarBodyHeight, "horizontal rail")
                root.check(first.navigation.safeZones[3].x > 0 && first.navigation.safeZones[3].width > first.navigation.safeZones[3].height, "physical rail safe zone")
                root.checkNavigationGate(first, true)
                root.check(first.navigation.leftAttached, "main Navigation flare uses the left attachment")
                root.capture("leftbar-navigation")
                first.navigation.toggleSidebarTool("quickActions", true)
            } else if (root.phase === 4) {
                root.check(first.navigation.sidebarToolOpen && first.navigation.safeZones[6].width > 0, "tool handoff retains safe zones")
                recorder.start("navigation-close", first.bar, function() {
                    return root.navigationGeometry(first)
                })
                UiState.closeNavigation()
                root.checkNavigationGate(first, true)
            } else if (root.phase === 5) {
                if (!first.navigation.releaseReady) { root.checkNavigationGate(first, true); return }
                if (!recorder.ready) return
                recorder.finish()
                root.checkNavigationGate(first, false)
                var bell = root.find(root.find(first.bar.contentItem, "NotificationGroup"), "TopModule")
                TooltipManager.show(bell.interactionItem, bell.tooltip)
                root.phase = 50
                return
            } else if (root.phase === 50) {
                var tooltip = root.find(first.bar.contentItem, "TooltipLayer")
                root.check(tooltip.leftAttached && tooltip.menuHeight > 0, "tooltip opens on left axis")
                root.check(first.bar.width === first.modelData.width, "tooltip does not resize host")
                var flare = root.find(tooltip, "FlareHost")
                root.check(flare.end <= first.modelData.height - ScreenGeometry.bottomReservation(first.modelData.name) + 1, "bell hover silhouette stays above Dock")
                root.capture("bell-tooltip")
                console.info("Bell tooltip " + JSON.stringify({anchor: flare.localizedAnchorRect, start: flare.start, end: flare.end,
                    depth: flare.currentHeight, contentHeight: flare.naturalContentHeight, bounds: tooltip.sideBounds}))
                TooltipManager.dismiss()
                UiState.openHakuMenu(first.modelData.name, "theme", "edge")
                root.phase = 6
                return
            } else if (root.phase === 6) {
                root.check(ChromeLayout.topEdgeHakuMenuEnabled && UiState.hakuMenuStyle === "topFlare", "HakuMenu keeps top attachment")
                if (root.expectV3) {
                    var theme = root.find(first.menu, "ThemeList")
                    root.check(!!theme && theme.visibleItems.some(item => item.statusEdgeSwitch), "Theme exposes the status-edge row in Hikai status mode")
                    root.capture("hakumenu-theme-position")
                }
                root.phase = 61
                return
            } else if (root.phase === 61) {
                UiState.closeHakuMenu()
                recorder.start("wallpaper-open", first.bar, function() { return root.wallpaperGeometry(first.wallpaper) })
                UiState.openWallpaperWorkspace(first.modelData.name)
                root.phase = 7
                return
            } else if (root.phase === 7) {
                if (!first.wallpaper.browserItem || !first.wallpaper.browserItem.openingReady || first.wallpaper.expansion < 1) return
                if (!recorder.ready) return
                var browser = first.wallpaper.browserItem
                var carousel = root.find(browser, "WallpaperCarousel")
                if (!carousel.count) { WallpaperLibrary.items = root.records; WallpaperLibrary.selectIndex(4); return }
                if (!carousel.currentItem) return
                root.check(carousel.vertical && carousel.pathItemCount === 3 && carousel.currentItem.rotation === 0, "vertical upright carousel")
                root.check(browser.topInputItem.x === ScreenGeometry.contentLeftEdge && browser.topInputItem.width > 0, "left controls attach to bar")
                root.check(browser.cardInputItems.length <= 2 && browser.bottomInputItem.width === 0, "empty gallery stays click-through")
                for (var output of root.outputs) root.checkWallpaperLeadingModules(output, output === first)
                root.check(root.sawWallpaperLeadingFadeOut, "logo and workspace modules fade out during wallpaper workspace open")
                carousel.forceActiveFocus()
                if (root.expectV3) {
                    root.check(!!root.find(browser, "WorkspaceToolbar"), "workspace shares the original toolbar")
                    var toolbar = root.find(browser, "WorkspaceToolbar")
                    var search = root.named(browser, "wallpaperSearch")
                    var title = root.named(browser, "wallpaper-selected-title")
                    var apply = root.named(browser, "wallpaper-apply")
                    var settings = root.named(browser, "wallpaper-settings")
                    var mode = root.named(browser, "wallpaper-mode-badge")
                    var shuffle = root.named(browser, "wallpaper-shuffle")
                    var refresh = root.named(browser, "wallpaper-refresh")
                    root.check(Math.abs(search.width - title.width) < 1 && Math.abs(search.width - apply.width) < 1,
                        "search, selected title and primary action fill the same grid width")
                    root.check(Math.abs(shuffle.width - refresh.width) < 1 && apply.caption.length > 0,
                        "paired library controls share width and the primary action keeps its label")
                    root.check(Math.abs(mode.mapToItem(toolbar, 0, 0).y - settings.mapToItem(toolbar, 0, 0).y) < 1,
                        "mode and settings align in the header row")
                    var close = root.named(browser, "wallpaper-close")
                    root.check(settings.x < close.x && Math.abs(close.mapToItem(toolbar, close.width, 0).x - search.mapToItem(toolbar, search.width, 0).x) < 1,
                        "settings precede the outer close action at the shared right edge")
                    var playback = root.named(browser, "wallpaper-playback")
                    var cache = root.named(browser, "wallpaper-cache")
                    root.check([shuffle, refresh, playback, cache, apply].every(item => item.height === search.height && item.radius === search.background.radius),
                        "all left control rows share their height and corner radius")
                    root.check(playback.width === cache.width && playback.disabledOpacity === 1 && cache.disabledOpacity === 1
                        && Math.abs(root.named(browser, "wallpaper-lively-controls").opacity - 0.3) < 0.001 && !playback.enabled
                        && playback.border.width === 0 && cache.border.width === 0,
                        "video actions keep borderless backgrounds at 0.3 opacity in image mode")
                    var informationScroll = browser.topInputItem.children[0]
                    if (informationScroll.contentHeight > informationScroll.height) {
                        informationScroll.contentY = informationScroll.contentHeight - informationScroll.height
                        var applyPosition = apply.mapToItem(browser.topInputItem, 0, 0)
                        root.check(applyPosition.y >= -1 && applyPosition.y + apply.height <= browser.topInputItem.height + 1,
                            "compact information scrolling keeps the bottom action reachable")
                        informationScroll.contentY = 0
                    }
                    var gallery = root.named(browser, "wallpaperBottomPanel")
                    root.check(gallery.vertical && Math.abs(gallery.x + gallery.width - browser.width + ScreenGeometry.rightInset) < 1, "curved gallery hugs the right physical edge")
                    var composition = root.named(browser, "wallpaper-information-composition")
                    var media = browser.mediaInputItem
                    var categories = browser.categoryInputItem
                    root.check(composition.rotation === 0 && root.named(browser, "wallpaper-selected-title").rotation === 0, "corner toolbar text stays upright")
                    root.check(media.x > browser.width * 0.75 && media.y < browser.height * 0.1, "Images/Lively occupy the upper-right rail")
                    var mediaIndicator = root.named(browser, "wallpaper-type-indicator")
                    root.check(mediaIndicator.targetItem === root.named(browser, "wallpaper-kind-" + browser.filter)
                        && mediaIndicator.opacity > 0 && mediaIndicator.width > 0,
                        "media selection is painted on the first open")
                    root.checkMediaIndicator(browser)
                    root.check(categories.x === media.x && categories.y > media.y + media.height && categories.height > 0, "categories occupy an upright right-side column")
                    var previousCategory = root.named(browser, "wallpaper-prev-category")
                    if (previousCategory.visible) {
                        root.check(Math.abs(previousCategory.mapToItem(browser, 0, 0).y - media.y - media.height - Theme.gap - 36) < 1,
                            "upper category arrow has thirty-six pixels of extra clearance")
                        var arrowIcon = root.named(previousCategory, "wallpaper-button-content").children[0]
                        categoryArrowMetrics.font = arrowIcon.font
                        categoryArrowMetrics.text = arrowIcon.text
                        var inkTop = arrowIcon.mapToItem(browser, 0, arrowIcon.baselineOffset + categoryArrowMetrics.tightBoundingRect.y).y
                        root.check(inkTop - media.y - media.height >= 32,
                            "visible arrow ink stays clearly separated from the media switch")
                    }
                    root.check(root.named(browser, "wallpaper-category-scroll").height >= browser.categoryTabHeight,
                        "compact category navigation retains at least one full scrolling row")
                    var categoryScroll = root.named(browser, "wallpaper-category-scroll")
                    var categoryItems = WallpaperLibrary.categories.map(name => root.named(browser, "wallpaper-category-" + name))
                    root.check(categoryItems.every(item => item.radius === Math.min(item.height, browser.categoryTabHeight) / 2 && item.idleColor.a === 0),
                        "category rows leave selection to one rounded pill")
                    var categoryIndicator = root.named(browser, "wallpaper-category-indicator")
                    root.check(categoryIndicator.targetItem.parent.selected && categoryIndicator.radius === categoryIndicator.targetItem.height / 2
                        && categoryIndicator.height <= browser.categoryTabHeight && categoryIndicator.targetItem.parent.selectedForegroundColor === Theme.onAccentColor,
                        "selected category pill preserves its contrast and rounded shape")
                    var categoryContentHeight = categoryItems.length * browser.categoryTabHeight + (categoryItems.length - 1) * (Math.max(2, Theme.gap / 2) + 4)
                    for (var index = 1; index < categoryItems.length; index++)
                        root.check(Math.abs(categoryItems[index].y - categoryItems[index - 1].y - categoryItems[index - 1].height - (Math.max(2, Theme.gap / 2) + 4)) < 1,
                            "category row gaps include four extra pixels")
                    if (categoryContentHeight + browser.sideGeometry.categoryInset * 2 <= categoryScroll.height) {
                        var top = categoryItems[0].mapToItem(categoryScroll.contentItem, 0, 0).y
                        root.check(Math.abs(top - (categoryScroll.height - top - categoryContentHeight)) < 1
                            && top >= browser.sideGeometry.categoryInset, "short category lists have equal larger top and bottom margins")
                    }
                    var pillTarget = categoryIndicator.targetItem.mapToItem(categoryIndicator.parent, 0, 0)
                    root.check(Math.abs(categoryIndicator.y - pillTarget.y) < 1, "category pill follows the centered list origin")
                    root.check(browser.sideGeometry.infoSurfaceRect.y + browser.sideGeometry.infoSurfaceRect.height + Theme.gap <= carousel.y,
                        "content-sized information and gallery have a positive gap")
                    root.check(Math.abs(browser.sideGeometry.railRect.y + browser.sideGeometry.railRect.height - carousel.y) < 1,
                        "selector content fills down to the carousel")
                    gallery.containsMode = Shape.FillContains
                    var visibleCards = carousel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible)
                    root.check(visibleCards.length === Math.min(3, carousel.count), "Leftbar paints exactly three bounded preview cards")
                    var rightEdges = [], lowerEdges = [], previewRects = []
                    for (var card of visibleCards) {
                        var topLeft = card.mapToItem(carousel, 0, 0)
                        var bottomRight = card.mapToItem(carousel, card.width, card.height)
                        root.check(card.chosen || carousel.currentItem.z > card.z, "selected artwork sits above both neighbors")
                        previewRects.push({chosen: card.chosen, x: topLeft.x, y: topLeft.y, right: bottomRight.x, bottom: bottomRight.y})
                        root.check(Math.abs(card.height / card.width - 9 / 16) < 0.001 && card.rotation === 0, "preview artwork keeps upright 16:9 proportions")
                        rightEdges.push(bottomRight.x)
                        lowerEdges.push(bottomRight.y)
                        root.check(topLeft.x >= -1 && topLeft.y >= -1 && bottomRight.x <= carousel.width + 1 && bottomRight.y <= carousel.height + 1,
                            "all three previews remain fully visible inside the gallery viewport")
                    }
                    var selection = previewRects.find(rect => rect.chosen)
                    var upper = previewRects.find(rect => !rect.chosen && rect.y < selection.y && rect.right > selection.right)
                    var left = previewRects.find(rect => !rect.chosen && rect.x < selection.x && rect.bottom > selection.bottom)
                    root.check(!!upper && !!left, "neighbors sit above and left of the bottom-right selection")
                    root.check(upper.bottom > selection.y && left.right > selection.x && left.y < selection.bottom,
                        "foreground previews overlap the raised selected card")
                    root.check(browser.sideGeometry.rightSurfaceRect.y === browser.sideGeometry.safeRect.y
                        && browser.sideGeometry.rightSurfaceRect.height === browser.sideGeometry.safeRect.height,
                        "the selector backing continues into the lower gallery")
                    root.check(browser.rightRailWidth >= 104 && browser.rightRailWidth <= 176,
                        "rail width follows measured labels within responsive bounds")
                    root.check(gallery.backingCurve === browser.sideGeometry.backingCurve && carousel.cornerCurve === browser.sideGeometry.anchors && gallery.z < carousel.z,
                        "the panel shares the carousel curve and stays behind the preview artwork")
                    for (var point of [
                        {rect: upper, curve: browser.sideGeometry.surfaceAnchors.upper},
                        {rect: selection, curve: browser.sideGeometry.surfaceAnchors.selected},
                        {rect: left, curve: browser.sideGeometry.surfaceAnchors.left}
                    ]) {
                        var x = (point.rect.x + point.rect.right) / 2 + carousel.x - gallery.x
                        var y = (point.rect.y + point.rect.bottom) / 2 + carousel.y - gallery.y
                        root.check(Math.hypot(x - point.curve.x, y - point.curve.y) < 0.5,
                            "static panel anchors align with each native preview center")
                    }
                    root.check(selection.right < upper.right && selection.bottom < left.bottom,
                        "selected preview floats above the lower edge and inside the upper card")
                    root.check(Math.abs(Math.max(...lowerEdges) - carousel.height + carousel.contentPadding) < 1,
                        "preview stack rests on the bottom gutter")
                    root.check(!!root.named(browser, "wallpaper-shuffle") && !!root.named(browser, "wallpaper-apply")
                        && !!root.named(browser, "wallpaper-category-lane"), "shared actions and category chips remain reachable")
                }
                console.info("Wallpaper layout " + JSON.stringify({layout: browser.sideGeometry, cards: browser.cardInputRects, maskCount: first.wallpaper.mask.regions.length,
                    bottomReservation: ScreenGeometry.bottomReservation(first.modelData.name)}))
                recorder.finish()
                var before = WallpaperLibrary.selectedIndex
                browser.handleShortcut({key: Qt.Key_Down, modifiers: Qt.NoModifier, accepted: false})
                root.check(WallpaperLibrary.selectedIndex !== before, "Down moves one card: focus=" + carousel.activeFocus + " enabled=" + carousel.enabled + " count=" + carousel.count + " before=" + before + " after=" + WallpaperLibrary.selectedIndex)
                root.check(carousel.currentItem.visible && carousel.currentItem.opacity > 0, "selected card remains painted")
                var cardRect = carousel.currentItem.mapToItem(browser, 0, 0)
                var cardEnd = carousel.currentItem.mapToItem(browser, carousel.currentItem.width, carousel.currentItem.height)
                root.check(cardRect.x >= carousel.x && cardRect.y >= carousel.y
                    && cardEnd.x <= browser.width && cardEnd.y <= browser.height, "selected card stays in the right viewport: " + JSON.stringify(cardRect))
                root.keyboardSelection = (WallpaperLibrary.selectedIndex + 1) % carousel.count
                keyboard.write("key 108\n")
                root.phase = 70
                return
            } else if (root.phase === 70) {
                var reel = root.find(first.wallpaper.browserItem, "WallpaperCarousel")
                console.info("Leftbar gallery " + JSON.stringify({x: reel.x, y: reel.y, width: reel.width, height: reel.height,
                    opacity: reel.opacity, cardScale: reel.currentItem.scale, cardWidth: reel.currentItem.width,
                    cardHeight: reel.currentItem.height, cardX: reel.currentItem.x, cardY: reel.currentItem.y,
                    focus: reel.focus, activeFocus: reel.activeFocus, owner: UiState.interactionOwner,
                    screen: UiState.interactionScreenName, keyboardMode: first.wallpaper.WlrLayershell.keyboardFocus,
                    windowActive: first.wallpaper.contentItem.Window.active, cardVisible: reel.currentItem.visible,
                    expectedIndex: root.keyboardSelection, actualIndex: WallpaperLibrary.selectedIndex}))
                root.capture("leftbar-wallpaper")
                root.desktopClicks = root.client.clicks
                var layout = first.wallpaper.browserItem.sideGeometry
                pointer.write(Math.round(layout.safeRect.x + 24) + " " + Math.round(layout.infoSurfaceRect.height + 40)
                    + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 700
                return
            } else if (root.phase === 700) {
                root.check(root.client.clicks === root.desktopClicks + 1, "empty desktop passes native pointer input to the client below")
                var layout = first.wallpaper.browserItem.sideGeometry
                pointer.write(Math.round(layout.railRect.x + layout.railRect.width / 2) + " "
                    + Math.round((layout.railRect.y + layout.railRect.height + layout.galleryRect.y) / 2)
                    + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 7005
                return
            } else if (root.phase === 7005) {
                root.check(root.client.clicks === root.desktopClicks + 2, "the empty painted right panel stays click-through")
                var input = root.named(first.wallpaper.browserItem, "wallpaperSearch")
                var point = input.mapToItem(first.wallpaper.contentItem, input.width / 2, input.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 701
                return
            } else if (root.phase === 701) {
                root.check(root.named(first.wallpaper.browserItem, "wallpaperSearch").activeFocus, "native click follows the upright search input and physical mask")
                root.workspaceKeyIndex = 0
                keyboard.write("key " + root.workspaceKeyCases[0][0] + "\n")
                root.phase = 7011
                return
            } else if (root.phase === 7011) {
                var browser = first.wallpaper.browserItem
                var action = root.workspaceKeyCases[root.workspaceKeyIndex]
                root.keyboardSelection = (root.keyboardSelection + action[1] + browser.filteredItems.length) % browser.filteredItems.length
                root.check(WallpaperLibrary.selectedIndex === root.keyboardSelection,
                    "native workspace key updates carousel selection once: " + JSON.stringify(action))
                root.check(root.named(browser, "wallpaperSearch").activeFocus === action[2] && browser.query === "",
                    "workspace arrows preserve search focus/query and Tab toggles focus: " + JSON.stringify(action))
                if (++root.workspaceKeyIndex < root.workspaceKeyCases.length) {
                    keyboard.write("key " + root.workspaceKeyCases[root.workspaceKeyIndex][0] + "\n")
                    return
                }
                root.named(browser, "wallpaper-settings").forceActiveFocus()
                keyboard.write("key 15\n")
                root.phase = 7012
                return
            } else if (root.phase === 7012) {
                root.check(root.named(first.wallpaper.browserItem, "wallpaperSearch").activeFocus,
                    "Tab from a toolbar action returns focus to search")
                TooltipManager.dismiss()
                root.tooltipSettleTicks = 0
                root.phase = 70125
                return
            } else if (root.phase === 70125) {
                var tooltip = root.find(first.wallpaper.browserItem, "SettingsTooltip")
                if (tooltip.visible && ++root.tooltipSettleTicks < 8) return
                root.check(!tooltip.visible, "the preceding search tooltip finishes its fade before the title hover probe")
                root.named(first.wallpaper.browserItem, "wallpaper-title-tooltip").active = true
                root.tooltipSettleTicks = 0
                root.phase = 71
                return
            } else if (root.phase === 71) {
                root.check(WallpaperLibrary.selectedIndex === root.keyboardSelection, "real Down key advances one card")
                var browser = first.wallpaper.browserItem
                var tooltip = root.find(browser, "SettingsTooltip")
                root.check(!!tooltip, "Leftbar workspace owns a normal floating tooltip")
                if ((!tooltip.visible || tooltip.opacity < 0.999) && ++root.tooltipSettleTicks < 8) return
                root.check(tooltip.visible && tooltip.immediate && tooltip.text === browser.selectedTooltip && root.sawWallpaperTooltipFadeIn,
                    "floating metadata tooltip fades in without a geometry morph: " + JSON.stringify({visible: tooltip.visible, immediate: tooltip.immediate, text: tooltip.text, expected: browser.selectedTooltip, fade: root.sawWallpaperTooltipFadeIn, opacity: tooltip.opacity, itemOpacity: tooltip.contentItem.parent.opacity}))
                root.check(!root.find(browser, "TooltipLayer"), "Leftbar workspace does not instantiate a tooltip flare host")
                var point = tooltip.parent.mapToItem(browser, tooltip.x, tooltip.y)
                root.check(point.x >= ScreenGeometry.contentLeftEdge && point.x + tooltip.width <= browser.width - ScreenGeometry.rightInset,
                    "floating tooltip stays within the content viewport")
                root.capture("wallpaper-floating-tooltip")
                root.phase = 713
                return
            } else if (root.phase === 713) {
                root.named(first.wallpaper.browserItem, "wallpaper-title-tooltip").active = false
                root.phase = 7135
                return
            } else if (root.phase === 7135) {
                root.check(root.sawWallpaperTooltipFadeOut && !root.find(first.wallpaper.browserItem, "SettingsTooltip").visible,
                    "floating tooltip fades out and releases its popup after hover ends")
                TooltipManager.dismiss()
                var button = root.named(first.wallpaper.browserItem, "wallpaper-kind-video")
                var point = button.mapToItem(first.wallpaper.contentItem, button.width / 2, button.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 710
                return
            } else if (root.phase === 710) {
                root.check(first.wallpaper.browserItem.filter === "video", "native click reaches the upper-right Lively selector")
                root.checkMediaIndicator(first.wallpaper.browserItem)
                var button = root.named(first.wallpaper.browserItem, "wallpaper-kind-static")
                var point = button.mapToItem(first.wallpaper.contentItem, button.width / 2, button.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 711
                return
            } else if (root.phase === 711) {
                root.check(first.wallpaper.browserItem.filter === "static", "native click restores Images")
                root.checkMediaIndicator(first.wallpaper.browserItem)
                var button = root.named(first.wallpaper.browserItem, "wallpaper-category-Anime")
                root.check(!!button, "right category column contains the existing library folders")
                root.named(first.wallpaper.browserItem, "wallpaper-category-lane").ensureVisible(button)
                root.categoryStartY = root.named(first.wallpaper.browserItem, "wallpaper-category-indicator").y
                root.sawCategoryMorph = false
                var point = button.mapToItem(first.wallpaper.contentItem, button.width / 2, button.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 712
                return
            } else if (root.phase === 712) {
                root.check(WallpaperLibrary.activeCategory === "Anime", "native click reaches the upright category column")
                root.check(root.sawCategoryMorph, "native category selection morphs through intermediate pill positions")
                WallpaperLibrary.setCategory("")
                root.normalRailWidth = first.wallpaper.browserItem.rightRailWidth
                WallpaperLibrary.items = root.records.concat([{path: "fixture-long", label: "3840x2160-" + "W".repeat(48) + "-日本語", kind: "static",
                    thumbnail: Quickshell.env("HAKUSPACE_LEFTBAR_FIXTURE"), category: "A_very_long_Unicode_カテゴリ_category_name"}])
                root.phase = 715
                return
            } else if (root.phase === 715) {
                var browser = first.wallpaper.browserItem
                WallpaperLibrary.selectIndex(WallpaperLibrary.filteredItems.findIndex(item => item.path === "fixture-long"))
                var button = root.named(browser, "wallpaper-category-A_very_long_Unicode_カテゴリ_category_name")
                var label = root.named(button, "wallpaper-category-label")
                root.check(browser.rightRailWidth >= root.normalRailWidth && browser.rightRailWidth <= 176 && label.truncated, "long category names are elided at the rail width limit")
                root.named(browser, "wallpaper-category-lane").ensureVisible(button)
                var point = button.mapToItem(first.wallpaper.contentItem, button.width / 2, button.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 0\n")
                root.tooltipSettleTicks = 0
                root.phase = 716
                return
            } else if (root.phase === 716) {
                var title = root.named(first.wallpaper.browserItem, "wallpaper-selected-title")
                root.check(title.maximumLineCount === 1 && title.lineCount === 1 && title.truncated,
                    "long wallpaper filenames elide on one row: " + JSON.stringify({text: title.text, lines: title.lineCount, maximum: title.maximumLineCount, width: title.width, height: title.height, selected: WallpaperLibrary.selectedPath}))
                var tooltip = root.find(first.wallpaper.browserItem, "SettingsTooltip")
                if ((!tooltip.visible || tooltip.text !== "A_very_long_Unicode_カテゴリ_category_name") && ++root.tooltipSettleTicks < 8) return
                root.check(tooltip.visible && tooltip.text === "A_very_long_Unicode_カテゴリ_category_name"
                    && tooltip.contentItem.textFormat === Text.PlainText, "floating tooltip preserves the full elided category name as plain text")
                root.capture("wallpaper-long-category")
                root.phase = 717
                return
            } else if (root.phase === 717) {
                TooltipManager.dismiss()
                WallpaperLibrary.items = root.records
                root.check(first.wallpaper.browserItem.rightRailWidth === root.normalRailWidth, "rail returns to its natural width with shorter category names")
                root.named(first.wallpaper.browserItem, "wallpaper-title-tooltip").active = true
                root.tooltipSettleTicks = 0
                root.phase = 714
                return
            } else if (root.phase === 714) {
                var tooltip = root.find(first.wallpaper.browserItem, "SettingsTooltip")
                if (!tooltip.visible && ++root.tooltipSettleTicks < 8) return
                root.check(tooltip.visible, "floating tooltip is present before closing the workspace")
                var carousel = root.find(first.wallpaper.browserItem, "WallpaperCarousel")
                var selected = carousel.currentItem
                var selectedStart = selected.mapToItem(first.wallpaper.contentItem, 0, 0)
                var selectedEnd = selected.mapToItem(first.wallpaper.contentItem, selected.width, selected.height)
                var peer = selected.parent.children.find(item => item.wallpaper !== undefined && item.visible && !item.chosen)
                var peerStart = peer.mapToItem(first.wallpaper.contentItem, 0, 0)
                var peerEnd = peer.mapToItem(first.wallpaper.contentItem, peer.width, peer.height)
                var overlap = {left: Math.max(selectedStart.x, peerStart.x), right: Math.min(selectedEnd.x, peerEnd.x),
                    top: Math.max(selectedStart.y, peerStart.y), bottom: Math.min(selectedEnd.y, peerEnd.y)}
                root.check(overlap.right > overlap.left && overlap.bottom > overlap.top, "neighbor shares a clickable overlap with selection")
                root.nativeCardIndex = WallpaperLibrary.selectedIndex
                pointer.write(Math.round((overlap.left + overlap.right) / 2) + " " + Math.round((overlap.top + overlap.bottom) / 2)
                    + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 7145
                return
            } else if (root.phase === 7145) {
                root.check(WallpaperLibrary.selectedIndex === root.nativeCardIndex, "overlapping artwork routes input to the selected front layer")
                var browser = first.wallpaper.browserItem
                var carousel = root.find(browser, "WallpaperCarousel")
                var card = carousel.currentItem.parent.children.find(item => item.wallpaper !== undefined && item.visible && !item.chosen)
                root.nativeCardIndex = card.index
                var point = card.mapToItem(first.wallpaper.contentItem, card.width / 2, card.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 718
                return
            } else if (root.phase === 718) {
                root.check(WallpaperLibrary.selectedIndex === root.nativeCardIndex, "native pointer selects neighboring artwork")
                root.check(root.client.clicks === root.desktopClicks + 2, "controls and artwork consume their native pointer input")
                root.keyboardSelection = (WallpaperLibrary.selectedIndex + 1) % WallpaperLibrary.filteredItems.length
                var reel = root.find(first.wallpaper.browserItem, "WallpaperCarousel")
                var point = reel.currentItem.mapToItem(first.wallpaper.contentItem, reel.currentItem.width / 2, reel.currentItem.height / 2)
                pointer.write("scroll " + Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 1\n")
                root.phase = 7180
                return
            } else if (root.phase === 7180) {
                root.check(WallpaperLibrary.selectedIndex === root.keyboardSelection, "native wheel advances the shared carousel selection")
                var browser = first.wallpaper.browserItem
                browser.filter = "video"
                browser.settingsSection = "playback"
                root.phase = 7181
                return
            } else if (root.phase === 7181) {
                var browser = first.wallpaper.browserItem
                var details = root.named(browser, "wallpaper-settings-popover")
                if (details.animating || !details.editorLoaded) return
                root.check(Math.abs(root.named(browser, "wallpaper-lively-controls").opacity - 1) < 0.001
                    && root.named(browser, "wallpaper-playback").enabled && root.named(browser, "wallpaper-cache").enabled,
                    "video actions return to full opacity in Lively mode")
                var safe = browser.sideGeometry.safeRect
                root.check(details.visible && details.width > 0 && details.x >= safe.x && details.y >= safe.y
                    && details.x + details.width <= browser.sideGeometry.galleryRect.x
                    && details.y + details.height <= safe.y + safe.height, "Leftbar settings popover fits the clear left column")
                root.capture("wallpaper-playback-settings")
                browser.settingsSection = ""
                browser.filter = "static"
                WallpaperLibrary.items = root.records
                root.phase = 719
                return
            } else if (root.phase === 719) {
                var sizes = [0, 1, 2, 3, 9]
                if (root.named(first.wallpaper.browserItem, "wallpaper-settings-popover").editorLoaded) return
                if (root.cardinalityIndex < sizes.length) {
                    var size = sizes[root.cardinalityIndex++]
                    WallpaperLibrary.items = root.records.slice(0, size)
                    WallpaperLibrary.selectIndex(size ? 0 : -1)
                    root.phase = 7200
                    return
                }
                WallpaperLibrary.items = root.records.concat(Array.from({length: 20}, (_, index) => ({path: "category-" + index,
                    label: "Category fixture", kind: "static", thumbnail: Quickshell.env("HAKUSPACE_LEFTBAR_FIXTURE"), category: "Unicode_カテゴリ_" + index})))
                root.phase = 7201
                return
            } else if (root.phase === 7200) {
                var carousel = root.find(first.wallpaper.browserItem, "WallpaperCarousel")
                var expected = [0, 1, 2, 3, 9][root.cardinalityIndex - 1]
                root.check(carousel.count === expected && (expected === 0 || !!carousel.currentItem), "empty and small libraries settle without losing selection")
                root.capture("wallpaper-count-" + expected)
                root.phase = 719
                return
            } else if (root.phase === 7201) {
                var browser = first.wallpaper.browserItem
                var scroll = root.named(browser, "wallpaper-category-scroll")
                root.check(scroll.contentHeight > scroll.height && browser.categoryInputItem.y + browser.categoryInputItem.height < browser.sideGeometry.galleryRect.y,
                    "many Unicode categories scroll inside the bounded selector rail")
                var lane = root.named(browser, "wallpaper-category-lane")
                for (var category of [WallpaperLibrary.categories[WallpaperLibrary.categories.length - 1], ""]) {
                    var button = root.named(browser, "wallpaper-category-" + category)
                    lane.ensureVisible(button)
                    var position = button.mapToItem(scroll, 0, 0)
                    root.check(position.y >= browser.sideGeometry.categoryInset - 1
                        && position.y + button.height <= scroll.height - browser.sideGeometry.categoryInset + 1,
                        "first and last categories remain reachable inside the larger scroll margins")
                }
                root.capture("wallpaper-many-categories")
                var other = root.outputs.find(output => output !== first)
                UiState.openWallpaperWorkspace(other.modelData.name)
                root.phase = 72011
                return
            } else if (root.phase === 72011) {
                var other = root.outputs.find(output => output !== first)
                if (other.wallpaper.expansion < 1 || !first.wallpaper.releaseReady) return
                root.check(UiState.wallpaperScreenName === other.modelData.name && other.wallpaper.inputActive && !first.wallpaper.inputActive,
                    "output transfer releases the previous mask and moves the interaction lease")
                root.check(other.wallpaper.browserItem.sideGeometry.safeRect.width === other.wallpaper.width - ScreenGeometry.contentLeftEdge - ScreenGeometry.rightInset,
                    "transferred workspace uses its own logical output dimensions")
                root.checkWallpaperLeadingModules(first, false)
                root.checkWallpaperLeadingModules(other, true)
                root.capture("wallpaper-output-transfer", other.modelData.name)
                UiState.openWallpaperWorkspace(first.modelData.name)
                root.phase = 72012
                return
            } else if (root.phase === 72012) {
                if (first.wallpaper.expansion < 1 || !first.wallpaper.inputActive) return
                root.phase = 7202
                return
            } else if (root.phase === 7202) {
                recorder.start("wallpaper-close", first.bar, function() { return root.wallpaperGeometry(first.wallpaper) })
                UiState.closeWallpaper()
                root.checkWallpaperLeadingModules(first, true)
                root.check(first.wallpaper.mask.item === null, "closing immediately detaches the root input region")
                for (var region of first.wallpaper.mask.regions) root.check(region.item === null && region.width === 0 && region.height === 0,
                    "closing clears every child input region")
                root.check(!root.find(first.wallpaper.browserItem, "SettingsTooltip").active, "workspace close immediately disables its floating tooltip")
                wallpaperReopen.screenName = first.modelData.name
                wallpaperReopen.start()
                root.phase = 7203
                return
            } else if (root.phase === 7203) {
                if (!first.wallpaper.panelOpen || first.wallpaper.closing || first.wallpaper.expansion < 1) return
                root.check(first.wallpaper.inputActive && UiState.ownsInteraction("wallpaper", first.modelData.name),
                    "interrupted close restores masks and the keyboard lease")
                if (!recorder.ready) return
                UiState.closeWallpaper()
                root.phase = 8
                return
            } else if (root.phase === 8) {
                if (Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_ONLY") === "1") {
                    if (!first.wallpaper.releaseReady || !recorder.ready) return
                    for (var output of root.outputs) root.checkWallpaperLeadingModules(output, false)
                    root.check(root.sawWallpaperLeadingFadeIn, "logo and workspace modules fade in during wallpaper workspace close")
                    if (recorder.name) { recorder.finish(); return }
                    if (recorder.writing) return
                    console.info("Leftbar runtime checks passed")
                    Qt.quit()
                    return
                }
                if (!first.wallpaper.releaseReady) return
                if (recorder.name === "wallpaper-close") {
                    if (!recorder.ready) return
                    recorder.finish()
                }
                if (++root.switches < 30) {
                    var mode = root.switches % 3
                    ShellSettingsStore.setValue("chrome", "statusEdge", mode === 1 ? "left" : "top")
                    AppState.taskbarManualState = mode === 2
                    if (root.switches === 3) root.phase = 80
                    return
                }
                root.check(!ShellSettingsStore.error && !UiState.trayMenu && UiState.navigationMode === "closed", "repeated layout changes release transient ownership")
                ShellSettingsStore.setValue("chrome", "statusEdge", "left")
                AppState.taskbarManualState = false
                NotificationStore.records = [{key: 1, id: 1, summary: "Leftbar notification", body: "History fixture",
                    appName: "fixture", actions: [], timestamp: Date.now(), screenName: first.modelData.name, popup: false}]
                UiState.toggleNotifications(first.modelData.name, ScreenGeometry.itemRect(root.find(first.bar.contentItem, "NotificationGroup")))
                Qt.callLater(function() {
                    var window = root.find(first.notifications, "FlarePanelWindow")
                    var flare = root.find(window.contentItem, "FlareHost")
                    recorder.start("notifications-open", window, function() { return root.notificationGeometry(window, flare) })
                })
            } else if (root.phase === 79) {
                if (++root.referenceSettleTicks < 3) return
                root.phase = 80
                return
            } else if (root.phase === 80) {
                root.capture("topbar-idle")
                root.phase = 81
                return
            } else if (root.phase === 81) {
                var top = root.find(first, "TopBar")
                root.find(top.contentItem, "RecorderGroup").hovered = true
                root.phase = 82
                return
            } else if (root.phase === 82) {
                root.capture("topbar-hover")
                root.phase = 83
                return
            } else if (root.phase === 83) {
                var top = root.find(first, "TopBar")
                root.find(top.contentItem, "RecorderGroup").hovered = false
                if (Quickshell.env("HAKUSPACE_LEFTBAR_REFERENCE_ONLY") === "1") {
                    AppState.taskbarManualState = true
                    root.phase = 84
                } else root.phase = 8
                return
            } else if (root.phase === 84) {
                root.capture("taskbar-reference")
                root.phase = 85
                return
            } else if (root.phase === 85) {
                console.info("Leftbar runtime checks passed")
                Qt.quit()
                return
            } else if (root.phase === 9) {
                if (!recorder.ready) return
                recorder.finish()
                var panel = root.find(first.notifications, "FlarePanelWindow")
                root.check(!!panel, "notification side host exists")
                root.check(panel.panelOpen && panel.openedAtLeft && panel.safeZones[2].width > 0, "Notification Center opens from the left module")
                root.check(panel.safeZones[2].x >= ScreenGeometry.contentLeftEdge - Interaction.safeZoneMargin, "notification input follows its side surface")
                root.capture("leftbar-notifications")
            } else if (root.phase === 10) {
                var window = root.find(first.notifications, "FlarePanelWindow")
                var flare = root.find(window.contentItem, "FlareHost")
                recorder.start("notifications-close", window, function() { return root.notificationGeometry(window, flare) })
                UiState.closeNotifications()
                root.phase = 100
                return
            } else if (root.phase === 100) {
                if (!recorder.ready) return
                recorder.finish()
                if (Quickshell.env("HAKUSPACE_LEFTBAR_FLARE_ONLY") === "1") { root.phase = 101; return }
                ShellSettingsStore.setValue("topbar", "center", false)
                diskWriter.command = ShellSettingsStore.command("write")
                diskWriter.environment = {HAKUSPACE_HIKAI_SETTINGS_JSON: JSON.stringify({chrome: {statusEdge: "top"}})}
                diskWriter.running = true
                root.phase = 11
                return
            } else if (root.phase === 101) {
                if (recorder.writing) return
                console.info("Leftbar runtime checks passed")
                Qt.quit()
                return
            } else if (root.phase === 11) {
                if (diskWriter.running || !ChromeLayout.topBarMode) return
                root.check(!ShellSettingsStore.values.topbar.center && ShellSettingsStore.savedValues.topbar.center, "external layout writes retain unrelated drafts")
                diskWriter.environment = {HAKUSPACE_HIKAI_SETTINGS_JSON: JSON.stringify({chrome: {statusEdge: "left"}})}
                diskWriter.running = true
            } else if (root.phase === 12) {
                if (diskWriter.running || !ChromeLayout.leftBarMode) return
                root.check(!ShellSettingsStore.values.topbar.center, "external return keeps center preference")
                ShellSettingsStore.setValue("topbar", "center", true)
                Theme.fontSize = 21
            } else if (root.phase === 13) {
                var verticalTitle = root.find(first.bar.contentItem, "WindowTitle")
                var titleRect = ScreenGeometry.itemRect(verticalTitle)
                var modules = root.find(first.bar.contentItem, "LeftStatusModules")
                root.check(titleRect.y + titleRect.height + 12 <= modules.lanes.bottomY + 1, "large fonts keep title clear of bottom controls")
                root.check(root.named(verticalTitle, "vertical-window-title-icon").rotation === 0
                    && root.named(verticalTitle, "vertical-window-title-text").rotation === 90, "upright icon above rotated title")
                if (root.expectV3) {
                    var clock = root.find(first.bar.contentItem, "ClockGroup")
                    for (var name of ["time"]) {
                        var label = root.named(clock, "leftbar-clock-" + name)
                        root.check(!!label && label.visible && label.text.length > 0 && /^\d{2}\n\d{2}$/.test(label.text), "large-font stacked clock shows " + name)
                    }
                    root.check(!root.named(clock, "leftbar-clock-weekday") && !root.named(clock, "leftbar-clock-date"), "no hidden date elements in the vertical clock")
                    root.capture("leftbar-font21")
                }
            } else if (root.phase === 160) {
                if (root.matrixIndex >= 18) { console.info("Leftbar runtime checks passed"); Qt.quit(); return }
                Theme.fontSize = 14
                var mode = Math.floor(root.matrixIndex / 6)
                ShellSettingsStore.setValue("chrome", "statusEdge", mode === 1 ? "left" : "top")
                AppState.taskbarManualState = mode === 2
                ShellSettingsStore.setValue("roundedScreen", "borderThickness", Math.floor(root.matrixIndex / 3) % 2 ? 4 : 0)
                AppState.dockbarManualState = root.matrixIndex % 3 !== 0
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", root.matrixIndex % 3 === 2)
                root.frameSettleTicks = 0
                root.phase = 161
                return
            } else if (root.phase === 161) {
                if (++root.frameSettleTicks < 3) return
                for (var output of root.outputs) {
                    var frame = root.find(output, "RoundedScreen")
                    var horizontal = frame.horizontalReservationWindow
                    var border = ScreenGeometry.borderThickness
                    var native = client.clients.find(value => value.screen.name === output.modelData.name)
                    if (!native) return
                    var top = ChromeLayout.topBarMode ? Math.round(Theme.topBarHeight) : border
                    var bottom = ChromeLayout.taskbarMode ? ScreenGeometry.taskbarHeight
                        : Math.max(ChromeLayout.topBarMode ? border : 0, ScreenGeometry.dockbarReservation(output.modelData.name))
                    if (root.matrixIndex === 0) root.frameDecorations[output.modelData.name] = output.modelData.height - top - bottom - native.height
                    var expectedHeight = output.modelData.height - top - bottom - root.frameDecorations[output.modelData.name]
                    var expectedWidth = output.modelData.width - ScreenGeometry.reservedLeft - ScreenGeometry.rightInset
                    if (Math.abs(native.height - expectedHeight) >= 2 || Math.abs(native.width - expectedWidth) >= 2) {
                        root.check(root.frameSettleTicks < 12, "native frame zones match the painted edges: " + JSON.stringify({native: native, expectedWidth: expectedWidth, expectedHeight: expectedHeight}))
                        return
                    }
                    root.check(horizontal.anchors.top === !ChromeLayout.topBarMode && horizontal.anchors.bottom === ChromeLayout.topBarMode, "horizontal owner follows the intended physical edge")
                    root.check(frame.frameItem.leftRail === (ChromeLayout.leftBarMode ? 0 : border), "Leftbar has no standalone physical left rail")
                    root.check(frame.frameItem.topInset === (ChromeLayout.topBarMode ? 0 : border), "top paint matches its reservation")
                    root.check(frame.leftReservationWindow.exclusiveZone === ScreenGeometry.reservedLeft && output.bar.exclusiveZone === 0, "one left reservation owner")
                    root.check(!ChromeLayout.leftBarMode || frame.frameItem.x === ScreenGeometry.leftBarWidth, "corner masks start at the rail seam")
                    root.check(horizontal.visible === (border > 0 && (!ChromeLayout.topBarMode || ScreenGeometry.dockbarReservation(output.modelData.name) === 0)), "left top rail stays reserved with an exclusive Dock")
                    console.info("Frame matrix " + JSON.stringify({caseIndex: root.matrixIndex, output: output.modelData.name, edge: ChromeLayout.statusEdge, border: border, top: top, bottom: bottom, native: native,
                        frameX: frame.frameItem.x, leftRail: frame.frameItem.leftRail, topPaint: frame.frameItem.topInset, leftZone: frame.leftReservationWindow.exclusiveZone}))
                }
                root.capture("frame-" + root.matrixIndex)
                root.matrixIndex++
                root.phase = 160
                return
            } else if (root.phase === 179) {
                for (var output of root.outputs) {
                    for (var type of ["PowerProfileGroup", "WallpaperGroup", "RecorderGroup"])
                        root.check(!root.find(output.bar.contentItem, type), "Leftbar omits " + type)
                    var workspace = root.find(output.bar.contentItem, "Workspaces")
                    workspace.items = Array.from({length: 5}, (_, index) => ({key: String(index + 1), name: String(index + 1), active: index === 1, focused: index === 1, special: false, urgent: false, occupied: true}))
                    workspace.visible = true
                }
                root.phase = 1795
                return
            } else if (root.phase === 1795) {
                root.capture("leftbar-modules")
                root.phase = 180
                return
            } else if (root.phase === 180) {
                var logo = root.find(first.bar.contentItem, "Logo")
                for (var output of root.outputs) {
                    var glyph = root.find(output.bar.contentItem, "Logo").visualItem
                    var dot = root.named(root.find(output.bar.contentItem, "Workspaces"), "workspace-dot-0")
                    var gap = dot.mapToItem(output.bar.contentItem, 0, 0).y - glyph.mapToItem(output.bar.contentItem, 0, glyph.height).y
                    root.check(gap > 0 && gap <= Theme.pad + 6, "workspace markers sit close below the logo: " + gap)
                }
                root.navScreen = first.modelData.name
                root.navAnchor = ScreenGeometry.itemRect(logo.visualItem)
                var point = logo.interactionItem.mapToItem(first.bar.contentItem, logo.width / 2, logo.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 0\n")
                earlyNavigationClose.start()
                root.phase = 181
                return
            } else if (root.phase === 181) {
                root.check(first.navigation.panelOpen, "native logo hover opens Navigation through an interrupted open/reopen")
                root.check(first.navigation.capturedAnchorRect.width === ScreenGeometry.leftVisualSize, "logo handoff captures the painted circle")
                root.checkNavigationGate(first, true)
                UiState.closeNavigation()
                navigationReopen.start()
                root.phase = 182
                return
            } else if (root.phase === 182) {
                root.check(first.navigation.panelOpen, "rapid reopen reverses the close morph")
                root.checkNavigationGate(first, true)
                UiState.closeNavigation()
                root.phase = 183
                return
            } else if (root.phase === 183) {
                root.navReleaseChecks++
                root.check(root.navReleaseChecks < 12, "Navigation releases after an interrupted close")
                if (!first.navigation.releaseReady) return
                root.checkNavigationGate(first, false)
                var other = root.outputs.find(output => output !== first)
                UiState.openNavigation(other.modelData.name, ScreenGeometry.itemRect(root.find(other.bar.contentItem, "Logo").visualItem))
                root.phase = 184
                return
            } else if (root.phase === 184) {
                var other = root.outputs.find(output => output !== first)
                root.check(other.navigation.panelOpen && !first.navigation.panelOpen, "cross-output ownership does not reopen a stale logo")
                root.checkNavigationGate(first, false)
                root.checkNavigationGate(other, true)
                UiState.openNavigation(first.modelData.name, root.navAnchor)
                root.phase = 185
                return
            } else if (root.phase === 185) {
                var other = root.outputs.find(output => output !== first)
                root.check(first.navigation.panelOpen && !other.navigation.panelOpen, "active Navigation transfers output ownership")
                root.check(first.navigation.capturedAnchorRect.width === root.navAnchor.width, "output transfer captures the new anchor")
                root.checkNavigationGate(other, false)
                UiState.beginNavigationHandoff("sidebar")
                pointer.write(Math.round(first.navigation.sidebarBodyX + first.navigation.sidebarBodyWidth / 2) + " "
                    + Math.round(first.navigation.sidebarBodyY + first.navigation.sidebarBodyHeight / 2) + " "
                    + first.modelData.width + " " + first.modelData.height + " 0\n")
                root.phase = 186
                return
            } else if (root.phase === 186) {
                first.navigation.toggleSidebarTool("clipboard", true)
                root.phase = 187
                return
            } else if (root.phase === 187) {
                root.check(first.navigation.sidebarToolOpen && first.navigation.safeZones[6].width > 0, "Clipboard keeps the horizontal tool corridor")
                first.navigation.toggleSidebarTool("quickActions", true)
                root.phase = 188
                return
            } else if (root.phase === 188) {
                root.check(first.navigation.sidebarToolOpen && first.navigation.safeZones[5].width > 0, "Quick Actions keeps the horizontal tool corridor")
                UiState.closeNavigation()
                root.phase = 189
                return
            } else if (root.phase === 189) {
                if (!first.navigation.releaseReady) return
                pointer.write("200 200 " + first.modelData.width + " " + first.modelData.height + " 0\n")
                root.phase = 190
                return
            } else if (root.phase === 190) {
                var logo = root.find(first.bar.contentItem, "Logo")
                var point = logo.interactionItem.mapToItem(first.bar.contentItem, logo.width / 2, logo.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 0\n")
                root.phase = 191
                return
            } else if (root.phase === 191) {
                root.check(first.navigation.panelOpen, "the first genuine hover after leaving opens Navigation")
                UiState.closeNavigation()
                root.phase = 192
                return
            } else if (root.phase === 192) {
                if (!first.navigation.releaseReady) return
                root.check(root.gateChecks > 30, "visual ownership audited across animation frames")
                root.check(root.sawWorkspaceHiddenBeforeMidpoint, "workspace remains hidden during the first half of navigation close")
                root.check(root.sawWorkspaceReturnFade, "workspace fades after the close midpoint and before visual release")
                UiState.openNavigation(first.modelData.name, root.navAnchor)
                root.check(!UiState.navigationWorkspaceReturnReady, "opening clears the previous midpoint permission")
                UiState.beginNavigationHandoff("dashboard")
                root.phase = 196
                return
            } else if (root.phase === 196) {
                if (first.navigation.dashboardMorphProgress < 1) return
                UiState.closeNavigation()
                root.phase = 197
                return
            } else if (root.phase === 197) {
                if (!first.navigation.releaseReady) return
                root.check(root.sawDashboardWorkspaceReturn, "Dashboard close also releases workspace at its normalized midpoint")
                root.check(!UiState.navigationWorkspaceReturnReady, "visual release clears the midpoint permission")
                console.info("Navigation ownership frame checks " + root.gateChecks)
                console.info("Leftbar runtime checks passed")
                Qt.quit()
                return
            } else if (root.phase === 193) {
                if (root.matrixIndex >= 16) { console.info("Leftbar runtime checks passed"); Qt.quit(); return }
                Theme.fontSize = [12, 14, 18, 21][Math.floor(root.matrixIndex / 4)]
                var titles = [["", ""], ["kitty", "Code"], ["code", "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".repeat(4)], ["kitty", "日本語😀".repeat(30)]]
                WM.activeWindowClass = titles[root.matrixIndex % 4][0]
                WM.activeWindowTitle = titles[root.matrixIndex % 4][1]
                root.phase = 194
                return
            } else if (root.phase === 194) {
                for (var output of root.outputs) {
                    var title = root.find(output.bar.contentItem, "WindowTitle")
                    var clock = root.named(root.find(output.bar.contentItem, "ClockGroup"), "leftbar-clock-time")
                    if (Quickshell.env("HAKUSPACE_LEFTBAR_TITLE_ONLY") !== "1") {
                        root.check(clock.font.pixelSize === Theme.fontSize - 4 && clock.minimumPixelSize <= clock.font.pixelSize,
                            "vertical clock preserves the requested eight-pixel reduction at every font size")
                        root.check(/^\d{2}\n\d{2}$/.test(clock.text) && clock.contentWidth <= clock.width + 1, "smaller clock stays fitted")
                    }
                    root.check(title.maxTitleCharacters === 42 && Array.from(title.displayTitle).length <= 42,
                        "Leftbar title exposes the forty-two-character limit")
                    if (root.matrixIndex % 4 === 0)
                        root.check(title.displayTitle === "...hakushell...", "empty title uses the normal shell placeholder")
                    if (root.matrixIndex % 4 === 2)
                        root.check(Array.from(title.displayTitle).length === 42 && title.displayTitle.endsWith("…"),
                            "long titles use all forty-two characters before ellipsis")
                    if (title.maximumLength >= title.preferredVerticalHeight - 0.5)
                        root.check(root.named(title, "vertical-window-title-text").text === title.displayTitle,
                            "a title that fits retains every character, including the shell placeholder")
                    root.checkTitle(output)
                }
                root.capture("leftbar-typography-" + root.matrixIndex)
                root.matrixIndex++
                root.phase = 193
                return
            } else if (root.phase === 130) {
                if (root.matrixIndex >= 16) {
                    for (var output of root.outputs) {
                        var quick = root.find(output.bar.contentItem, "SettingsGroup")
                        quick.backlight = -1
                        quick.volume = -1
                        root.named(quick, "quick-battery").bat = null
                    }
                    root.phase = 132
                    return
                }
                Theme.fontSize = [12, 14, 18, 21][Math.floor(root.matrixIndex / 4)]
                ShellSettingsStore.setValue("appearance", "colorMode", root.matrixIndex % 4 >= 2 ? "light" : "dark")
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", root.matrixIndex % 2 === 1)
                for (var output of root.outputs) {
                    var workspaces = root.find(output.bar.contentItem, "Workspaces")
                    var count = [3, 5, 10][root.matrixIndex % 3]
                    workspaces.items = Array.from({length: count}, (_, index) => ({key: String(index + 1), name: String(index + 1), active: index === 0, focused: index === 0, special: index === 1, urgent: index === count - 1}))
                    workspaces.visible = root.matrixIndex !== 15
                    WM.activeWindowClass = root.matrixIndex % 4 === 1 ? "" : "kitty"
                    WM.activeWindowTitle = ["Code", "", "日本語 · Tiếng Việt 😀", "Very long Unicode 日本語 title with line\nbreak · ".repeat(8)][root.matrixIndex % 4]
                    var quick = root.find(output.bar.contentItem, "SettingsGroup")
                    quick.backlight = root.matrixIndex % 4 ? 60 : -1
                    quick.volume = 42
                    root.named(quick, "quick-battery").bat = root.matrixIndex % 2 ? {isPresent: true, state: 1, percentage: 0.75} : null
                }
                root.phase = 131
                return
            } else if (root.phase === 131) {
                for (var output of root.outputs) {
                    var modules = root.find(output.bar.contentItem, "LeftStatusModules")
                    var title = root.find(output.bar.contentItem, "WindowTitle")
                    root.check(title.y + title.height + 12 <= modules.lanes.bottomY + 1, "matrix title gap")
                    var clock = root.find(output.bar.contentItem, "ClockGroup")
                    var label = root.named(clock, "leftbar-clock-time")
                    root.check(/^\d{2}\n\d{2}$/.test(label.text) && label.contentWidth <= label.width + 1, "matrix clock is fitted hours above minutes")
                    var quick = root.find(output.bar.contentItem, "SettingsGroup")
                    var capsule = root.named(quick, "quick-controls-capsule")
                    root.check(capsule.width <= ScreenGeometry.leftBarWidth - ScreenGeometry.leftVisualGutter * 2 && capsule.height > 0, "painted capsule leaves at least 8 px exterior gutters")
                    root.check(root.named(quick, "quick-battery").visible === (root.matrixIndex % 2 === 1), "missing battery collapses its slot")
                    root.check(root.named(quick, "quick-brightness").visible === (root.matrixIndex % 4 !== 0), "missing brightness collapses its slot")
                    var count = 1 + (root.matrixIndex % 4 !== 0 ? 1 : 0) + (root.matrixIndex % 2 ? 1 : 0)
                    root.check(capsule.height >= quick.verticalControlHeight * count, "capsule contains the available controls without ghost slots")
                    root.checkDensity(output)
                    root.checkTitle(output)
                }
                root.capture("matrix-" + root.matrixIndex)
                if (root.matrixIndex === 15) { root.phase = 133; return }
                root.matrixIndex++
                root.phase = 130
                return
            } else if (root.phase === 133) {
                var quick = root.find(first.bar.contentItem, "SettingsGroup")
                var capsule = root.named(quick, "quick-controls-capsule")
                root.hoverWidth = capsule.width
                root.hoverHeight = root.named(quick, "quick-controls-hit").height
                root.hoverPaintHeight = capsule.height
                var point = root.named(quick, "quick-brightness").mapToItem(first.bar.contentItem, ScreenGeometry.leftModuleTouchSize / 2, ScreenGeometry.leftModuleTouchSize / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 0\n")
                root.phase = 134
                return
            } else if (root.phase === 134 || root.phase === 135) {
                var quick = root.find(first.bar.contentItem, "SettingsGroup")
                var capsule = root.named(quick, "quick-controls-capsule")
                root.check(capsule.hoverExpansion > 0 && capsule.width === root.hoverWidth && capsule.height > root.hoverPaintHeight && root.named(quick, "quick-controls-hit").height === root.hoverHeight, "native child hover stretches the capsule without reflow")
                root.checkDensity(first)
                root.capture("quick-hover-" + root.phase)
                var point = root.phase === 134
                    ? root.named(quick, "quick-battery").mapToItem(first.bar.contentItem, ScreenGeometry.leftModuleTouchSize / 2, ScreenGeometry.leftModuleTouchSize / 2)
                    : capsule.mapToItem(first.bar.contentItem, capsule.width + 40, capsule.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 0\n")
                root.phase++
                return
            } else if (root.phase === 136) {
                var capsule = root.named(root.find(first.bar.contentItem, "SettingsGroup"), "quick-controls-capsule")
                root.check(capsule.hoverExpansion < 0.5 && Math.abs(capsule.height - root.hoverPaintHeight) < 0.5, "capsule hover releases without layout movement")
                root.dndBefore = NotificationStore.dnd
                var bell = root.find(root.find(first.bar.contentItem, "NotificationGroup"), "TopModule")
                var point = bell.interactionItem.mapToItem(first.bar.contentItem, 1, bell.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 273\n")
                root.phase = 137
                return
            } else if (root.phase === 137) {
                root.check(NotificationStore.dnd !== root.dndBefore, "bell right click works in the transparent gutter of the hit target")
                NotificationStore.dnd = root.dndBefore
                var bell = root.find(root.find(first.bar.contentItem, "NotificationGroup"), "TopModule")
                var point = bell.interactionItem.mapToItem(first.bar.contentItem, 1, bell.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 272\n")
                root.phase = 138
                return
            } else if (root.phase === 138) {
                root.check(UiState.activePanel === "notifications", "bell left click opens its panel from the larger hit target")
                UiState.closeNotifications()
                var clock = root.find(first.bar.contentItem, "ClockGroup")
                root.monthBefore = clock.monthOffset
                var point = clock.interactionItem.mapToItem(first.bar.contentItem, 1, clock.height / 2)
                pointer.write("scroll " + Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " -1\n")
                root.phase = 139
                return
            } else if (root.phase === 139) {
                var clock = root.find(first.bar.contentItem, "ClockGroup")
                root.check(clock.monthOffset !== root.monthBefore, "calendar wheel works outside its painted chassis")
                var point = clock.interactionItem.mapToItem(first.bar.contentItem, 1, clock.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 273\n")
                root.phase = 140
                return
            } else if (root.phase === 140) {
                root.check(root.find(first.bar.contentItem, "ClockGroup").monthOffset === 0, "calendar right click resets the month")
                TooltipManager.dismiss()
                var lane = root.named(first.bar.contentItem, "leftbar-bottom-lane")
                lane.contentY = 0
                root.phase = 143
                return
            } else if (root.phase === 143) {
                var tray = root.find(root.find(first.bar.contentItem, "TrayGroup"), "TopModule")
                var point = tray.interactionItem.mapToItem(first.bar.contentItem, 1, tray.height / 2)
                pointer.write(Math.round(point.x) + " " + Math.round(point.y) + " " + first.modelData.width + " " + first.modelData.height + " 273\n")
                root.phase = 144
                return
            } else if (root.phase === 144) {
                root.check(!!UiState.trayMenu, "tray menu opens from its transparent hit margin")
                UiState.closeTrayMenu()
                var lane = root.named(first.bar.contentItem, "leftbar-bottom-lane")
                lane.contentY = Math.max(0, lane.contentHeight - lane.height)
                root.matrixIndex++
                root.phase = 130
                return
            } else if (root.phase === 132) {
                for (var output of root.outputs) {
                    var quick = root.find(output.bar.contentItem, "SettingsGroup")
                    root.check(!root.named(quick, "quick-controls-capsule").visible && quick.height === 0, "unavailable controls leave no ghost capsule or slot")
                    root.check(quick.subscribed, "service discovery stays acquired while the enabled group is empty")
                }
                if (Quickshell.env("HAKUSPACE_LEFTBAR_MATRIX_ONLY") === "1") {
                    console.info("Leftbar runtime checks passed")
                    Qt.quit()
                } else root.phase = 14
                return
            } else if (root.phase === 14) {
                root.check(preview.leftbar, "Settings selects the Leftbar preview")
                root.capture("leftbar-settings-preview")
                if (root.expectV3) { root.phase = 141; return }
            } else if (root.phase === 141) {
                AppState.taskbarManualState = true
                root.phase = 142
                return
            } else if (root.phase === 142) {
                var edge = root.find(previewWindow.contentItem, "StatusEdgeControl")
                var seg = edge ? root.find(edge, "SettingsSegmentedControl") : null
                root.check(!!edge && edge.visible && !!seg && seg.value === "taskbar", "Taskbar selects the Taskbar option in the layout control")
                AppState.taskbarManualState = false
                root.phase = 15
                return
            } else if (root.phase === 15) {
                reloadMemory.count = 1
                Quickshell.reload(false)
                return
            } else if (root.phase === 98) {
                root.check(ChromeLayout.leftBarMode && first.bar.visible && !ChromeLayout.taskbarMode, "reload restores persisted edge")
                var expectedClientWidth = first.modelData.width - ScreenGeometry.reservedLeft - ScreenGeometry.rightInset
                if (Math.abs(client.width - expectedClientWidth) >= 2) {
                    root.check(++root.reloadSettleTicks < 10, "reload has no duplicate left reservation: actual=" + client.width
                        + " expected=" + expectedClientWidth + " output=" + first.modelData.name)
                    return
                }
                root.reloadSettleTicks = 0
                if (reloadMemory.count < 5) {
                    reloadMemory.count++
                    Quickshell.reload(false)
                    return
                }
                console.info("Leftbar runtime checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
