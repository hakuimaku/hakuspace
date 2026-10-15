import QtQuick

Item {
    id: backend
    
    // Present an empty workspace model when no supported backend is active.
    Component.onCompleted: {
        WM.caps = { occupied: false, windowCount: false, urgent: false, perOutput: false, special: false, secondary: false };
        WM.workspaces = [];
    }
    
    // No-op workspace activation handler when no WM backend is available.
    function activate(key) {}

    // No-op secondary action handler when no WM backend is available.
    function secondary(key) {}
}

