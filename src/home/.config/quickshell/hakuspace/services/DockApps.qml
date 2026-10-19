pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."
import "DockAppModel.js" as Model

QtObject {
    id: root
    // Binding evaluation observes membership, app identity and per-window focus changes.
    readonly property var runningGroups: Model.group(ToplevelManager.toplevels.values, lookup)
    readonly property var renderedApps: Model.merge(TaskbarPins.pins, runningGroups, lookup)
    readonly property var entries: DesktopEntries.applications.values
    // Layer-shell clicks can clear activation before the click handler executes.
    property var focusedWindows: ({})
    onRunningGroupsChanged: {
        var focused = {}
        for (var app of runningGroups)
            focused[app.key] = app.windows.find(function(window) { return window.activated })
                || (app.windows.indexOf(focusedWindows[app.key]) >= 0 ? focusedWindows[app.key] : null)
        focusedWindows = focused
    }

    // Keep resolver policy separate from compositor workspace backends.
    function lookup(id) {
        if (!id) return null
        return Model.resolve(id, entries,
            function(candidate) { return DesktopEntries.byId(candidate) },
            function(candidate) { return DesktopEntries.heuristicLookup(candidate) })
    }
    // A user click supplies the seat context required by Toplevel.activate().
    function activate(app) {
        var window = Model.nextWindow(app.windows, focusedWindows[app.key])
        if (window) {
            focusedWindows[app.key] = window
            window.activate()
        }
        else if (app.entry) app.entry.execute()
        else if (app.command) Quickshell.execDetached(["sh", "-c", app.command])
    }
    // One event-driven icon stream avoids stale Qt theme pixmaps on every output.
    property var iconSources: ({})
    property bool iconSourcesReady: false
    readonly property string iconRequest: JSON.stringify({
        icons: renderedApps.map(function(app) { return app.icon }).concat(["drive-removable-media", "user-trash", "application-x-executable"]),
        size: ShellSettingsStore.dockIconSize
    })
    onIconRequestChanged: if (iconWatcher.running) iconWatcher.write(iconRequest + "\n")
    property Process iconWatcher: Process {
        running: AppState.taskbarManualState
        stdinEnabled: true
        command: ["sh", "-c",
            'for script in "$1" "$2" "$3"; do if [ -f "$script" ]; then exec python3 -u "$script"; fi; done; exit 127',
            "--", (Quickshell.env("HOME") || "") + "/.local/bin/dock_icon_watch.py",
            Env.binDir + "/dock_icon_watch.py", Quickshell.shellPath("../../../../core/backend/user/dock_icon_watch.py")]
        onStarted: write(root.iconRequest + "\n")
        stdout: SplitParser {
            onRead: data => {
                try { root.iconSources = JSON.parse(data); root.iconSourcesReady = true }
                catch (error) { console.warn("Could not update Dock icons") }
            }
        }
    }
    readonly property bool terminationBusy: terminator.running
    property string terminationKey: ""
    signal terminationFinished(string key, var result)

    // Resolve the controller as an argument vector, keeping app IDs out of shell text.
    function terminate(app, confirmedRoots) {
        if (terminationBusy || !app.runningCount) return false
        var ids = app.windows.map(function(window) { return window.appId }).filter(function(id) { return !!id })
        if (!ids.length) return false
        terminationKey = app.key
        terminator.command = ["sh", "-c",
            'for script in "$1" "$2" "$3"; do if [ -f "$script" ]; then shift 3; exec python3 "$script" "$@"; fi; done; exit 127',
            "--", (Quickshell.env("HOME") || "") + "/.local/bin/dock_app_ctl.py",
            Env.binDir + "/dock_app_ctl.py", Quickshell.shellPath("../../../../core/backend/user/dock_app_ctl.py"),
            "terminate", JSON.stringify(ids), JSON.stringify(confirmedRoots)]
        terminator.running = true
        return true
    }
    property Process terminator: Process {
        stdout: StdioCollector { id: terminationOutput }
        stderr: StdioCollector { id: terminationError }
        onExited: (code, status) => {
            var result
            try {
                result = JSON.parse(terminationOutput.text)
                if (["confirmation", "terminated", "error"].indexOf(result.status) < 0)
                    throw new Error("Invalid termination response")
            } catch (error) {
                result = {status: "error", message: terminationError.text.trim() || "Could not close this app."}
            }
            root.terminationFinished(root.terminationKey, result)
        }
    }
}
