import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"

ShellRoot {
    id: root
    // Drive real pointer events against the first isolated output.
    property var outputs: []
    property int phase: 0
    property int ticks: 0
    property int clientClicks: 0
    property string groupKey: ""
    property string launched: ""
    property string gioRequest: ""
    property string terminationRequests: ""
    property bool autohideAnimationObserved: false
    property bool labwcSession: false
    property int nativeClosed: 0
    property string nativeTerminationLog: ""
    // Capture logical geometry before hover to detect layout motion.
    property var hoverSlot: null
    property real hoverWidth: 0
    readonly property var dock: outputs.length ? outputs[0].dock : null
    FloatingWindow {
        id: first
        screen: Quickshell.screens[0]
        title: "Dock input A"
        implicitWidth: 240; implicitHeight: 160
        visible: false
        maximized: true
        color: "#597987"
        onClosed: { root.nativeClosed++; visible = false }
        MouseArea { anchors.fill: parent; onClicked: root.clientClicks++ }
    }
    FloatingWindow {
        id: second
        screen: Quickshell.screens[0]
        title: "Dock input B"
        visible: false
        implicitWidth: 240; implicitHeight: 160
        onClosed: { root.nativeClosed++; visible = false }
    }
    Process {
        id: pointer
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_POINTER")]
        stdinEnabled: true
        running: true
        stderr: StdioCollector { id: pointerError }
        onExited: code => root.check(code === 0, "pointer fixture: " + pointerError.text)
    }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]
        stdinEnabled: true
        running: true
        stderr: StdioCollector { id: keyboardError }
        onExited: code => root.check(code === 0, "keyboard fixture: " + keyboardError.text)
    }
    Process { id: writer; onExited: code => root.check(code === 0, "state toggle") }
    FileView {
        path: Quickshell.env("HAKUSPACE_TEST_LAUNCH_LOG")
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onTextChanged: root.launched = text().trim()
    }
    FileView {
        path: Quickshell.env("HAKUSPACE_TEST_GIO_LOG")
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onTextChanged: root.gioRequest = text().trim()
    }
    FileView {
        path: Quickshell.env("HAKUSPACE_TEST_TERMINATION_LOG")
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onTextChanged: root.terminationRequests = text().trim()
    }
    // Observe tooltips before the former 450 ms delay could elapse.
    Timer {
        id: tooltipCheck
        interval: 60
        onTriggered: {
            var tooltip = root.appTooltip()
            root.check(tooltip && tooltip.visible, "Dock tooltip appears without delay")
        }
    }
    // Observe icon painting during an actual pointer-driven autohide transition.
    Connections {
        target: root.dock
        function onShownChanged() {
            if (!root.dock.shown && root.dock.enabledDock && root.phase === 7) autohideProbe.restart()
        }
    }
    Timer {
        id: autohideProbe
        interval: 60
        onTriggered: {
            var motion = root.find(root.dock, function(item) { return typeof item.phase === "string" && typeof item.moving === "boolean" })
            var window = root.find(root.dock, function(item) { return item.contentItem && item.anchors.bottom && item.height > root.dock.targetHeight })
            var viewport = root.find(window, function(item) { return typeof item.contentX === "number" })
            root.check(window.visible && motion.moving && motion.height > 1 && motion.height < root.dock.targetHeight,
                "autohide keeps the visual window mapped during close")
            root.check(viewport.visible && !viewport.enabled && viewport.opacity > 0 && viewport.opacity < 1,
                "autohide paints fading icons without accepting input")
            root.autohideAnimationObserved = true
        }
    }
    // A brief return inside the grace period must cancel an autohide close.
    Timer { id: reenter; interval: 100; onTriggered: root.move(root.dock.modelData.width / 2, root.dock.modelData.height - 16) }
    // Fail with the active phase so input regressions are reproducible.
    function check(ok, message) {
        if (ok) return
        console.error("Hikai Dock failed: input phase " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Send output-local coordinates through the virtual pointer protocol.
    function move(x, y, button) {
        pointer.write([Math.round(x), Math.round(y), dock.modelData.width, dock.modelData.height, button || 0].join(" ") + "\n")
    }
    // Locate existing controls without exposing test-only production API.
    function find(item, predicate) {
        if (predicate(item)) return item
        var children = item.contentItem ? item.contentItem.children : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var index = 0; index < children.length; ++index) {
            var found = find(children[index], predicate)
            if (found) return found
        }
        return null
    }
    // Map a logical icon's center into the output-local bottom window.
    function pointAt(item, button) {
        check(!!item, "control exists")
        check(dock.shown, "Dock is open before clicking an item")
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        move(ScreenGeometry.leftInset + point.x, dock.modelData.height - dock.targetHeight - 180 + point.y, button)
    }
    // Resolve the real grouped application represented by the input fixture windows.
    function app() { return DockApps.renderedApps.find(function(value) { return value.key === root.groupKey }) }
    function appIcon() { return find(dock, function(item) { return item.appActions && item.label.indexOf(app().name + " ·") === 0 }) }
    function appTooltip() { return find(appIcon(), function(item) { return item.immediate === true }) }
    function toggle() {
        writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash", Quickshell.env("HAKUSPACE_TEST_TASKBAR_CTL"), "--toggle"]
        writer.running = true
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: output
            required property var modelData
            property alias dock: dock
            RoundedScreen { modelData: output.modelData }
            DockBar { id: dock; modelData: output.modelData }
            Component.onCompleted: root.outputs.push(output)
        }
    }
    Timer {
        interval: 650
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 65, "timeout")
            if (!root.dock || !ShellSettingsStore.ready || TaskbarPins.busy || writer.running) return
            var width = root.dock.modelData.width
            var height = root.dock.modelData.height
            if (root.phase === 0) {
                // Exercise mocked PID confirmation separately from native Labwc close requests.
                root.labwcSession = WM.labwcSession
                WM.labwcSession = false
                root.check(HAnimation.dockOpenDuration === 360 && HAnimation.dockCloseDuration === 224
                    && HAnimation.hakuMenuOpenDuration === 360 && HAnimation.hakuMenuCloseDuration === 308
                    && HAnimation.floatingPanelOpenDuration === 504 && HAnimation.floatingPanelCloseDuration === 280,
                    "Dock and HakuMenu open 10 percent sooner and close 30 percent sooner")
                root.toggle()
            }
            else if (root.phase === 1) root.move(10, height - 1)
            else if (root.phase === 2) {
                root.check(!root.dock.shown, "left edge does not reveal")
                root.move(width - 10, height - 1)
            } else if (root.phase === 3) {
                root.check(!root.dock.shown, "right edge does not reveal")
                UiState.activePanel = "notifications"
                root.move(width / 2, height - 1)
            } else if (root.phase === 4) {
                root.check(root.dock.shown, "center edge reveals")
                root.check(UiState.activePanel === "notifications", "reveal preserves transient panel ownership")
                UiState.activePanel = ""
                first.visible = true
                root.move(width / 2, height - 16)
            } else if (root.phase === 5) {
                root.move(10, 100)
                reenter.start()
            } else if (root.phase === 6) {
                root.check(root.dock.shown, "grace re-entry keeps Dock alive")
                root.move(80, height - 20, 272)
            } else if (root.phase === 7) {
                root.check(!root.dock.shown, "safe-zone exit closes")
                root.check(root.autohideAnimationObserved, "autohide was sampled before its animation completed")
                root.check(root.clientClicks === 1, "desktop beside Dock remains clickable")
                root.groupKey = DockApps.runningGroups.find(function(value) { return value.windows.some(function(window) { return window.title === first.title }) }).key
                root.move(width / 2, height - 1)
            } else if (root.phase === 8) root.pointAt(root.appIcon(), 273)
            else if (root.phase === 9) {
                root.check(root.app().pinned, "right click directly pins the app")
                var feedback = root.find(root.dock, function(item) { return item.objectName === "dock-pin-feedback" })
                root.check(root.dock.pinMessage.indexOf("Pinned “") === 0 && feedback && feedback.visible,
                    "successful pin shows feedback above its Dock")
                root.check(root.outputs.slice(1).every(function(output) { return !output.dock.pinMessage }),
                    "pin feedback stays on the originating output")
                root.check(!root.appTooltip().visible, "pin feedback replaces the hover tooltip")
                root.check(!root.find(root.dock, function(item) { return item.objectName === "dock-context-menu" }), "pin popup is removed")
                tooltipCheck.start()
                root.pointAt(root.appIcon(), 274)
            } else if (root.phase === 10) {
                root.check(!root.dock.pinMessage, "termination confirmation dismisses pin feedback")
                root.check(root.dock.terminationRoots.length === 1 && root.appIcon().actionMessage.indexOf("512 MB") >= 0,
                    "middle click shows the high RAM confirmation tooltip")
                root.check(root.terminationRequests === "[]", "warning sends no confirmed termination")
                root.pointAt(root.find(root.dock, function(item) { return item.label === "Trash" }))
            } else if (root.phase === 11) {
                root.check(root.dock.terminationKey === "", "leaving the app dismisses confirmation")
                root.check(root.dock.shown && !root.appIcon().hovered && root.appIcon().activeFocus,
                    "moving to another icon retains the clicked item's keyboard focus")
                root.check(!root.appTooltip().visible, "mouse focus cannot keep the previous tooltip open")
                root.check(DockApps.renderedApps.filter(function(value) { return value.key === root.groupKey }).length === 1, "pinned/running app stays deduplicated")
                second.visible = true
                root.move(width / 2, height - 1)
            } else if (root.phase === 12) {
                root.check(root.app().runningCount === 2, "two real windows share one icon")
                root.pointAt(root.appIcon(), 272)
            } else if (root.phase === 13) {
                root.check(root.app().windows.find(function(window) { return window.title === first.title }).activated, "first cycle activates A")
                root.pointAt(root.appIcon(), 272)
            } else if (root.phase === 14) {
                root.check(root.app().windows.find(function(window) { return window.title === second.title }).activated, "next cycle activates B")
                root.pointAt(root.appIcon(), 273)
            } else if (root.phase === 15) {
                root.check(!root.app().pinned, "right click directly unpins the app")
                root.check(root.dock.pinMessage.indexOf("Unpinned “") === 0, "successful unpin shows feedback")
                root.pointAt(root.appIcon(), 274)
            } else if (root.phase === 16) {
                root.check(!root.app().pinned && root.app().runningCount === 2, "unpin retains running application")
                root.check(root.dock.terminationRoots.length === 1, "repeated middle click requests fresh confirmation")
                root.pointAt(root.appIcon(), 274)
            } else if (root.phase === 17) {
                root.check(root.dock.terminationKey === "" && root.terminationRequests.split("\n").length === 3,
                    "second middle click confirms and dismisses the warning")
                root.check(JSON.parse(root.terminationRequests.split("\n")[2])[0].startTime === "fixture",
                    "confirmation preserves the process identity")
                first.fullscreen = true
                second.visible = false
                root.move(width / 2, height / 2)
            } else if (root.phase === 18) {
                root.check(!root.dock.shown, "hidden over fullscreen client")
                root.move(width / 2, height - 1)
            } else if (root.phase === 19) {
                root.check(!root.dock.shown, "fullscreen client covers the Top-layer trigger")
                first.fullscreen = false
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                root.move(10, 100)
            } else if (root.phase === 20) {
                root.check(root.dock.shown, "Always ignores pointer exit")
                var menuIcon = root.find(root.dock, function(item) { return item.label === "Applications" })
                root.pointAt(menuIcon, 272)
            } else if (root.phase === 21) {
                root.check(UiState.hakuMenuScreenName === root.dock.modelData.name && UiState.hakuMenuMode === "drun", "App Menu routes to this monitor")
                UiState.closeHakuMenu()
                TaskbarPins.add("hikai-dock-launch")
            } else if (root.phase === 22) {
                root.pointAt(root.find(root.dock, function(item) { return item.label === "Dock Launch Fixture" }), 272)
            } else if (root.phase === 23) {
                root.check(root.launched === "launched", "stopped pin executes its DesktopEntry")
                SysStats.mounts = [{target: "/media/Drive", percent: 37}]
            } else if (root.phase === 24) {
                root.pointAt(root.find(root.dock, function(item) { return item.label === "/media/Drive · 37% used" }), 272)
            } else if (root.phase === 25) {
                root.check(root.gioRequest === "open\n/media/Drive", "drive click opens the mount path")
                root.pointAt(root.find(root.dock, function(item) { return item.label === "Trash" }), 272)
            } else if (root.phase === 26) {
                root.check(root.gioRequest === "open\ntrash:///", "Trash click opens its URI")
                root.move(10, 100)
            } else if (root.phase === 27) {
                ShellSettingsStore.setValue("dock", "visibilityMode", "autohide")
                root.check(!root.dock.shown, "Always to autohide closes when pointer is outside")
                ShellSettingsStore.setValue("roundedScreen", "borderThickness", 6)
                root.move(width / 2, height - 1)
            } else if (root.phase === 28) {
                var icon = root.appIcon()
                var point = icon.mapToItem(null, 0, 0)
                root.hoverSlot = {x: point.x, y: point.y, width: icon.width, height: icon.height}
                root.hoverWidth = root.dock.targetWidth
                root.check(root.dock.bottomInset === 6, "Dock follows live frame reservation changes")
                root.check(Math.abs(point.y - (184 - root.dock.bottomInset)) < 1,
                    "icon slots sit above RoundedScreen's bottom zone")
                ShellSettingsStore.setValue("dock", "hoverLift", 48)
                ShellSettingsStore.setValue("dock", "hoverScale", 100)
                root.pointAt(icon)
            } else if (root.phase === 29) {
                var icon = root.appIcon()
                var point = icon.mapToItem(null, 0, 0)
                var surface = root.find(root.dock, function(item) { return typeof item.sideSlope === "number" })
                root.check(surface && surface.sideSlope > 0 && surface.cornerRadius > 0 && surface.baseFlareRadius > 0,
                    "Dock has slanted sides, rounded top corners and small bottom flares")
                root.check(surface.cornerRadius < surface.height / 2
                    && surface.sideStepY * 2 < surface.height
                    && surface.baseFlareRadius < surface.cornerRadius
                    && root.dock.safeRect.width >= surface.width + surface.topInset * 2,
                    "trapezoid and small flares fit the safe envelope and retain straight sides")
                root.check(Math.abs(icon.iconLift - ShellSettingsStore.dockHoverLift) < 0.1, "hover lifts the icon to its configured peak")
                root.check(Math.abs(icon.iconScale - 2) < 0.01 && Math.abs(icon.iconRect.width - icon.iconSize * 2) < 0.1,
                    "100 percent enlargement doubles the painted artwork")
                var seed = root.dock.menuAnchor(icon)
                root.check(seed.width === icon.iconRect.width && seed.height === icon.iconRect.height,
                    "HakuMenu captures the enlarged artwork dimensions")
                root.check(point.x === root.hoverSlot.x && point.y === root.hoverSlot.y
                    && icon.width === root.hoverSlot.width && icon.height === root.hoverSlot.height
                    && root.dock.targetWidth === root.hoverWidth, "hover preserves slots and Dock width")
                var neighbor = root.find(root.dock, function(item) {
                    if (typeof item.iconLift !== "number" || item === icon) return false
                    var distance = Math.abs(item.mapToItem(null, 0, 0).x - point.x)
                    return distance > 1 && distance < icon.width * 1.5
                })
                root.check(!!neighbor && neighbor.iconLift > 0 && neighbor.iconLift < icon.iconLift, "neighbor receives a weaker lift")
                root.check(neighbor.iconScale > 1 && neighbor.iconScale < icon.iconScale, "neighbor receives weaker enlargement")
                var viewport = root.find(root.dock, function(item) { return typeof item.contentX === "number" })
                var firstIcon = root.find(root.dock, function(item) { return typeof item.iconRect === "object" })
                var edge = firstIcon.mapToItem(viewport, firstIcon.iconRect.x, firstIcon.iconRect.y)
                root.check(edge.x >= 0 && edge.y >= 0 && edge.x + firstIcon.iconRect.width <= viewport.width,
                    "enlarged edge artwork fits the clipping viewport")
                root.move(ScreenGeometry.leftInset + point.x + icon.width / 2,
                    height - root.dock.targetHeight - 180 + point.y + icon.iconRect.y + 2)
            } else if (root.phase === 30) {
                root.check(root.dock.shown && root.appIcon().hovered, "raised artwork remains inside hit area and safe zone")
                root.pointAt(root.appIcon(), 273)
            } else if (root.phase === 31) {
                root.check(root.app().pinned, "direct pin works on a raised icon")
                root.pointAt(root.appIcon(), 274)
            } else if (root.phase === 32) {
                root.check(root.dock.terminationRoots.length === 1 && root.appIcon().actionMessage.length > 0,
                    "high RAM confirmation works after hover")
                keyboard.write("key 1\n")
            } else if (root.phase === 33) {
                root.check(root.dock.terminationKey === "" && root.appIcon().hovered && !root.appTooltip().visible,
                    "Escape closes confirmation and its tooltip while still hovering")
                root.pointAt(root.appIcon(), 273)
            } else if (root.phase === 34) {
                root.check(!root.app().pinned && root.dock.terminationKey === "", "right click unpins and cancels confirmation")
                root.check(root.dock.pinMessage.indexOf("Unpinned “") === 0, "raised icon unpin shows feedback")
                root.pointAt(root.appIcon())
            } else if (root.phase === 35) {
                ShellSettingsStore.setValue("dock", "hoverLift", 0)
            } else if (root.phase === 36) {
                root.check(root.appIcon().hovered && Math.abs(root.appIcon().iconLift) < 0.1 && root.appIcon().iconScale > 1.99,
                    "zero lift leaves enlargement enabled")
                ShellSettingsStore.setValue("dock", "hoverScale", 0)
            } else if (root.phase === 37) {
                root.check(root.appIcon().hovered && Math.abs(root.appIcon().iconLift) < 0.1 && root.appIcon().iconScale === 1,
                    "zero enlargement restores original artwork while hovered")
                root.check(root.dock.targetWidth === root.hoverWidth && root.appIcon().width === root.hoverSlot.width,
                    "hover settings preserve Dock and slot widths")
                ShellSettingsStore.discard()
            } else if (root.phase === 38) {
                root.check(!root.dock.pinMessage, "pin feedback expires automatically")
                root.check(Math.abs(root.appIcon().iconLift - 14) < 0.1 && root.appIcon().iconScale === 1,
                    "Discard restores the default hover effect")
                root.move(10, 100)
            } else if (root.phase === 39) {
                root.check(!root.dock.shown, "autohide still closes after hover")
                if (!root.labwcSession) {
                    root.toggle()
                    root.phase = 48
                } else {
                    WM.labwcSession = true
                    root.nativeTerminationLog = root.terminationRequests
                    ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                }
            } else if (root.phase === 40) {
                root.pointAt(root.appIcon(), 274)
            } else if (root.phase === 41) {
                root.check(root.dock.terminationRoots.length === 1 && root.appIcon().actionMessage.indexOf("RAM usage is unavailable") >= 0,
                    "Labwc middle click requests confirmation when RAM cannot be inspected")
                root.check(root.nativeClosed === 0 && first.visible && root.terminationRequests === root.nativeTerminationLog,
                    "Labwc warning neither closes nor signals processes")
                second.visible = true
            } else if (root.phase === 42) {
                root.pointAt(root.appIcon(), 274)
            } else if (root.phase === 43) {
                root.check(root.dock.terminationRoots.length === 2 && root.nativeClosed === 0 && first.visible && second.visible,
                    "changed window membership requires fresh confirmation")
                root.pointAt(root.appIcon(), 274)
            } else if (root.phase === 44) {
                root.check(root.nativeClosed === 2 && !first.visible && !second.visible && root.dock.terminationKey === "",
                    "confirmed Labwc action closes both real windows through Wayland")
                root.check(root.terminationRequests === root.nativeTerminationLog, "native close never invokes PID termination")
                first.visible = true
            } else if (root.phase === 45) {
                root.app().windows[0].minimized = true
            } else if (root.phase === 46) {
                root.check(root.app().windows[0].minimized, "Labwc fixture is minimized before activation")
                root.pointAt(root.appIcon(), 272)
            } else if (root.phase === 47) {
                root.check(!root.app().windows[0].minimized && root.app().windows[0].activated,
                    "Dock activation restores and focuses a minimized Labwc window")
                ShellSettingsStore.discard()
                root.move(10, 100)
            } else if (root.phase === 48) {
                root.check(!root.dock.shown, "autohide still works after native window operations")
                root.toggle()
            } else if (root.phase === 49) {
                root.check(!root.dock.shown && SysStats._extendedSubscribers === 0, "manual OFF releases all output subscriptions")
                console.info("Hikai Dock checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
