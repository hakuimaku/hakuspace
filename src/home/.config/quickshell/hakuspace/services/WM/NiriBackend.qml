import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: backend
    
    Component.onCompleted: {
        WM.caps = { occupied: true, windowCount: true, urgent: true, perOutput: true, special: false, secondary: false };
        niriInitProc.running = true;
        niriWinInitProc.running = true;
    }
    
    property var workspacesData: []
    property var windowsData: ({})
    
    function _update() {
        var newWorkspaces = [];
        var newClass = "";
        var newTitle = "";
        
        for (var i = 0; i < workspacesData.length; i++) {
            var w = workspacesData[i];
            
            var count = 0;
            var keys = Object.keys(windowsData);
            for (var j = 0; j < keys.length; j++) {
                if (windowsData[keys[j]].workspace_id === w.id) {
                    count++;
                }
            }
            
            var fTitle = "";
            var fClass = "";
            if (w.active_window_id !== null && windowsData[w.active_window_id]) {
                fTitle = windowsData[w.active_window_id].title || "";
                fClass = windowsData[w.active_window_id].app_id || "";
            }
            
            if (w.is_focused) {
                newTitle = fTitle;
                newClass = fClass;
            }
            
            newWorkspaces.push({
                key: "niri:" + w.id,
                label: w.name ? w.name : w.idx.toString(),
                name: w.name ? w.name : ("Workspace " + w.idx),
                output: w.output,
                active: w.is_active,
                focused: w.is_focused,
                occupied: count > 0,
                windows: count,
                focusedTitle: fTitle,
                urgent: w.is_urgent,
                special: false
            });
        }
        
        if (JSON.stringify(WM.workspaces) !== JSON.stringify(newWorkspaces)) {
            WM.workspaces = newWorkspaces;
        }
        if (WM.activeWindowClass !== newClass) WM.activeWindowClass = newClass;
        if (WM.activeWindowTitle !== newTitle) WM.activeWindowTitle = newTitle;
    }
    
    Process {
        id: niriInitProc
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    var parsed = JSON.parse(data);
                    if (Array.isArray(parsed)) {
                        backend.workspacesData = parsed;
                        backend._update();
                    }
                } catch(e) {}
            }
        }
        onExited: {
            if (!niriStreamProc.running) niriStreamProc.running = true;
        }
    }
    
    Process {
        id: niriWinInitProc
        command: ["niri", "msg", "-j", "windows"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    var parsed = JSON.parse(data);
                    if (Array.isArray(parsed)) {
                        var map = {};
                        for (var i = 0; i < parsed.length; i++) {
                            map[parsed[i].id] = parsed[i];
                        }
                        backend.windowsData = map;
                        backend._update();
                    }
                } catch(e) {}
            }
        }
    }
    
    Process {
        id: niriStreamProc
        running: false
        command: ["niri", "msg", "-j", "event-stream"]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    var event = JSON.parse(data);
                    if (event.WorkspacesChanged) {
                        backend.workspacesData = event.WorkspacesChanged.workspaces;
                        backend._update();
                    }
                    if (event.WindowsChanged) {
                        var wins = event.WindowsChanged.windows;
                        var map = {};
                        for (var i = 0; i < wins.length; i++) {
                            map[wins[i].id] = wins[i];
                        }
                        backend.windowsData = map;
                        backend._update();
                    }
                    if (event.WorkspaceActivated) {
                        var wId = event.WorkspaceActivated.id;
                        for (var i = 0; i < backend.workspacesData.length; i++) {
                            if (backend.workspacesData[i].id === wId) {
                                backend.workspacesData[i].is_focused = event.WorkspaceActivated.focused;
                            }
                        }
                        backend._update();
                    }
                    if (event.WorkspaceActiveWindowChanged) {
                        var wId2 = event.WorkspaceActiveWindowChanged.workspace_id;
                        var aId = event.WorkspaceActiveWindowChanged.active_window_id;
                        for (var j = 0; j < backend.workspacesData.length; j++) {
                            if (backend.workspacesData[j].id === wId2) {
                                backend.workspacesData[j].active_window_id = aId;
                            }
                        }
                        backend._update();
                    }
                    // Ignoring WindowOpenedOrChanged, WindowClosed since WindowsChanged provides full list according to the docs/probe
                    // Wait, WindowsChanged gives full list of windows when there's a change?
                    // Probe shows `WindowsChanged` gives a full array of all windows! Yes!
                    
                } catch(e) {}
            }
        }
        
        onExited: {
            if (WM.backendName === "niri") {
                niriRestartTimer.start();
            }
        }
    }
    
    Timer {
        id: niriRestartTimer
        interval: 1000
        onTriggered: niriStreamProc.running = true
    }
    
    Process {
        id: niriActionProc
    }
    
    function activate(key) {
        var id = parseInt(key.substring(5)); // "niri:3" -> 3
        var ws = null;
        for (var i = 0; i < workspacesData.length; i++) {
            if (workspacesData[i].id === id) {
                ws = workspacesData[i];
                break;
            }
        }
        if (!ws) return;
        
        // As per WORKSPACES_PLAN.md: "VERIFY: the CLI interprets a number as the idx on the currently focused output, not the id."
        // Oh wait! In niri msg action focus-workspace, we can pass the name. But if name is null...
        // Let's use `niri msg action focus-workspace <idx>`? No, idx is per output.
        // niri 26.04 actually supports `niri msg action focus-workspace <name>` but our name is null.
        // Wait, niri has `focus-monitor <output>` and then `focus-workspace <idx>`.
        // I will do: niri msg action focus-monitor <output> && niri msg action focus-workspace <idx>.
        var output = ws.output;
        var idx = ws.idx;
        niriActionProc.command = ["bash", "-c", "niri msg action focus-monitor '" + output + "' && niri msg action focus-workspace " + idx];
        niriActionProc.running = false;
        niriActionProc.running = true;
    }
    
    function secondary(key) {}
}
