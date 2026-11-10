import QtQuick
import "../../services"
import "../../services/WM"
import "../top" as TopModules
import "LeftBarGeometry.js" as LeftBarGeometry

Item {
    id: root
    // Each output owns its anchors and tray menu lifecycle.
    required property string screenName
    required property var ownerWindow
    // Hide only this output's leading modules until the workspace close finishes.
    readonly property bool wallpaperWorkspaceActive: UiState.wallpaperWorkspaceActiveFor(screenName)
    readonly property bool wallpaperWorkspaceHidden: wallpaperWorkspaceActive && !UiState.wallpaperCloseRequested
    property real wallpaperOpacity: 1
    onWallpaperWorkspaceHiddenChanged: {
        wallpaperFade.stop()
        wallpaperFade.from = wallpaperOpacity
        if (wallpaperWorkspaceHidden) {
            wallpaperFade.to = 0
            wallpaperFade.restart()
        } else if (wallpaperWorkspaceActive) {
            wallpaperFade.to = 1
            wallpaperFade.restart()
        } else {
            wallpaperOpacity = 1
        }
    }
    onWallpaperWorkspaceActiveChanged: {
        if (!wallpaperWorkspaceActive) {
            wallpaperFade.stop()
            wallpaperOpacity = 1
        }
    }
    NumberAnimation {
        id: wallpaperFade
        target: root; property: "wallpaperOpacity"
        duration: HAnimation.slow
        easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.tooltipCurve
    }
    readonly property bool navigationOpen: UiState.activePanel === "navigation" && UiState.navigationScreenName === screenName
    readonly property bool navigationVisualActive: UiState.navigationVisualScreenName === screenName
    readonly property bool navigationWorkspaceHidden: navigationOpen || (navigationVisualActive && !UiState.navigationWorkspaceReturnReady)
    onNavigationVisualActiveChanged: {
        if (!navigationVisualActive) return
        if (TooltipManager.activeBar === ownerWindow) TooltipManager.dismiss()
        trayController.closeTrayMenu()
        UiState.closeTrayMenuIfScreen(screenName)
    }
    readonly property var lanes: LeftBarGeometry.lanes(ScreenGeometry.leftbarUsableBottom(screenName),
        logoSlot.y + logoSlot.height, workspaces.visible ? workspaces.height + ScreenGeometry.leftModuleInset * 2 : 0,
        status.height + ScreenGeometry.leftModuleInset * 2, ShellSettingsStore.showWindowTitle ? windowTitle.preferredVerticalHeight : 0,
        Math.max(12, ScreenGeometry.leftModuleGap), ScreenGeometry.leftModuleInset, Theme.fontSize)

    TrayMenuController {
        id: trayController
        screenName: root.screenName
        ownerWindow: root.ownerWindow
    }

    // The Logo slot survives Navigation taking over its painted glyph.
    Item {
        id: logoSlot
        objectName: "leftbar-logo-slot"
        opacity: root.wallpaperOpacity
        enabled: !root.wallpaperWorkspaceActive
        y: ScreenGeometry.leftModuleInset
        width: parent.width
        height: ScreenGeometry.leftModuleTouchSize
        TopModules.Logo {
            anchors.centerIn: parent
            hoverAxis: "vertical"
            compactVisual: true
            hoverExpansion: 0
            iconFontSize: Theme.fontSize
            navigationAnchorItem: visualItem
            implicitWidth: implicitHeight
            screenName: root.screenName
        }
    }
    Flickable {
        id: workspaceLane
        objectName: "leftbar-workspace-lane"
        property real navigationOpacity: 1
        opacity: (root.navigationWorkspaceHidden ? 0 : navigationOpacity) * root.wallpaperOpacity
        enabled: !root.navigationWorkspaceHidden && !root.wallpaperWorkspaceActive
        // Fade after the close midpoint; reopening Navigation hides the lane immediately.
        Connections {
            target: root
            function onNavigationWorkspaceHiddenChanged() {
                workspaceReturn.stop()
                if (root.navigationWorkspaceHidden) workspaceLane.navigationOpacity = 0
                else if (root.navigationVisualActive) workspaceReturn.restart()
                else workspaceLane.navigationOpacity = 1
            }
            function onNavigationVisualActiveChanged() {
                if (root.navigationVisualActive) return
                workspaceReturn.stop()
                workspaceLane.navigationOpacity = 1
            }
        }
        NumberAnimation {
            id: workspaceReturn
            target: workspaceLane; property: "navigationOpacity"
            from: 0; to: 1; duration: HAnimation.effects
            easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.effectsCurve
        }
        y: root.lanes.upperY
        width: parent.width
        height: root.lanes.upperHeight
        contentHeight: workspaces.height + ScreenGeometry.leftModuleInset * 2
        contentWidth: width
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        TopModules.Workspaces {
            id: workspaces
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            hoverAxis: "vertical"
            vertical: true
            implicitWidth: ScreenGeometry.leftModuleTouchSize
            screenName: root.screenName
            visible: ShellSettingsStore.showWorkspaces && WM.supported && items.length > 0
        }
    }
    TopModules.WindowTitle {
        id: windowTitle
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.lanes.titleY + (root.lanes.titleHeight - height) / 2
        vertical: true
        maximumLength: root.lanes.titleHeight
        visible: ShellSettingsStore.showWindowTitle
    }
    // The bottom lane scrolls independently and keeps the clock and bell at its trailing edge.
    Flickable {
        id: bottomLane
        objectName: "leftbar-bottom-lane"
        y: root.lanes.bottomY
        width: parent.width
        height: root.lanes.bottomHeight
        contentWidth: width
        contentHeight: status.height + ScreenGeometry.leftModuleInset * 2
        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
        onHeightChanged: contentY = Math.max(0, contentHeight - height)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: status
            anchors.horizontalCenter: parent.horizontalCenter
            y: ScreenGeometry.leftModuleInset + Math.max(0, bottomLane.height - bottomLane.contentHeight)
            spacing: ScreenGeometry.leftModuleGap
            TopModules.TrayGroup {
                objectName: "tray-module"
                vertical: true
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ShellSettingsStore.showTray
                menuOpenItem: UiState.trayMenu ? UiState.trayMenu.item : trayController.trayMenuItem
                onMenuRequested: (item, anchor) => trayController.requestTrayMenu(item, anchor)
            }
            TopModules.SettingsGroup {
                vertical: true
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ShellSettingsStore.showQuickControls
            }
            TopModules.ClockGroup {
                anchors.horizontalCenter: parent.horizontalCenter
                vertical: true
                visible: ShellSettingsStore.showClock
            }
            TopModules.NotificationGroup {
                anchors.horizontalCenter: parent.horizontalCenter
                compact: true
                screenName: root.screenName
                visible: ShellSettingsStore.showNotifications
            }
        }
    }
}
