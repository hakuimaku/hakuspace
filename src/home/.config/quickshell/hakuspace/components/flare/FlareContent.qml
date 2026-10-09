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
    
    property bool useA: true
    property var lastKey: null
    
    onContentKeyChanged: {
        hideTimer.stop();
        if (contentKey !== lastKey) {
            useA = !useA;
            lastKey = contentKey;
        }
        
        var activeLoader = useA ? loaderA : loaderB;
        activeLoader.sourceComponent = contentComponent;
        
        if (activeLoader.item) {
            for (var k in contentProps) {
                activeLoader.item[k] = contentProps[k];
            }
        }
        
        Qt.callLater(updateSize);
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
        var inactiveLoader = useA ? loaderB : loaderA;
        if (inactiveLoader.opacity === 0) {
            inactiveLoader.sourceComponent = null;
        }
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
        opacity: useA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: HAnimation.effects } }
        onLoaded: {
            if (useA && root.contentProps) {
                for (var k in root.contentProps) item[k] = root.contentProps[k];
            }
            Qt.callLater(updateSize);
        }
    }
    
    Loader {
        id: loaderB
        anchors.centerIn: parent
        opacity: !useA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: HAnimation.effects } }
        onLoaded: {
            if (!useA && root.contentProps) {
                for (var k in root.contentProps) item[k] = root.contentProps[k];
            }
            Qt.callLater(updateSize);
        }
    }
}
