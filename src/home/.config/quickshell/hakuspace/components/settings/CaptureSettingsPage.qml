import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "SettingsCatalog.js" as Catalog

SettingsCategoryPage {
    id: root
    category: "Capture"
    excludedIds: ["REC_OPTS"]
    trailingContent: Component {
        SettingsSectionCard {
            width: parent.width; title: "Recording options"
            SettingsArgumentsForm { width: parent.width; preference: "REC_OPTS"; shortcutTarget: root.shortcutTarget }
            Text { width: parent.width; text: executableStatus; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2; wrapMode: Text.Wrap }
        }
    }
    property string executableStatus: "Checking recorder executable…"
    // Resolve only a command path; user input is passed as an argument, never evaluated.
    function checkRecorder() {
        if (probe.running) return
        probe.command = ["sh", "-c", 'if command -v "$1" >/dev/null 2>&1; then printf "Found in PATH / executable"; else printf "Recorder executable not found"; fi', "--", Catalog.folderPath(SettingsStore.value("REC_COMMAND"), Quickshell.env("HOME"))]
        probe.running = true
    }
    Component.onCompleted: checkRecorder()
    Connections { target: SettingsStore; function onSavedValuesChanged() { root.checkRecorder() } }
    Process { id: probe; stdout: StdioCollector { id: result } onExited: root.executableStatus = result.text.trim() }
}
