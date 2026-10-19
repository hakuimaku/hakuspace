import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"

ShellRoot {
    id: root
    // Retain real output surfaces for lifecycle and reservation assertions.
    property var outputs: []
    property int phase: 0
    property int ticks: 0
    property real initialWidth: 0
    property int initialPins: 0
    property var snapshot: null
    property string initialPinText: ""
    property real fixtureHeight: 0
    property real reservedHeight: 0
    property bool closeAnimationObserved: false
    property bool autohideReservationObserved: false
    FloatingWindow { id: first; title: "Dock fixture A"; visible: false; implicitWidth: 200; implicitHeight: 100; color: "#607080" }
    FloatingWindow { id: second; title: "Dock fixture B"; visible: false; implicitWidth: 200; implicitHeight: 100 }
    FileView { id: pinFile; path: TaskbarPins.path; onLoaded: root.initialPinText = text() }
    Process {
        id: writer
        // All writes target disposable preferences, pins or manual state.
        onExited: code => {
            root.check(code === 0, "fixture write")
        }
    }
    // Sample the manual-OFF transition before its close animation completes.
    Connections {
        target: AppState
        function onTaskbarManualStateChanged() {
            if (!AppState.taskbarManualState && root.phase === 17) closeProbe.restart()
        }
    }
    Timer {
        id: closeProbe
        interval: 60
        onTriggered: {
            for (var output of root.outputs) {
                var dock = output.dock
                var motion = dock.children.find(function(item) { return typeof item.phase === "string" && typeof item.moving === "boolean" })
                var window = root.dockWindow(dock)
                var viewport = window.contentItem.children.find(function(item) { return typeof item.contentX === "number" })
                root.check(!dock.enabledDock && !dock.shown && motion.moving
                    && motion.height > 1 && motion.height < dock.targetHeight, "manual OFF animates through intermediate heights")
                root.check(window.visible, "Dock window remains mapped until manual-OFF animation finishes")
                root.check(viewport.visible && !viewport.enabled && viewport.opacity > 0 && viewport.opacity < 1,
                    "icons remain painted and fade without accepting input during close")
                root.check(window.mask.width === 0 && window.mask.height === 0, "manual OFF clears input before unmapping")
            }
            root.closeAnimationObserved = true
        }
    }
    // Locate the visual window without confusing it with the shorter reservation.
    function dockWindow(dock) {
        return dock.data.find(function(item) { return item.contentItem && item.anchors.bottom && item.height > dock.targetHeight })
    }
    // Resolve composed visual controls without adding production test hooks.
    function find(item, predicate) {
        if (predicate(item)) return item
        var children = item.contentItem ? item.contentItem.children : item.children || []
        if (!item.contentItem && item.data && typeof item.data !== "function" && typeof item.data.length === "number") children = item.data
        for (var child of children) {
            var found = find(child, predicate)
            if (found) return found
        }
        return null
    }
    // Observe a real reservation before pointer-free autohide closes the revealed Dock.
    Timer {
        id: reservationProbe
        interval: 100
        onTriggered: {
            var dock = root.outputs[0].dock
            root.check(dock.shown && ScreenGeometry.dockReservation(dock.modelData.name) === dock.targetHeight,
                "autohide reveal restores its exclusive zone")
            root.checkClientHeight(root.fixtureHeight - dock.targetHeight, "autohide reveal reserves client space")
            root.checkFrames()
            if (root.outputs.length > 1)
                root.check(ScreenGeometry.dockReservation(root.outputs[1].modelData.name) === 0,
                    "revealing one full bar leaves the other output's usable area untouched")
            root.autohideReservationObserved = true
        }
    }
    // Fail the runner immediately when a behavioral assertion is false.
    function check(ok, message) {
        if (ok) return
        console.error("Hikai Dock failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // Replace fixture files through the platform process API without shell interpolation.
    function write(path, contents) {
        writer.command = ["python3", "-c", "import pathlib,sys; pathlib.Path(sys.argv[1]).write_text(sys.argv[2])", path, contents]
        writer.running = true
    }
    // Exercise the existing Hikai ON/OFF controller against the fixture HOME.
    function toggleTaskbar() {
        writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash",
            Quickshell.env("HAKUSPACE_TEST_TASKBAR_CTL"), "--toggle"]
        writer.running = true
    }
    // Read the real frame surface rather than its declarative geometry bindings.
    function frameWindow(output) {
        return output.rounded.data.find(function(item) {
            return item.contentItem && item.anchors.top && item.anchors.bottom && item.anchors.left && item.anchors.right
        })
    }
    // Niri retiles fixture windows; its actual reservation is checked through frame bounds.
    function checkClientHeight(expected, message) {
        if (Quickshell.env("XDG_CURRENT_DESKTOP") === "niri") return
        root.check(Math.abs(first.height - expected) <= 1, message + ": " + first.height + " expected=" + expected)
    }
    // Both Dock styles preserve the physical frame across reservation changes.
    function checkFrames() {
        for (var output of root.outputs) {
            var frame = frameWindow(output)
            root.check(frame.width === output.modelData.width && frame.height === output.modelData.height,
                "RoundedScreen remains at physical edges: " + frame.width + "x" + frame.height)
        }
    }
    Variants {
        model: Quickshell.screens
        Item {
            id: output
            required property var modelData
            property alias dock: dock
            property alias rounded: rounded
            // Keep the gradient's backdrop stable outside maximized client bounds.
            PanelWindow {
                screen: output.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                color: "#607080"
                mask: Region {}
            }
            DockBar { id: dock; modelData: output.modelData }
            RoundedScreen { id: rounded; modelData: output.modelData }
            Component.onCompleted: root.outputs.push(output)
            Component.onDestruction: root.outputs = root.outputs.filter(function(item) { return item !== output })
        }
    }
    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 50, "timeout: " + ShellSettingsStore.error + " " + TaskbarPins.error)
            if (!ShellSettingsStore.ready || ShellSettingsStore.loading || ShellSettingsStore.saving || TaskbarPins.busy || writer.running || !root.outputs.length) return
            var dock = root.outputs[0].dock
            if (root.phase === 0) {
                root.check(!AppState.taskbarManualState && !dock.shown, "manual OFF startup")
                root.check(TaskbarPins.pins.length === 4, "shared pins load")
                root.initialPins = TaskbarPins.pins.length
                root.toggleTaskbar()
            } else if (root.phase === 1) {
                root.check(AppState.taskbarManualState && !dock.shown, "ON retains autohide")
                for (var output of root.outputs) output.dock.reveal()
                root.check(dock.shown, "reveal")
            } else if (root.phase === 2) {
                root.check(!dock.shown, "safe-zone closes without pointer")
                root.check(dock.triggerRect.width === (dock.modelData.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset) * 0.2, "local center trigger")
                root.check(dock.safeRect.y + dock.safeRect.height === dock.targetHeight + 180, "safe envelope touches bottom")
                root.initialWidth = dock.targetWidth
                first.visible = true
                second.visible = true
                first.maximized = true
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
            } else if (root.phase === 3) {
                var group = DockApps.runningGroups.find(function(app) { return app.windows.some(function(window) { return window.title === first.title }) })
                root.check(group && group.runningCount === 2, "real toplevel group has two windows")
                root.check(dock.targetWidth > root.initialWidth, "new running app expands target width")
                root.fixtureHeight = first.height
                root.checkFrames()
                dock.close()
                root.check(dock.shown, "Always survives close request")
                ShellSettingsStore.setValue("dock", "iconSize", 72)
                root.check(dock.iconSize === 72 && dock.targetHeight === 89, "live size preview")
                ShellSettingsStore.discard()
                root.check(dock.iconSize === 48, "Discard restores size")
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", true)
                ShellSettingsStore.apply()
            } else if (root.phase === 4) {
                root.checkFrames()
                root.checkClientHeight(root.fixtureHeight - dock.targetHeight, "reservation adds Dock height above the existing frame")
                root.reservedHeight = first.height
                dock.reveal()
                ShellSettingsStore.reload()
            } else if (root.phase === 5) {
                root.checkFrames()
                root.checkClientHeight(root.reservedHeight, "reveal leaves client geometry stable")
                first.visible = false
                second.visible = false
            } else if (root.phase === 6) {
                root.check(ShellSettingsStore.dockExclusiveSpace, "exclusive preference persisted")
                root.check(!DockApps.runningGroups.some(function(app) { return app.windows.some(function(window) { return window.title === first.title }) }), "close removes running group")
                root.check(dock.targetWidth === root.initialWidth, "close retargets width: " + root.initialWidth + " -> "
                    + dock.targetWidth + " apps=" + DockApps.renderedApps.map(function(app) { return app.key }).join(",") + " places=" + dock.places.length)
                TaskbarPins.add("hikai-test-missing-app")
            } else if (root.phase === 7) {
                root.check(TaskbarPins.pins.length === root.initialPins + 1, "pin updates model")
                root.snapshot = TaskbarPins.pins
                root.write(TaskbarPins.path, "{malformed")
            } else if (root.phase === 8) {
                root.check(!!TaskbarPins.error && TaskbarPins.pins.length === root.snapshot.length, "malformed pin file keeps last-known-good")
                root.write(TaskbarPins.path, root.initialPinText)
            } else if (root.phase === 9) {
                root.check(!TaskbarPins.error && TaskbarPins.pins.length === root.initialPins, "external valid edit recovers")
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
            } else if (root.phase === 10) {
                root.check(root.outputs.every(function(output) { return output.dock.shown }), "Always on every output")
                SysStats.mounts = [{target: "/", percent: 20}, {target: "/boot", percent: 10}, {target: "/media/Drive", percent: 37}]
                root.check(dock.places.length === 1, "storage mount filtering")
                if (Quickshell.env("HAKUSPACE_DOCK_ARTIFACT_DIR")) {
                    writer.command = ["grim", "-o", dock.modelData.name, Quickshell.env("HAKUSPACE_DOCK_ARTIFACT_DIR") + "/dock.png"]
                    writer.running = true
                }
            } else if (root.phase === 11) {
                if (root.outputs.some(function(output) { return output.modelData.name === "HEADLESS-2" })) {
                    writer.command = ["wlr-randr", "--output", "HEADLESS-2", "--off"]
                    writer.running = true
                } else root.phase = 13
            } else if (root.phase === 12) {
                root.check(root.outputs.length === 1 && SysStats._extendedSubscribers === 1, "output removal releases its Dock subscription")
                writer.command = ["wlr-randr", "--output", "HEADLESS-2", "--on"]
                writer.running = true
            } else if (root.phase === 13) {
                root.check(root.outputs.length === 2 && SysStats._extendedSubscribers === 2, "output return acquires exactly one subscription")
                root.check(root.outputs.every(function(output) { return output.dock.shown }), "new output restores Always Dock")
            } else if (root.phase === 14) {
                root.checkFrames()
                first.visible = true
                ShellSettingsStore.setValue("dock", "exclusiveSpace", false)
            } else if (root.phase === 15) {
                root.checkFrames()
                root.checkClientHeight(root.fixtureHeight, "exclusive OFF restores the client's frame-only work area")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", true)
            } else if (root.phase === 16) {
                root.checkFrames()
                root.checkClientHeight(root.fixtureHeight - dock.targetHeight, "exclusive ON restores the inner Dock zone")
                root.toggleTaskbar()
            } else if (root.phase === 17) {
                root.checkFrames()
                root.checkClientHeight(root.fixtureHeight, "manual OFF restores the client's frame-only work area")
                root.check(root.outputs.every(function(output) { return !output.dock.shown }), "manual OFF hides every output")
                root.check(root.closeAnimationObserved && root.outputs.every(function(output) { return !root.dockWindow(output.dock).visible }),
                    "every output unmaps only after its close animation")
                root.toggleTaskbar()
            } else if (root.phase === 18) {
                SysStats.mounts = [{target: "/media/Drive", percent: 37}]
                root.check(dock.places.length === 1, "mounted device shortcut starts visible")
                ShellSettingsStore.setValue("dock", "showTrash", false)
                ShellSettingsStore.setValue("dock", "showDevices", false)
            } else if (root.phase === 19) {
                var trash = root.find(dock, function(item) { return item.label === "Trash" })
                root.check(trash && !trash.visible && !dock.places.length, "accessory switches remove Trash and device slots")
                ShellSettingsStore.setValue("dock", "showTrash", true)
                ShellSettingsStore.setValue("dock", "showDevices", true)
                ShellSettingsStore.setValue("dock", "style", "bar")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", false)
            } else if (root.phase === 20) {
                var window = root.dockWindow(dock)
                var background = root.find(dock, function(item) { return item.objectName === "dock-full-bar" })
                root.check(window.width === dock.modelData.width && window.margins.left === 0 && window.margins.right === 0
                    && dock.bottomInset === 0 && dock.targetWidth === dock.modelData.width, "full bar reaches physical screen edges")
                root.check(background && background.visible && background.y + background.height === window.height,
                    "full-width gradient attaches to the physical bottom")
                root.check(Math.abs(background.gradient.stops[1].color.a - 0.5) < 0.01 && background.gradient.stops[0].color.a === 0,
                    "gradient fades from half-opacity black to transparent")
                root.checkFrames()
                root.checkClientHeight(root.fixtureHeight, "full bar without exclusivity leaves client space unchanged")
                root.check(root.find(dock, function(item) { return item.label === "Trash" }).visible && dock.places.length === 1,
                    "accessories can be enabled again")
                if (Quickshell.env("HAKUSPACE_DOCK_ARTIFACT_DIR")) {
                    writer.command = ["grim", "-o", dock.modelData.name, Quickshell.env("HAKUSPACE_DOCK_ARTIFACT_DIR") + "/full-bar.png"]
                    writer.running = true
                }
                ShellSettingsStore.apply()
            } else if (root.phase === 21) {
                ShellSettingsStore.reload()
            } else if (root.phase === 22) {
                root.check(dock.fullWidth, "full bar style survives Apply and Reload")
                ShellSettingsStore.setValue("dock", "visibilityMode", "autohide")
                ShellSettingsStore.setValue("dock", "exclusiveSpace", true)
            } else if (root.phase === 23) {
                root.check(!dock.shown && ScreenGeometry.dockReservation(dock.modelData.name) === 0, "hidden autohide bar has no exclusive zone")
                root.checkClientHeight(root.fixtureHeight, "hidden bar releases client space")
                root.checkFrames()
                dock.reveal()
                reservationProbe.start()
            } else if (root.phase === 24) {
                root.check(root.autohideReservationObserved && !dock.shown, "autohide releases the exclusive zone")
                root.checkClientHeight(root.fixtureHeight, "autohide restores client height")
                root.checkFrames()
                ShellSettingsStore.setValue("dock", "style", "dock")
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
            } else if (root.phase === 25) {
                root.checkFrames()
                ShellSettingsStore.setValue("dock", "visibilityMode", "autohide")
            } else if (root.phase === 26) {
                root.check(!dock.shown && ScreenGeometry.dockReservation(dock.modelData.name) === 0,
                    "compact autohide Dock also releases its exclusive zone")
                root.checkClientHeight(root.fixtureHeight, "hidden compact Dock releases client space")
                root.checkFrames()
                console.info("Hikai Dock checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
