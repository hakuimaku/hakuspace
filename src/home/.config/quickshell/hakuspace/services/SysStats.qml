pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property int cpu: 0
    property int ram: 0
    property int temp: 0
    property bool hasTemp: true

    property int _subscribers: 0

    property real _prevTotal: 0
    property real _prevIdle: 0
    property real _memTotal: 0
    property real _memAvailable: 0

    // Poll only while at least one monitor drawer subscribes.
    function acquire() {
        _subscribers++;
        if (_subscribers === 1) {
            statTimer.start();
            statProc.running = false;
            statProc.running = true;
        }
    }

    function release() {
        if (_subscribers > 0) {
            _subscribers--;
            if (_subscribers === 0) {
                statTimer.stop();
            }
        }
    }

    property var statTimer: Timer {
        interval: 2000
        repeat: true
        onTriggered: {
            statProc.running = false;
            statProc.running = true;
        }
    }

    property var statProc: Process {
        command: ["bash", "-c", "cat /proc/stat /proc/meminfo 2>/dev/null | grep -E '^cpu |MemTotal|MemAvailable'; cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 'NOTEMP'"]
        
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var line = data.trim();
                
                if (line.startsWith("cpu ")) {
                    var parts = line.split(/\s+/);
                    if (parts.length >= 8) {
                        var user = parseInt(parts[1]) || 0;
                        var nice = parseInt(parts[2]) || 0;
                        var system = parseInt(parts[3]) || 0;
                        var idle = parseInt(parts[4]) || 0;
                        var iowait = parseInt(parts[5]) || 0;
                        var irq = parseInt(parts[6]) || 0;
                        var softirq = parseInt(parts[7]) || 0;
                        var steal = parseInt(parts[8]) || 0;
                        
                        var idle_time = idle + iowait;
                        var non_idle_time = user + nice + system + irq + softirq + steal;
                        var total_time = idle_time + non_idle_time;
                        
                        // CPU load uses deltas because /proc/stat counters are cumulative.
                        if (root._prevTotal > 0) {
                            var total_d = total_time - root._prevTotal;
                            var idle_d = idle_time - root._prevIdle;
                            if (total_d > 0) {
                                root.cpu = Math.round(((total_d - idle_d) / total_d) * 100);
                            }
                        }
                        root._prevTotal = total_time;
                        root._prevIdle = idle_time;
                    }
                } else if (line.startsWith("MemTotal:")) {
                    var m = line.match(/\d+/);
                    if (m) root._memTotal = parseInt(m[0]);
                } else if (line.startsWith("MemAvailable:")) {
                    var m = line.match(/\d+/);
                    if (m) {
                        root._memAvailable = parseInt(m[0]);
                        if (root._memTotal > 0) {
                            root.ram = Math.round(((root._memTotal - root._memAvailable) / root._memTotal) * 100);
                        }
                    }
                // Hide temperature when thermal_zone0 is unavailable.
                } else if (line === "NOTEMP") {
                    root.hasTemp = false;
                } else if (/^\d+$/.test(line)) {
                    root.hasTemp = true;
                    root.temp = Math.round(parseInt(line) / 1000);
                }
            }
        }
    }
}
