import QtQuick
import Quickshell
import "services"
import "components/top" as Top

ShellRoot {
    id: root

    property int reloadEventCount: 0
    property int phase: 0

    DesktopColorScheme { id: desktopScheme }

    Top.TrayGroup {
        id: trayGroup
    }

    Connections {
        target: Theme
        function onTrayReloadRequested() {
            root.reloadEventCount++
        }
    }

    Timer {
        id: driver
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (phase === 0) {
                // Ensure initial state
                if (Theme.trayGeneration !== 0) {
                    console.error("Initial trayGeneration must be 0, got " + Theme.trayGeneration)
                    Qt.exit(1)
                }
                // Test direct Theme.reloadTray(true)
                Theme.reloadTray(true)
                if (Theme.trayGeneration !== 1 || root.reloadEventCount !== 1) {
                    console.error("Direct reloadTray failed: gen=" + Theme.trayGeneration + ", events=" + root.reloadEventCount)
                    Qt.exit(1)
                }
                phase = 1
            } else if (phase === 1) {
                // Trigger mode switch via ShellSettingsStore
                ShellSettingsStore.setValue("appearance", "colorMode", "light")
                phase = 2
            } else if (phase === 2) {
                // Wait for desktopScheme writer to complete and apply mode
                if (Theme.trayGeneration >= 2) {
                    console.info("Tray reload on theme switch succeeded: gen=" + Theme.trayGeneration + ", events=" + root.reloadEventCount)
                    phase = 3
                }
            } else if (phase === 3) {
                // Switch back to dark mode
                ShellSettingsStore.setValue("appearance", "colorMode", "dark")
                phase = 4
            } else if (phase === 4) {
                if (Theme.trayGeneration >= 3) {
                    console.info("Tray reload on switch back to dark succeeded: gen=" + Theme.trayGeneration + ", events=" + root.reloadEventCount)
                    console.info("Hikai Tray reload checks passed")
                    Qt.quit()
                }
            }
        }
    }
}
