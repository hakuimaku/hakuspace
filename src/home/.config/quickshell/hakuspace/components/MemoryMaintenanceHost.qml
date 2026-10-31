import QtQuick
import Quickshell.Io
import "../services"

Item {
    id: root
    // Count hosts rather than retaining any loaded surface or screencopy item.
    required property var hosts
    required property bool externalBusy
    readonly property int loadedCount: {
        var count = 0
        for (var host of hosts) count += host.loadedCount
        return count
    }
    // Conservative gates preserve drafts, native dialogs and background commits.
    readonly property var blockers: {
        var reasons = []
        if (externalBusy || LockState.locked || !ShellTransitionState.chromeEnabled || ShellTransitionState.active) reasons.push("lock-picker-transition")
        if (loadedCount || UiState.activePanel || UiState.tempNoteOpen || UiState.taskManagerOpen || UiState.dashboardVisuallyActive) reasons.push("surface")
        if (UiState.nativeDialogOpen) reasons.push("native-dialog")
        if (WindowNavigator.active || WindowNavigator.sessionWindows.length || WindowNavigator.pendingAddress) reasons.push("screencopy")
        if (ImageEditor.sourcePath || ImageEditor.busy || ImageEditor.dirty) reasons.push("image-editor")
        if (SettingsCoordinator.busy || SettingsCoordinator.dirty || ConfigEditorStore.busy || ConfigEditorStore.dirty) reasons.push("settings")
        if (TextStore.bioDirty || TextStore.scratchDirty || TextStore.bioSaving || TextStore.scratchSaving || Avatar.busy) reasons.push("draft-save")
        if (WallpaperService.maintenanceBusy || WallpaperLibrary.loading) reasons.push("wallpaper")
        if (IdleService.sleepPending || IdleService.suspendPending || IdleService.releasing || IdleService.recovering) reasons.push("session")
        return reasons
    }
    Binding { target: MemoryMaintenance; property: "activitySafe"; value: root.blockers.length === 0 }
    Binding { target: MemoryMaintenance; property: "loadedSurfaces"; value: root.loadedCount }
    Binding { target: MemoryMaintenance; property: "activeLayer"; value: UiState.activePanel }
    Binding { target: MemoryMaintenance; property: "blockers"; value: root.blockers }
    Component.onCompleted: MemoryMaintenance.start()
    Component.onDestruction: MemoryMaintenance.stop()

    IpcHandler {
        target: "memory"
        function status(): string { return MemoryMaintenance.status() }
        function baseline(): string { return JSON.stringify(MemoryMaintenance.baseline) }
        function collect(): string { return MemoryMaintenance.collect() }
        function recycle(): string { return MemoryMaintenance.recycle() }
    }
}
