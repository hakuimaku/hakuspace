import QtQuick
import "../services"
import "base" as Base

Item {
    id: root
    required property var modelData
    // Keep lightweight view state after the owning visual trees are destroyed.
    property string settingsCategory: "General"
    property QtObject dashboardState: QtObject {
        property int widgetIndex: 0
        property int calendarMonthOffset: 0
    }
    // Expose resource counts without retaining destroyed surface objects.
    readonly property var loaders: [navigation, settings, note, tray, appMenu, center, wallpaper, wallpaperWorkspace, action, popup, osd, navigator]
    readonly property int loadedCount: loaders.filter(function(loader) { return loader.active }).length + menu.loadedCount
    readonly property var navigationItem: navigation.active ? navigation.item : null

    HakuMenuPanel { id: menu; modelData: root.modelData }
    NotificationPopupFlare { modelData: root.modelData; popup: popup.active ? popup.item : null }

    Base.LifecycleLoader {
        id: navigation
        requested: UiState.activePanel === "navigation" && UiState.navigationScreenName === root.modelData.name
        NavigationPanel { modelData: root.modelData; dashboardState: root.dashboardState }
    }
    Base.LifecycleLoader {
        id: settings
        requested: UiState.activePanel === "settings" && UiState.settingsScreenName === root.modelData.name
        SettingsPanel {
            modelData: root.modelData
            Component.onCompleted: selectCategory(root.settingsCategory)
            onSelectedCategoryChanged: root.settingsCategory = selectedCategory
        }
    }
    Base.LifecycleLoader {
        id: note
        requested: UiState.tempNoteOpen && UiState.tempNoteScreenName === root.modelData.name
        TempNoteOverlay { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: tray
        requested: UiState.activePanel === "tray" && !!UiState.trayMenu && UiState.trayMenu.screenName === root.modelData.name
        TrayMenuPanel { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: appMenu
        requested: UiState.activePanel === "appMenu" && !!UiState.appMenu && UiState.appMenu.screenName === root.modelData.name
        AppBarMenuPanel { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: center
        requested: UiState.activePanel === "notifications" && !!UiState.notificationPanel
            && UiState.notificationPanel.screenName === root.modelData.name
        NotificationCenterPanel { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: wallpaper
        requested: UiState.wallpaperQuickActive && UiState.wallpaperScreenName === root.modelData.name
        WallpaperQuickOverlay { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: wallpaperWorkspace
        requested: UiState.wallpaperWorkspaceActiveFor(root.modelData.name)
        WallpaperWorkspace { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: action
        requested: UiState.activePanel === "actionMenu" && UiState.actionMenuScreenName === root.modelData.name
        ActionMenuPanel { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: popup
        requested: NotificationStore._started && NotificationStore.popupForScreen(root.modelData.name).length > 0
        NotificationPopup { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: osd
        requested: CenterState.osdVisible || CenterState.osdExpansion > 0
        LevelOsdOverlay { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: navigator
        requested: WindowNavigator.active && WindowNavigator.screenName === root.modelData.name
        WindowNavigatorOverlay { modelData: root.modelData }
    }
}
