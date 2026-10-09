import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../services"
import "top" as TopModules
import "base"
import "flare" as Flare

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    
    property real barH: Theme.topBarHeight
    property real tipAreaH: 160
    property var trayMenuItem: null
    property Item trayMenuAnchor: null
    property string lastTrayFallbackReason: ""
    readonly property int trayRowCount: trayOpener.children.values.length
    onTrayRowCountChanged: {
        if (trayMenuItem && trayRowCount > 0) menuSettled.restart()
    }

    function closeTrayMenu() {
        menuTimeout.stop()
        menuSettled.stop()
        trayMenuItem = null
        trayMenuAnchor = null
    }

    function platformMenu(item, anchor, reason) {
        lastTrayFallbackReason = reason
        if (!item || !anchor) return
        if (item.hasMenu) {
            var point = anchor.mapToItem(null, 0, anchor.height)
            item.display(root, point.x, point.y)
        } else {
            item.secondaryActivate()
        }
    }

    function requestTrayMenu(item, anchor) {
        if (UiState.trayMenu && UiState.trayMenu.item === item) {
            UiState.closeTrayMenu()
            return
        }
        if (trayMenuItem === item) {
            closeTrayMenu()
            return
        }
        closeTrayMenu()
        if (UiState.activePanel !== "") UiState.activePanel = ""
        UiState.closeTrayMenu()
        if (!item || !item.hasMenu || !item.menu) {
            platformMenu(item, anchor, "no menu handle")
            return
        }
        TooltipManager.dismiss()
        trayMenuItem = item
        trayMenuAnchor = anchor
        menuTimeout.restart()
        if (trayRowCount > 0) menuSettled.restart()
    }

    function openTrayPanel() {
        if (!trayMenuItem || !trayMenuAnchor) return
        var item = trayMenuItem
        var anchor = trayMenuAnchor
        var x = anchor.mapToItem(null, 0, 0).x
        closeTrayMenu()
        UiState.openTrayMenu(item, item.menu, root.modelData.name, x, anchor.width)
    }

    function resolveTrayMenu() {
        if (!trayMenuItem) return
        var rows = trayOpener.children.values
        if (!rows || rows.length === 0) return
        menuTimeout.stop()
        openTrayPanel()
    }

    QsMenuOpener {
        id: trayOpener
        menu: root.trayMenuItem ? root.trayMenuItem.menu : null
    }

    Timer {
        id: menuSettled
        interval: 100
        onTriggered: root.resolveTrayMenu()
    }

    Timer {
        id: menuTimeout
        interval: 1500
        onTriggered: {
            if (!root.trayMenuItem) return
            root.resolveTrayMenu()
            if (!root.trayMenuItem) return
            var item = root.trayMenuItem
            var anchor = root.trayMenuAnchor
            root.closeTrayMenu()
            root.platformMenu(item, anchor, "root menu empty after 1500 ms")
        }
    }

    Connections {
        target: SystemTray.items
        function onObjectRemovedPre(object, index) {
            if (object === root.trayMenuItem) root.closeTrayMenu()
            UiState.closeTrayMenuIfItem(object)
        }
    }

    Connections {
        target: UiState
        function onActivePanelChanged() {
            if (UiState.activePanel !== "") root.closeTrayMenu()
        }
    }
    
    anchors { top: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-bar"
    
    exclusionMode: ExclusionMode.Normal
    // Edge-hugging Flare feet extend below the content body; keep that area inside the window.
    implicitHeight: barH + tipAreaH + Theme.tipHugRadius
    exclusiveZone: Math.round(barH)
    
    color: "transparent"
    visible: AppState.waybarManualState
    onVisibleChanged: {
        if (!visible) {
            if (TooltipManager.activeBar === root) TooltipManager.dismiss()
            closeTrayMenu()
            UiState.closeTrayMenuIfScreen(root.modelData.name)
        }
    }
    
    mask: Region { item: barBg }

    Rectangle {
        id: barBg
        width: parent.width
        height: root.barH
        color: Theme.barColor
        border.width: Theme.borderWidth
        border.color: Theme.border
        
        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.pad
            anchors.rightMargin: Theme.pad
            
            Row {
                id: leftModules
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Theme.topBarTopPadding / 2
                spacing: Theme.gap
                TopModules.Logo {}
                TopModules.Workspaces { screenName: root.modelData.name }
                TopModules.WindowTitle {}
            }
            
            Row {
                id: centerCluster
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Theme.topBarTopPadding / 2
                spacing: showCava ? Theme.gap : 0
                Behavior on spacing { NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve } }
                readonly property real safeSpan: Math.max(0, 2 * Math.min(parent.width / 2 - leftModules.width - Theme.gap,
                                                                          parent.width / 2 - rightModules.width - Theme.gap))
                readonly property real cavaSlotWidth: cavaModule.hoverSafeWidth
                readonly property bool showCava: CenterState.centerMode === "media" && Cava.available && Cava.audioVisible
                                                  && safeSpan >= cavaSlotWidth + Theme.gap + Theme.fontSize * 3
                opacity: CenterState.osdVisible || CenterState.osdExpansion > 0 ? 0 : 1
                enabled: !CenterState.osdVisible && CenterState.osdExpansion === 0
                Behavior on opacity { NumberAnimation { duration: HAnimation.fast } }

                Item {
                    id: cavaSlot
                    width: centerCluster.showCava ? centerCluster.cavaSlotWidth : 0
                    height: centerModule.implicitHeight
                    visible: width > 0
                    clip: true
                    Behavior on width { NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve } }

                    TopModules.CavaGroup {
                        id: cavaModule
                        anchors.centerIn: parent
                        width: parent.width
                        visible: centerCluster.showCava
                    }
                }

                TopModules.CenterModule {
                    id: centerModule
                    maximumWidth: Math.max(0, centerCluster.safeSpan
                                             - (cavaSlot.width > 0 ? cavaSlot.width + centerCluster.spacing : 0))
                }
            }
            
            Row {
                id: rightModules
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Theme.topBarTopPadding / 2
                spacing: Theme.gap
                TopModules.TrayGroup {
                    menuOpenItem: UiState.trayMenu ? UiState.trayMenu.item : root.trayMenuItem
                    onMenuRequested: (item, anchor) => root.requestTrayMenu(item, anchor)
                }
                TopModules.SettingsGroup {}
                TopModules.RecorderGroup {}
                TopModules.ClockGroup {}
                TopModules.NotificationGroup {}
            }
        }
    }
    
    Flare.FlareSurface {
        width: root.width
        y: root.barH
        start: (root.width - spanWidth) / 2
        end: (root.width + spanWidth) / 2
        currentHeight: Theme.levelOsdHeight * CenterState.osdExpansion
        bounds: FlareEdges.getBounds(root.width)
        r: Theme.tipRadius
        rf: Theme.tipHugRadius
        surfaceColor: Theme.barColor
        visible: CenterState.osdExpansion > 0 && spanWidth > 0

        readonly property real spanWidth: Math.min(Theme.levelOsdWidth + Theme.levelOsdPadding * 2,
                                                    Math.max(0, root.width - 2 * (FlareEdges.thickness + Theme.tipRadius)))
    }

    TooltipLayer {
        id: tooltipLayer
        y: barBg.height
        tipAreaHeight: root.tipAreaH
    }
}
