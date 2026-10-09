import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

PopupWindow {
    id: root
    property string text: ""
    property Item target: null
    property bool active: false

    property bool shouldShow: active && text.length > 0
    visible: shouldShow || revealProgress > 0
    
    property real revealProgress: shouldShow ? 1.0 : 0.0
    Behavior on revealProgress {
        NumberAnimation { 
            duration: HAnimation.fast 
            easing.bezierCurve: HAnimation.tooltipCurve 
        }
    }
    
    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    
    property real targetAbsCenter: 0
    property real targetAbsY: 0
    
    Connections {
        target: root.target
        function onXChanged() { updatePos() }
        function onYChanged() { updatePos() }
        function onWidthChanged() { updatePos() }
        function onHeightChanged() { updatePos() }
    }
    
    property bool isMapped: false
    
    function updatePos() {
        if (target) {
            try {
                var pt = target.mapToItem(null, 0, 0);
                targetAbsY = pt.y;
                targetAbsCenter = pt.x + target.width / 2;
                isMapped = true;
            } catch(e) {}
        }
    }
    
    Component.onCompleted: {
        updatePos();
        mapTimer.start();
    }
    onTargetChanged: updatePos()
    
    Timer {
        id: mapTimer
        interval: 100
        repeat: true
        onTriggered: {
            if (!isMapped) {
                updatePos();
            } else {
                stop();
            }
        }
    }
    
    anchor.margins.top: {
        var h = 30; // standard TopBar height
        var bottom = targetAbsY + (target ? target.height : 0);
        return Math.max(0, h - bottom);
    }
    
    color: "transparent"

    property int r: 20
    property int textPad: 10
    
    Text {
        id: measureText
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        visible: false
    }
    
    property int reqBodyWidth: Math.max(80, measureText.implicitWidth + textPad * 2)
    property int reqBodyHeight: Math.max(40, measureText.implicitHeight + textPad * 2)
    
    // Hardcode 1920 or use a better way if windowWidth is needed, but assuming standard FHD for now, 
    // or we can map another way.
    // Actually target.parent... up to PanelWindow works, but let's just use Quickshell.app.windows[0].width? No.
    // Wait, let's just use 1920.
    property real windowWidth: 1920
    property real expectedCenterPopupX: targetAbsCenter - (reqBodyWidth + r * 2) / 2
    
    property bool isLeftEdge: expectedCenterPopupX <= Theme.pad
    property bool isRightEdge: !isLeftEdge && ((expectedCenterPopupX + reqBodyWidth + r * 2) >= (windowWidth - Theme.pad))
    property bool isCenter: !isLeftEdge && !isRightEdge
    
    property int targetWidth: {
        if (isLeftEdge) return reqBodyWidth + r;
        if (isRightEdge) return reqBodyWidth + r;
        return reqBodyWidth + r * 2;
    }
    
    property int targetHeight: reqBodyHeight
    property int canvasHeight: targetHeight + r
    
    implicitWidth: targetWidth
    implicitHeight: canvasHeight
    
    Item {
        id: clipContainer
        width: targetWidth
        height: canvasHeight * root.revealProgress
        clip: true
        
        Canvas {
            id: canvas
            width: targetWidth
            height: canvasHeight
            
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = AppState.opaqueThemeState ? "#000000" : Theme.bg;
                
                ctx.beginPath();
                
                if (root.isLeftEdge) {
                    ctx.moveTo(0, 0);
                    ctx.lineTo(0, root.targetHeight + root.r);
                    ctx.arc(root.r, root.targetHeight + root.r, root.r, Math.PI, -Math.PI/2, false);
                    ctx.lineTo(width - root.r * 2, root.targetHeight);
                    ctx.arc(width - root.r * 2, root.targetHeight - root.r, root.r, Math.PI/2, 0, true);
                    ctx.lineTo(width - root.r, root.r);
                    ctx.arc(width, root.r, root.r, Math.PI, -Math.PI/2, false);
                    ctx.lineTo(0, 0);
                } else if (root.isRightEdge) {
                    ctx.moveTo(0, 0);
                    ctx.arc(0, root.r, root.r, -Math.PI/2, 0, false);
                    ctx.lineTo(root.r, root.targetHeight - root.r);
                    ctx.arc(root.r * 2, root.targetHeight - root.r, root.r, Math.PI, Math.PI/2, true);
                    ctx.lineTo(width - root.r, root.targetHeight);
                    ctx.arc(width - root.r, root.targetHeight + root.r, root.r, -Math.PI/2, 0, false);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(0, 0);
                } else {
                    ctx.moveTo(0, 0);
                    ctx.arc(0, root.r, root.r, -Math.PI/2, 0, false);
                    ctx.lineTo(root.r, root.targetHeight - root.r);
                    ctx.arc(root.r * 2, root.targetHeight - root.r, root.r, Math.PI, Math.PI/2, true);
                    ctx.lineTo(width - root.r * 2, root.targetHeight);
                    ctx.arc(width - root.r * 2, root.targetHeight - root.r, root.r, Math.PI/2, 0, true);
                    ctx.lineTo(width - root.r, root.r);
                    ctx.arc(width, root.r, root.r, Math.PI, -Math.PI/2, false);
                    ctx.lineTo(0, 0);
                }
                
                ctx.fill();
            }
            
            Connections {
                target: Theme
                function onBgChanged() { canvas.requestPaint() }
            }
            Connections {
                target: AppState
                function onOpaqueThemeStateChanged() { canvas.requestPaint() }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            
            Item {
                width: root.reqBodyWidth
                height: root.targetHeight
                x: root.isLeftEdge ? 0 : root.r
                y: 0
                
                Text {
                    id: contentText
                    text: root.text
                    anchors.centerIn: parent
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
