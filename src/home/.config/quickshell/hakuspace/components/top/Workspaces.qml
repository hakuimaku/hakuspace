import QtQuick
import Quickshell
import "../"
import "../../services"
import "../../services/WM"

TopModule {
    id: root
    
    property int dot: 20
    property int gap: 8
    property int activeW: 50
    
    property var ids: WM.ids || []
    property int activeId: WM.activeId
    property int activeIdx: ids.indexOf(activeId)
    property int n: ids.length
    

    function slotX(index) {
        var x = index * (dot + gap);
        if (activeIdx !== -1 && index > activeIdx) {
            x += (activeW - dot);
        }
        return x;
    }
    
    property int totalWidth: {
        if (n === 0) return 0;
        var w = n * dot + Math.max(0, n - 1) * gap;
        if (activeIdx !== -1) w += (activeW - dot);
        return w;
    }
    
    implicitWidth: totalWidth + Theme.pad * 2
    
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
    onNChanged: retargetTimer.restart()
    
    Item {
        id: container
        width: parent.width - Theme.pad * 2
        height: root.dot
        anchors.centerIn: parent
        
        // 1. Base dots
        Repeater {
            model: root.n
            
            Rectangle {
                property int wsId: root.ids[index]
                property bool isOccupied: WM.occupied.indexOf(wsId) !== -1
                property bool isHovered: root.hoveredIdx === index
                
                width: root.dot
                height: root.dot
                radius: root.dot / 2
                
                x: root.slotX(index)
                
                color: isOccupied ? Theme.accent : Theme.fgMuted
                opacity: isOccupied ? 0.6 : 0.4
                
                Behavior on x {
                    NumberAnimation { duration: HAnimation.spatial; easing.bezierCurve: HAnimation.spatialCurve }
                }
                Behavior on color {
                    ColorAnimation { duration: HAnimation.effects; easing.bezierCurve: HAnimation.effectsCurve }
                }
                Behavior on opacity {
                    NumberAnimation { duration: HAnimation.effects; easing.bezierCurve: HAnimation.effectsCurve }
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
        
        // Indicators are retargeted from root
        // 3. Interactions
        property int hoveredIdx: -1
        
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            
            function getIndexAt(mx) {
                // Approximate clicking since they animate, we use current active layout
                for (var i = 0; i < root.n; i++) {
                    var sx = root.slotX(i);
                    var w = (i === root.activeIdx) ? root.activeW : root.dot;
                    if (mx >= sx - root.gap/2 && mx <= sx + w + root.gap/2) return i;
                }
                return -1;
            }
            
            onPositionChanged: (mouse) => {
                root.hoveredIdx = getIndexAt(mouse.x);
            }
            onExited: root.hoveredIdx = -1
            
            onClicked: (mouse) => {
                var idx = getIndexAt(mouse.x);
                if (idx !== -1) {
                    WM.activate(root.ids[idx]);
                }
            }
            
            onWheel: (wheel) => {
                if (!WM.supported || root.n === 0) return;
                var step = wheel.angleDelta.y > 0 ? -1 : 1;
                var nextIdx = root.activeIdx + step;
                if (nextIdx < 0) nextIdx = 0;
                if (nextIdx >= root.n) nextIdx = root.n - 1;
                WM.activate(root.ids[nextIdx]);
            }
        }
    }
}
