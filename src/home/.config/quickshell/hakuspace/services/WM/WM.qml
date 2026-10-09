pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    // ==========================================
    // Unified Data Model
    // ==========================================
    property var workspaces: []
    property bool supported: backendName !== "none"
    property string backendName: "none"
    property var caps: ({ occupied: false, windowCount: false, urgent: false, perOutput: false, special: false, secondary: false })
    
    // For WindowTitle module
    property string activeWindowClass: ""
    property string activeWindowTitle: ""
    
    function activate(key) {
        if (backendItem && backendItem.activate) {
            backendItem.activate(key);
        }
    }
    
    function secondary(key) {
        if (backendItem && backendItem.secondary && caps.secondary) {
            backendItem.secondary(key);
        }
    }
    
    function cycle(step, outputName) {
        if (!supported) return;
        var wsList = workspacesFor(outputName);
        if (wsList.length === 0) return;
        
        var currentIdx = -1;
        for (var i = 0; i < wsList.length; i++) {
            if (wsList[i].focused || wsList[i].active) {
                currentIdx = i;
                if (wsList[i].focused) break; // Prefer globally focused
            }
        }
        if (currentIdx === -1) currentIdx = 0;
        
        var nextIdx = currentIdx + step;
        if (nextIdx < 0) nextIdx = 0;
        if (nextIdx >= wsList.length) nextIdx = wsList.length - 1;
        
        activate(wsList[nextIdx].key);
    }
    
    function workspacesFor(outputName) {
        if (!supported) return [];
        if (backendName === "hyprland") {
            return workspaces;
        } else if (backendName === "niri") {
            return workspaces.filter(w => w.output === outputName);
        } else if (backendName === "mango") {
            return workspaces.filter(w => w.output === outputName && (w.occupied || w.active));
        } else if (backendName === "ext") {
            return workspaces;
        }
        return workspaces;
    }

    // ==========================================
    // Backend Loading
    // ==========================================
    property Item backendItem: null
    
    Component.onCompleted: {
        var envHypr = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        var envNiri = Quickshell.env("NIRI_SOCKET");
        var envMango = Quickshell.env("MANGO_INSTANCE_SIGNATURE");
        var envLabwc = Quickshell.env("LABWC_PID");
        var envXdg = Quickshell.env("XDG_CURRENT_DESKTOP") || "";
        
        var comp;
        if (envHypr) {
            backendName = "hyprland";
            comp = Qt.createComponent("HyprlandBackend.qml");
        } else if (envNiri) {
            backendName = "niri";
            comp = Qt.createComponent("NiriBackend.qml"); // stub for now
        } else if (envMango) {
            backendName = "mango";
            comp = Qt.createComponent("MangoBackend.qml"); // stub
        } else if (envLabwc || envXdg.toLowerCase().indexOf("labwc") !== -1) {
            backendName = "ext";
            comp = Qt.createComponent("ExtBackend.qml"); // stub
        } else {
            backendName = "none";
            comp = Qt.createComponent("NullBackend.qml");
        }
        
        if (comp && comp.status === Component.Ready) {
            backendItem = comp.createObject(root);
        } else if (comp) {
            comp.statusChanged.connect(function() {
                if (comp.status === Component.Ready) {
                    backendItem = comp.createObject(root);
                }
            });
        }
    }
}
