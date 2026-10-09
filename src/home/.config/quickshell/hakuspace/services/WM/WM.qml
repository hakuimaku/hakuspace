pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../"

Item {
    id: root

    // ==========================================
    // Unified Interface
    // ==========================================
    property var ids: []
    property int activeId: -1
    property var occupied: []
    property var urgent: []
    property bool supported: true
    
    function activate(id) {
        if (!supported) return;
        
        if (Env.wmName === "hyprland") {
            Hyprland.dispatch("workspace " + id);
        } else if (Env.wmName === "niri") {
            niriSwitchProc.command = ["niri", "msg", "action", "focus-workspace", id.toString()];
            niriSwitchProc.running = false;
            niriSwitchProc.running = true;
        }
    }

    // ==========================================
    // Implementation
    // ==========================================
    
    property string _wm: Env.wmName ? Env.wmName.toLowerCase() : ""
    
    Component.onCompleted: {
        if (_wm === "hyprland") {
            // Setup bindings for Hyprland dynamically
        } else if (_wm === "niri") {
            niriInitProc.running = true;
        } else {
            supported = false;
        }
    }
    
    // --- Hyprland Logic ---
    function _updateHyprland() {
        if (_wm !== "hyprland") return;
        
        var wss = Hyprland.workspaces.values.filter(w => w.id > 0);
        wss.sort((a, b) => a.id - b.id);
        
        var newIds = wss.map(w => w.id);
        var newOccupied = wss.filter(w => w.windows > 0).map(w => w.id);
        var newActiveId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        var newUrgent = []; // Hyprland doesn't expose urgent easily, fallback empty
        
        if (JSON.stringify(ids) !== JSON.stringify(newIds)) ids = newIds;
        if (JSON.stringify(occupied) !== JSON.stringify(newOccupied)) occupied = newOccupied;
        if (activeId !== newActiveId) activeId = newActiveId;
        if (JSON.stringify(urgent) !== JSON.stringify(newUrgent)) urgent = newUrgent;
    }
    
    Connections {
        target: _wm === "hyprland" ? Hyprland.workspaces : null
        function onValuesChanged() { root._updateHyprland() }
    }
    Connections {
        target: _wm === "hyprland" ? Hyprland : null
        function onFocusedWorkspaceChanged() { root._updateHyprland() }
    }
    
    // --- Niri Logic ---
    // Command to switch workspace
    Process {
        id: niriSwitchProc
    }
    
    // Niri initial fetch
    Process {
        id: niriInitProc
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    var wss = JSON.parse(data);
                    var newIds = [];
                    var newOccupied = [];
                    var newActiveId = -1;
                    
                    for (var i = 0; i < wss.length; i++) {
                        var w = wss[i];
                        newIds.push(w.idx);
                        // In niri, a workspace might have no windows. Is it 'is_active'? 
                        // Actually 'is_active' usually means focused on a monitor.
                        // Let's assume occupied means exists in the array (niri only lists active/occupied workspaces?)
                        // If niri lists all, maybe we just mark all as occupied if they exist?
                        newOccupied.push(w.idx); 
                        if (w.is_focused) newActiveId = w.idx;
                    }
                    newIds.sort((a,b) => a-b);
                    
                    if (JSON.stringify(root.ids) !== JSON.stringify(newIds)) root.ids = newIds;
                    if (JSON.stringify(root.occupied) !== JSON.stringify(newOccupied)) root.occupied = newOccupied;
                    if (root.activeId !== newActiveId) root.activeId = newActiveId;
                } catch(e) {}
            }
        }
        onExited: {
            niriStreamProc.running = true;
        }
    }
    
    // Niri event stream
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
                        var wss = event.WorkspacesChanged.workspaces;
                        var newIds = [];
                        var newOccupied = [];
                        var newActiveId = -1;
                        
                        for (var i = 0; i < wss.length; i++) {
                            var w = wss[i];
                            newIds.push(w.idx);
                            newOccupied.push(w.idx);
                            if (w.is_focused) newActiveId = w.idx;
                        }
                        newIds.sort((a,b) => a-b);
                        
                        if (JSON.stringify(root.ids) !== JSON.stringify(newIds)) root.ids = newIds;
                        if (JSON.stringify(root.occupied) !== JSON.stringify(newOccupied)) root.occupied = newOccupied;
                        if (newActiveId !== -1 && root.activeId !== newActiveId) root.activeId = newActiveId;
                    }
                    else if (event.WorkspaceActivated) {
                        root.activeId = event.WorkspaceActivated.idx;
                    }
                } catch(e) {}
            }
        }
        
        onExited: {
            if (_wm === "niri") {
                niriRestartTimer.start();
            }
        }
    }
    
    Timer {
        id: niriRestartTimer
        interval: 1000
        onTriggered: niriStreamProc.running = true
    }
}
