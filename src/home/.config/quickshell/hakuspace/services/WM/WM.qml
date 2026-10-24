pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    property var workspaces: []
    property bool supported: backendName !== "none"
    property string backendName: "none"
    property bool labwcSession: false
    property var caps: ({ occupied: false, windowCount: false, urgent: false, perOutput: false, special: false, secondary: false })
    
    // Settings consume session capabilities instead of repeating compositor rules.
    readonly property var uiCaps: ({
        screenshotDirectory: backendName !== "niri",
        nativeScreenshot: backendName === "niri",
        workspaceSettings: supported,
        compositorAnimationSettings: backendName === "niri",
        currentWmConfig: backendName,
        windowNavigator: ["hyprland", "niri", "mango"].includes(backendName),
        dockbar: !ChromeLayout.taskbarMode,
        wallpaperRotation: AppState.wallpaperRotationActive
    })
    readonly property string displayName: ({hyprland: "Hyprland", niri: "Niri", mango: "Mango", none: "Wayland", ext: "Wayland"})[backendName] || "Wayland"

    property string activeWindowClass: ""
    property string activeWindowTitle: ""
    
    // Requests a compositor-native session exit through the active backend.
    // Returns true when a backend accepted the request.
    function quitSession() {
        if (labwcSession) {
            Quickshell.execDetached(["labwc", "--exit"]);
            return true;
        }
        if (backendItem && backendItem.quitSession) {
            backendItem.quitSession();
            return true;
        }
        return false;
    }

    // Delegates workspace activation to the active WM backend.
    function activate(key) {
        if (backendItem && backendItem.activate) {
            backendItem.activate(key);
        }
    }
    
    // Dispatches secondary backend action (special workspace or secondary toggle).
    function secondary(key) {
        if (backendItem && backendItem.secondary && caps.secondary) {
            backendItem.secondary(key);
        }
    }
    
    // Cycles workspace focus forward or backward by step on the specified monitor output.
    function cycle(step, outputName) {
        if (!supported) return;
        var wsList = workspacesFor(outputName);
        if (wsList.length === 0) return;
        
        var currentIdx = -1;
        for (var i = 0; i < wsList.length; i++) {
            if (wsList[i].focused || wsList[i].active) {
                currentIdx = i;
                if (wsList[i].focused) break;
            }
        }
        if (currentIdx === -1) currentIdx = 0;
        
        var nextIdx = currentIdx + step;
        if (nextIdx < 0) nextIdx = 0;
        if (nextIdx >= wsList.length) nextIdx = wsList.length - 1;
        
        activate(wsList[nextIdx].key);
    }
    
    // Filters and returns workspace list for the given monitor output based on WM compositor semantics.
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
            comp = Qt.createComponent("NiriBackend.qml");
        } else if (envMango) {
            backendName = "mango";
            comp = Qt.createComponent("MangoBackend.qml");
        // Disable Labwc workspace loading: ext-workspace crashes Quickshell 0.3.1.
        } else if (envLabwc || envXdg.toLowerCase().indexOf("labwc") !== -1) {
            labwcSession = true;
            backendName = "none";
            comp = Qt.createComponent("NullBackend.qml");
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
