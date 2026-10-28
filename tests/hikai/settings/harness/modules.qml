import QtQuick
import Quickshell
import "services"
import "components/bar" as Bar

ShellRoot {
    id: root
    // Exercise the shared module list in both presentations on two private outputs.
    property var surfaces: []
    property int phase: 0
    property int ticks: 0
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: Theme.surface
            Bar.StatusModules {
                id: top
                ownerWindow: window
                screenName: window.modelData.name
            }
            Bar.StatusModules {
                id: bottom
                y: window.height - height
                presentation: "fullBottom"
                ownerWindow: window
                screenName: window.modelData.name
            }
            Component.onCompleted: root.surfaces = root.surfaces.concat([top, bottom])
        }
    }
    // Find the real shared modules independently of their internal child structure.
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children || []) {
            var match = find(child, name)
            if (match) return match
        }
        return null
    }
    function check(ok, message) {
        if (ok) return
        console.error("Hikai modules failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            root.check(++root.ticks < 100, "module runtime timeout")
            if (!ShellSettingsStore.ready || ShellSettingsStore.loading || ShellSettingsStore.saving || root.surfaces.length !== 4) return
            root.check(!ShellSettingsStore.error, ShellSettingsStore.error)
            if (root.phase === 0) {
                PpdProfile.profile = "balanced"
                ShellSettingsStore.setValue("topbar", "quickControls", false)
                ShellSettingsStore.setValue("topbar", "powerProfile", true)
                ShellSettingsStore.setValue("topbar", "wallpaperWorkspace", false)
                ShellSettingsStore.setValue("topbar", "recorder", false)
            } else if (root.phase === 1) {
                for (var surface of root.surfaces) {
                    root.check(!root.find(surface, "quick-controls-module").visible, "Quick Controls can be hidden alone")
                    root.check(root.find(surface, "power-profile-module").visible, "Power Profile remains independently visible")
                    root.check(!root.find(surface, "wallpaper-workspace-launcher").visible, "Wallpaper Workspace can be hidden")
                    root.check(!root.find(surface, "screen-recorder-module").visible, "idle Recorder can be hidden")
                }
                root.check(PpdProfile.subscribers === 4, "visible bars subscribe to Power Profile")
                ShellSettingsStore.setValue("topbar", "powerProfile", false)
                ShellSettingsStore.setValue("topbar", "quickControls", true)
                ShellSettingsStore.setValue("topbar", "wallpaperWorkspace", true)
                ShellSettingsStore.setValue("topbar", "recorder", true)
            } else if (root.phase === 2) {
                for (var surface of root.surfaces) {
                    root.check(root.find(surface, "quick-controls-module").visible, "Quick Controls remains independently visible")
                    root.check(!root.find(surface, "power-profile-module").visible, "Power Profile can be hidden alone")
                    root.check(root.find(surface, "wallpaper-workspace-launcher").visible, "Wallpaper Workspace can be restored")
                    root.check(root.find(surface, "screen-recorder-module").visible, "Recorder can be restored")
                }
                root.check(PpdProfile.subscribers === 0, "hidden Power Profile stops recurring polling")
                Recorder.isRecording = true
                ShellSettingsStore.setValue("topbar", "recorder", false)
            } else if (root.phase === 3) {
                for (var surface of root.surfaces)
                    root.check(root.find(surface, "screen-recorder-module").visible, "recording keeps its stop control visible")
                Recorder.isRecording = false
            } else if (root.phase === 4) {
                for (var surface of root.surfaces)
                    root.check(!root.find(surface, "screen-recorder-module").visible, "Recorder hides again after recording stops")
                ShellSettingsStore.apply()
            } else if (root.phase === 5) {
                root.check(!ShellSettingsStore.savedValues.topbar.powerProfile && !ShellSettingsStore.savedValues.topbar.recorder, "independent gates reach disk")
                ShellSettingsStore.reset(); ShellSettingsStore.apply()
            } else {
                root.check(!ShellSettingsStore.dirty, "reset is persisted")
                console.info("Hikai modules checks passed")
                Qt.quit()
            }
            ++root.phase
        }
    }
}
