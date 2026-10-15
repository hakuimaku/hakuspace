pragma Singleton
import QtQuick
import QtQuick.Window
import "."

Item {
    id: root
    
    property var current: null
    property bool shown: false
    property bool warm: false
    property var activeBar: null

    // Stops pending tooltip timers and hides active tooltip state.
    function dismiss() {
        showTimer.stop();
        graceTimer.stop();
        warmTimer.stop();
        shown = false;
        warm = false;
        current = null;
        activeBar = null;
    }

    // Dismisses active tooltip if it matches the released target.
    function release(target) {
        if (current && current.target === target) dismiss();
    }

    // Recursively verifies visibility of the target through its parent hierarchy.
    function targetVisible(target) {
        if (!target) return false;
        try {
            var p = target;
            while (p) {
                if (p.visible === false) return false;
                p = p.parent;
            }
            return true;
        } catch (e) { return false; }
    }

    Connections {
        target: root.current ? root.current.target : null
        function onVisibleChanged() {
            if (root.current && !root.targetVisible(root.current.target)) root.dismiss();
        }
    }

    Connections {
        target: UiState
        function onActivePanelChanged() {
            if (UiState.activePanel !== "") root.dismiss();
        }
    }
    
    Timer {
        id: showTimer
        interval: 400
        onTriggered: {
            if (root.current && root.targetVisible(root.current.target) && UiState.activePanel === "")
                root.shown = true;
            else root.dismiss();
        }
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
    
    // Associates tooltip payload with target item and schedules display.
    function show(target, text, component, props) {
        if (!target || !targetVisible(target) || UiState.activePanel !== "") return;
        
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
    
    // Cancels show timer and begins grace cooldown period for target.
    function hide(target) {
        if (current && current.target === target) {
            showTimer.stop();
            graceTimer.restart();
        }
    }
}
