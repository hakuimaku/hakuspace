pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Public properties (Basic)
    property int cpu: 0
    property int ram: 0
    property int temp: 0
    property bool hasTemp: true

    // Public properties (Extended)
    property int rootFsUsed: 0
    property bool hasRootFs: false

    property var mounts: []
    property bool hasMounts: false

    property int gpu: 0
    property bool hasGpu: false
    property int gpuMemoryPercent: 0
    property alias gpuMemory: root.gpuMemoryPercent
    property bool hasGpuMemory: false
    property string gpuBackend: "unsupported"

    // Subscription tracking
    property int _basicSubscribers: 0
    property int _extendedSubscribers: 0
    readonly property int totalSubscribers: _basicSubscribers + _extendedSubscribers

    // Internal calculation state
    property real _prevTotal: 0
    property real _prevIdle: 0
    property real _currentTotal: 0
    property real _memTotal: 0

    readonly property string snapshotScript: Env.binDir + "/sysstats_snapshot.sh"

    function acquire() {
        _basicSubscribers++;
        _syncState(false);
    }

    function release() {
        if (_basicSubscribers > 0) {
            _basicSubscribers--;
            _syncState(false);
        }
    }

    function acquireExtended() {
        _extendedSubscribers++;
        _syncState(true);
    }

    function releaseExtended() {
        if (_extendedSubscribers > 0) {
            _extendedSubscribers--;
            _syncState(false);
        }
    }

    function _syncState(immediateFetch) {
        if (totalSubscribers > 0) {
            if (!statTimer.running) {
                statTimer.start();
                _triggerPoll();
            } else if (immediateFetch) {
                _triggerPoll();
            }
        } else {
            statTimer.stop();
            root._prevTotal = 0;
            root._prevIdle = 0;
            root._currentTotal = 0;
            root.mounts = [];
            root.hasMounts = false;
            root.hasGpuMemory = false;
        }
    }

    function _triggerPoll() {
        statProc.command = _extendedSubscribers > 0
            ? [snapshotScript, "--extended"]
            : [snapshotScript];
        statProc.running = false;
        statProc.running = true;
    }

    property var statTimer: Timer {
        interval: 2000
        repeat: true
        onTriggered: root._triggerPoll()
    }

    property var statProc: Process {
        command: [root.snapshotScript]

        stdout: SplitParser {
            onRead: data => {
                if (!data || root.totalSubscribers === 0) return;
                var line = data.trim();
                var eqIdx = line.indexOf("=");
                if (eqIdx === -1) return;
                var key = line.substring(0, eqIdx);
                var val = line.substring(eqIdx + 1).trim();

                switch (key) {
                    case "CPU_TOTAL":
                        var total_time = parseInt(val) || 0;
                        root._currentTotal = total_time;
                        break;
                    case "CPU_IDLE":
                        var idle_time = parseInt(val) || 0;
                        if (root._prevTotal > 0 && root._currentTotal > 0) {
                            var total_d = root._currentTotal - root._prevTotal;
                            var idle_d = idle_time - root._prevIdle;
                            if (total_d > 0) {
                                root.cpu = Math.max(0, Math.min(100, Math.round(((total_d - idle_d) / total_d) * 100)));
                            }
                        }
                        if (root._currentTotal > 0) {
                            root._prevTotal = root._currentTotal;
                            root._prevIdle = idle_time;
                        }
                        break;
                    case "MEM_TOTAL_KB":
                        root._memTotal = parseInt(val) || 0;
                        break;
                    case "MEM_AVAILABLE_KB":
                        var memAvail = parseInt(val) || 0;
                        if (root._memTotal > 0) {
                            root.ram = Math.max(0, Math.min(100, Math.round(((root._memTotal - memAvail) / root._memTotal) * 100)));
                        }
                        break;
                    case "TEMP_MILLIC":
                        if (val === "NA" || val === "") {
                            root.hasTemp = false;
                        } else {
                            var t = parseInt(val);
                            if (!isNaN(t)) {
                                root.hasTemp = true;
                                root.temp = Math.round(t / 1000);
                            } else {
                                root.hasTemp = false;
                            }
                        }
                        break;
                    case "ROOT_USED_PERCENT":
                        if (val === "NA" || val === "") {
                            root.hasRootFs = false;
                        } else {
                            var rf = parseInt(val);
                            if (!isNaN(rf) && rf >= 0 && rf <= 100) {
                                root.hasRootFs = true;
                                root.rootFsUsed = rf;
                            } else {
                                root.hasRootFs = false;
                            }
                        }
                        break;
                    case "MOUNTS_JSON":
                        try {
                            var parsedMounts = JSON.parse(val);
                            if (Array.isArray(parsedMounts) && parsedMounts.length > 0) {
                                root.mounts = parsedMounts;
                                root.hasMounts = true;
                                if (!root.hasRootFs && parsedMounts[0].target === "/" && typeof parsedMounts[0].percent === "number") {
                                    root.hasRootFs = true;
                                    root.rootFsUsed = parsedMounts[0].percent;
                                }
                            } else {
                                root.mounts = [];
                                root.hasMounts = false;
                            }
                        } catch (e) {
                            root.mounts = [];
                            root.hasMounts = false;
                        }
                        break;
                    case "GPU_PERCENT":
                        if (val === "NA" || val === "") {
                            root.hasGpu = false;
                        } else {
                            var g = parseInt(val);
                            if (!isNaN(g) && g >= 0 && g <= 100) {
                                root.hasGpu = true;
                                root.gpu = g;
                            } else {
                                root.hasGpu = false;
                            }
                        }
                        break;
                    case "GPU_MEM_PERCENT":
                        if (val === "NA" || val === "") {
                            root.hasGpuMemory = false;
                        } else {
                            var gm = parseInt(val);
                            if (!isNaN(gm) && gm >= 0 && gm <= 100) {
                                root.hasGpuMemory = true;
                                root.gpuMemoryPercent = gm;
                            } else {
                                root.hasGpuMemory = false;
                            }
                        }
                        break;
                    case "GPU_BACKEND":
                        root.gpuBackend = val;
                        break;
                }
            }
        }
    }
}
