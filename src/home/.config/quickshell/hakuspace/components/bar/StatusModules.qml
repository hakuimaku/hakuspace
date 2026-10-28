import "../../services"
import "../../services/ScreenGeometry.js" as Geometry
import "../top" as TopModules
import QtQuick

Item {
    id: root

    // Share module order and preference gates between Top Bar and Taskbar.
    required property string screenName
    required property var ownerWindow
    property string presentation: "top"
    // Bounded bottom windows translate captured anchors into output coordinates once.
    readonly property real screenOffsetY: presentation === "fullBottom" && ownerWindow.screen ? ownerWindow.screen.height - ownerWindow.height : 0
    property bool showCenterCluster: presentation === "top"
    // Hiding the right lane preserves the other lanes' existing geometry.
    property bool showRightCluster: true
    // Expose actual lane limits for the physically centered taskbar viewport.
    readonly property real leftStatusEnd: x + leftModules.x + leftModules.width
    readonly property real rightStatusStart: x + rightLane.x
    readonly property real centerViewportWidth: Geometry.centerSpan(width, leftModules.x + leftModules.width, rightLane.x, Theme.gap)
    readonly property bool navigationVisualActive: UiState.navigationVisualScreenName === screenName
    readonly property real navigationDiameter: Math.max(146, Theme.fontSize * 10.5)
    readonly property real navigationClearEdge: navigationDiameter + 8 + Math.ceil(navigationDiameter * 0.12) + Theme.gap

    onNavigationVisualActiveChanged: {
        if (navigationVisualActive && TooltipManager.activeBar === ownerWindow) {
            TooltipManager.dismiss();
        }
    }
    height: presentation === "fullBottom" ? ScreenGeometry.taskbarHeight : Theme.topBarContentHeight
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Theme.pad
    anchors.rightMargin: Theme.pad

    TrayMenuController {
        id: trayController

        ownerWindow: root.ownerWindow
        screenName: root.screenName
    }

    Flickable {
        id: leftModules
        objectName: "leftStatusModules"

        readonly property real naturalWidth: movingLeftModules.visibleChildren.length > 0 ? movingLeftModules.x + movingLeftModules.width : logoModule.width

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.presentation === "top" ? Theme.topBarTopPadding / 2 : 0
        width: root.presentation === "fullBottom" ? Math.min(naturalWidth, Math.max(0, root.width / 2 - Theme.gap * 2 - ShellSettingsStore.dockIconSize)) : naturalWidth
        contentWidth: naturalWidth
        contentHeight: height
        clip: root.presentation === "fullBottom"
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        height: root.presentation === "fullBottom" ? parent.height : Math.max(logoModule.height, movingLeftModules.height)

        // Logo never participates in the horizontal displacement.
        TopModules.Logo {
            id: logoModule

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            screenName: root.screenName
        }

        Row {
            id: movingLeftModules

            readonly property real baseX: logoModule.width + Theme.gap
            readonly property bool navigationOpen: UiState.activePanel === "navigation" && UiState.navigationMode !== "closed" && (UiState.navigationScreenName === "" || UiState.navigationScreenName === root.screenName)
            readonly property real navigationShift: navigationOpen ? Math.max(0, root.navigationClearEdge - Theme.pad - baseX) : 0

            x: baseX + navigationShift
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap
            opacity: 1
            enabled: true

            // Workspaces, WindowTitle and any future non-Logo left
            // modules belong in this row so they all clear Navigation.
            TopModules.Workspaces {
                visible: ShellSettingsStore.showWorkspaces && WM.supported && items.length > 0
                screenName: root.screenName
                anchors.verticalCenter: parent.verticalCenter
            }

            TopModules.WindowTitle {
                visible: ShellSettingsStore.showWindowTitle
                anchors.verticalCenter: parent.verticalCenter
            }

            // Animates horizontal displacement of left modules to clear expanding navigation controller.
            Behavior on x {
                NumberAnimation {
                    duration: movingLeftModules.navigationOpen ? HAnimation.navigationOpenDuration : 560
                    easing.bezierCurve: [0.18, 1, 0.32, 1, 1, 1]
                }

            }

        }

    }

    Loader {
        objectName: "centerStatusModules"
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.presentation === "top" ? Theme.topBarTopPadding / 2 : 0
        active: root.showCenterCluster
        width: active && item ? item.implicitWidth : 0
        height: active && item ? item.implicitHeight : 0

        sourceComponent: Component {
            Row {
                id: centerCluster

                readonly property real safeSpan: Math.max(0, 2 * Math.min(root.width / 2 - (leftModules.x + leftModules.width) - Theme.gap, root.width / 2 - rightLane.width - Theme.gap))
                readonly property real cavaSlotWidth: cavaModule.hoverSafeWidth
                readonly property bool hakuMenuActive: UiState.activePanel === "hakumenu" && UiState.hakuMenuScreenName === root.screenName
                readonly property bool dashboardActive: (UiState.dashboardVisuallyActive || UiState.navigationMode === "handoff-dashboard") && (UiState.navigationScreenName === "" || UiState.navigationScreenName === root.screenName || UiState.navigationVisualScreenName === root.screenName)
                readonly property bool showCava: ShellSettingsStore.showCava && !hakuMenuActive && !dashboardActive && CenterState.centerMode === "media" && Cava.available && Cava.audioVisible && safeSpan >= cavaSlotWidth + Theme.gap + Theme.fontSize * 3

                spacing: showCava ? Theme.gap : 0
                opacity: (CenterState.osdVisible || CenterState.osdExpansion > 0 || dashboardActive) ? 0 : 1
                enabled: !CenterState.osdVisible && CenterState.osdExpansion === 0 && !dashboardActive

                Item {
                    id: cavaSlot

                    width: centerCluster.showCava ? centerCluster.cavaSlotWidth : 0
                    height: centerModule.implicitHeight
                    visible: width > 0
                    clip: true

                    TopModules.CavaGroup {
                        id: cavaModule

                        anchors.centerIn: parent
                        width: parent.width
                        visible: centerCluster.showCava
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: HAnimation.normal
                            easing.bezierCurve: HAnimation.moduleCurve
                        }

                    }

                }

                TopModules.CenterModule {
                    id: centerModule

                    visible: ShellSettingsStore.showCenter && centerModule.active
                    screenName: root.screenName
                    maximumWidth: Math.max(0, centerCluster.safeSpan - (cavaSlot.width > 0 ? cavaSlot.width + centerCluster.spacing : 0))
                }

                // Animates center cluster spacing when the cava visualizer expands or collapses.
                Behavior on spacing {
                    NumberAnimation {
                        duration: HAnimation.normal
                        easing.bezierCurve: HAnimation.moduleCurve
                    }

                }

                // Animates center cluster opacity when OSD feedback or dashboard becomes active.
                Behavior on opacity {
                    NumberAnimation {
                        duration: HAnimation.fast
                        easing.bezierCurve: HAnimation.effectsCurve
                    }

                }

            }

        }

    }

    Flickable {
        id: rightLane
        objectName: "rightStatusModules"
        visible: root.showRightCluster
        enabled: visible

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.presentation === "top" ? Theme.topBarTopPadding / 2 : 0
        width: root.presentation === "fullBottom" ? Math.min(rightModules.implicitWidth, Math.max(0, root.width / 2 - Theme.gap * 2 - ShellSettingsStore.dockIconSize)) : rightModules.implicitWidth
        height: rightModules.implicitHeight
        contentWidth: rightModules.implicitWidth
        contentHeight: height
        clip: root.presentation === "fullBottom"
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: rightModules

            spacing: Theme.gap

            TopModules.TrayGroup {
                visible: ShellSettingsStore.showTray
                menuOpenItem: UiState.trayMenu ? UiState.trayMenu.item : trayController.trayMenuItem
                onMenuRequested: (item, anchor) => {
                    return trayController.requestTrayMenu(item, anchor);
                }
            }

            TopModules.SettingsGroup {
                objectName: "quick-controls-module"
                visible: ShellSettingsStore.showQuickControls
            }

            TopModules.PowerProfileGroup {
                objectName: "power-profile-module"
                requested: ShellSettingsStore.showPowerProfile
            }

            TopModules.WallpaperGroup {
                visible: ShellSettingsStore.showWallpaperWorkspace
                screenName: root.screenName
            }

            TopModules.RecorderGroup {
                objectName: "screen-recorder-module"
                // Keep the stop control available while recording.
                visible: ShellSettingsStore.showRecorder || isRecording
            }

            TopModules.ClockGroup {
                visible: ShellSettingsStore.showClock
            }

            TopModules.NotificationGroup {
                visible: ShellSettingsStore.showNotifications
                screenName: root.screenName
            }

        }

    }

}
