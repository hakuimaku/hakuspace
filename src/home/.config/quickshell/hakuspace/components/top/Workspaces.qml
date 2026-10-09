import "../"
import "../../services"
import "../../services/WM"
import "../base"
import QtQuick
import Quickshell

TopModule {
    id: root

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

    function slotX(index) {
        var x = 0;
        for (var i = 0; i < index; i++) {
            x += (i === activeIdx ? activeW : dot) + gap;
            if (items[i] && items[i].special)
                x += gap;

        }
        return x;
    }

    color: Theme.surface
    tooltip: ""
    visible: WM.supported && items.length > 0
    implicitWidth: visible ? totalWidth + Theme.pad * 2 : 0
    onActiveIdxChanged: retargetTimer.restart()
    onItemsChanged: retargetTimer.restart()
    onScreenNameChanged: retargetTimer.restart()

    Timer {
        id: retargetTimer

        interval: 10
        running: false
        onTriggered: {
            if (indicator)
                indicator.retarget();

        }
    }

    Item {
        id: container

        width: parent.width - Theme.pad * 2
        height: root.dot
        anchors.centerIn: parent

        Repeater {
            model: root.items.length

            Item {
                id: cell

                property var ws: root.items[index]
                property bool isActive: index === root.activeIdx
                property bool isHovered: containerMouseArea.hoveredIdx === index

                width: root.dot
                height: root.dot
                x: root.slotX(index)

                Rectangle {
                    anchors.centerIn: parent
                    width: root.dot
                    height: root.dot
                    radius: root.dot / 2
                    color: (ws && ws.special) ? "transparent" : Theme.workspaceDot
                    border.width: (ws && ws.special) ? 2 : 0
                    border.color: Theme.accent
                    opacity: (ws && ws.special) ? 1 : (cell.isHovered ? 1 : ((ws && ws.occupied) || !WM.caps.occupied ? 1 : 0.7))

                    Behavior on color {
                        ColorAnimation {
                            duration: HAnimation.effects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: HAnimation.effectsCurve
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: HAnimation.effects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: HAnimation.effectsCurve
                        }

                    }

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

                HTooltip {
                    target: cell
                    enabled: cell.isHovered && ws !== undefined
                    text: {
                        if (!ws)
                            return "";

                        var lines = [ws.name];
                        if (WM.caps.windowCount && ws.windows > 0) {
                            var title = ws.focusedTitle || "";
                            if (title.length > 40)
                                title = title.substring(0, 39) + "…";

                            lines.push(ws.windows + " windows" + (title ? " · " + title : ""));
                        }
                        var uniqueOutputs = {
                        };
                        var c = 0;
                        for (var i = 0; i < WM.workspaces.length; i++) {
                            if (WM.workspaces[i].output && !uniqueOutputs[WM.workspaces[i].output]) {
                                uniqueOutputs[WM.workspaces[i].output] = true;
                                c++;
                            }
                        }
                        if (c > 1 && ws.output)
                            lines.push("Output: " + ws.output);

                        if (ws.urgent)
                            lines.push("Urgent");

                        return lines.join("\n");
                    }
                }

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
                var hIdx = -1;
                for (var i = 0; i < root.items.length; i++) {
                    var sx = root.slotX(i);
                    var w = (i === root.activeIdx) ? root.activeW : root.dot;
                    if (mouse.x >= sx && mouse.x <= sx + w) {
                        hIdx = i;
                        break;
                    }
                }
                hoveredIdx = hIdx;
            }
            onExited: hoveredIdx = -1
            onClicked: (mouse) => {
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

        Rectangle {
            id: indicator

            property real start: 0
            property real end: 0
            property bool firstTime: true

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

            height: root.dot
            radius: root.dot / 2
            color: Theme.accent
            x: start
            width: Math.max(root.dot, end - start)
            visible: root.activeIdx !== -1
            Component.onCompleted: {
                if (root.activeIdx !== -1) {
                    start = root.slotX(root.activeIdx);
                    end = start + root.activeW;
                    firstTime = false;
                }
            }

            NumberAnimation {
                id: startAnim

                target: indicator
                property: "start"
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.spatialCurve
            }

            NumberAnimation {
                id: endAnim

                target: indicator
                property: "end"
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.spatialCurve
            }

        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: HAnimation.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.spatialCurve
        }

    }

}
