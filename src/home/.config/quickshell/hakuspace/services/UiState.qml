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
    property bool dashboardVisuallyActive: false
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
    property string actionMenuScreenName: ""
    property string actionMenuFlow: ""
    property bool actionMenuCloseRequested: false
    property string settingsScreenName: ""
    // Keep the pinned note independent of mutually exclusive panels.
    property bool tempNoteOpen: false
    // Assign the shared scratch editor to exactly one output.
    property string tempNoteScreenName: ""
    // Let the owning overlay flush and reset before hiding or transferring it.
    signal tempNoteClosing(string screenName)
    readonly property string hakuMenuTabLabel: hakuMenuMode === "general" ? "General"
                                                   : hakuMenuMode === "drun" ? "Drun"
                                                   : hakuMenuMode === "theme" ? "Theme"
                                                   : ""
    readonly property string hakuMenuBreadcrumb: hakuMenuSelectionLabel.length > 0
                                                  ? hakuMenuTabLabel + " → " + hakuMenuSelectionLabel
                                                  : hakuMenuTabLabel


    // Open the note on one output, finishing any previous ownership first.
    function openTempNote(screenName) {
        if (tempNoteOpen && tempNoteScreenName === screenName) return
        if (tempNoteOpen) closeTempNote()
        tempNoteScreenName = screenName
        tempNoteOpen = true
    }

    // Flush the owning overlay before clearing its visibility and ownership.
    function closeTempNote() {
        if (!tempNoteOpen) return
        tempNoteClosing(tempNoteScreenName)
        tempNoteOpen = false
        tempNoteScreenName = ""
    }

    // Close on the same output or transfer ownership to the requested output.
    function toggleTempNote(screenName) {
        if (tempNoteOpen && tempNoteScreenName === screenName) closeTempNote()
        else openTempNote(screenName)
    }

    // Clear ownership when its output disappears.
    function closeTempNoteIfScreen(screenName) {
        if (tempNoteScreenName === screenName) closeTempNote()
    }

    // Opens navigation surface with anchor coordinates and updates active panel.
    function openNavigation(screenName, anchorX, anchorWidth, anchorHeight, anchorY) {
        if (activePanel === "navigation" && navigationScreenName === screenName && navigationMode !== "closed")
            return
        navigationScreenName = screenName
        navigationVisualScreenName = screenName
        navigationAnchorX = Number.isFinite(anchorX) ? anchorX : 0
        navigationAnchorY = Number.isFinite(anchorY) ? anchorY : Theme.topBarTopPadding
        navigationAnchorWidth = Number.isFinite(anchorWidth) ? anchorWidth : 0
        navigationAnchorHeight = Number.isFinite(anchorHeight) ? anchorHeight : navigationAnchorWidth
        navigationMode = "open"
        activePanel = "navigation"
    }

    // Toggles navigation panel visibility for the specified screen.
    function toggleNavigation(screenName, anchorX, anchorWidth, anchorHeight, anchorY) {
        if (navigationMode !== "closed" && navigationScreenName === screenName) {
            closeNavigation()
            return
        }
        openNavigation(screenName, anchorX, anchorWidth, anchorHeight, anchorY)
    }

    // Transitions navigation mode into handoff state for dashboard, sidebar, or settings.
    function beginNavigationHandoff(target) {
        if (activePanel !== "navigation") return
        if (target !== "dashboard" && target !== "sidebar" && target !== "settings") return
        navigationMode = "handoff-" + target
    }

    // Cancels active handoff transition and returns navigation mode to open.
    function cancelNavigationHandoff() {
        if (activePanel === "navigation" && navigationMode.indexOf("handoff-") === 0) {
            navigationMode = "open"
            dashboardVisuallyActive = false
        }
    }

    // Closes navigation surface and clears active navigation coordinates and mode.
    function closeNavigation() {
        if (activePanel === "navigation") activePanel = ""
        navigationMode = "closed"
        navigationScreenName = ""
        dashboardVisuallyActive = false
        navigationAnchorX = 0
        navigationAnchorY = 0
        navigationAnchorWidth = 0
        navigationAnchorHeight = 0
    }

    // Cleans up visual ownership after navigation close morph finishes on screen.
    function finishNavigationVisual(screenName) {
        if (navigationVisualScreenName !== screenName) return
        // A reopen on the same screen wins over a stale close-animation finish.
        if (activePanel === "navigation" && navigationScreenName === screenName) return
        navigationVisualScreenName = ""
        dashboardVisuallyActive = false
    }

    // Closes navigation if currently active on the matching screen.
    function closeNavigationIfScreen(screenName) {
        if (navigationScreenName === screenName) closeNavigation()
        else if (navigationVisualScreenName === screenName && activePanel !== "navigation")
            navigationVisualScreenName = ""
    }

    // Opens HakuMenu panel in specified tab mode on the given screen.
    function openHakuMenu(screenName, mode) {
        hakuMenuScreenName = screenName
        hakuMenuMode = (mode === "drun" || mode === "theme" || mode === "general") ? mode : "general"
        hakuMenuQuery = ""
        hakuMenuSelectionLabel = ""
        activePanel = "hakumenu"
    }

    // Switches HakuMenu tab mode (general, drun, theme).
    function setHakuMenuMode(mode) {
        if (mode !== "general" && mode !== "drun" && mode !== "theme") return
        if (activePanel !== "hakumenu") return
        hakuMenuMode = mode
        hakuMenuSelectionLabel = ""
    }

    // Sets breadcrumb selection label for the active HakuMenu entry.
    function setHakuMenuSelectionLabel(label) {
        if (activePanel !== "hakumenu") return
        hakuMenuSelectionLabel = label || ""
    }

    // Updates HakuMenu search query and auto-switches mode based on prefix trigger.
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

    // Closes HakuMenu panel and resets query and selection state.
    function closeHakuMenu() {
        if (activePanel === "hakumenu") activePanel = ""
        hakuMenuMode = "closed"
        hakuMenuScreenName = ""
        hakuMenuQuery = ""
        hakuMenuSelectionLabel = ""
    }

    // Closes HakuMenu if active on the specified screen.
    function closeHakuMenuIfScreen(screenName) {
        if (hakuMenuScreenName === screenName) closeHakuMenu()
    }

    // Opens wallpaper selector panel on the specified screen.
    function openWallpaper(screenName) {
        wallpaperCloseRequested = false
        wallpaperScreenName = screenName
        activePanel = "wallpaper"
    }

    // Toggles wallpaper panel visibility for the specified screen.
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

    // Finalizes wallpaper panel close and resets active panel state once animation completes.
    function finishCloseWallpaper(screenName) {
        if (activePanel !== "wallpaper" || wallpaperScreenName !== screenName) return
        wallpaperCloseRequested = false
        activePanel = ""
        wallpaperScreenName = ""
    }

    // Immediately forces wallpaper panel closed without waiting for animation.
    function forceCloseWallpaperIfScreen(screenName) {
        if (wallpaperScreenName !== screenName) return
        wallpaperCloseRequested = false
        if (activePanel === "wallpaper") activePanel = ""
        wallpaperScreenName = ""
    }

    // Requests animated close if wallpaper is active on the specified screen.
    function closeWallpaperIfScreen(screenName) {
        if (wallpaperScreenName === screenName) closeWallpaper()
    }

    // Toggles notification center dropdown panel on a screen.
    function toggleNotifications(screenName, anchorX, anchorWidth) {
        if (activePanel === "notifications" && notificationPanel
                && notificationPanel.screenName === screenName) {
            closeNotifications()
            return
        }
        notificationPanel = { screenName: screenName, anchorX: anchorX, anchorWidth: anchorWidth }
        activePanel = "notifications"
    }

    // Closes notification center dropdown panel.
    function closeNotifications() {
        if (activePanel === "notifications") activePanel = ""
        notificationPanel = null
    }

    // Closes notification panel if active on the specified screen.
    function closeNotificationsIfScreen(screenName) {
        if (notificationPanel && notificationPanel.screenName === screenName)
            closeNotifications()
    }

    // Opens system tray popup menu anchored to a tray item.
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

    // Closes system tray popup menu.
    function closeTrayMenu() {
        if (activePanel === "tray") activePanel = ""
        trayMenu = null
    }

    // Closes system tray popup if currently anchored to the given item.
    function closeTrayMenuIfItem(item) {
        if (trayMenu && trayMenu.item === item) closeTrayMenu()
    }

    // Closes system tray popup if active on the specified screen.
    function closeTrayMenuIfScreen(screenName) {
        if (trayMenu && trayMenu.screenName === screenName) closeTrayMenu()
    }

    // Opens centered settings panel on the specified screen.
    function openSettings(screenName) {
        settingsScreenName = screenName
        activePanel = "settings"
    }

    // Closes centered settings panel.
    function closeSettings() {
        if (activePanel === "settings") activePanel = ""
        settingsScreenName = ""
    }

    // Closes settings panel if active on the specified screen.
    function closeSettingsIfScreen(screenName) {
        if (settingsScreenName === screenName) closeSettings()
    }

    // Opens action menu panel with specified flow page on a screen.
    function openActionMenu(screenName, flow) {
        actionMenuCloseRequested = false
        actionMenuScreenName = screenName
        actionMenuFlow = flow || ""
        activePanel = "actionMenu"
    }

    // Toggles action menu panel visibility for the specified screen and flow.
    function toggleActionMenu(screenName, flow) {
        if (activePanel === "actionMenu" && actionMenuScreenName === screenName && actionMenuFlow === flow) {
            if (actionMenuCloseRequested) {
                actionMenuCloseRequested = false
                return
            }
            closeActionMenu()
            return
        }
        openActionMenu(screenName, flow)
    }

    function closeActionMenu() {
        if (activePanel === "actionMenu") actionMenuCloseRequested = true
    }

    // Finalizes action menu panel close after animation finishes.
    function finishCloseActionMenu(screenName) {
        if (activePanel !== "actionMenu" || actionMenuScreenName !== screenName) return
        actionMenuCloseRequested = false
        activePanel = ""
        actionMenuScreenName = ""
        actionMenuFlow = ""
    }

    // Immediately forces action menu closed without waiting for animation.
    function forceCloseActionMenuIfScreen(screenName) {
        if (actionMenuScreenName !== screenName) return
        actionMenuCloseRequested = false
        if (activePanel === "actionMenu") activePanel = ""
        actionMenuScreenName = ""
        actionMenuFlow = ""
    }

    // Requests animated close if action menu is active on the specified screen.
    function closeActionMenuIfScreen(screenName) {
        if (actionMenuScreenName === screenName) closeActionMenu()
    }

    signal actionMenuScrollNextRequested()
    signal actionMenuScrollPreviousRequested()
    signal actionMenuActivateRequested()

    onActivePanelChanged: {
        if (activePanel !== "navigation") {
            navigationMode = "closed"
            navigationScreenName = ""
            navigationAnchorX = 0
            navigationAnchorY = 0
            navigationAnchorWidth = 0
            navigationAnchorHeight = 0
        }
        if (activePanel !== "tray") trayMenu = null
        if (activePanel !== "notifications") notificationPanel = null
        if (activePanel !== "wallpaper") {
            wallpaperScreenName = ""
            wallpaperCloseRequested = false
        }
        if (activePanel !== "actionMenu") {
            actionMenuScreenName = ""
            actionMenuCloseRequested = false
            actionMenuFlow = ""
        }
        if (activePanel !== "hakumenu") {
            hakuMenuMode = "closed"
            hakuMenuScreenName = ""
            hakuMenuQuery = ""
            hakuMenuSelectionLabel = ""
        }
        if (activePanel !== "settings") {
            settingsScreenName = ""
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
