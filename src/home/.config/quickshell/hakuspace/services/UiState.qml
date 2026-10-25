pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    property string activePanel: ""
    // Keep keyboard ownership separate from persistent surface visibility.
    property string interactionOwner: ""
    property string interactionScreenName: ""
    signal interactionReleasing(string owner, string screenName)

    // Release the previous lease synchronously before announcing the new owner.
    function claimInteraction(owner, screenName) {
        if (interactionOwner === owner && interactionScreenName === screenName) return
        interactionReleasing(interactionOwner, interactionScreenName)
        interactionOwner = ""
        interactionScreenName = screenName || ""
        interactionOwner = owner
    }

    // Native file dialogs need a normal application window above the requesting layer.
    property string nativeDialogOwner: ""
    property string nativeDialogScreenName: ""
    property int nativeDialogSerial: 0
    signal nativeDialogFinished(string owner, string screenName)
    readonly property bool nativeDialogOpen: nativeDialogOwner.length > 0

    // Suspend the layer's keyboard lease without closing its draft-owning surface.
    function beginNativeDialog(owner) {
        if (nativeDialogOpen || activePanel !== owner) return 0
        nativeDialogOwner = owner
        nativeDialogScreenName = interactionScreenName
        ++nativeDialogSerial
        claimInteraction("nativeDialog", nativeDialogScreenName)
        return nativeDialogSerial
    }

    // A stale dialog callback cannot restore focus on a replaced surface or output.
    function endNativeDialog(serial) {
        if (!nativeDialogOpen || serial !== nativeDialogSerial) return
        var owner = nativeDialogOwner
        var screenName = nativeDialogScreenName
        nativeDialogOwner = ""
        nativeDialogScreenName = ""
        if (interactionOwner === "nativeDialog") {
            if (activePanel === owner) claimInteraction(owner, screenName)
            else releaseInteraction("nativeDialog", screenName)
        }
        nativeDialogFinished(owner, screenName)
    }

    // Match both surface and output so a stale monitor cannot keep focus.
    function ownsInteraction(owner, screenName) {
        return interactionOwner === owner && interactionScreenName === screenName
    }

    // Only the current owner can release its lease.
    function releaseInteraction(owner, screenName) {
        if (ownsInteraction(owner, screenName)) claimInteraction("", "")
    }

    property string navigationMode: "closed"
    property string navigationScreenName: ""
    // Visual ownership intentionally outlives logical navigation state while
    // the close morph finishes, so TopBar left modules do not reappear under
    // an in-flight Navigation surface.
    property string navigationVisualScreenName: ""
    property bool dashboardVisuallyActive: false
    // Captured module anchors use target-screen coordinates.
    property var navigationAnchorRect: null
    property var trayMenu: null
    property var appMenu: null
    property var notificationPanel: null
    property string hakuMenuMode: "closed"
    property string hakuMenuScreenName: ""
    // Retain the source-selected presentation for the current menu lifetime.
    property string hakuMenuStyle: "topFlare"
    property var hakuMenuAnchorRect: null
    property string hakuMenuQuery: ""
    property string hakuMenuSelectionLabel: ""
    // Remember the requested Settings domain when opening from the wallpaper browser.
    property string settingsGroup: ""
    property string wallpaperScreenName: ""
    property bool wallpaperCloseRequested: false
    // Preserve the source menu's actual screen rectangle for a single geometry handoff.
    property string actionMenuScreenName: ""
    property string actionMenuFlow: ""
    property bool actionMenuCloseRequested: false
    property string settingsScreenName: ""
    // Keep the pinned note independent of mutually exclusive panels.
    property bool tempNoteOpen: false
    // Assign the shared scratch editor to exactly one output.
    property string tempNoteScreenName: ""
    // Full-screen modal masks leave visible pinned-note pixels available for pointer handoff.
    property rect tempNoteRect: Qt.rect(0, 0, 0, 0)
    // Let the owning overlay flush and reset before hiding or transferring it.
    signal tempNoteClosing(string screenName)
    // Transfer keyboard input only after an explicit note focus request.
    signal tempNoteFocusRequested(string screenName)
    readonly property string hakuMenuTabLabel: hakuMenuMode === "general" ? "General"
                                                   : hakuMenuMode === "drun" ? "Drun"
                                                   : hakuMenuMode === "theme" ? "Theme"
                                                   : ""
    readonly property string hakuMenuBreadcrumb: hakuMenuSelectionLabel.length > 0
                                                  ? hakuMenuTabLabel + " → " + hakuMenuSelectionLabel
                                                  : hakuMenuTabLabel


    // Clear captured transient anchors before transferring status ownership.
    property Connections chromeConnections: Connections {
        target: ChromeLayout
        function onDockbarActiveChanged() {
            if (!ChromeLayout.dockbarActive && root.hakuMenuStyle === "dockFloating") root.closeHakuMenu()
        }
        function onTaskbarModeChanged() {
            TooltipManager.dismiss()
            root.closeTrayMenu()
            root.closeNotifications()
            root.closeHakuMenu()
            root.closeNavigation()
        }
    }

    // Open the note on one output, finishing any previous ownership first.
    function openTempNote(screenName) {
        if (tempNoteOpen && tempNoteScreenName === screenName) { tempNoteFocusRequested(screenName); return }
        if (activePanel === "navigation") closeNavigation()
        if (tempNoteOpen) closeTempNote()
        tempNoteScreenName = screenName
        tempNoteOpen = true
        tempNoteFocusRequested(screenName)
    }

    // Flush the owning overlay before clearing its visibility and ownership.
    function closeTempNote() {
        if (!tempNoteOpen) return
        tempNoteClosing(tempNoteScreenName)
        tempNoteOpen = false
        tempNoteRect = Qt.rect(0, 0, 0, 0)
        releaseInteraction("tempNote", tempNoteScreenName)
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
    function openNavigation(screenName, anchorRect) {
        if (activePanel === "navigation" && navigationScreenName === screenName && navigationMode !== "closed")
            return
        navigationScreenName = screenName
        navigationVisualScreenName = screenName
        navigationAnchorRect = anchorRect || ScreenGeometry.fallbackModuleAnchor(screenName, Theme.pad, Theme.fontSize * 1.8)
        navigationMode = "open"
        claimInteraction("navigation", screenName)
        activePanel = "navigation"
    }

    // Toggles navigation panel visibility for the specified screen.
    function toggleNavigation(screenName, anchorRect) {
        if (navigationMode !== "closed" && navigationScreenName === screenName) {
            closeNavigation()
            return
        }
        openNavigation(screenName, anchorRect)
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
        navigationAnchorRect = null
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

    // Resolve source availability once; hosts never choose a presentation themselves.
    function resolveHakuMenuPresentation(source) {
        if (!source || source === "default") return ChromeLayout.defaultHakuMenuPresentation
        if (source === "edge") return ChromeLayout.topEdgeHakuMenuEnabled ? "topFlare" : ""
        if (source === "taskbar") return ChromeLayout.taskbarMode ? "bottomFlare" : ""
        if (source === "dockbar") return ChromeLayout.dockbarActive ? "dockFloating" : ""
        return ""
    }

    // Open an available source and capture its real anchor or topology-specific seed.
    function openHakuMenu(screenName, mode, source, anchorRect) {
        var presentation = resolveHakuMenuPresentation(source)
        if (!presentation) return
        var captured = anchorRect
            && [anchorRect.x, anchorRect.y, anchorRect.width, anchorRect.height].every(Number.isFinite)
            && anchorRect.width > 0 && anchorRect.height > 0
            ? {x: anchorRect.x, y: anchorRect.y, width: anchorRect.width, height: anchorRect.height} : null
        if (source === "dockbar" && !captured) return
        hakuMenuStyle = presentation
        hakuMenuAnchorRect = captured
        if (!hakuMenuAnchorRect) {
            for (var output of Quickshell.screens) if (output.name === screenName) {
                var size = ShellSettingsStore.dockIconSize
                hakuMenuAnchorRect = presentation === "topFlare"
                    ? {x: output.width * 0.4, y: 0, width: output.width * 0.2, height: 4}
                    : {x: (output.width - size) / 2, y: output.height - ScreenGeometry.taskbarHeight + 4,
                        width: size, height: size}
                break
            }
        }
        hakuMenuScreenName = screenName
        claimInteraction("hakumenu", screenName)
        hakuMenuMode = (mode === "drun" || mode === "theme" || mode === "general") ? mode : "general"
        hakuMenuQuery = ""
        hakuMenuSelectionLabel = ""
        activePanel = "hakumenu"
    }

    // Toggle matching ownership; a different source presentation replaces the menu.
    function toggleHakuMenu(screenName, mode, source, anchorRect) {
        var nextStyle = resolveHakuMenuPresentation(source)
        if (!nextStyle) return
        if (activePanel === "hakumenu" && hakuMenuScreenName === screenName && hakuMenuStyle === nextStyle) closeHakuMenu()
        else openHakuMenu(screenName, mode, source, anchorRect)
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
        hakuMenuStyle = "topFlare"
        hakuMenuAnchorRect = null
    }

    // Closes HakuMenu if active on the specified screen.
    function closeHakuMenuIfScreen(screenName) {
        if (hakuMenuScreenName === screenName) closeHakuMenu()
    }

    // Opens wallpaper selector panel on the specified screen.
    function openWallpaper(screenName) {
        wallpaperCloseRequested = false
        wallpaperScreenName = screenName
        claimInteraction("wallpaper", screenName)
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

    // Request an animated close. WallpaperBrowserPanel owns the visual sequence and
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
    function toggleNotifications(screenName, anchorRect) {
        if (activePanel === "notifications" && notificationPanel
                && notificationPanel.screenName === screenName) {
            closeNotifications()
            return
        }
        notificationPanel = { screenName: screenName, anchorRect: anchorRect }
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
    function openTrayMenu(item, handle, screenName, anchorRect) {
        trayMenu = {
            item: item,
            handle: handle,
            screenName: screenName,
            anchorRect: anchorRect
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

    // Opens app bar popup menu anchored to an app icon.
    function openAppMenu(app, screenName, anchorRect) {
        appMenu = {
            app: app,
            screenName: screenName,
            anchorRect: anchorRect
        }
        activePanel = "appMenu"
    }

    // Closes app bar popup menu.
    function closeAppMenu() {
        if (activePanel === "appMenu") activePanel = ""
        appMenu = null
    }

    // Closes app bar popup if active on the specified screen.
    function closeAppMenuIfScreen(screenName) {
        if (appMenu && appMenu.screenName === screenName) closeAppMenu()
    }

    // Opens centered settings panel on the specified screen.
    function openSettings(screenName) {
        settingsScreenName = screenName
        claimInteraction("settings", screenName)
        activePanel = "settings"
    }

    // Toggles centered settings panel visibility for the specified screen.
    function toggleSettings(screenName) {
        if (activePanel === "settings" && (!screenName || settingsScreenName === screenName)) {
            closeSettings()
            return
        }
        openSettings(screenName)
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
        claimInteraction("actionMenu", screenName)
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
        var output = activePanel === "navigation" ? navigationScreenName
            : activePanel === "settings" ? settingsScreenName
            : activePanel === "wallpaper" ? wallpaperScreenName
            : activePanel === "actionMenu" ? actionMenuScreenName
            : activePanel === "hakumenu" ? hakuMenuScreenName
            : activePanel === "notifications" && notificationPanel ? notificationPanel.screenName
            : activePanel === "tray" && trayMenu ? trayMenu.screenName
            : activePanel === "appMenu" && appMenu ? appMenu.screenName : ""
        claimInteraction(activePanel, output)
        if (activePanel !== "navigation") {
            navigationMode = "closed"
            navigationScreenName = ""
            navigationAnchorRect = null
        }
        if (activePanel !== "tray") trayMenu = null
        if (activePanel !== "appMenu") appMenu = null
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
            hakuMenuStyle = "topFlare"
            hakuMenuAnchorRect = null
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
