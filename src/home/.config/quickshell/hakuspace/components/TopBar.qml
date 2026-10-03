import QtQuick
import Quickshell
import "../services"
import "top" as TopModules

PanelWindow {
    id: root
    property var modelData
    screen: modelData
    
    anchors { top: true; left: true; right: true }
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
                TopModules.MusicGroup {}
            }
            
            Row {
                id: centerModules
                anchors.centerIn: parent
                spacing: Theme.gap
                TopModules.RecorderGroup {}
                TopModules.ClockGroup {}
            }
            
            Row {
                id: rightModules
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gap
                TopModules.MonitorGroup {}
                TopModules.SettingsGroup {}
                TopModules.TrayGroup {}
                TopModules.NotificationGroup {}
            }
        }
    }
}
