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
    
    function show(target, text, component, props) {
        if (!target) return;
        
        var newText = text !== undefined ? text : "";
        var newComp = component !== undefined ? component : null;
        var newProps = props !== undefined ? props : {};
        
        if (current && current.target === target && current.text === newText && current.component === newComp) {
            return;
        }
        
        current = {
            target: target,
            text: newText,
            component: newComp,
            props: newProps
        };
        
        var p = target;
        var debugP = target; while(debugP) { console.log("target ancestor:", debugP); debugP = debugP.parent; }
        while (p && p.parent) {
            p = p.parent;
        }
        activeBar = p;
        
        console.log("TOOLTIP MANAGER: target=", target, " text=", newText, " activeBar=", activeBar, " warm=", warm, " shown=", shown);
        
        graceTimer.stop();
        
        if (shown || warm) {
            shown = true;
            showTimer.stop();
        } else if (!showTimer.running) {
            showTimer.restart();
        }
    }
    
    function hide(target) {
        if (current && current.target === target) {
            showTimer.stop();
            graceTimer.restart();
        }
    }
}
