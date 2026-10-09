import QtQuick
import Quickshell
import "../../services"
import "../../services/WM"

Item {
    id: root
    
    implicitHeight: Theme.fontSize * 1.8
    implicitWidth: row.implicitWidth + Theme.pad * 2
    
    property string activeClass: WM.activeWindowClass
    property string activeTitle: WM.activeWindowTitle
    
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap + 6
        
        Text {
            id: iconText
            text: {
                var c = root.activeClass.toLowerCase();
                if (c.indexOf("kitty") !== -1 || c.indexOf("terminal") !== -1) return "";
                if (c.indexOf("firefox") !== -1 || c.indexOf("browser") !== -1 || c.indexOf("chrome") !== -1 || c.indexOf("zen") !== -1) return "";
                if (c.indexOf("code") !== -1 || c.indexOf("vscode") !== -1) return "󰨞";
                if (c.indexOf("discord") !== -1) return "";
                if (c.indexOf("spotify") !== -1) return "";
                if (c.indexOf("thunar") !== -1 || c.indexOf("file") !== -1) return "";
                return "";
            }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.weight: Font.Bold
            color: Theme.fg
            anchors.verticalCenter: parent.verticalCenter
            
            Behavior on color { ColorAnimation { duration: HAnimation.normal } }
        }
        
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            
            Text {
                id: classText
                text: root.activeClass !== "" ? root.activeClass : "Desktop"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.75
                font.weight: Font.Bold
                color: Theme.fgMuted
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 350)
                
                Behavior on color { ColorAnimation { duration: HAnimation.normal } }
            }
            
            Text {
                id: titleText
                text: root.activeTitle !== "" ? root.activeTitle : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.fg
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 350)
                visible: root.activeTitle !== ""
                
                Behavior on color { ColorAnimation { duration: HAnimation.normal } }
            }
        }
    }
}
