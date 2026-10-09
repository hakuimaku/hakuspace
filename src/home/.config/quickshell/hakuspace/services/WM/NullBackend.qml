import QtQuick

Item {
    id: backend
    
    // Present an empty workspace model when no supported backend is active.
    Component.onCompleted: {
        WM.caps = { occupied: false, windowCount: false, urgent: false, perOutput: false, special: false, secondary: false };
        WM.workspaces = [];
    }
    
    function activate(key) {}
    function secondary(key) {}
}

