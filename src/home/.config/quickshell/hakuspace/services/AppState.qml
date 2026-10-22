pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root
    
    // State files are watched so changes from external scripts update the shell.
    property bool waybarManualState: true
    property FileView fv1: FileView { path: Env.stateDir + "/waybar_manual_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.waybarManualState = true; else if (txt === "0") root.waybarManualState = false; else root.waybarManualState = true; } }

    // Taskbar mode and compact Dockbar requests are watched independently.
    property bool taskbarManualState: false
    property FileView taskbarStateFile: FileView {
        path: Env.stateDir + "/taskbar_manual_state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.taskbarManualState = text().trim() === "1"
        onLoadFailed: root.taskbarManualState = false
    }

    property bool dockbarManualState: false
    property FileView dockbarStateFile: FileView {
        path: Env.stateDir + "/dockbar_manual_state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.dockbarManualState = text().trim() === "1"
        onLoadFailed: root.dockbarManualState = false
    }

    property bool opaqueThemeState: false
    property FileView fv2: FileView { path: Env.stateDir + "/opaque_theme_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.opaqueThemeState = true; else if (txt === "0") root.opaqueThemeState = false; else root.opaqueThemeState = false; } }

    property bool cavaLayerState: false
    property FileView cavaStateFile: FileView {
        path: Env.stateDir + "/cava_layer_state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.cavaLayerState = text().trim() === "1"
        onLoadFailed: root.cavaLayerState = false
    }

    property bool cavaTopState: true
    property FileView cavaTopStateFile: FileView {
        path: Env.stateDir + "/cava_top_state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: {
            var val = text().trim().toLowerCase()
            root.cavaTopState = (val === "0" || val === "bottom") ? false : true
        }
        onLoadFailed: root.cavaTopState = true
    }

    property bool cavaDynamicPosition: false
    property FileView cavaDynamicStateFile: FileView {
        path: Env.stateDir + "/cava_dynamic_state"
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

    function syncCavaDynamicPosition() {
        var wantTop = !taskbarManualState
        if (cavaTopState !== wantTop) {
            cavaTopState = wantTop
        }
    }

    property string cavaColorMode: "accent"
    property FileView cavaColorStateFile: FileView {
        path: Env.stateDir + "/cava_color_state"
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
        path: Env.stateDir + "/cava_height"
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
