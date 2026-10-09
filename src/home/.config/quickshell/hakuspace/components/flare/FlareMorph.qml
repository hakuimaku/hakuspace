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
    property int openDuration: HAnimation.normal
    property int closeDuration: HAnimation.normal
    property var openWidthCurve: HAnimation.spatialCurve
    property var closeWidthCurve: HAnimation.spatialCurve
    property var openHeightCurve: HAnimation.moduleCurve
    property var closeHeightCurve: HAnimation.moduleCurve
    // Width retargets while already open (for example HakuMenu tab-size changes)
    // use their own calmer profile. Initial opening remains a vertical slide.
    property int retargetDuration: HAnimation.normal
    property var retargetWidthCurve: HAnimation.spatialCurve
    property var _activeWidthCurve: openWidthCurve
    
    property real mStart: 0
    property real mEnd: 0
    property real mHeight: 0
    property bool hugging: false
    
    signal settled(bool isShown)
    
    property var _lastExpected: ({start: 0, end: 0, height: 0})
    property real _lastAnimTime: 0
    
    Timer {
        id: throttleTimer
        interval: 60
        onTriggered: updateTargetBounds()
    }
    
    function checkSettled() {
        if (!animStart.running && !animEnd.running && !animHeight.running) {
            root.settled(root.shown);
        }
    }
    
    function anchorSpan() {
        if (!anchorItem) return null;
        var t = anchorItem;
        var pt;
        try {
            var mapRoot = root;
            while(mapRoot.parent) mapRoot = mapRoot.parent;
            pt = t.mapToItem(mapRoot, 0, 0);
        } catch(e) { return null; }
        var tW = t.implicitWidth > 0 ? t.implicitWidth : t.width;
        return {start: pt.x, end: pt.x + tW};
    }

    function updateTargetBounds() {
        if (!shown) return;
        var anchor = anchorSpan();
        if (!anchor) return;
        
        var res = FG.resolveSpan({
            anchorStart: anchor.start, anchorEnd: anchor.end, contentW: contentW, padX: padX, minW: minW, maxW: maxW,
            bounds: bounds, snap: snap
        });
        
        var eL = res.start;
        var eR = res.end;
        var eH = contentH + padY;
        
        hugging = (eL <= bounds.start || eR >= bounds.end);
        
        // Initial open keeps the established HakuMenu slide-down motion:
        // resolve the final horizontal span immediately, then animate only
        // vertical reveal. Width animation is reserved for in-place retargets
        // such as General <-> Drun/Theme resizing.
        if (mHeight <= 0.01 && eH > 0
                && !animStart.running && !animEnd.running && !animHeight.running) {
            mStart = eL;
            mEnd = eR;
            mHeight = 0;
            _lastExpected = {start: eL, end: eR, height: eH};

            animHeight.to = eH;
            animHeight.duration = openDuration;
            animHeight.restart();
            return;
        }
        
        var now = Date.now();
        var isRetarget = FG.needsRetarget(_lastExpected, {start: eL, end: eR}, 2) || Math.abs(_lastExpected.height - eH) > 2
                         || animHeight.to !== eH;
        
        if (isRetarget) {
            if (now - _lastAnimTime >= 60) {
                _lastAnimTime = now;
                _lastExpected = {start: eL, end: eR, height: eH};
                
                // Already-open width changes use the dedicated retarget profile.
                // This keeps tab-size morphs gentle without changing first-open motion.
                _activeWidthCurve = retargetWidthCurve;

                if (Math.abs(eL - mStart) > 0.5) {
                    animStart.duration = retargetDuration;
                    animStart.to = eL;
                    animStart.restart();
                }
                
                if (Math.abs(eR - mEnd) > 0.5) {
                    animEnd.duration = retargetDuration;
                    animEnd.to = eR;
                    animEnd.restart();
                }
                
                if (Math.abs(eH - mHeight) > 0.5) {
                    animHeight.to = eH;
                    animHeight.duration = openDuration;
                    animHeight.restart();
                }
            } else {
                throttleTimer.restart();
            }
        }
    }
    
    onShownChanged: {
        if (shown) {
            Qt.callLater(updateTargetBounds);
        } else {
            throttleTimer.stop();

            // Opening resolves the horizontal span first and then reveals the
            // surface vertically. Closing is the exact visual reverse: keep
            // the current span stable while the surface slides back up. Once
            // height reaches zero, the span can snap to the anchor invisibly.
            animStart.stop();
            animEnd.stop();
            animHeight.to = 0;
            animHeight.duration = closeDuration;
            animHeight.restart();
        }
    }
    
    onAnchorItemChanged: { Qt.callLater(updateTargetBounds); }
    
    Connections {
        target: shown && anchorItem ? anchorItem : null
        function onXChanged() { Qt.callLater(updateTargetBounds); }
        function onWidthChanged() { Qt.callLater(updateTargetBounds); }
    }
    
    onContentWChanged: { Qt.callLater(updateTargetBounds); }
    onContentHChanged: { Qt.callLater(updateTargetBounds); }
    
    NumberAnimation { id: animStart; target: root; property: "mStart"; easing.bezierCurve: root._activeWidthCurve; onFinished: checkSettled() }
    NumberAnimation { id: animEnd; target: root; property: "mEnd"; easing.bezierCurve: root._activeWidthCurve; onFinished: checkSettled() }
    NumberAnimation {
        id: animHeight
        target: root
        property: "mHeight"
        duration: HAnimation.normal
        easing.bezierCurve: root.shown ? root.openHeightCurve : root.closeHeightCurve
        onFinished: {
            if (!root.shown && root.mHeight <= 0.01) {
                var anchor = root.anchorSpan();
                if (anchor) {
                    root.mStart = anchor.start;
                    root.mEnd = anchor.end;
                }
            }
            checkSettled();
        }
    }
}
