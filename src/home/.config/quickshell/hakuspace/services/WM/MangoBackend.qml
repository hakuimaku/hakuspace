import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: backend
    
    Component.onCompleted: {
        WM.caps = { occupied: true, windowCount: true, urgent: true, perOutput: true, special: false, secondary: true };
        mangoInitProc.running = true;
    }
    
    property var tagsData: []
    
    function _update() {
        var newWorkspaces = [];
        
        for (var m = 0; m < tagsData.length; m++) {
            var monitorData = tagsData[m];
            var monitorName = monitorData.monitor;
            var tags = monitorData.tags || [];
            
            for (var i = 0; i < tags.length; i++) {
                var t = tags[i];
                newWorkspaces.push({
                    key: "mango:" + monitorName + ":" + t.index,
                    label: t.index.toString(),
                    name: "Tag " + t.index,
                    output: monitorName,
                    active: t.is_active,
                    focused: t.is_active, // Mango doesn't have a separate globally focused tag? We'll assume active is focused
                    occupied: t.client_count > 0,
                    windows: t.client_count,
                    focusedTitle: "",
                    urgent: t.is_urgent,
                    special: false
                });
            }
        }
        
        if (JSON.stringify(WM.workspaces) !== JSON.stringify(newWorkspaces)) {
            WM.workspaces = newWorkspaces;
        }
    }
    
    Process {
        id: mangoInitProc
        command: ["mmsg", "get", "all-tags"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    var parsed = JSON.parse(data);
                    if (parsed.all_tags) {
                        backend.tagsData = parsed.all_tags;
                        backend._update();
                    }
                } catch(e) {}
            }
        }
        onExited: {
            if (!mangoStreamProc.running) mangoStreamProc.running = true;
        }
    }
    
    Process {
        id: mangoStreamProc
        running: false
        command: ["mmsg", "watch", "all-tags"]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    var parsed = JSON.parse(data);
                    if (parsed.all_tags) {
                        backend.tagsData = parsed.all_tags;
                        backend._update();
                    }
                } catch(e) {}
            }
        }
        
        onExited: {
            if (WM.backendName === "mango") {
                mangoRestartTimer.start();
            }
        }
    }
    
    Timer {
        id: mangoRestartTimer
        interval: 1000
        onTriggered: mangoStreamProc.running = true
    }
    
    Process {
        id: mangoActionProc
    }
    
    function activate(key) {
        var parts = key.split(":"); // "mango:eDP-1:3"
        if (parts.length < 3) return;
        var idx = parts[2];
        // Mango dispatch uses view,<n>,0
        mangoActionProc.command = ["mmsg", "dispatch", "view," + idx + ",0"];
        mangoActionProc.running = false;
        mangoActionProc.running = true;
    }
    
    function secondary(key) {
        var parts = key.split(":");
        if (parts.length < 3) return;
        var idx = parts[2];
        mangoActionProc.command = ["mmsg", "dispatch", "toggleview," + idx + ",0"];
        mangoActionProc.running = false;
        mangoActionProc.running = true;
    }
}
