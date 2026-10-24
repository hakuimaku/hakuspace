import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Item {
    id: root
    // Production hosts expose loader counts without retaining their loaded items.
    property var hosts: []
    property bool lazy: false

    IpcHandler {
        target: "memoryProbe"
        // Route benchmark requests through the same state owners as shell IPC.
        function open(surface: string, output: string) {
            var screen = Quickshell.screens[Number(output)]
            var anchor = ScreenGeometry.fallbackModuleAnchor(screen.name, Theme.pad, Theme.fontSize * 1.8)
            if (surface === "navigation" || surface === "dashboard" || surface === "sidebar" || surface === "clipboard") {
                UiState.openNavigation(screen.name, anchor)
                if (surface === "dashboard") UiState.beginNavigationHandoff("dashboard")
                if (surface === "sidebar" || surface === "clipboard") {
                    UiState.beginNavigationHandoff("sidebar")
                    for (var host of root.hosts) if (host.navigationItem)
                        host.navigationItem.openSidebarTool(surface === "clipboard" ? "clipboard" : "quickActions", true)
                }
            } else if (surface === "settings") UiState.openSettings(screen.name)
            else if (surface === "hakumenu") UiState.openHakuMenu(screen.name, "drun")
            else if (surface === "actionMenu") UiState.openActionMenu(screen.name, "clipboard")
            else if (surface === "notifications") UiState.toggleNotifications(screen.name, anchor)
            else if (surface === "wallpaper") UiState.openWallpaper(screen.name)
            else if (surface === "tempNote") UiState.openTempNote(screen.name)
        }

        // Request normal visual closing instead of forcing loader destruction.
        function close(surface: string) {
            if (["navigation", "dashboard", "sidebar", "clipboard"].indexOf(surface) >= 0) UiState.closeNavigation()
            else if (surface === "settings") UiState.closeSettings()
            else if (surface === "hakumenu") UiState.closeHakuMenu()
            else if (surface === "actionMenu") UiState.closeActionMenu()
            else if (surface === "notifications") UiState.closeNotifications()
            else if (surface === "wallpaper") UiState.closeWallpaper()
            else if (surface === "tempNote") UiState.closeTempNote()
        }

        // Close native handles and let popup animations finish normally.
        function expireAll() {
            for (var key of Object.keys(NotificationStore._handles)) NotificationStore.expire(Number(key))
        }

        // Report resource ownership without keeping references to loaded surfaces.
        function status(): string {
            var loaded = 0
            for (var i = 0; i < root.hosts.length; ++i) loaded += root.hosts[i].loadedCount
            var surfaces = []
            for (var host of root.hosts) for (var loader of host.loaders) if (loader.active)
                surfaces.push({type: String(loader.item), requested: loader.requested,
                    releaseReady: loader.item ? loader.item.releaseReady : null,
                    panelOpen: loader.item && loader.item.panelOpen, closing: loader.item && loader.item.closing})
            return JSON.stringify({surfaces: surfaces, activePanel: UiState.activePanel, loaded: root.lazy ? loaded : null, records: NotificationStore.records.length,
                handles: Object.keys(NotificationStore._handles).length,
                deadlines: Object.keys(NotificationStore._deadlines).length})
        }
    }
}
