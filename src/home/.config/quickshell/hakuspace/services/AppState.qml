pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root
    
    // Backend ownership follows atomic state-file commits during shell transitions.
    property string shellBackend: "classic"
    property FileView shellBackendFile: FileView {
        path: Env.stateShellBackend
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.shellBackend = text().trim() === "hikai" ? "hikai" : "classic"
        onLoadFailed: root.shellBackend = "classic"
    }
    // Caffeine shares one manual inhibitor with the Classic policy helper.
    property bool idleInhibited: false
    property FileView idleInhibitFile: FileView {
        path: Env.stateIdleInhibited
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.idleInhibited = text().trim() === "1"
        onLoadFailed: root.idleInhibited = false
    }

    // Rotation is controlled by the existing wallpaper facade and state file.
    property bool wallpaperRotationActive: false
    property FileView wallpaperRotationFile: FileView {
        path: "/tmp/random_wallpaper_status"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.wallpaperRotationActive = text().trim() === "1"
        onLoadFailed: root.wallpaperRotationActive = false
    }

    // State files are watched so changes from external scripts update the shell.
    property bool waybarManualState: true
    property FileView fv1: FileView { path: Env.stateDesktopWaybarRequested; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.waybarManualState = true; else if (txt === "0") root.waybarManualState = false; else root.waybarManualState = true; } }

    // Taskbar mode and compact Dockbar requests are watched independently.
    property bool taskbarManualState: false
    property FileView taskbarStateFile: FileView {
        path: Env.stateDesktopTaskbarRequested
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.taskbarManualState = text().trim() === "1"
        onLoadFailed: root.taskbarManualState = false
    }

    property bool dockbarManualState: false
    property FileView dockbarStateFile: FileView {
        path: Env.stateDesktopDockbarRequested
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.dockbarManualState = text().trim() === "1"
        onLoadFailed: root.dockbarManualState = false
    }

    property bool opaqueThemeState: false
    property FileView fv2: FileView { path: Env.stateThemeOpaqueEnabled; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.opaqueThemeState = true; else if (txt === "0") root.opaqueThemeState = false; else root.opaqueThemeState = false; } }

    property bool cavaLayerState: false
    property FileView cavaStateFile: FileView {
        path: Env.stateCavaEnabled
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.cavaLayerState = text().trim() === "1"
        onLoadFailed: root.cavaLayerState = false
    }

    property string cavaPosition: "top"
    property bool cavaTopState: true
    onCavaTopStateChanged: {
        var target = cavaTopState ? "top" : "bottom"
        if (cavaPosition !== target && (cavaPosition === "top" || cavaPosition === "bottom")) {
            cavaPosition = target
        }
    }
    onCavaPositionChanged: {
        var wantTop = (cavaPosition === "top")
        if (cavaTopState !== wantTop) {
            cavaTopState = wantTop
        }
    }
    property FileView cavaTopStateFile: FileView {
        path: Env.stateCavaPosition
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: {
            var val = text().trim().toLowerCase()
            if (val === "0" || val === "bottom") root.cavaPosition = "bottom"
            else if (val === "left") root.cavaPosition = "left"
            else if (val === "right") root.cavaPosition = "right"
            else root.cavaPosition = "top"
        }
        onLoadFailed: root.cavaPosition = "top"
    }

    property bool cavaDynamicPosition: false
    property FileView cavaDynamicStateFile: FileView {
        path: Env.stateCavaDynamicPosition
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: {
            var val = text().trim()
            root.cavaDynamicPosition = (val === "1" || val === "true" || val === "on")
            if (root.cavaDynamicPosition) {
                root.syncCavaDynamicPosition()
            }
        }
        onLoadFailed: root.cavaDynamicPosition = false
    }

    onTaskbarManualStateChanged: {
        if (cavaDynamicPosition) {
            syncCavaDynamicPosition()
        }
    }

    property Connections statusEdgeConn: Connections {
        target: typeof ShellSettingsStore !== "undefined" ? ShellSettingsStore : null
        ignoreUnknownSignals: true
        function onStatusEdgeChanged() {
            if (root.cavaDynamicPosition) {
                root.syncCavaDynamicPosition()
            }
        }
    }

    function syncCavaDynamicPosition() {
        var wantPos = "top"
        if (taskbarManualState) {
            wantPos = "bottom"
        } else if (typeof ShellSettingsStore !== "undefined" && ShellSettingsStore.statusEdge === "left") {
            wantPos = "left"
        } else {
            wantPos = "top"
        }
        if (cavaPosition !== wantPos) {
            cavaPosition = wantPos
        }
    }

    property string cavaColorMode: "accent"
    property FileView cavaColorStateFile: FileView {
        path: Env.stateCavaColorMode
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: {
            var val = text().trim().toLowerCase()
            root.cavaColorMode = (val === "0" || val === "surface" || val === "black") ? "surface" : "accent"
        }
        onLoadFailed: root.cavaColorMode = "accent"
    }

    property int cavaHeight: 72
    property FileView cavaHeightFile: FileView {
        path: Env.stateCavaHeight
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: {
            var val = parseInt(text().trim(), 10)
            if (!isNaN(val) && val >= 32 && val <= 300) {
                root.cavaHeight = val
            } else {
                root.cavaHeight = 72
            }
        }
        onLoadFailed: root.cavaHeight = 72
    }
}
