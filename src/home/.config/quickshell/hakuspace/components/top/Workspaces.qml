import QtQuick
import Quickshell
import "../"
import "../base"
import "../../services"
import "../../services/WM"

TopModule {
    id: root
    
    color: "transparent"
    tooltip: ""
    
    property string screenName: ""
    property var items: WM.workspacesFor(screenName)
    
    property int dot: 20
    property int gap: 8
    property int activeW: 50
    
    visible: WM.supported && items.length > 0
    implicitWidth: visible ? totalWidth + Theme.pad * 2 : 0
    
    property int activeIdx: {
        for (var i = 0; i < items.length; i++) {
            if (items[i].active || items[i].focused) {
                // Prefer globally focused if available
                if (items[i].focused) return i;
            }
        }
        for (var j = 0; j < items.length; j++) {
            if (items[j].active) return j;
        }
        return -1;
    }
    
    function slotX(index) {
        var x = 0;
        for (var i = 0; i < index; i++) {
            x += (i === activeIdx ? activeW : dot) + gap;
            if (items[i].special) x += gap;
        }
        return x;
    }
    
    property int totalWidth: {
        var w = 0;
        for (var i = 0; i < items.length; i++) {
            w += (i === activeIdx ? activeW : dot);
            if (i < items.length - 1) {
                w += gap;
                if (items[i].special) w += gap;
            }
        }
        return w;
    }
    
    Behavior on implicitWidth {
        NumberAnimation { duration: HAnimation.spatial; easing.bezierCurve: HAnimation.spatialCurve }
    }
    
    Timer {
        id: retargetTimer
        interval: 10
        running: false
        onTriggered: if (indicator) indicator.retarget()
    }
    
    onActiveIdxChanged: retargetTimer.restart()
    onItemsChanged: retargetTimer.restart()
    onScreenNameChanged: retargetTimer.restart()
    
    Item {
        id: container
        width: parent.width - Theme.pad * 2
        height: root.dot
        anchors.centerIn: parent
        
        Repeater {
            model: root.items
            
            Item {
                id: cell
                property var ws: modelData
                property bool isActive: index === root.activeIdx
                
                property real targetWidth: isActive ? root.activeW : (mouseArea.containsMouse ? root.dot + 8 : root.dot)
                
                width: targetWidth
                height: root.dot
                x: isActive ? root.slotX(index) : root.slotX(index) + root.dot / 2 - targetWidth / 2
                
                Behavior on targetWidth { NumberAnimation { duration: HAnimation.spatial; easing.bezierCurve: HAnimation.spatialCurve } }
                Behavior on x { NumberAnimation { duration: HAnimation.spatial; easing.bezierCurve: HAnimation.spatialCurve } }
                
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: root.dot
                    radius: root.dot / 2
                    
                    color: ws.special ? "transparent" : (ws.occupied || !WM.caps.occupied ? Theme.accent : Theme.fgMuted)
                    border.width: ws.special ? 1 : 0
                    border.color: Theme.accent
                    
                    opacity: ws.special ? 1.0 : (mouseArea.containsMouse ? 0.9 : (ws.occupied ? 0.6 : (!WM.caps.occupied ? 0.5 : 0.4)))
                    
                    Behavior on color { ColorAnimation { duration: HAnimation.effects; easing.bezierCurve: HAnimation.effectsCurve } }
                    Behavior on opacity { NumberAnimation { duration: HAnimation.effects; easing.bezierCurve: HAnimation.effectsCurve } }
                    
                    SequentialAnimation on opacity {
                        running: ws.urgent
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.0; duration: 400 }
                        NumberAnimation { to: 0.2; duration: 400 }
                    }
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    
                    property real lastScroll: 0
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            WM.activate(ws.key);
                        } else if (mouse.button === Qt.RightButton) {
                            WM.secondary(ws.key);
                        }
                    }
                    
                    onWheel: (wheel) => {
                        var now = Date.now();
                        if (now - lastScroll < 150) return;
                        lastScroll = now;
                        
                        var step = wheel.angleDelta.y > 0 ? -1 : 1;
                        WM.cycle(step, root.screenName);
                    }
                }
                
                HTooltip {
                    target: cell
                    enabled: mouseArea.containsMouse
                    text: {
                        var lines = [ws.name];
                        if (WM.caps.windowCount && ws.windows > 0) {
                            var title = ws.focusedTitle || "";
                            if (title.length > 40) title = title.substring(0, 39) + "…";
                            lines.push(ws.windows + " windows" + (title ? " · " + title : ""));
                        }
                        
                        var uniqueOutputs = {};
                        var c = 0;
                        for (var i = 0; i < WM.workspaces.length; i++) {
                            if (WM.workspaces[i].output && !uniqueOutputs[WM.workspaces[i].output]) {
                                uniqueOutputs[WM.workspaces[i].output] = true;
                                c++;
                            }
                        }
                        if (c > 1 && ws.output) {
                            lines.push("Output: " + ws.output);
                        }
                        if (ws.urgent) {
                            lines.push("Urgent");
                        }
                        return lines.join("\n");
                    }
                }
            }
        }
        
        // 2. Gliding Indicator (The Worm)
        Rectangle {
            id: indicator
            height: root.dot
            radius: root.dot / 2
            color: Theme.accent
            
            property real start: 0
            property real end: 0
            
            x: start
            width: Math.max(root.dot, end - start)
            visible: root.activeIdx !== -1
            
            function retarget() {
                if (root.activeIdx === -1) return;
                var s = root.slotX(root.activeIdx);
                var e = s + root.activeW;
                var goingLeft = s < start;
                
                var lead = HAnimation.spatial;
                var trail = HAnimation.spatial * HAnimation.trailFactor;
                
                startAnim.duration = goingLeft ? lead : trail;
                endAnim.duration = goingLeft ? trail : lead;
                
                startAnim.to = s;
                endAnim.to = e;
                
                startAnim.restart();
                endAnim.restart();
            }
            
            NumberAnimation {
                id: startAnim
                target: indicator
                property: "start"
                easing.bezierCurve: HAnimation.spatialCurve
            }
            
            NumberAnimation {
                id: endAnim
                target: indicator
                property: "end"
                easing.bezierCurve: HAnimation.spatialCurve
            }
            
            Component.onCompleted: {
                if (root.activeIdx !== -1) {
                    start = root.slotX(root.activeIdx);
                    end = start + root.activeW;
                }
            }
        }
    }
}
