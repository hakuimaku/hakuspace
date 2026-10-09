import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "top" as TopModules
import "base"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    
    property real barH: Math.max(30, Theme.fontSize * 2.3)
    property real tipAreaH: 160
    property color barColor: AppState.opaqueThemeState ? Theme.inkBg : Theme.bg
    
    anchors { top: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-bar"
    
    exclusionMode: ExclusionMode.Normal
    implicitHeight: barH + tipAreaH
    exclusiveZone: Math.round(barH)
    
    color: "transparent"
    visible: AppState.waybarManualState
    
    mask: Region { item: barBg }

    Rectangle {
        id: barBg
        Component.onCompleted: { var p = barBg; while(p) { console.log("barBg ancestor:", p); p = p.parent; } }
        width: parent.width
        height: root.barH
        color: root.barColor
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
                TopModules.WindowTitle {}
            }
            
            Row {
                id: centerModules
                anchors.centerIn: parent
                spacing: Theme.gap
            }
            
            Row {
                id: rightModules
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gap
                TopModules.TrayGroup {}
                Timer { running: true; interval: 2000; onTriggered: { console.log("INJECTED TIMER FIRED"); TooltipManager.show(leftModules.children[1], "Injected Tooltip"); } }
                TopModules.SettingsGroup {}
                TopModules.RecorderGroup {}
                TopModules.ClockGroup {}
                TopModules.NotificationGroup {}
            }
        }
    }
    
    TooltipLayer {
        y: barBg.height
    }
}
