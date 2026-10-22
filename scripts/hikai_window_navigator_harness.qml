import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "services"
import "components"

ShellRoot {
    id: root
    // Exercise the real service and surfaces against disposable native windows.
    property int phase: 0
    property int ticks: 0
    property string a: ""
    property string b: ""
    property string c: ""
    // Repeat rapid taps to cover release before the switcher obtains focus.
    property int rapidTaps: 0
    property string rapidTarget: ""
    property var overlay: hosts.instances.find(function(host) { return host.ownsSession }) || null
    FloatingWindow { id: clientA; title: "Navigator A"; visible: true; color: "#202020"; implicitWidth: 320; implicitHeight: 240 }
    FloatingWindow { id: clientB; title: "Navigator B"; visible: true; color: "#505050"; implicitWidth: 320; implicitHeight: 240 }
    FloatingWindow { id: clientC; title: "Navigator C"; visible: true; color: "#808080"; implicitWidth: 320; implicitHeight: 240 }
    Variants { id: hosts; model: Quickshell.screens; WindowNavigatorOverlay {} }
    Process {
        id: keyboard
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_KEYBOARD")]
        running: true; stdinEnabled: true
        stderr: StdioCollector { id: keyboardError }
        onExited: code => root.check(code === 0, "keyboard: " + keyboardError.text)
    }
    Process {
        id: pointer
        command: ["python3", Quickshell.env("HAKUSPACE_TEST_POINTER")]
        running: true; stdinEnabled: true
        stderr: StdioCollector { id: pointerError }
        onExited: code => root.check(code === 0, "pointer: " + pointerError.text)
    }
    Process {
        id: outputRemoval
        command: ["hyprctl", "output", "remove", "NAV-2"]
        onExited: code => root.check(code === 0, "remove disposable output")
    }
    IpcHandler {
        target: "windowNavigator"
        function next() { WindowNavigator.step(1) }
        function previous() { WindowNavigator.step(-1) }
        function commit() { WindowNavigator.commitSwitcher() }
        function cancel() { WindowNavigator.cancel() }
        function overviewToggle() { WindowNavigator.overviewToggle() }
        function status(): string { return WindowNavigator.status() }
    }
    // Fail with the exact interaction phase instead of silently timing out.
    function check(ok, message) {
        if (ok) return
        console.error("Window Navigator failed at phase " + phase + " (rapid taps=" + rapidTaps + "): " + message + " " + WindowNavigator.status())
        console.error("Protocol state: " + JSON.stringify(Hyprland.toplevels.values.map(function(window) {
            return {address: window.address, workspace: window.workspace ? window.workspace.id : null, wayland: !!window.wayland, active: window.activated}
        })) + "; workspaces=" + Hyprland.workspaces.values.length)
        Qt.exit(1)
        throw new Error(message)
    }
    // Wait for compositor confirmation between focus requests.
    function focus(address) { Hyprland.dispatch('hl.dsp.focus({window = "address:0x' + address.replace(/^0x/, "") + '"})') }
    function key(code, modifiers) { keyboard.write("key " + code + " " + (modifiers || 0) + "\n") }
    // Locate composed previews and cards without exposing test-only production APIs.
    function find(item, predicate) {
        if (predicate(item)) return item
        var children = item.contentItem ? item.contentItem.data : item.children || []
        for (var child of children) {
            var found = find(child, predicate)
            if (found) return found
        }
        return null
    }
    // Catch accidental compositor activation while the user is only highlighting.
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (WindowNavigator.active && WindowNavigator.mode === "switcher" && Hyprland.activeToplevel)
                root.check(Hyprland.activeToplevel.address === WindowNavigator.originAddress, "cycle changed real focus")
        }
    }
    Timer {
        interval: 220; running: true; repeat: true
        onTriggered: {
            root.check(++root.ticks < 45, "runtime timeout")
            var nav = WindowNavigator
            var focused = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
            switch (root.phase) {
            case 0:
                if (nav.windows.length !== 3) return
                root.a = nav.windows.find(function(window) { return window.title === "Navigator A" }).address
                root.b = nav.windows.find(function(window) { return window.title === "Navigator B" }).address
                root.c = nav.windows.find(function(window) { return window.title === "Navigator C" }).address
                root.focus(root.a); break
            case 1: if (focused !== root.a) return; root.focus(root.b); break
            case 2: if (focused !== root.b) return; root.focus(root.c); break
            case 3: if (focused !== root.c) return; root.key(15, 8); break
            case 4:
                if (!nav.active) return
                root.check(nav.selectedAddress === root.b && !!root.overlay, "first MRU target and output ownership")
                root.check(hosts.instances.filter(function(host) { return host.ownsSession }).length === 1, "duplicate output owner")
                root.key(15, 8); break
            case 5: root.check(nav.selectedAddress === root.a, "stable cycle"); root.key(1); break
            case 6: root.check(!nav.active, "Escape cancels"); break
            case 7: root.check(focused === root.c, "cancel retains origin"); root.key(15, 9); break
            case 8: root.check(nav.selectedAddress === root.a, "reverse MRU"); root.key(56); break
            case 9: if (focused !== root.a) return; root.check(!nav.active, "Alt release commits"); nav.step(1); break
            case 10: root.check(nav.selectedAddress === root.c, "confirmed focus updates MRU"); clientC.visible = false; break
            case 11: if (nav.windows.length !== 2) return; root.check(!nav.active || nav.selectedAddress !== root.c, "closed target removed"); nav.cancel(); break
            case 12: clientC.visible = true; break
            case 13: if (nav.windows.length !== 3) return; nav.open("overview", 0); break
            case 14:
                root.check(nav.active && nav.mode === "overview" && nav.sessionWindows.length === 3, "overview membership")
                nav.commitSwitcher(); root.check(nav.active, "Alt fallback ignores overview")
                root.key(107); break
            case 15: root.check(nav.selectedIndex === 2, "End selection"); root.key(102); break
            case 16: root.check(nav.selectedIndex === 0, "Home selection"); root.key(15); break
            case 17: root.check(nav.selectedIndex === 1, "Tab selection"); root.key(15, 1); break
            case 18:
                root.check(nav.selectedIndex === 0, "Shift-Tab selection")
                // Still frames arrive asynchronously; the phase timeout bounds this wait.
                if (!root.find(root.overlay, function(item) { return item.hasContent === true && item.live === false })) return
                clientB.visible = false; break
            case 19: if (nav.sessionWindows.length !== 2) return; clientB.visible = true; break
            case 20: if (nav.sessionWindows.length !== 3) return; nav.overviewToggle(); nav.overviewToggle(); break
            case 21:
                root.check(nav.active && root.overlay.reveal > 0, "reopen reverses close")
                UiState.activePanel = "settings"; break
            case 22: root.check(!nav.active, "panel handoff cancels"); nav.open("overview", 0); LockState.locked = true; break
            case 23: root.check(!nav.active, "lock cancels"); LockState.locked = false; nav.open("overview", 0); ShellTransitionState.chromeEnabled = false; break
            case 24: root.check(!nav.active, "chrome teardown cancels"); ShellTransitionState.chromeEnabled = true; break
            case 25:
                // Focus a target on another workspace, then confirm it through Enter.
                Hyprland.dispatch('hl.dsp.window.move({window = "title:^Navigator B$", workspace = 2, follow = false})')
                break
            case 26:
                if (!nav.windows.some(function(window) { return window.title === "Navigator B" && window.workspaceId === 2 })) return
                nav.open("overview", 0)
                nav.select(nav.sessionWindows.findIndex(function(window) { return window.title === "Navigator B" }))
                break
            case 27:
                root.key(28); break
            case 28:
                if (!Hyprland.activeToplevel || Hyprland.activeToplevel.title !== "Navigator B") return
                root.check(!nav.active, "cross-workspace Enter commits")
                Hyprland.dispatch('hl.dsp.focus({monitor = "WAYLAND-1"})'); break
            case 29:
                if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== "WAYLAND-1") return
                nav.open("overview", 0); break
            case 30:
                // A real pointer click selects the card and closes modal input.
                var card = root.find(root.overlay, function(item) { return item.windowEntry && item.windowEntry.title === "Navigator A" && typeof item.chosen === "function" })
                root.check(!!card, "pointer card exists")
                var point = card.mapToItem(null, card.width / 2, card.height / 2)
                pointer.write([Math.round(point.x), Math.round(point.y), root.overlay.width, root.overlay.height, 272].join(" ") + "\n")
                break
            case 31:
                if (focused !== root.a) return
                root.check(!nav.active, "pointer activates selected window")
                nav.open("overview", 0); break
            case 32: nav.cancel(); break
            case 33:
                if (nav.sessionWindows.length) return
                root.check(hosts.instances.every(function(host) { return !host.visible }), "close releases surfaces and previews")
                Hyprland.dispatch('hl.dsp.focus({monitor = "NAV-2"})'); break
            case 34:
                if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== "NAV-2") return
                nav.open("overview", 0); break
            case 35:
                root.check(nav.screenName === "NAV-2", "focused output owns overview")
                outputRemoval.running = true; break
            case 36:
                if (Quickshell.screens.some(function(screen) { return screen.name === "NAV-2" })) return
                root.check(!nav.active && nav.sessionWindows.length === 0, "output removal cancels and releases snapshot")
                Hyprland.dispatch('hl.dsp.window.move({window = "title:^Navigator A$", workspace = "special:nav-test", follow = false})')
                break
            case 37:
                if (!nav.windows.some(function(window) { return window.title === "Navigator A" && window.special })) return
                nav.open("overview", 0)
                nav.select(nav.sessionWindows.findIndex(function(window) { return window.title === "Navigator A" }))
                break
            case 38: root.key(28); break
            case 39:
                if (focused !== root.a) return
                root.check(!nav.active, "special workspace activation")
                clientB.visible = false; clientC.visible = false; break
            case 40:
                if (nav.windows.length !== 1) return
                nav.step(1); root.check(!nav.active, "one window skips switcher")
                nav.open("overview", 0); break
            case 41: clientA.visible = false; break
            case 42:
                if (nav.windows.length) return
                root.check(!nav.active, "last window close cancels overview")
                clientA.visible = true; clientB.visible = true; break
            case 43:
                if (nav.windows.length !== 2) return
                root.focus(nav.windows.find(function(window) { return window.title === "Navigator A" }).address)
                break
            case 44:
                if (!focused || nav.active || nav.pendingAddress) return
                root.rapidTarget = nav.mruAddresses[1]
                keyboard.write("alt-tab " + (root.rapidTaps % 2 ? 100 : 56) + " "
                    + (root.rapidTaps % 2) + " " + (Math.floor(root.rapidTaps / 2) % 2) + "\n")
                break
            case 45:
                if (nav.active || nav.pendingAddress || focused !== root.rapidTarget) return
                if (++root.rapidTaps < 8) { root.phase = 43; break }
                console.log("PASS: Hikai Window Navigator runtime, keyboard, pointer, previews and lifecycle")
                Qt.quit(); break
            }
            root.phase++
            root.ticks = 0
        }
    }
}
