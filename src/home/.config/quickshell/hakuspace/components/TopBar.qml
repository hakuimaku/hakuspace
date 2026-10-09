import QtQuick
import Quickshell
import Quickshell.Wayland
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
    
    anchors { top: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "hakuspace-bar"
    
    exclusionMode: ExclusionMode.Normal
    implicitHeight: barH + tipAreaH
    exclusiveZone: Math.round(barH)
    
    color: "transparent"
    visible: AppState.waybarManualState
    
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
                readonly property bool showCava: CenterState.centerMode === "media" && Cava.audioVisible
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
                TopModules.TrayGroup {}
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
        y: barBg.height
    }
}
