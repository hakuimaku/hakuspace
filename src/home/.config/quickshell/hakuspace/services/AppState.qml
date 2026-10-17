pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"

QtObject {
    id: root
    
    // State files are watched so changes from external scripts update the shell.
    property bool waybarManualState: true
    property FileView fv1: FileView { path: Env.stateDir + "/waybar_manual_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.waybarManualState = true; else if (txt === "0") root.waybarManualState = false; else root.waybarManualState = true; } }

    property bool opaqueThemeState: false
    property FileView fv2: FileView { path: Env.stateDir + "/opaque_theme_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.opaqueThemeState = true; else if (txt === "0") root.opaqueThemeState = false; else root.opaqueThemeState = false; } }


}
