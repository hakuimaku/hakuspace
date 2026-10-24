import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    // Drive held-button gestures against disposable shared pins and output surfaces.
    property var outputs: []
    property int phase: 0
    property int ticks: 0
    property string launched: ""
    readonly property var dock: outputs.length ? outputs[0].dock : null
    Process {
        id: pointer
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_POINTER")]
        stdinEnabled: true
        running: true
    }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]
        stdinEnabled: true
        running: true
    }
    Process { id: writer; onExited: code => root.check(code === 0, "manual state toggle") }
    FileView {
        path: Quickshell.env("HAKUSPACE_TEST_LAUNCH_LOG")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.launched = text().trim()
    }
    // Find real icons through the composed window tree without test-only production API.
    function content(host) {
        return find(host, function(item) { return typeof item.activationSource === "string" && typeof item.menuAnchor === "function" })
    }
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
    function icon(id) {
        return find(dock, function(item) { return item.reorderable && item.parent && item.parent.app && item.parent.app.pinId === id })
    }
    function check(ok, message) {
        if (ok) return
        console.error("Hikai Dock failed: reorder phase " + phase + ": " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    // The sixth pointer field holds or releases a button instead of clicking it.
    function move(x, y, button, state) {
        var request = [Math.round(x), Math.round(y), dock.modelData.width, dock.modelData.height, button || 0]
        if (state !== undefined) request.push(state)
        pointer.write(request.join(" ") + "\n")
    }
    function pointAt(id, button, state) {
        var item = icon(id)
        check(!!item && dock.shown, "pinned icon is available: " + id + " item=" + !!item + " shown=" + dock.shown)
        var point = item.mapToItem(null, item.width / 2, item.height / 2)
        move(ScreenGeometry.leftInset + point.x, dock.modelData.height - dock.targetHeight - 180 + point.y, button, state)
    }
    function order() { return TaskbarPins.pins.map(function(pin) { return pin.id }).join(",") }
    // Move before the hold timeout to exercise a normal press-and-drag gesture.
    Timer {
        id: quickDrag
        interval: 70
        onTriggered: {
            if (root.phase === 3) root.pointAt("kitty")
            else if (root.phase === 22) root.pointAt("reorder-2")
        }
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
        interval: 450
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 65, "timeout: " + TaskbarPins.error)
            if (!root.dock || !ShellSettingsStore.ready || TaskbarPins.busy || writer.running) return
            var width = root.dock.modelData.width
            var height = root.dock.modelData.height
            if (root.phase === 0) {
                writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash",
                    Quickshell.env("HAKUSPACE_TEST_DOCKBAR_CTL"), "--toggle"]
                writer.running = true
            } else if (root.phase === 1) root.move(width / 2, height - 1)
            else if (root.phase === 2) {
                root.pointAt("firefox", 272, 1)
                quickDrag.start()
            }
            else if (root.phase === 3) {
                root.check(root.content(root.dock).reorderPin === "firefox" && root.icon("firefox").reordering, "early pointer motion starts one-icon drag")
                root.pointAt("kitty")
            } else if (root.phase === 4) {
                root.check(root.content(root.dock).reorderTarget === "kitty" && root.icon("firefox").reorderOffset < -1, "dragged icon follows the pointer")
                root.check(root.order() === "menu,kitty,thunar,firefox" && !root.launched && UiState.activePanel === "", "drag leaves pins and activation unchanged")
                root.pointAt("kitty", 272, 0)
            } else if (root.phase === 5) {
                root.check(!root.content(root.dock).reorderKey && root.order() === "menu,firefox,kitty,thunar", "drop persists the requested shared pin order")
                TaskbarPins.reload()
            } else if (root.phase === 6) {
                root.check(root.order() === "menu,firefox,kitty,thunar", "reordered pins survive backend reload")
                root.pointAt("firefox", 272, 1)
            } else if (root.phase === 7) root.move(10, 100)
            else if (root.phase === 8) {
                root.check(root.dock.shown && root.content(root.dock).reorderKey, "held icon leases autohide outside the Dock")
                root.move(10, 100, 272, 0)
            } else if (root.phase === 9) {
                root.check(!root.content(root.dock).reorderKey && root.order() === "menu,firefox,kitty,thunar", "outside drop cancels without changing pins")
                root.move(width / 2, height - 1)
            } else if (root.phase === 10) root.pointAt("firefox", 272, 1)
            else if (root.phase === 11) root.pointAt("kitty")
            else if (root.phase === 12) keyboard.write("key 139\nkey 1\n")
            else if (root.phase === 13) {
                root.check(!root.content(root.dock).reorderKey && root.order() === "menu,firefox,kitty,thunar", "Escape cancels the drag")
                root.pointAt("kitty", 272, 0)
            } else if (root.phase === 14) root.pointAt("menu", 272, 1)
            else if (root.phase === 15) root.pointAt("thunar")
            else if (root.phase === 16) root.pointAt("thunar", 272, 0)
            else if (root.phase === 17) {
                root.check(root.order() === "firefox,kitty,thunar,menu" && UiState.activePanel === "", "Applications can move without opening HakuMenu")
                root.pointAt("firefox", 272, 1)
            } else if (root.phase === 18) {
                root.check(root.content(root.dock).reorderKey, "external-edit fixture holds a pin")
                TaskbarPins.move(0, 1)
            } else if (root.phase === 19) {
                root.check(!root.content(root.dock).reorderKey && root.order() === "kitty,firefox,thunar,menu", "external pin changes cancel a stale drag")
                root.pointAt("firefox", 272, 0)
            } else if (root.phase === 20) {
                root.check(!root.launched && UiState.activePanel === "", "no drag or canceled release launches an app")
                ShellSettingsStore.setValue("dock", "visibilityMode", "always")
                writer.command = ["python3", "-c", "import json,pathlib,sys; ids=['menu']+['reorder-'+str(i) for i in range(40)]; data={'group/pin':{'modules':['image#'+i for i in ids]}}; data.update({'image#'+i:{'on-click':'true'} for i in ids}); pathlib.Path(sys.argv[1]).write_text(json.dumps(data))", TaskbarPins.path]
                writer.running = true
            } else if (root.phase === 21) {
                root.check(TaskbarPins.pins.length === 41, "external crowded pin list loads")
                root.pointAt("reorder-0", 272, 1)
                quickDrag.start()
            } else if (root.phase === 22) {
                var viewport = root.find(root.dock, function(item) { return typeof item.contentX === "number" })
                root.check(viewport.contentWidth > viewport.width && root.content(root.dock).reorderTarget === "reorder-2",
                    "crowded Dock reserves early motion for reordering instead of scrolling")
                var point = viewport.mapToItem(null, viewport.width - 8, viewport.height - root.dock.targetHeight / 2)
                root.move(ScreenGeometry.leftInset + point.x, height - root.dock.targetHeight - 180 + point.y)
            } else if (root.phase === 23) {
                var viewport = root.find(root.dock, function(item) { return typeof item.contentX === "number" })
                root.check(viewport.contentX > 0 && root.content(root.dock).reorderKey, "held pointer edge scrolls crowded pins")
                var held = root.icon("reorder-0").mapToItem(viewport, root.content(root.dock).reorderGrabX, 0)
                root.check(Math.abs(held.x - (viewport.width - 8)) < 1, "edge scroll keeps the grabbed icon under the pointer")
                var point = viewport.mapToItem(null, viewport.width - 8, viewport.height - root.dock.targetHeight / 2)
                root.move(ScreenGeometry.leftInset + point.x, height - root.dock.targetHeight - 180 + point.y, 272, 0)
            } else if (root.phase === 24) {
                root.check(TaskbarPins.pins.findIndex(function(pin) { return pin.id === "reorder-0" }) > 1 && TaskbarPins.pins.length === 41,
                    "scrolled drop moves exactly one pin without losing entries")
                root.check(!root.launched && UiState.activePanel === "", "crowded drag does not activate apps or HakuMenu")
                root.pointAt("reorder-5", 272, 1)
            } else if (root.phase === 25) {
                root.check(root.content(root.dock).reorderKey, "manual OFF fixture starts with a held icon")
                writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash",
                    Quickshell.env("HAKUSPACE_TEST_DOCKBAR_CTL"), "--toggle"]
                writer.running = true
            } else if (root.phase === 26) {
                root.check(!root.dock.enabledDock && !root.content(root.dock).reorderKey, "manual OFF cancels dragging and releases its lease")
                root.move(width / 2, height - 1, 272, 0)
            } else if (root.phase === 27) {
                writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash",
                    Quickshell.env("HAKUSPACE_TEST_DOCKBAR_CTL"), "--toggle"]
                writer.running = true
            } else if (root.phase === 28) {
                ShellSettingsStore.setValue("dock", "visibilityMode", "autohide")
                root.move(width / 2, height - 1)
            } else if (root.phase === 29) {
                var app = DockApps.renderedApps.find(function(app) { return app.pinId === "reorder-0" })
                root.check(!!app, "stopped pin feedback fixture is available")
                root.content(root.dock).togglePin(app)
            } else if (root.phase === 30) {
                var feedback = root.find(root.dock, function(item) { return item.objectName === "dock-pin-feedback" })
                root.check(root.content(root.dock).pinMessage.indexOf("Unpinned “") === 0 && feedback && feedback.visible
                    && feedback.y + feedback.height < root.dock.safeRect.y,
                    "removing a stopped pin paints noninteractive feedback above the Dock")
                root.move(10, 100)
            } else if (root.phase === 31) {
                root.check(root.dock.shown && root.content(root.dock).pinMessage, "feedback briefly keeps autohide visible after pointer exit")
            } else if (root.phase === 34) {
                root.check(!root.content(root.dock).pinMessage, "pin feedback expires after two seconds")
            } else if (root.phase === 35) {
                root.check(!root.dock.shown, "feedback timeout releases the autohide grace period")
                root.move(width / 2, height - 1)
            } else if (root.phase === 36) {
                root.content(root.dock).togglePin({type: "app", pinned: true, pinId: "menu", name: "Reserved menu"})
            } else if (root.phase === 37) {
                root.check(root.content(root.dock).pinMessage === TaskbarPins.error && !!TaskbarPins.error,
                    "failed pin mutation shows the backend error instead of success")
                writer.command = ["env", "HOME=" + Quickshell.shellPath("../../../"), "bash",
                    Quickshell.env("HAKUSPACE_TEST_DOCKBAR_CTL"), "--toggle"]
                writer.running = true
            } else if (root.phase === 38) {
                root.check(!root.content(root.dock).pinMessage && !root.dock.shown, "manual OFF clears pin feedback")
                console.info("Hikai Dock checks passed")
                Qt.quit()
            }
            root.phase++
        }
    }
}
