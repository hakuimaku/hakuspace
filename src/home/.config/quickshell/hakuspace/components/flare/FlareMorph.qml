import QtQuick
import "../../services"
import "FlareGeometry.js" as FG

Item {
    id: root
    property Item anchorItem: null
    property real contentW: 0
    property real contentH: 0
    property bool shown: false
    property var bounds: ({start: 0, end: 1920})
    
    property real minW: 80
    property real maxW: 360
    property real padX: 24
    property real padY: 16
    property real snap: 48
    
    property real mStart: 0
    property real mEnd: 0
    property real mHeight: 0
    property bool hugging: false
    
    signal settled(bool isShown)
    
    property var _lastExpected: ({start: 0, end: 0, height: 0})
    property real _lastAnimTime: 0
    
    function updateTargetBounds() {
        if (!shown || !anchorItem) return;
        var t = anchorItem;
        var pt;
        try {
            var mapRoot = root;
            while(mapRoot.parent) mapRoot = mapRoot.parent;
            pt = t.mapToItem(mapRoot, 0, 0);
        } catch(e) { return; }
        
        var aStart = pt.x;
        var tW = t.implicitWidth > 0 ? t.implicitWidth : t.width;
        var aEnd = pt.x + tW;
        
        var res = FG.resolveSpan({
            anchorStart: aStart, anchorEnd: aEnd, contentW: contentW, padX: padX, minW: minW, maxW: maxW,
            bounds: bounds, snap: snap
        });
        
        var eL = res.start;
        var eR = res.end;
        var eH = contentH + padY;
        
        hugging = (eL <= bounds.start || eR >= bounds.end);
        
        if (mHeight === 0 && eH > 0 && !animHeight.running) {
            mStart = eL;
            mEnd = eR;
            _lastExpected = {start: eL, end: eR, height: eH};
            animHeight.to = eH;
            animHeight.restart();
            return;
        }
        
        var now = Date.now();
        if (FG.needsRetarget(_lastExpected, {start: eL, end: eR}, 2) && (now - _lastAnimTime >= 60)) {
            _lastAnimTime = now;
            _lastExpected = {start: eL, end: eR, height: eH};
            
            var goingLeft = eL < mStart;
            var durs = FG.durations(goingLeft, HAnimation.normal, HAnimation.trailFactor);
            
            if (Math.abs(eL - mStart) > 0.5) {
                animStart.duration = durs.startMs;
                animStart.to = eL;
                if (!animStart.running) animStart.restart();
            }
            
            if (Math.abs(eR - mEnd) > 0.5) {
                animEnd.duration = durs.endMs;
                animEnd.to = eR;
                if (!animEnd.running) animEnd.restart();
            }
            
            if (Math.abs(eH - mHeight) > 0.5) {
                animHeight.to = eH;
                if (!animHeight.running) animHeight.restart();
            }
        } else if (animStart.running || animEnd.running || animHeight.running) {
            animStart.to = eL;
            animEnd.to = eR;
            animHeight.to = eH;
        }
    }
    
    onShownChanged: {
        if (shown) {
            Qt.callLater(updateTargetBounds);
        } else {
            animHeight.to = 0;
            animHeight.restart();
        }
    }
    
    Connections {
        target: shown && anchorItem ? anchorItem : null
        function onXChanged() { Qt.callLater(updateTargetBounds); }
        function onWidthChanged() { Qt.callLater(updateTargetBounds); }
    }
    
    onContentWChanged: { Qt.callLater(updateTargetBounds); }
    onContentHChanged: { Qt.callLater(updateTargetBounds); }
    
    NumberAnimation { id: animStart; target: root; property: "mStart"; easing.bezierCurve: HAnimation.spatialCurve; onFinished: root.settled(root.shown) }
    NumberAnimation { id: animEnd; target: root; property: "mEnd"; easing.bezierCurve: HAnimation.spatialCurve; onFinished: root.settled(root.shown) }
    NumberAnimation { id: animHeight; target: root; property: "mHeight"; duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve; onFinished: root.settled(root.shown) }
}
