import QtQuick
import Quickshell
import "../services"

PanelWindow {
    id: root
    property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    
    exclusionMode: ExclusionMode.Normal
    aboveWindows: !AppState.roundedScreenDynamicState
    
    mask: Region {}
    
    visible: AppState.roundedScreenState

    Canvas {
        id: canvas
        anchors.fill: parent
        
        property int r: Theme.radius > 0 ? Theme.radius : 12
        property int t: Theme.borderWidth
        
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = "#000000";
            
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(r, 0);
            ctx.arc(r, r, r, -Math.PI/2, Math.PI, true);
            ctx.closePath();
            ctx.fill();
            
            ctx.beginPath();
            ctx.moveTo(w, 0);
            ctx.lineTo(w, r);
            ctx.arc(w - r, r, r, 0, -Math.PI/2, true);
            ctx.closePath();
            ctx.fill();
            
            ctx.beginPath();
            ctx.moveTo(w, h);
            ctx.lineTo(w - r, h);
            ctx.arc(w - r, h - r, r, Math.PI/2, 0, true);
            ctx.closePath();
            ctx.fill();
            
            ctx.beginPath();
            ctx.moveTo(0, h);
            ctx.lineTo(0, h - r);
            ctx.arc(r, h - r, r, Math.PI, Math.PI/2, true);
            ctx.closePath();
            ctx.fill();
            
            if (t > 0) {
                ctx.strokeStyle = "#000000";
                
                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(w - r, 0);
                ctx.arc(w - r, r, r, -Math.PI/2, 0, false);
                ctx.lineTo(w, h - r);
                ctx.arc(w - r, h - r, r, 0, Math.PI/2, false);
                ctx.lineTo(r, h);
                ctx.arc(r, h - r, r, Math.PI/2, Math.PI, false);
                ctx.lineTo(0, r);
                ctx.arc(r, r, r, Math.PI, -Math.PI/2, false);
                ctx.closePath();
                ctx.stroke();
            }
        }
        
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: Theme
            function onRadiusChanged() { canvas.requestPaint() }
        }
    }
}
