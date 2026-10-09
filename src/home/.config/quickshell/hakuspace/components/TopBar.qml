import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "top" as TopModules

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    
    anchors { top: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Normal
    implicitHeight: Math.max(30, Theme.fontSize * 2.3)
    color: AppState.opaqueThemeState ? "#000000" : Theme.bg
    visible: AppState.waybarManualState
    
    exclusiveZone: Math.round(implicitHeight)

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.border
        
        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.pad
            anchors.rightMargin: Theme.pad
            
            Row {
                id: leftModules
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gap
                TopModules.Logo {}
                TopModules.Workspaces {}
                TopModules.CavaGroup {}
            }
            
            Row {
                id: centerModules
                anchors.centerIn: parent
                spacing: Theme.gap
                TopModule {
                    text: "Window Title"
                    icon: ""
                    isAccent: false
                    // Placeholder for future window title module
                }
            }
            
            Row {
                id: rightModules
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gap
                TopModules.TrayGroup {}
                TopModules.SettingsGroup {}
                TopModules.RecorderGroup {}
                TopModules.ClockGroup {}
                TopModules.NotificationGroup {}
            }
        }
    }
}
