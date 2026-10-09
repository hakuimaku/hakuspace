import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: backend

    Component.onCompleted: {
        WM.caps = { occupied: true, windowCount: true, urgent: true, perOutput: true, special: false, secondary: false };
        niriStreamProc.running = true;
    }

    property var workspacesData: []
    property var windowsData: ({})

    // Merge workspace snapshots with window events into the shared WM model.
    function _update() {
        var newWorkspaces = [];
        var newClass = "";
        var newTitle = "";

        var sortedData = workspacesData.slice();
        sortedData.sort(function(a, b) {
            if (!a && !b) return 0;
            if (!a) return 1;
            if (!b) return -1;
            var aOut = a.output || "";
            var bOut = b.output || "";
            if (aOut < bOut) return -1;
            if (aOut > bOut) return 1;

            var aIdx = (a.idx !== undefined && a.idx !== null) ? a.idx : 99999;
            var bIdx = (b.idx !== undefined && b.idx !== null) ? b.idx : 99999;
            return aIdx - bIdx;
        });

        var seenIds = {};

        for (var i = 0; i < sortedData.length; i++) {
            var w = sortedData[i];
            if (!w || w.id === undefined || w.id === null) continue;
            if (w.idx === undefined || w.idx === null) continue;

            if (seenIds[w.id]) continue;
            seenIds[w.id] = true;

            var count = 0;
            var keys = Object.keys(windowsData);
            for (var j = 0; j < keys.length; j++) {
                var windowObj = windowsData[keys[j]];
                if (windowObj && windowObj.workspace_id === w.id) {
                    count++;
                }
            }

            var fTitle = "";
            var fClass = "";
            if (w.active_window_id !== undefined && w.active_window_id !== null) {
                var win = windowsData[w.active_window_id];
                if (win) {
                    fTitle = win.title || "";
                    fClass = win.app_id || "";
                }
            }

            if (w.is_focused) {
                newTitle = fTitle;
                newClass = fClass;
            }

            var safeIdx = (w.idx !== undefined && w.idx !== null) ? w.idx : 0;
            var safeName = w.name || "";

            newWorkspaces.push({
                key: "niri:" + w.id,
                label: safeName ? safeName : safeIdx.toString(),
                name: safeName ? safeName : ("Workspace " + safeIdx),
                output: w.output || "",
                active: !!w.is_active,
                focused: !!w.is_focused,
                occupied: count > 0,
                windows: count,
                focusedTitle: fTitle,
                urgent: !!w.is_urgent,
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
                    // Activation affects one output; focus may move across outputs.
                    if (event.WorkspaceActivated) {
                        var targetId = event.WorkspaceActivated.id;
                        var isFocused = event.WorkspaceActivated.focused;
                        var targetOutput = null;

                        for (var i = 0; i < backend.workspacesData.length; i++) {
                            if (backend.workspacesData[i].id === targetId) {
                                targetOutput = backend.workspacesData[i].output;
                                break;
                            }
                        }

                        if (targetOutput !== null) {
                            for (var i = 0; i < backend.workspacesData.length; i++) {
                                var ws = backend.workspacesData[i];

                                if (ws.output === targetOutput) {
                                    ws.is_active = (ws.id === targetId);
                                }

                                if (isFocused) {
                                    ws.is_focused = (ws.id === targetId);
                                } else if (ws.id === targetId) {
                                    ws.is_focused = false;
                                }
                            }
                        }
                        backend._update();
                    }
                    if (event.WorkspaceUrgencyChanged) {
                        var uWId = event.WorkspaceUrgencyChanged.id;
                        var isUrgentWS = event.WorkspaceUrgencyChanged.urgent;
                        var found = false;
                        for (var k = 0; k < backend.workspacesData.length; k++) {
                            if (backend.workspacesData[k].id === uWId) {
                                backend.workspacesData[k].is_urgent = isUrgentWS;
                                found = true;
                                break;
                            }
                        }
                        if (found) backend._update();
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
                    // Reassign after mutation so QML bindings see the updated map.
                    if (event.WindowOpenedOrChanged) {
                        var win = event.WindowOpenedOrChanged.window;
                        var wmap1 = backend.windowsData;
                        wmap1[win.id] = win;
                        backend.windowsData = wmap1;
                        backend._update();
                    }
                    if (event.WindowClosed) {
                        var cId = event.WindowClosed.id;
                        var wmap2 = backend.windowsData;
                        delete wmap2[cId];
                        backend.windowsData = wmap2;
                        backend._update();
                    }
                    if (event.WindowFocusChanged) {
                        var fId = event.WindowFocusChanged.id;
                        var wmap3 = backend.windowsData;
                        for (var key in wmap3) {
                            wmap3[key].is_focused = false;
                        }
                        if (fId !== null && wmap3[fId]) {
                            wmap3[fId].is_focused = true;
                        }
                        backend.windowsData = wmap3;
                        backend._update();
                    }
                    if (event.WindowUrgencyChanged) {
                        var uId = event.WindowUrgencyChanged.id;
                        var wmap4 = backend.windowsData;
                        if (wmap4[uId]) {
                            wmap4[uId].is_urgent = event.WindowUrgencyChanged.urgent;
                            backend.windowsData = wmap4;
                            backend._update();
                        }
                    }

                } catch(e) {}
            }
        }

        // Clear stale state and reconnect if the event stream stops.
        onExited: {
            if (WM.backendName !== "niri") return;
            backend.workspacesData = [];
            backend.windowsData = ({});
            backend._update();
            niriRestartTimer.start();
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
        var id = parseInt(key.substring(5));
        var ws = null;
        for (var i = 0; i < workspacesData.length; i++) {
            if (workspacesData[i].id === id) {
                ws = workspacesData[i];
                break;
            }
        }
        if (!ws) return;

        var output = ws.output;
        var idx = ws.idx;
        // Focus the monitor first because workspace indices are output-local.
        niriActionProc.command = ["bash", "-c", "niri msg action focus-monitor '" + output + "' && niri msg action focus-workspace " + idx];
        niriActionProc.running = false;
        niriActionProc.running = true;
    }

    function secondary(key) {}
}
