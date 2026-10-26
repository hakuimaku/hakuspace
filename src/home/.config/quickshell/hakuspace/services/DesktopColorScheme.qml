import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Only the main shell owns desktop preference changes, including covered cutovers.
    readonly property string scheme: ShellTransitionState.chromeEnabled && ShellSettingsStore.colorMode === "light"
                                     ? "prefer-light" : "prefer-dark"
    readonly property string kittyPalette: JSON.stringify([scheme === "prefer-light" ? "light" : "dark",
                                                         String(Theme.surface), String(Theme.accent)])

    // Serialize writes and let the latest preview win after an in-flight request.
    function sync() {
        if (!ShellSettingsStore.ready || !writer || writer.running) return
        writer.requestedScheme = scheme
        writer.command = ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme]
        writer.running = true
    }
    onSchemeChanged: sync()
    Component.onCompleted: { sync(); syncKitty() }
    onKittyPaletteChanged: syncKitty()

    // Keep live surface and accent previews serialized across mode reversals.
    function syncKitty() {
        if (!ShellSettingsStore.ready || !kittyWriter || kittyWriter.running) return
        kittyWriter.requestedPalette = kittyPalette
        kittyWriter.command = ["sh", "-c", 'if [ -f "$1" ]; then script="$1"; else script="$2"; fi; shift 2; exec python3 "$script" "$@"',
            "--", (Quickshell.env("HOME") || "") + "/.local/bin/kitty_theme_ctl.py",
            Quickshell.shellPath("../../../../core/theme/kitty_theme_ctl.py")].concat(JSON.parse(kittyPalette))
        kittyWriter.running = true
    }

    property Connections settings: Connections {
        target: ShellSettingsStore
        function onReadyChanged() { root.sync(); root.syncKitty() }
    }
    property Process kittyWriter: Process {
        property string requestedPalette: ""
        stderr: StdioCollector { id: kittyError }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Could not synchronize Kitty theme: " + kittyError.text.trim())
            if (requestedPalette !== root.kittyPalette) root.syncKitty()
        }
    }
    property Process writer: Process {
        property string requestedScheme: ""
        stderr: StdioCollector { id: errorOutput }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Could not synchronize desktop color scheme: " + errorOutput.text.trim())
            if (requestedScheme !== root.scheme) root.sync()
        }
    }
}
