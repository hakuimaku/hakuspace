import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"

ShellRoot {
    id: root
    // Retain each real output's surfaces for layout and draft-lifecycle assertions.
    property var outputs: []
    property int phase: 0
    property int ticks: 0
    property QtObject notificationMemory: QtObject { property string recordsJson: "[]"; property int nextKey: 1 }
    readonly property var geometryCases: [[0, 0], [0, 6], [24, 0], [24, 6], [20, 4]]
    property var capturedBell: null
    property var capturedLogo: null
    property var afterCapture: null
    Process {
        id: capture
        onExited: (code, status) => {
            root.check(code === 0, "geometry screenshot capture")
            var next = root.afterCapture
            root.afterCapture = null
            if (next) next()
        }
    }

    // Turn behavioral failures into a failing runner exit status.
    function check(ok, message) {
        if (ok) return
        console.error("Hikai runtime failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Rect translation may introduce floating point roundoff at fractional module sizes.
    function sameRect(actual, expected) {
        return actual && expected && ["x", "y", "width", "height"].every(function(key) {
            return Math.abs(actual[key] - expected[key]) < 0.001
        })
    }
    // Locate an existing module without adding test hooks to production components.
    function module(item, name) {
        if (String(item).indexOf(name + "_QMLTYPE") >= 0) return item
        var children = item.contentItem ? item.contentItem.children : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number")
            children = item.data
        for (var i = 0; i < children.length; ++i) {
            var child = children[i]
            var found = module(child, name)
            if (found) return found
        }
        return null
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: output
            required property var modelData
            property alias bar: bar
            property alias settings: settings
            property alias rounded: rounded
            property alias navigation: navigation
            property alias center: center
            property alias tray: tray
            property alias menu: menu
            PanelWindow {
                screen: output.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                color: "#4a7188"
            }
            TrayMenuPanel { id: tray; modelData: output.modelData }
            NotificationCenterPanel { id: center; modelData: output.modelData }
            NotificationPopup { modelData: output.modelData }
            HakuMenuPanel { id: menu; modelData: output.modelData }
            LevelOsdOverlay { modelData: output.modelData }
            TopBar { id: bar; modelData: output.modelData }
            SettingsPanel { id: settings; modelData: output.modelData }
            RoundedScreen { id: rounded; modelData: output.modelData }
            NavigationPanel { id: navigation; modelData: output.modelData }
            Component.onCompleted: root.outputs.push(output)
        }
    }
    Timer {
        interval: 550
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 90, "runtime timeout: " + ShellSettingsStore.error)
            if (!ShellSettingsStore.ready || ShellSettingsStore.loading || ShellSettingsStore.saving || capture.running || root.outputs.length !== 2) return
            root.check(!ShellSettingsStore.error, ShellSettingsStore.error)
            var first = root.outputs[0]
            if (root.phase === 0) {
                root.check(!WM.supported && WM.labwcSession, "isolated Labwc backend")
                root.check(first.bar.width === first.modelData.width, "TopBar spans the full output: " + first.bar.width)
                var initialLogo = root.module(first.bar.contentItem, "Logo")
                var initialRect = ScreenGeometry.itemRect(initialLogo)
                var laneRect = ScreenGeometry.topBarAnchor(initialRect.x, initialRect.width)
                // Qt center anchors may snap the unchanged lane by half a logical pixel.
                root.check(Math.abs(initialRect.y - laneRect.y) <= 0.5, "TopBar module lane did not move")
                root.check(Theme.topBarHeight - Theme.topBarContentHeight === 4, "bottom chassis adds exactly four pixels")
                UiState.trayMenu = {screenName: first.modelData.name, item: null, handle: null, anchorRect: {x: 0, y: 8, width: 20, height: 24}}
                for (var key in ShellSettingsStore.values.topbar) ShellSettingsStore.setValue("topbar", key, false)
            } else if (root.phase === 1) {
                root.check(!UiState.trayMenu, "hidden tray clears ownership")
                for (var output of root.outputs) {
                    var content = output.bar.contentItem
                    var clock = root.module(content, "ClockGroup")
                    var title = root.module(content, "WindowTitle")
                    var logo = root.module(content, "Logo")
                    root.check(clock && title && logo, "existing module tree")
                    root.check(clock.parent.width === 0 && !clock.visible, "empty right Row reflows")
                    root.check(title.parent.width === 0 && !title.visible, "empty left Row reflows")
                    root.check(title.parent.parent.width === logo.width && logo.visible, "Logo footprint remains")
                    root.check(!root.module(content, "Workspaces").visible, "Labwc workspace gate")
                    root.check(!root.module(content, "CenterModule").visible, "center gate")
                    root.check(!root.module(content, "RecorderGroup").visible, "idle recorder gate")
                }
                Recorder.isRecording = true
                for (var output of root.outputs)
                    root.check(root.module(output.bar.contentItem, "RecorderGroup").visible, "active recording remains visible")
                Recorder.isRecording = false
                ShellSettingsStore.discard()
                UiState.openSettings(first.modelData.name)
                first.settings.selectedGroup = "Shell"
            } else if (root.phase === 2) {
                ShellSettingsStore.setValue("appearance", "baseRadius", 20)
                first.settings.requestClose()
                root.check(first.settings.confirmation === "close", "Shell dirty close prompts")
                first.settings.confirmation = ""
                root.check(UiState.activePanel === "settings" && Theme.radius === 20, "Keep retains preview")
                first.settings.requestClose()
                first.settings.confirmDiscard()
                root.check(UiState.activePanel === "" && Theme.radius === 12 && !ShellSettingsStore.dirty, "confirmed close discards preview")
            } else if (root.phase >= 3 && root.phase <= 17) {
                var radius = [4, 12, 24][Math.floor((root.phase - 3) / 5)]
                ShellSettingsStore.setValue("appearance", "baseRadius", radius)
                ShellSettingsStore.setValue("appearance", "surfaceTone", ["ink", "dark", "soft"][Math.floor((root.phase - 3) / 5)])
                for (var output of root.outputs)
                    root.check(output.rounded.cornerRadius === 20, "radius reaches both screens")
                if ((root.phase - 3) % 5 === 0) UiState.openNavigation(first.modelData.name, ScreenGeometry.topBarAnchor(Theme.pad, Theme.fontSize * 1.8))
                else if ((root.phase - 3) % 5 === 1) UiState.beginNavigationHandoff("dashboard")
                else if ((root.phase - 3) % 5 === 2) {
                    if (Math.abs(first.navigation.dashboardMorphProgress - 1) > 0.001) return
                    // Capture the settled silhouette before handing the same Navigation session to Sidebar.
                    root.afterCapture = function() { UiState.beginNavigationHandoff("sidebar") }
                    capture.command = ["grim", "-t", "ppm", "-o", first.modelData.name,
                        Quickshell.env("HAKUSPACE_GEOMETRY_ARTIFACT_DIR") + "/dashboard-r-" + radius
                        + "-edge-" + first.navigation.dashboardVisualWidth + "-top-" + ScreenGeometry.flareTopY
                        + "-width-" + first.modelData.width + ".ppm"]
                    capture.running = true
                }
                else if ((root.phase - 3) % 5 === 3) {
                    // A protruding ear tip creates the visible spike at the Navigation seam.
                    var nav = first.navigation
                    var dx = nav.sidebarBodyWidth + nav.sidebarEarWidth - (nav.surfaceEnd - nav.sidebarJoinRadius)
                    var dy = nav.sidebarBodyY + nav.sidebarTopFlareY - 1 - (nav.surfaceHeight - nav.sidebarJoinRadius)
                    root.check(nav.sidebarExpanded && nav.sidebarTopFlareY >= 0, "Sidebar opens at radius " + radius)
                    var rail = root.module(nav, "SidebarSurface")
                    root.check(rail.tools.map(function(tool) { return tool.key }).join(",") === "quickActions,clipboard,tempNote",
                        "Sidebar contains only its three utility controls")
                    root.check(rail.preferredBodyHeight === rail.listTopPadding + 3 * rail.itemDiameter + 2 * rail.itemSpacing + rail.listBottomPadding,
                        "Sidebar height fits its remaining utility controls")
                    nav.moveSidebarSelection(100)
                    root.check(nav.sidebarSelectedIndex === 2, "rail keyboard cursor stops at Temp Note")
                    nav.moveSidebarSelection(-100)
                    root.check(nav.sidebarSelectedIndex === 0, "rail keyboard cursor stops at Quick Actions")
                    root.check(dx <= 0 || dy <= 0 || dx * dx + dy * dy <= nav.sidebarJoinRadius * nav.sidebarJoinRadius,
                        "Sidebar ear stays inside Navigation at radius " + radius)
                }
                else UiState.openSettings(first.modelData.name)
            } else if (root.phase === 18) {
                ShellSettingsStore.apply()
            } else if (root.phase === 19) {
                ShellSettingsStore.reset()
                ShellSettingsStore.apply()
            } else if (root.phase >= 20 && root.phase < 40) {
                var index = Math.floor((root.phase - 20) / 4)
                var mode = (root.phase - 20) % 4
                if (mode === 0) {
                    UiState.closeSettings()
                    UiState.closeNavigation()
                    AppState.waybarManualState = false
                    ShellSettingsStore.setValue("roundedScreen", "radius", root.geometryCases[index][0])
                    ShellSettingsStore.setValue("roundedScreen", "borderThickness", root.geometryCases[index][1])
                } else if (mode === 1) {
                    if (first.navigation.closing || first.settings.visible) return
                    // An image check catches rails/masks that numeric bindings alone cannot verify.
                    capture.command = ["grim", "-t", "ppm", "-o", first.modelData.name,
                        Quickshell.env("HAKUSPACE_GEOMETRY_ARTIFACT_DIR") + "/case-" + index + ".ppm"]
                    capture.running = true
                    for (var output of root.outputs) {
                        root.check(output.rounded.cornerRadius === root.geometryCases[index][0], "both corner masks update")
                        root.check(output.rounded.sideInset === root.geometryCases[index][1], "both border reservations update")
                        root.check(ScreenGeometry.flareTopY === Theme.topBarHeight, "border cannot move attachment")
                    }
                } else if (mode === 2) {
                    AppState.waybarManualState = true
                    UiState.openNavigation(first.modelData.name, ScreenGeometry.topBarAnchor(Theme.pad, Theme.fontSize * 1.8))
                } else UiState.beginNavigationHandoff("sidebar")
            } else if (root.phase === 40) {
                UiState.closeNavigation()
                ShellSettingsStore.reset()
                NotificationStore.start(root.notificationMemory)
                ShellSettingsStore.setValue("appearance", "baseRadius", 24)
                NotificationStore.records = [1, 2, 3, 4].map(function(key) {
                    return {key: key, id: key, appName: "notify-send", appIcon: "", summary: "Screenshot saved & copied",
                        body: "Isolated Notification Center geometry check", image: "", urgency: 1, actions: [],
                        timestamp: Date.now(), transient: false, dismissed: false, popupEligible: false, live: false}
                })
                var bell = root.module(root.outputs[1].bar.contentItem, "NotificationGroup").children[0]
                root.capturedBell = ScreenGeometry.itemRect(bell)
                UiState.toggleNotifications(root.outputs[1].modelData.name, root.capturedBell)
            } else if (root.phase === 41) {
                var center = root.outputs[1].center
                root.check(center.panelOpen && !first.center.panelOpen, "bell opens on its source monitor")
                var expected = ScreenGeometry.localizeRect(root.capturedBell, center.hostRect)
                root.check(root.sameRect(center.localAnchorRect, expected), "right host shares exact localized anchor")
                root.check(Math.abs(center.localAnchorRect.y - root.capturedBell.y) < 0.001
                    && Math.abs(center.localAnchorRect.height - root.capturedBell.height) < 0.001, "actual bell height and Y survive localization")
                var host = root.module(center, "FlareHost")
                root.check(host && host.currentHeight > 0, "Notification Center renders its history")
                root.afterCapture = function() {
                    UiState.closeNotifications()
                    UiState.openTrayMenu({id: "geometry-test"}, null, root.outputs[1].modelData.name, root.capturedBell)
                }
                capture.command = ["grim", "-t", "ppm", "-o", root.outputs[1].modelData.name,
                    Quickshell.env("HAKUSPACE_GEOMETRY_ARTIFACT_DIR") + "/center-start-" + (center.hostRect.x + host.start)
                    + "-end-" + (center.hostRect.x + host.end) + "-bottom-" + (ScreenGeometry.flareTopY + host.currentHeight)
                    + "-width-" + center.modelData.width + ".ppm"]
                capture.running = true
            } else if (root.phase === 42) {
                root.check(root.outputs[1].tray.panelOpen && !first.tray.panelOpen, "tray belongs to its source monitor")
                root.check(root.sameRect(root.outputs[1].tray.localAnchorRect, root.capturedBell), "tray keeps the actual module rect")
                NotificationStore.records = []
                ShellSettingsStore.setValue("topbar", "tray", false)
                root.check(!UiState.trayMenu, "hidden tray clears captured rect ownership")
                var logo = root.module(root.outputs[1].bar.contentItem, "Logo")
                root.capturedLogo = ScreenGeometry.itemRect(logo)
                UiState.openNavigation(root.outputs[1].modelData.name, root.capturedLogo)
            } else if (root.phase === 43) {
                root.check(root.outputs[1].navigation.panelOpen && !first.navigation.panelOpen, "Navigation belongs to its source monitor")
                root.check(root.sameRect(root.outputs[1].navigation.capturedAnchorRect, root.capturedLogo), "Navigation captures the full Logo rect")
                UiState.closeNavigation()
                CenterState.show("volume")
                ShellSettingsStore.setValue("roundedScreen", "borderThickness", 6)
            } else if (root.phase === 44) {
                root.check(ScreenGeometry.flareTopY === Theme.topBarHeight && Theme.topBarBottomPadding === 4, "OSD shares the upper chassis")
                ShellSettingsStore.reset()
                ShellSettingsStore.apply()
            } else if (root.phase >= 45 && root.phase < 55) {
                var index = Math.floor((root.phase - 45) / 2)
                if ((root.phase - 45) % 2 === 0) {
                    UiState.closeNavigation()
                    CenterState.transientMode = ""
                    AppState.waybarManualState = true
                    for (var output of root.outputs) output.bar.barH = Theme.topBarHeight + index
                    ShellSettingsStore.setValue("roundedScreen", "radius", root.geometryCases[index][0])
                    ShellSettingsStore.setValue("roundedScreen", "borderThickness", root.geometryCases[index][1])
                } else {
                    if (CenterState.osdExpansion > 0 || first.navigation.closing) return
                    // Capture the compositor's actual TopBar zone, including fractional-scale rounding.
                    capture.command = ["grim", "-t", "ppm", "-o", first.modelData.name,
                        Quickshell.env("HAKUSPACE_GEOMETRY_ARTIFACT_DIR") + "/bar-case-" + index
                        + "-top-" + Math.round(first.bar.barH) + "-width-" + first.modelData.width + ".ppm"]
                    capture.running = true
                }
            } else if (root.phase === 55) {
                for (var output of root.outputs) output.bar.barH = Qt.binding(function() { return Theme.topBarHeight })
                ShellSettingsStore.reset()
                ShellSettingsStore.apply()
            } else if (root.phase >= 56 && root.phase < 65) {
                var index = Math.floor((root.phase - 56) / 3)
                var mode = (root.phase - 56) % 3
                if (mode === 0) {
                    TooltipManager.dismiss()
                    ShellSettingsStore.setValue("appearance", "baseRadius", 24)
                    var target = index === 0 ? root.module(first.bar.contentItem, "WindowTitle")
                        : index === 1 ? root.module(first.bar.contentItem, "ClockGroup")
                        : root.module(first.bar.contentItem, "NotificationGroup").children[0]
                    TooltipManager.show(target, index === 0 ? "App ID: com.microsoft.VSCode\nTitle: apply_style.sh — hakuspace — Visual Studio Code"
                        : target.tooltip, index === 1 ? target.tooltipComponent : null)
                    TooltipManager.shown = true
                } else if (mode === 1) {
                    var layer = root.module(first.bar.contentItem, "TooltipLayer")
                    var surface = root.module(layer, "FlareSurface")
                    if (!surface || surface.currentHeight <= 0) return
                    root.check(first.bar.width === first.modelData.width, "tooltip host stays screen-wide")
                    root.check(surface.earStartRadius + surface.bottomStartRadius <= surface.currentHeight + 0.001
                        && surface.earEndRadius + surface.bottomEndRadius <= surface.currentHeight + 0.001,
                        "short tooltip ears stay above bottom corners")
                    root.check(first.bar.height >= Math.ceil(ScreenGeometry.flareTopY + surface.currentHeight
                        + surface.rf * surface.p.footEnd.scale), "tooltip foot fits inside the drawable window")
                    capture.command = ["grim", "-t", "ppm", "-o", first.modelData.name,
                        Quickshell.env("HAKUSPACE_GEOMETRY_ARTIFACT_DIR") + "/tooltip-" + index
                        + "-start-" + surface.start + "-end-" + surface.end
                        + "-bottom-" + (ScreenGeometry.flareTopY + surface.currentHeight)
                        + "-foot-" + surface.rf * surface.p.footEnd.scale + ".ppm"]
                    capture.running = true
                } else TooltipManager.dismiss()
            } else if (root.phase === 65) {
                ShellSettingsStore.reset()
                ShellSettingsStore.apply()
            } else if (root.phase === 66) {
                ShellSettingsStore.setValue("appearance", "baseRadius", 24)
                UiState.openHakuMenu(first.modelData.name)
            } else if (root.phase === 67) {
                root.check(first.menu.panelOpen, "HakuMenu opens for attachment render")
                var start = (first.modelData.width - first.menu.targetMenuWidth) / 2
                capture.command = ["grim", "-t", "ppm", "-o", first.modelData.name,
                    Quickshell.env("HAKUSPACE_GEOMETRY_ARTIFACT_DIR") + "/menu-start-" + start
                    + "-end-" + (start + first.menu.targetMenuWidth) + ".ppm"]
                capture.running = true
            } else if (root.phase === 68) {
                UiState.closeHakuMenu()
                ShellSettingsStore.reset()
                ShellSettingsStore.apply()
            } else {
                console.info("Hikai runtime checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
