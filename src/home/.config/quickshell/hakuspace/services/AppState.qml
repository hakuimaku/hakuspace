pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    
    // State files are watched so changes from external scripts update the shell.
    property bool waybarManualState: true
    property FileView fv1: FileView { path: Env.stateDir + "/waybar_manual_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.waybarManualState = true; else if (txt === "0") root.waybarManualState = false; else root.waybarManualState = true; } }

    property bool opaqueThemeState: false
    property FileView fv2: FileView { path: Env.stateDir + "/opaque_theme_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.opaqueThemeState = true; else if (txt === "0") root.opaqueThemeState = false; else root.opaqueThemeState = false; } }

    property bool roundedScreenState: false
    property FileView fv3: FileView { path: Env.stateDir + "/rounded_screen_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.roundedScreenState = true; else if (txt === "0") root.roundedScreenState = false; else root.roundedScreenState = false; } }

    property bool roundedScreenDynamicState: true
    property FileView fv4: FileView { path: Env.stateDir + "/rounded_screen_dynamic_state"; watchChanges: true; printErrors: false; onFileChanged: this.reload(); onTextChanged: { var txt = this.text().trim(); if (txt === "1") root.roundedScreenDynamicState = true; else if (txt === "0") root.roundedScreenDynamicState = false; else root.roundedScreenDynamicState = true; } }

    property int roundedScreenRadius: 20
    property int roundedScreenThickness: 4
    
    // Keep the last valid radius and thickness when a config field is missing.
    property FileView roundedConfView: FileView {
        path: Quickshell.env("HOME") + "/hakucfg/config/rounded-screen.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onTextChanged: {
            var lines = this.text().split('\n');
            var r = root.roundedScreenRadius;
            var t = root.roundedScreenThickness;
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.startsWith('border_thickness')) {
                    var pt = parseInt(line.split('=')[1].trim());
                    if (!isNaN(pt)) t = pt;
                } else if (line.startsWith('border_radius')) {
                    var pr = parseInt(line.split('=')[1].trim());
                    if (!isNaN(pr)) r = pr;
                }
            }
            root.roundedScreenRadius = r;
            root.roundedScreenThickness = t;
        }
    }
}
