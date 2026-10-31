import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "components"

ShellRoot {
    id: root
    // Cover bare frames, real reservations and the fixed Settings drawing plane.
    readonly property var cases: [[0, 0], [0, 6], [24, 0], [24, 6], [20, 4]]
    readonly property var modes: ["plain", "topbar", "taskbar", "settingsTopbar", "settingsTaskbar"]
    property var outputs: []
    property int index: 0
    property int phase: 0
    property int ticks: 0
    property bool hasBar: false
    property bool bottom: false
    Process { id: capture; onExited: code => { if (code !== 0) { console.error("Hikai frame failed: screenshot"); Qt.exit(1) } } }
    Variants {
        model: Quickshell.screens
        Item {
            id: output
            required property var modelData
            PanelWindow {
                screen: output.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                color: "#4a7188"
            }
            PanelWindow {
                id: bar
                screen: output.modelData
                anchors { top: !root.bottom; bottom: root.bottom; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Top
                visible: root.hasBar
                implicitHeight: root.bottom ? ScreenGeometry.taskbarHeight : Theme.topBarHeight
                exclusiveZone: implicitHeight
                color: Theme.surface
                mask: Region {}
            }
            RoundedScreen { modelData: output.modelData }
            readonly property real barHeight: bar.height
            Component.onCompleted: root.outputs = root.outputs.concat([this])
        }
    }
    Timer {
        interval: 180; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 160) { console.error("Hikai frame failed: timeout"); Qt.exit(1); return }
            if (!root.outputs.length || !ShellSettingsStore.ready || ShellSettingsStore.loading || capture.running) return
            if (root.index === root.cases.length * root.modes.length) {
                console.info("Hikai frame checks passed")
                Qt.quit()
                return
            }
            var mode = root.modes[Math.floor(root.index / root.cases.length)]
            var caseIndex = root.index % root.cases.length
            if (root.phase === 0) {
                root.hasBar = mode !== "plain"
                root.bottom = mode === "taskbar" || mode === "settingsTaskbar"
                AppState.taskbarManualState = root.bottom
                UiState.activePanel = mode.startsWith("settings") ? "settings" : ""
                ShellSettingsStore.setValue("roundedScreen", "radius", root.cases[caseIndex][0])
                ShellSettingsStore.setValue("roundedScreen", "borderThickness", root.cases[caseIndex][1])
                root.phase = 1
            } else {
                var output = root.outputs[0]
                // The frame retains its status lane even without a mapped fixture bar.
                var top = root.bottom ? 0 : Math.round(Theme.topBarHeight)
                var bottom = output.modelData.height - (root.bottom ? output.barHeight : 0)
                capture.command = ["grim", "-t", "ppm", "-o", output.modelData.name,
                    Quickshell.env("HAKUSPACE_GEOMETRY_ARTIFACT_DIR") + "/frame-" + caseIndex + "-" + mode
                    + "-top-" + top + "-bottom-" + bottom + "-width-" + output.modelData.width + ".ppm"]
                capture.running = true
                root.index++
                root.phase = 0
            }
        }
    }
}
