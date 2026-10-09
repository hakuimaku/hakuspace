pragma Singleton
import QtQuick

QtObject {
    id: root
    
    // Tracks which panel/menu is currently open (hakumenu, launcher, notif, power, wallpaper)
    property string activePanel: ""
    
    function toggle(panel: string) {
        if (activePanel === panel) {
            activePanel = ""
        } else {
            activePanel = panel
        }
    }
}
