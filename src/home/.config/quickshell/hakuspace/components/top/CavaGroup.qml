import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "../"

TopModule {
    id: root
    
    visible: cavaOutput.length > 0
    property string cavaOutput: ""

    text: cavaOutput
    
    // Fallback if cava is not found or fails
    property bool hasError: false

    Process {
        id: proc
        command: ["cava", "-p", Env.home + "/.config/cava/config_waybar"]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                if (root.hasError) return;
                try {
                    if (!data) return;
                    var bars = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"];
                    var out = "";
                    var parts = data.split(';');
                    for (var i = 0; i < parts.length; i++) {
                        if (parts[i] !== "") {
                            var val = parseInt(parts[i]);
                            if (isNaN(val)) continue;
                            var idx = Math.floor((val / 1000) * 7);
                            if (idx < 0) idx = 0;
                            if (idx > 7) idx = 7;
                            out += bars[idx];
                        }
                    }
                    if (out.length > 0) {
                        root.cavaOutput = out;
                    }
                } catch(e) {
                    console.error("[CavaGroup] Error parsing cava output:", e);
                    root.hasError = true;
                    root.cavaOutput = "";
                }
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
                if (data.trim() !== "") {
                    console.warn("[CavaGroup] Cava stderr:", data);
                }
            }
        }
        
        onExited: exitCode => {
            console.error("[CavaGroup] Cava process exited with code:", exitCode);
            root.hasError = true;
            root.cavaOutput = "";
        }
    }
}
