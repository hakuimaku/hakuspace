pragma Singleton
import QtQuick

QtObject {
    id: root
    
    property string activePanel: ""
    
    // One panel name is active at a time; toggling it closes the panel.
    function toggle(panel: string) {
        if (activePanel === panel) {
            activePanel = ""
        } else {
            activePanel = panel
        }
    }
}
