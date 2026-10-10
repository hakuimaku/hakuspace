pragma Singleton
import QtQuick

QtObject {
    id: root

    property string activePanel: ""
    property string navigationMode: "closed"
    property string navigationScreenName: ""
    // Visual ownership intentionally outlives logical navigation state while
    // the close morph finishes, so TopBar left modules do not reappear under
    // an in-flight Navigation surface.
    property string navigationVisualScreenName: ""
    property real navigationAnchorX: 0
    property real navigationAnchorY: 0
    property real navigationAnchorWidth: 0
    property real navigationAnchorHeight: 0
    property var trayMenu: null
    property var notificationPanel: null
    property string hakuMenuMode: "closed"
    property string hakuMenuScreenName: ""
    property string hakuMenuQuery: ""
    property string hakuMenuSelectionLabel: ""
    property string wallpaperScreenName: ""
    property bool wallpaperCloseRequested: false
    readonly property string hakuMenuTabLabel: hakuMenuMode === "general" ? "General"
                                                   : hakuMenuMode === "drun" ? "Drun"
                                                   : hakuMenuMode === "theme" ? "Theme"
                                                   : ""
    readonly property string hakuMenuBreadcrumb: hakuMenuSelectionLabel.length > 0
                                                  ? hakuMenuTabLabel + " → " + hakuMenuSelectionLabel
                                                  : hakuMenuTabLabel


    function openNavigation(screenName, anchorX, anchorWidth, anchorHeight, anchorY) {
        navigationScreenName = screenName
        navigationVisualScreenName = screenName
        navigationAnchorX = Number.isFinite(anchorX) ? anchorX : 0
        navigationAnchorY = Number.isFinite(anchorY) ? anchorY : Theme.topBarTopPadding
        navigationAnchorWidth = Number.isFinite(anchorWidth) ? anchorWidth : 0
        navigationAnchorHeight = Number.isFinite(anchorHeight) ? anchorHeight : navigationAnchorWidth
        navigationMode = "open"
        activePanel = "navigation"
    }

    function toggleNavigation(screenName, anchorX, anchorWidth, anchorHeight, anchorY) {
        if (navigationMode !== "closed" && navigationScreenName === screenName) {
            closeNavigation()
            return
        }
        openNavigation(screenName, anchorX, anchorWidth, anchorHeight, anchorY)
    }

    function beginNavigationHandoff(target) {
        if (activePanel !== "navigation") return
        if (target !== "dashboard" && target !== "sidebar" && target !== "settings") return
        navigationMode = "handoff-" + target
    }

    function cancelNavigationHandoff() {
        if (activePanel === "navigation" && navigationMode.indexOf("handoff-") === 0)
            navigationMode = "open"
    }

    function closeNavigation() {
        if (activePanel === "navigation") activePanel = ""
        navigationMode = "closed"
        navigationScreenName = ""
        navigationAnchorX = 0
        navigationAnchorY = 0
        navigationAnchorWidth = 0
        navigationAnchorHeight = 0
    }

    function finishNavigationVisual(screenName) {
        if (navigationVisualScreenName !== screenName) return
        // A reopen on the same screen wins over a stale close-animation finish.
        if (activePanel === "navigation" && navigationScreenName === screenName) return
        navigationVisualScreenName = ""
    }

    function closeNavigationIfScreen(screenName) {
        if (navigationScreenName === screenName) closeNavigation()
        else if (navigationVisualScreenName === screenName && activePanel !== "navigation")
            navigationVisualScreenName = ""
    }

    function openHakuMenu(screenName, mode) {
        hakuMenuScreenName = screenName
        hakuMenuMode = (mode === "drun" || mode === "theme" || mode === "general") ? mode : "general"
        hakuMenuQuery = ""
        hakuMenuSelectionLabel = ""
        activePanel = "hakumenu"
    }

    function setHakuMenuMode(mode) {
        if (mode !== "general" && mode !== "drun" && mode !== "theme") return
        if (activePanel !== "hakumenu") return
        hakuMenuMode = mode
        hakuMenuSelectionLabel = ""
    }

    function setHakuMenuSelectionLabel(label) {
        if (activePanel !== "hakumenu") return
        hakuMenuSelectionLabel = label || ""
    }

    function setHakuMenuQuery(query) {
        hakuMenuQuery = query
        if (activePanel !== "hakumenu" || query.length === 0) return

        var nextMode = query.charAt(0) === ">" ? "general"
                     : query.charAt(0) === "~" ? "theme"
                     : "drun"
        if (hakuMenuMode !== nextMode) {
            hakuMenuMode = nextMode
            hakuMenuSelectionLabel = ""
        }
    }

    function closeHakuMenu() {
        if (activePanel === "hakumenu") activePanel = ""
        hakuMenuMode = "closed"
        hakuMenuScreenName = ""
        hakuMenuQuery = ""
        hakuMenuSelectionLabel = ""
    }

    function closeHakuMenuIfScreen(screenName) {
        if (hakuMenuScreenName === screenName) closeHakuMenu()
    }

    function openWallpaper(screenName) {
        wallpaperCloseRequested = false
        wallpaperScreenName = screenName
        activePanel = "wallpaper"
    }

    function toggleWallpaper(screenName) {
        if (activePanel === "wallpaper" && wallpaperScreenName === screenName) {
            // A second toggle while the close animation is running reopens the
            // existing surface instead of tearing the layer down mid-motion.
            if (wallpaperCloseRequested) {
                wallpaperCloseRequested = false
                return
            }
            closeWallpaper()
            return
        }
        openWallpaper(screenName)
    }

    // Request an animated close. WallpaperPanel owns the visual sequence and
    // calls finishCloseWallpaper only after the close animation has faded out.
    function closeWallpaper() {
        if (activePanel === "wallpaper") wallpaperCloseRequested = true
    }

    function finishCloseWallpaper(screenName) {
        if (activePanel !== "wallpaper" || wallpaperScreenName !== screenName) return
        wallpaperCloseRequested = false
        activePanel = ""
        wallpaperScreenName = ""
    }

    function forceCloseWallpaperIfScreen(screenName) {
        if (wallpaperScreenName !== screenName) return
        wallpaperCloseRequested = false
        if (activePanel === "wallpaper") activePanel = ""
        wallpaperScreenName = ""
    }

    function closeWallpaperIfScreen(screenName) {
        if (wallpaperScreenName === screenName) closeWallpaper()
    }

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
        if (activePanel !== "navigation") {
            navigationMode = "closed"
            navigationScreenName = ""
            navigationAnchorX = 0
            navigationAnchorWidth = 0
            navigationAnchorHeight = 0
        }
        if (activePanel !== "tray") trayMenu = null
        if (activePanel !== "notifications") notificationPanel = null
        if (activePanel !== "wallpaper") {
            wallpaperScreenName = ""
            wallpaperCloseRequested = false
        }
        if (activePanel !== "hakumenu") {
            hakuMenuMode = "closed"
            hakuMenuScreenName = ""
            hakuMenuQuery = ""
            hakuMenuSelectionLabel = ""
        }
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
