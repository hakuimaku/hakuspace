pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "."
import "WindowNavigatorModel.js" as Model

QtObject {
    id: root
    // Availability follows compositor, lock and shell presentation ownership.
    readonly property bool supported: WM.backendName === "hyprland"
    readonly property bool available: supported && !LockState.locked
        && ShellTransitionState.chromeEnabled && !ShellTransitionState.active
    readonly property var windows: supported ? Model.normalize(Hyprland.toplevels.values, DockApps.lookup) : []
    readonly property string focusedAddress: supported && Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
    property var mruAddresses: []
    // Session order remains independent from subsequent compositor focus changes.
    property bool active: false
    property string mode: "closed"
    property string screenName: ""
    property var sessionWindows: []
    property int selectedIndex: -1
    readonly property string selectedAddress: sessionWindows[selectedIndex] ? sessionWindows[selectedIndex].address : ""
    property string originAddress: ""
    property int previewGeneration: 0
    property string pendingAddress: ""

    // A single Wayland event stream prevents fast Alt release from overtaking open.
    property Loader shortcuts: Loader {
        active: root.supported
        sourceComponent: Item {
            GlobalShortcut {
                appid: "hakuspace"; name: "window-navigator-next"
                description: "Select the next window"
                onPressed: root.step(1)
            }
            GlobalShortcut {
                appid: "hakuspace"; name: "window-navigator-previous"
                description: "Select the previous window"
                onPressed: root.step(-1)
            }
            GlobalShortcut {
                appid: "hakuspace"; name: "window-navigator-commit"
                description: "Confirm the window switcher"
                onPressed: root.commitSwitcher()
                onReleased: root.commitSwitcher()
            }
        }
    }

    onAvailableChanged: if (!available) cancel()
    onWindowsChanged: refresh()
    onFocusedAddressChanged: {
        mruAddresses = Model.mru(mruAddresses, windows, focusedAddress)
        if (active && mode === "switcher" && focusedAddress && focusedAddress !== originAddress) cancel()
    }

    // Reflect source changes without injecting new windows into an Alt-Tab cycle.
    function refresh() {
        mruAddresses = Model.mru(mruAddresses, windows, focusedAddress)
        if (!active) return
        var ordered = orderedWindows(mode === "overview")
        var updated = Model.reconcile(sessionWindows, ordered, mode === "overview", selectedAddress, selectedIndex)
        sessionWindows = updated.windows
        selectedIndex = updated.index
        if (!sessionWindows.length) cancel()
    }

    // Rank normal and special workspaces around the focused output.
    function orderedWindows(overview) {
        return Model.ordered(windows, mruAddresses, overview,
            Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0, screenName)
    }

    // Assign one output, preferring the focused monitor over the active window.
    function ownerScreen() {
        var preferred = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        var window = windows.find(function(entry) { return entry.address === focusedAddress })
        return Quickshell.screens.find(function(screen) { return screen.name === preferred })
            || Quickshell.screens.find(function(screen) { return window && screen.name === window.monitorName })
            || Quickshell.screens[0]
    }

    // Start closed sessions with confirmed focus at the MRU head.
    function open(requestedMode, delta) {
        if (!available || windows.length < (requestedMode === "switcher" ? 2 : 1)) return
        var screen = ownerScreen()
        if (!screen) return
        pendingAddress = ""
        screenName = screen.name
        originAddress = focusedAddress || mruAddresses[0] || ""
        mruAddresses = Model.mru(mruAddresses, windows, originAddress)
        sessionWindows = orderedWindows(requestedMode === "overview")
        selectedIndex = Math.max(0, sessionWindows.findIndex(function(entry) { return entry.address === originAddress }))
        if (requestedMode === "switcher") selectedIndex = Model.cycle(selectedIndex, delta, sessionWindows.length)
        mode = requestedMode
        previewGeneration++
        UiState.activePanel = "windowNavigator"
        active = true
    }

    // Move selection only; compositor focus changes exclusively on commit.
    function step(delta) {
        if (!active) open("switcher", delta)
        else selectedIndex = Model.cycle(selectedIndex, delta, sessionWindows.length)
    }

    // Keep pointer and geometry navigation within the current live snapshot.
    function select(index) {
        if (active && index >= 0 && index < sessionWindows.length) selectedIndex = index
    }

    // Release logical input ownership before asking the compositor to focus.
    function commit() {
        if (!active) return
        var address = selectedAddress
        cancel()
        pendingAddress = address
    }

    // Hyprland rejects activation until the compositor releases the exclusive layer.
    function activatePending() {
        if (!available || active || !pendingAddress) return
        var address = pendingAddress
        pendingAddress = ""
        var entry = windows.find(function(window) { return window.address === address })
        if (!entry) return
        if (entry.waylandToplevel) {
            entry.waylandToplevel.minimized = false
            entry.waylandToplevel.activate()
        } else if (/^(0x)?[0-9a-f]+$/i.test(address)) {
            var target = "address:0x" + address.replace(/^0x/, "")
            Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({window = "' + target + '"})' : "focuswindow " + target)
        }
    }

    // Modifier release must never confirm an overview selection.
    function commitSwitcher() { if (active && mode === "switcher") commit() }

    // Retain the last visual snapshot only until the host finishes its close morph.
    function cancel() {
        active = false
        pendingAddress = ""
        mode = "closed"
        if (UiState.activePanel === "windowNavigator") UiState.activePanel = ""
    }

    // Drop capture handles after the owning host completes its visual teardown.
    function finishClose(outputName) {
        if (active || screenName !== outputName) return
        sessionWindows = []
        selectedIndex = -1
        originAddress = ""
        screenName = ""
    }

    // Reopening reverses the host animation through the same logical owner.
    function overviewToggle() {
        if (active && mode === "overview") cancel()
        else open("overview", 0)
    }

    // Expose compact state without leaking window titles into IPC logs.
    function status() {
        return JSON.stringify({supported: supported, active: active, mode: mode, screenName: screenName,
            windowCount: active ? sessionWindows.length : windows.length,
            selectedIndex: active ? selectedIndex : -1, selectedAddress: active ? selectedAddress : "",
            originAddress: active ? originAddress : ""})
    }

    // Panel handoff and output removal terminate a session immediately.
    property Connections panelChanges: Connections {
        target: UiState
        function onActivePanelChanged() {
            if (root.active && UiState.activePanel !== "windowNavigator"
                || root.pendingAddress && UiState.activePanel && UiState.activePanel !== "windowNavigator") root.cancel()
        }
    }
    property Connections outputChanges: Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.screenName && !Quickshell.screens.some(function(screen) { return screen.name === root.screenName })) {
                root.cancel()
                root.finishClose(root.screenName)
            }
        }
    }
    // Refresh IPC metadata on window events; new workspace objects can arrive later.
    function refreshSource() {
        if (!supported) return
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
    }
    property Connections compositorChanges: Connections {
        target: root.supported ? Hyprland : null
        function onRawEvent(event) {
            if (/^(openwindow|closewindow|movewindow|windowtitle|urgent|workspace|createworkspace|destroyworkspace|activespecial)/.test(event.name))
                Qt.callLater(root.refreshSource)
        }
    }
    Component.onCompleted: { refreshSource(); refresh() }
}
