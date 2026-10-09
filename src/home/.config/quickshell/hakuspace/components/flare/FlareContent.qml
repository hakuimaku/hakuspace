import QtQuick
import "../../services"

Item {
    id: root
    property Component contentComponent: null
    property var contentProps: ({})
    property var contentKey: null
    property real maxWidth: 360
    
    property real naturalWidth: 0
    property real naturalHeight: 0
    
    property bool shown: false
    property bool useA: true
    property var lastKey: null

    function applyProps(item) {
        if (!item || !contentProps) return
        for (var key in contentProps) {
            if (key in item) item[key] = contentProps[key]
        }
    }

    function syncActive() {
        var activeLoader = useA ? loaderA : loaderB
        if (activeLoader.sourceComponent !== contentComponent)
            activeLoader.sourceComponent = contentComponent
        applyProps(activeLoader.item)
        Qt.callLater(updateSize)
    }
    
    onShownChanged: {
        if (shown) {
            hideTimer.stop()
            syncActive()
        }
    }

    onContentComponentChanged: syncActive()
    
    onContentPropsChanged: {
        var activeLoader = useA ? loaderA : loaderB;
        applyProps(activeLoader.item)
        Qt.callLater(updateSize)
    }
    
    onContentKeyChanged: {
        hideTimer.stop();
        if (contentKey !== lastKey) {
            useA = !useA;
            lastKey = contentKey;
        }
        
        syncActive()
    }
    
    function updateSize() {
        var activeLoader = useA ? loaderA : loaderB;
        if (activeLoader.item) {
            naturalWidth = activeLoader.item.implicitWidth || 0;
            naturalHeight = activeLoader.item.implicitHeight || 0;
        } else {
            naturalWidth = 0; naturalHeight = 0;
        }
    }
    
    function settle(isShown) {
        if (!isShown) {
            hideTimer.restart();
        }
    }
    
    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: {
            loaderA.sourceComponent = null;
            loaderB.sourceComponent = null;
        }
    }
    
    Loader {
        id: loaderA
        anchors.centerIn: parent
        onImplicitWidthChanged: Qt.callLater(root.updateSize)
        onImplicitHeightChanged: Qt.callLater(root.updateSize)
        opacity: useA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: HAnimation.effects } }
        onOpacityChanged: { if (opacity === 0) sourceComponent = null; }
        onLoaded: {
            if (useA) root.applyProps(item)
            Qt.callLater(updateSize);
        }
    }
    
    Loader {
        id: loaderB
        anchors.centerIn: parent
        onImplicitWidthChanged: Qt.callLater(root.updateSize)
        onImplicitHeightChanged: Qt.callLater(root.updateSize)
        opacity: !useA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: HAnimation.effects } }
        onOpacityChanged: { if (opacity === 0) sourceComponent = null; }
        onLoaded: {
            if (!useA) root.applyProps(item)
            Qt.callLater(updateSize);
        }
    }
}
