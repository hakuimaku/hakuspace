import QtQuick
import Quickshell
import Quickshell.WindowManager
import "../"

Item {
    id: backend
    
    Component.onCompleted: {
        WM.caps = { occupied: false, windowCount: false, urgent: true, perOutput: false, special: false, secondary: false };
        _update();
    }
    
    // Normalize ext-workspace data; its API does not expose a window count.
    function _update() {
        var wss = [];
        try {
            if (WindowManager && WindowManager.windowsets) {
                for (var j = 0; j < WindowManager.windowsets.values.length; j++) {
                    wss.push(WindowManager.windowsets.values[j]);
                }
            }
        } catch(e) {}
        
        wss.sort((a, b) => {
            if (a.coordinates !== undefined && b.coordinates !== undefined) {
                if (a.coordinates[0] !== b.coordinates[0]) return a.coordinates[0] - b.coordinates[0];
                if (a.coordinates.length > 1 && b.coordinates.length > 1) {
                    return a.coordinates[1] - b.coordinates[1];
                }
            }
            return 0;
        });
        
        var newWorkspaces = [];
        for (var i = 0; i < wss.length; i++) {
            var ws = wss[i];
            if (!ws.shouldDisplay) continue;
            
            newWorkspaces.push({
                key: "ext:" + ws.id,
                label: ws.name,
                name: ws.name,
                output: ws.projection ? ws.projection.name : "",
                active: ws.active,
                focused: ws.active,
                occupied: true,
                windows: -1,
                focusedTitle: "",
                urgent: ws.urgent,
                special: false
            });
        }
        
        // Avoid replacing the model when the snapshot is unchanged.
        if (JSON.stringify(WM.workspaces) !== JSON.stringify(newWorkspaces)) {
            WM.workspaces = newWorkspaces;
        }
    }
    
    Connections {
        target: WindowManager ? WindowManager.windowsets : null
        function onValuesChanged() { _update() }
    }
    
    function activate(key) {
        var id = key.substring(4);
        if (WindowManager && WindowManager.windowsets) {
            for (var i = 0; i < WindowManager.windowsets.values.length; i++) {
                var ws = WindowManager.windowsets.values[i];
                if (ws.id === id) {
                    if (ws.canActivate) ws.activate();
                    return;
                }
            }
        }
    }
    
    function secondary(key) {}
}
