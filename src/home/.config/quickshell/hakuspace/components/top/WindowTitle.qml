import QtQuick
import Quickshell
import "../../services"
import "../../services/WM"
import "../base"

Item {
    id: root
    
    property string nextClass: WM.activeWindowClass
    property string nextTitle: WM.activeWindowTitle
    
    property string activeClass: "Desktop"
    property string activeTitle: ""
    readonly property int maxTitleCharacters: 32
    readonly property var titleCharacters: Array.from(activeTitle)
    readonly property string displayTitle: titleCharacters.length > maxTitleCharacters
                                           ? titleCharacters.slice(0, maxTitleCharacters - 1).join("") + "…"
                                           : activeTitle
    
    property bool hovered: false
    
    implicitHeight: Theme.fontSize * 1.8
    implicitWidth: contentWrapper.implicitWidth + Theme.pad * 2
    
    Behavior on implicitWidth {
        NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve }
    }
    
    onNextClassChanged: {
        if (activeClass !== nextClass) morphAnim.restart();
    }
    onNextTitleChanged: {
        if (activeTitle !== nextTitle) morphAnim.restart();
    }
    
    SequentialAnimation {
        id: morphAnim
        NumberAnimation { target: contentWrapper; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
        ScriptAction {
            script: {
                root.activeClass = root.nextClass;
                root.activeTitle = root.nextTitle;
            }
        }
        NumberAnimation { target: contentWrapper; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
    }
    
    Component.onCompleted: {
        activeClass = nextClass;
        activeTitle = nextTitle;
        contentWrapper.opacity = 1;
    }

    Rectangle {
        anchors.fill: parent
        color: root.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        radius: Theme.radiusSm
        Behavior on color { ColorAnimation { duration: HAnimation.normal } }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: { root.hovered = true; tooltipObj.active = true; }
        onExited: { root.hovered = false; tooltipObj.active = false; }
    }
    
    HTooltip {
        id: tooltipObj
        target: root
        text: {
            var c = root.activeClass !== "" ? root.activeClass : "Desktop";
            var t = root.activeTitle !== "" ? root.activeTitle : "None";
            return "App ID: " + c + "\nTitle: " + t;
        }
    }
    
    Item {
        id: contentWrapper
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.gap + 10
            
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
                    return "";
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                font.weight: Font.Bold
                color: Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2
                spacing: 0
                
                Text {
                    id: classText
                    text: root.activeClass !== "" ? root.activeClass : "...hakushell..."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.75
                    font.weight: Font.Bold
                    color: Theme.fgMuted
                    width: implicitWidth
                }
                
                Text {
                    id: titleText
                    text: root.displayTitle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Bold
                    color: Theme.fg
                    width: implicitWidth
                    visible: root.activeTitle !== ""
                }
            }
        }
    }
}
