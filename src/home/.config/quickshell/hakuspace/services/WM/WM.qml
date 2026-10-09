pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root
    
    // Stub for WM (Hyprland mostly)
    property var workspaces: []
    property int activeWorkspace: 1
    
    // Placeholder function for M1
    function switchWorkspace(id) {
        console.log("Switch to workspace " + id);
    }
}
