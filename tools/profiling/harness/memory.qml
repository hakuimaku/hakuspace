import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Item {
    id: root
    // Production hosts expose loader counts without retaining their loaded items.
    property var hosts: []
    property bool lazy: false
    // Inspect the existing resident picker without creating a second window.
    property var picker: null

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
            else if (surface === "navigator") WindowNavigator.open("overview", 0)
            else if (surface === "imageEditor") ImageEditor.open(Quickshell.env("HAKUSPACE_MEMORY_IMAGE"), screen.name)
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
            else if (surface === "navigator") WindowNavigator.cancel()
            else if (surface === "imageEditor") ImageEditor.close()
        }

        // Close native handles and let popup animations finish normally.
        function expireAll() {
            for (var key of Object.keys(NotificationStore._handles)) NotificationStore.expire(Number(key))
        }

        // Private stress profiles lower pressure gates without changing production config.
        function pressure() {
            MemoryMaintenance.baseline = Object.assign({}, MemoryMaintenance.baseline, {rssMiB: 1})
            MemoryMaintenance.policy = Object.assign({}, MemoryMaintenance.policy, {softGrowthMiB: 1, hardGrowthMiB: 100000})
            MemoryMaintenance.requestSample("observe")
        }
        function collect(): string { return MemoryMaintenance.collect() }
        function pickerOpen() {
            var items = []
            for (var i = 0; i < 10000; ++i) items.push("memory picker item " + i)
            root.picker.open(Quickshell.env("HAKUSPACE_MEMORY_PICKER_OUTPUT"), "Memory picker", items, false, false)
        }
        function pickerFinish() { root.picker.finish("memory-picker-result") }

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
                pickerItems: root.picker ? root.picker.allItems.length + root.picker.filteredItems.length : null,
                pickerBusy: root.picker ? (root.picker.maintenanceBusy !== undefined ? root.picker.maintenanceBusy : root.picker.visible) : null,
                navigatorSupported: WindowNavigator.supported,
                memory: AppState.shellBackend === "hikai" && typeof MemoryMaintenance !== "undefined" ? JSON.parse(MemoryMaintenance.status()) : null,
                handles: Object.keys(NotificationStore._handles).length,
                deadlines: Object.keys(NotificationStore._deadlines).length})
        }
    }
}
