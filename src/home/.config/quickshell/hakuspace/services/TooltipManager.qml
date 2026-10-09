pragma Singleton
import QtQuick
import QtQuick.Window

Item {
    id: root
    
    property var current: null
    property bool shown: false
    property bool warm: false
    property var activeBar: null
    
    Timer {
        id: showTimer
        interval: 400
        onTriggered: root.shown = true
    }
    
    // A short grace period prevents flicker between nearby targets.
    Timer {
        id: graceTimer
        interval: 120
        onTriggered: {
            root.shown = false;
            root.warm = true;
            warmTimer.start();
        }
    }
    
    Timer {
        id: warmTimer
        interval: 300
        onTriggered: root.warm = false
    }
    
    // Associate each tooltip with the top-level bar containing its target.
    function show(target, text, component, props) {
        if (!target) return;
        
        var newText = text !== undefined ? text : "";
        var newComp = component !== undefined ? component : null;
        var newProps = props !== undefined ? props : {};
        
        var isSame = (current && current.target === target && current.text === newText && current.component === newComp);
        
        if (!isSame) {
            current = {
                target: target,
                text: newText,
                component: newComp,
                props: newProps
            };
            
            var p = target;
            while (p && p.parent) {
                p = p.parent;
            }
            activeBar = p;
        }
        
        graceTimer.stop();
        
        if (shown || warm) {
            shown = true;
            showTimer.stop();
        } else if (!showTimer.running) {
            showTimer.start();
        }
    }
    
    function hide(target) {
        if (current && current.target === target) {
            showTimer.stop();
            graceTimer.restart();
        }
    }
}
