pragma Singleton
import QtQuick

QtObject {
    id: root
    
    property string activePanel: ""
    property var trayMenu: null
    property var notificationPanel: null

    function toggleNotifications(screenName, anchorX, anchorWidth) {
        if (activePanel === "notifications" && notificationPanel
                && notificationPanel.screenName === screenName) {
            closeNotifications()
            return
        }
        notificationPanel = { screenName: screenName, anchorX: anchorX, anchorWidth: anchorWidth }
        activePanel = "notifications"
    }

    function closeNotifications() {
        if (activePanel === "notifications") activePanel = ""
        notificationPanel = null
    }

    function closeNotificationsIfScreen(screenName) {
        if (notificationPanel && notificationPanel.screenName === screenName)
            closeNotifications()
    }

    function openTrayMenu(item, handle, screenName, anchorX, anchorWidth) {
        trayMenu = {
            item: item,
            handle: handle,
            screenName: screenName,
            anchorX: anchorX,
            anchorWidth: anchorWidth
        }
        activePanel = "tray"
    }

    function closeTrayMenu() {
        if (activePanel === "tray") activePanel = ""
        trayMenu = null
    }

    function closeTrayMenuIfItem(item) {
        if (trayMenu && trayMenu.item === item) closeTrayMenu()
    }

    function closeTrayMenuIfScreen(screenName) {
        if (trayMenu && trayMenu.screenName === screenName) closeTrayMenu()
    }

    onActivePanelChanged: {
        if (activePanel !== "tray") trayMenu = null
        if (activePanel !== "notifications") notificationPanel = null
    }
    
    // One panel name is active at a time; toggling it closes the panel.
    function toggle(panel: string) {
        if (activePanel === panel) {
            activePanel = ""
        } else {
            activePanel = panel
        }
    }
}
