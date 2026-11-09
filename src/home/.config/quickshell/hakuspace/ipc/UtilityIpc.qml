import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Scope {
    id: root

    IpcHandler {
        target: "taskManager"
        function open(screenName: string) {
            if (AppState.shellBackend !== "hikai") return
            for (var screen of Quickshell.screens) if (screen.name === screenName) {
                UiState.openTaskManager(screenName)
                return
            }
        }
        function openDefault() {
            if (AppState.shellBackend === "hikai" && Quickshell.screens.length) UiState.openTaskManager(Quickshell.screens[0].name)
        }
        function toggle() {
            if (UiState.taskManagerOpen) UiState.closeTaskManager()
            else openDefault()
        }
        function close() { UiState.closeTaskManager() }
        function status(): string {
            return JSON.stringify(Object.assign(TaskManagerService.status(), {
                open: UiState.taskManagerOpen, screen: UiState.taskManagerScreenName,
                interactionOwner: UiState.interactionOwner
            }))
        }
    }

    IpcHandler {
        target: "settings"
        enabled: true
        function open(screenName: string) {
            for (var screen of Quickshell.screens) {
                if (screen.name === screenName) {
                    UiState.openSettings(screenName)
                    return
                }
            }
        }
        function openDefault() {
            if (Quickshell.screens.length > 0)
                UiState.openSettings(Quickshell.screens[0].name)
        }
        function toggleDefault() {
            if (Quickshell.screens.length > 0)
                UiState.toggleSettings(Quickshell.screens[0].name)
        }
        function close() { UiState.closeSettings() }
    }

    // Toggle only the floating note, independently of Navigation and Sidebar.
    IpcHandler {
        target: "tempNote"
        function toggle() {
            if (UiState.tempNoteOpen) UiState.closeTempNote()
            else if (Quickshell.screens.length > 0)
                UiState.openTempNote(Quickshell.screens[0].name)
        }
    }

    IpcHandler {
        target: "notif"
        function toggleCenter() {
            if (!NotificationStore._started || Quickshell.screens.length === 0) return
            var screen = Quickshell.screens[0]
            UiState.toggleNotifications(screen.name, ScreenGeometry.barAnchor(screen.height, screen.width - Theme.pad - Theme.fontSize * 2,
                                        Theme.fontSize * 2))
        }
        function closeCenter() {
            UiState.closeNotifications()
        }
        function toggleDnd() { NotificationStore.toggleDnd() }
        function clearAll() { NotificationStore.clearAll() }
        function count(): string { return String(NotificationStore.count) }
    }
}
