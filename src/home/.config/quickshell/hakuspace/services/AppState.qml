pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool waybarManualState: true
    property bool roundedScreenState: true
    property bool roundedScreenDynamicState: true
    property bool edgeTriggerState: true
    property bool opaqueThemeState: false

    FileView {
        id: fvWaybar
        path: Env.stateDir + "/waybar_manual_state"
        watchChanges: true
        onTextChanged: { root.waybarManualState = (fvWaybar.text().trim() === "1") }
    }
    FileView {
        id: fvRounded
        path: Env.stateDir + "/rounded_screen_state"
        watchChanges: true
        onTextChanged: { root.roundedScreenState = (fvRounded.text().trim() === "1") }
    }
    FileView {
        id: fvRoundedDyn
        path: Env.stateDir + "/rounded_screen_dynamic_state"
        watchChanges: true
        onTextChanged: { root.roundedScreenDynamicState = (fvRoundedDyn.text().trim() === "1") }
    }
    FileView {
        id: fvEdge
        path: Env.stateDir + "/edge_trigger_state"
        watchChanges: true
        onTextChanged: { root.edgeTriggerState = (fvEdge.text().trim() === "1") }
    }
    FileView {
        id: fvOpaque
        path: Env.stateDir + "/opaque_theme_state"
        watchChanges: true
        onTextChanged: { root.opaqueThemeState = (fvOpaque.text().trim() === "1") }
    }
}
