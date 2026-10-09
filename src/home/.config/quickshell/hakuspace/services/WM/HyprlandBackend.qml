import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../"

Item {
    id: backend
    
    Component.onCompleted: {
        WM.caps = { occupied: true, windowCount: true, urgent: true, perOutput: false, special: true, secondary: true };
        _update();
    }
    
    function _update() {
        var wss = [];
        for (var idx = 0; idx < Hyprland.workspaces.values.length; idx++) wss.push(Hyprland.workspaces.values[idx]);
        // Negative IDs are special workspaces and appear after normal ones.
        wss.sort((a, b) => {
            if (a.id < 0 && b.id > 0) return 1;
            if (a.id > 0 && b.id < 0) return -1;
            return a.id - b.id;
        });
        
        var newWorkspaces = [];
        for (var i = 0; i < wss.length; i++) {
            var ws = wss[i];
            var isSpecial = ws.id < 0;
            var lbl = ws.name;
            if (isSpecial && lbl.startsWith("special:")) {
                lbl = lbl.substring(8);
            }
            
            // IPC metadata fills gaps when the toplevel list is unavailable.
            var winCount = (ws.toplevels && ws.toplevels.values) ? ws.toplevels.values.length : (ws.lastIpcObject && ws.lastIpcObject.windows !== undefined ? ws.lastIpcObject.windows : 0);
            
            var fTitle = "";
            if (ws.lastIpcObject && ws.lastIpcObject.lastwindowtitle) {
                fTitle = ws.lastIpcObject.lastwindowtitle;
            } else if (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0) {
                fTitle = ws.toplevels.values[0].title || "";
            }
            
            var monitorName = "";
            if (ws.monitor) monitorName = ws.monitor.name;
            else if (ws.lastIpcObject && ws.lastIpcObject.monitor) monitorName = ws.lastIpcObject.monitor;
            
            newWorkspaces.push({
                key: "hypr:" + ws.id,
                label: lbl,
                name: ws.name,
                output: monitorName,
                active: ws.active || ws.focused,
                focused: ws.focused,
                occupied: winCount > 0,
                windows: winCount,
                focusedTitle: fTitle,
                urgent: ws.urgent,
                special: isSpecial
            });
        }
        
        if (JSON.stringify(WM.workspaces) !== JSON.stringify(newWorkspaces)) {
            WM.workspaces = newWorkspaces;
        }
        
        var newClass = "";
        var newTitle = "";
        if (Hyprland.activeToplevel) {
            newTitle = Hyprland.activeToplevel.title || "";
            if (Hyprland.activeToplevel.wayland) {
                newClass = Hyprland.activeToplevel.wayland.appId || "";
            }
        }
        if (WM.activeWindowClass !== newClass) WM.activeWindowClass = newClass;
        if (WM.activeWindowTitle !== newTitle) WM.activeWindowTitle = newTitle;
    }
    
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { _update() }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { _update() }
        function onActiveToplevelChanged() { _update() }
        // These events do not reliably update workspace properties directly.
        function onRawEvent(eventName) {
            if (eventName === "openwindow" || eventName === "closewindow" || eventName === "movewindow" || eventName === "urgent") {
                Hyprland.refreshWorkspaces();
            }
        }
    }
    Connections {
        target: Hyprland.activeToplevel || null
        function onTitleChanged() { _update() }
    }
    Connections {
        target: (Hyprland.activeToplevel && Hyprland.activeToplevel.wayland) ? Hyprland.activeToplevel.wayland : null
        function onAppIdChanged() { _update() }
    }
    
    function activate(key) {
        var id = parseInt(key.substring(5));
        var wss = Hyprland.workspaces.values;
        for (var i = 0; i < wss.length; i++) {
            if (wss[i].id === id) {
                wss[i].activate();
                return;
            }
        }
    }
    
    function secondary(key) {
        var id = parseInt(key.substring(5));
        if (id < 0) {
            var wss = Hyprland.workspaces.values;
            for (var i = 0; i < wss.length; i++) {
                if (wss[i].id === id) {
                    var sName = wss[i].name;
                    if (sName.startsWith("special:")) sName = sName.substring(8);
                    Hyprland.dispatch("togglespecialworkspace " + sName);
                    return;
                }
            }
        }
    }
}

