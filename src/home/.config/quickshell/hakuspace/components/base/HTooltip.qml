import QtQuick
import "../../services"

Item {
    id: root
    property string text: ""
    property Component component: null
    property Item target: null
    property bool active: false
    
    onActiveChanged: {
        if (active && (text.length > 0 || component)) {
            TooltipManager.show(target, text, component);
        } else {
            TooltipManager.hide(target);
        }
    }
    
    onTextChanged: {
        if (active && (text.length > 0 || component)) {
            TooltipManager.show(target, text, component);
        } else if (active) {
            TooltipManager.release(target);
        }
    }
    
    onComponentChanged: {
        if (active && (text.length > 0 || component)) {
            TooltipManager.show(target, text, component);
        } else if (active) {
            TooltipManager.release(target);
        }
    }

    Component.onDestruction: TooltipManager.release(target)
}
