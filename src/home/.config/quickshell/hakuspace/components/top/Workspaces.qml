import "../"
import "../../services"
import "../../services/WM"
import QtQuick
import Quickshell

TopModule {
    id: root

    // Use the same workspace model and activation for either bar axis.
    property bool vertical: false
    property string screenName: ""
    property var items: WM.workspacesFor(screenName)
    property int dot: 20
    property int gap: 6
    property int activeW: 50
    property int activeIdx: {
        for (var i = 0; i < items.length; i++) {
            if (items[i].active || items[i].focused) {
                if (items[i].focused)
                    return i;

            }
        }
        for (var j = 0; j < items.length; j++) {
            if (items[j].active)
                return j;

        }
        return -1;
    }
    property int totalWidth: {
        var w = 0;
        var n = items.length;
        for (var i = 0; i < n; i++) {
            w += (i === activeIdx ? activeW : dot);
            if (i < n - 1) {
                w += gap;
                if (items[i] && items[i].special)
                    w += gap;

            }
        }
        return w;
    }

    // Computes the horizontal X offset for a workspace slot within the container.
    function slotX(index) {
        var x = 0;
        for (var i = 0; i < index; i++) {
            x += (i === activeIdx ? activeW : dot) + gap;
            if (items[i] && items[i].special)
                x += gap;

        }
        return x;
    }

    // Keep the original markers while assigning transparent vertical gaps to a hit slot.
    function indexAt(position) {
        for (var index = 0; index < items.length; index++) {
            var start = slotX(index)
            var end = vertical && index < items.length - 1 ? slotX(index + 1)
                : start + (index === activeIdx ? activeW : dot)
            if (position >= start && (vertical ? position < end : position <= end)) return index
        }
        return -1
    }

    color: Theme.surface
    tooltip: ""
    implicitWidth: visible ? (vertical ? dot : totalWidth) + Theme.pad * 2 : 0
    implicitHeight: vertical ? totalWidth + Theme.pad * 2 : Theme.fontSize * 1.8
    onVerticalChanged: Qt.callLater(indicator.retarget)
    onActiveIdxChanged: Qt.callLater(indicator.retarget)
    onItemsChanged: Qt.callLater(indicator.retarget)
    onScreenNameChanged: Qt.callLater(indicator.retarget)

    Item {
        id: container

        x: root.vertical ? (root.width - width) / 2 : Theme.pad
        y: root.vertical ? (root.height - height) / 2 : (root.height - height) / 2
        width: root.vertical ? root.width : root.totalWidth
        height: root.vertical ? root.totalWidth : root.dot

        Repeater {
            model: root.items.length

            Item {
                id: cell

                property var ws: root.items[index]
                property bool isActive: index === root.activeIdx
                property bool isHovered: containerMouseArea.hoveredIdx === index

                width: root.vertical ? container.width : root.dot
                height: root.dot
                x: root.vertical ? 0 : root.slotX(index)
                y: root.vertical ? root.slotX(index) : 0

                // Background workspace dot indicating slot presence and occupancy.
                Rectangle {
                    objectName: "workspace-dot-" + index
                    anchors.centerIn: parent
                    width: root.dot
                    height: root.dot
                    radius: root.dot / 2
                    color: (ws && ws.special) ? "transparent" : Theme.workspaceDot
                    border.width: (ws && ws.special) ? 2 : 0
                    border.color: Theme.accent
                    opacity: (ws && ws.special) ? 1 : (cell.isHovered ? 1 : ((ws && ws.occupied) || !WM.caps.occupied ? 1 : 0.7))

                    // Animates dot color on occupancy or special state change.
                    Behavior on color {
                        ColorAnimation {
                            duration: HAnimation.effects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: HAnimation.effectsCurve
                        }

                    }

                    // Animates dot opacity on hover enter and exit.
                    Behavior on opacity {
                        NumberAnimation {
                            duration: HAnimation.effects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: HAnimation.effectsCurve
                        }

                    }

                    // Pulses dot opacity continuously for urgent workspace alert.
                    SequentialAnimation on opacity {
                        running: ws && ws.urgent
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 1
                            duration: 400
                        }

                        NumberAnimation {
                            to: 0.2
                            duration: 400
                        }

                    }

                }

                Behavior on y {
                    NumberAnimation { duration: HAnimation.spatial; easing.bezierCurve: HAnimation.spatialCurve }
                }
                // Animates slot horizontal position when adjacent slots expand or collapse.
                Behavior on x {
                    NumberAnimation {
                        duration: HAnimation.spatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: HAnimation.spatialCurve
                    }

                }

            }

        }

        MouseArea {
            id: containerMouseArea

            property int hoveredIdx: -1
            property real lastScroll: 0

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: (mouse) => {
                hoveredIdx = root.indexAt(root.vertical ? mouse.y : mouse.x);
            }
            onExited: hoveredIdx = -1
            onClicked: (mouse) => {
                hoveredIdx = root.indexAt(root.vertical ? mouse.y : mouse.x);
                if (hoveredIdx !== -1) {
                    var ws = root.items[hoveredIdx];
                    if (!ws)
                        return ;

                    if (mouse.button === Qt.LeftButton)
                        WM.activate(ws.key);
                    else if (mouse.button === Qt.RightButton)
                        WM.secondary(ws.key);
                }
            }
            onWheel: (wheel) => {
                var now = Date.now();
                if (now - lastScroll < 150)
                    return ;

                lastScroll = now;
                var step = wheel.angleDelta.y > 0 ? -1 : 1;
                WM.cycle(step, root.screenName);
            }
        }

        // Active workspace indicator pill morphing across workspace slots.
        Rectangle {
            id: indicator
            objectName: "workspace-active-indicator"

            property real start: 0
            property real end: 0
            property bool firstTime: true

            // Retargets the active indicator pill to the new active workspace slot with asymmetric lead/trail timing.
            function retarget() {
                if (root.activeIdx === -1)
                    return ;

                var s = root.slotX(root.activeIdx);
                var e = s + root.activeW;
                if (firstTime) {
                    start = s;
                    end = e;
                    firstTime = false;
                    return ;
                }
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

            height: root.vertical ? Math.max(root.dot, end - start) : root.dot
            radius: root.dot / 2
            color: Theme.accent
            x: root.vertical ? (container.width - root.dot) / 2 : start
            y: root.vertical ? start : 0
            width: root.vertical ? root.dot : Math.max(root.dot, end - start)
            visible: root.activeIdx !== -1
            Component.onCompleted: {
                if (root.activeIdx !== -1) {
                    start = root.slotX(root.activeIdx);
                    end = start + root.activeW;
                    firstTime = false;
                }
            }

            // Animates leading edge of the active workspace pill.
            NumberAnimation {
                id: startAnim

                target: indicator
                property: "start"
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.spatialCurve
            }

            // Animates trailing edge of the active workspace pill.
            NumberAnimation {
                id: endAnim

                target: indicator
                property: "end"
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.spatialCurve
            }

        }

    }

}
