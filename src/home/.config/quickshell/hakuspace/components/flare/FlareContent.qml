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
    property int fadeDuration: HAnimation.effects
    property bool useA: true
    property bool displayA: true
    property var lastKey: null
    property var measuredItem: null
    readonly property var activeLoader: useA ? loaderA : loaderB
    readonly property bool ready: shown && activeLoader.status === Loader.Ready
                                  && activeLoader.item === measuredItem
                                  && isFinite(naturalWidth) && naturalWidth > 0
                                  && isFinite(naturalHeight) && naturalHeight > 0

    onReadyChanged: { if (ready) displayA = useA }
    Component.onCompleted: { if (shown) syncActive() }

    function applyProps(item) {
        if (!item || !contentProps) return
        for (var key in contentProps) {
            if (key in item) item[key] = contentProps[key]
        }
    }

    function syncActive() {
        if (!shown) return
        var activeLoader = useA ? loaderA : loaderB
        if (activeLoader.sourceComponent !== contentComponent)
            activeLoader.sourceComponent = contentComponent
        applyProps(activeLoader.item)
        Qt.callLater(updateSize)
    }
    
    onShownChanged: {
        if (shown) {
            hideTimer.stop()
            measuredItem = null
            Qt.callLater(syncActive)
        } else hideTimer.restart()
    }

    onContentComponentChanged: {
        measuredItem = null
        Qt.callLater(syncActive)
    }
    
    onContentPropsChanged: {
        measuredItem = null
        Qt.callLater(syncActive)
    }
    
    onContentKeyChanged: {
        if (shown) hideTimer.stop();
        measuredItem = null;
        if (contentKey !== lastKey) {
            useA = !useA;
            lastKey = contentKey;
        }
        
        Qt.callLater(syncActive)
    }
    
    function updateSize() {
        var activeLoader = useA ? loaderA : loaderB;
        if (activeLoader.status !== Loader.Ready || !activeLoader.item) return;
        var width = activeLoader.item.implicitWidth;
        var height = activeLoader.item.implicitHeight;
        if (!isFinite(width) || width <= 0 || !isFinite(height) || height <= 0) {
            measuredItem = null;
            return;
        }
        naturalWidth = width;
        naturalHeight = height;
        measuredItem = activeLoader.item;
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
        opacity: displayA ? 1 : 0
        Behavior on opacity {
            enabled: root.fadeDuration > 0 && loaderA.item && loaderB.item
            NumberAnimation { duration: root.fadeDuration }
        }
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
        opacity: !displayA ? 1 : 0
        Behavior on opacity {
            enabled: root.fadeDuration > 0 && loaderA.item && loaderB.item
            NumberAnimation { duration: root.fadeDuration }
        }
        onOpacityChanged: { if (opacity === 0) sourceComponent = null; }
        onLoaded: {
            if (!useA) root.applyProps(item)
            Qt.callLater(updateSize);
        }
    }
}
