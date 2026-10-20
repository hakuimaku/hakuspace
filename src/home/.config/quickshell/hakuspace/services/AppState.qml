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


}
