import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare

PanelWindow {
    id: root
    required property var modelData
    readonly property bool panelOpen: UiState.activePanel === "hakumenu"
        && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    readonly property real triggerHeight: 4
    readonly property real triggerWidth: modelData.width * 0.20
    readonly property real triggerX: (width - triggerWidth) / 2
    readonly property real menuWidth: modelData.width * 0.40
    readonly property real menuHeight: modelData.height * 0.40
    readonly property real menuTop: FlareEdges.topOriginY
    readonly property real bounceHeadroom: menuHeight * HAnimation.hakuMenuBounceHeadroom
    readonly property bool contentReady: isFinite(menu.width) && menu.width > 0
                                         && isFinite(menu.height) && menu.height > 0

    screen: modelData
    anchors { top: true; left: true }
    margins.left: (modelData.width - implicitWidth) / 2
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-hakumenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: Math.max(triggerWidth, menuWidth + Theme.tipHugRadius * 2)
    implicitHeight: menuTop + menuHeight + bounceHeadroom
    color: "transparent"
    mask: Region {
        Region {
            x: root.triggerX
            width: root.triggerWidth
            height: root.triggerHeight
        }
        Region {
            x: Math.min(root.triggerX, morph.mStart)
            y: root.triggerHeight
            width: Math.max(root.triggerX + root.triggerWidth, morph.mEnd) - x
            height: root.panelOpen || morph.mHeight > 0 ? root.menuTop - y : 0
        }
        Region {
            x: morph.mStart
            y: root.menuTop
            width: Math.max(0, morph.mEnd - morph.mStart)
            height: morph.mHeight
            radius: Theme.tipHugRadius
        }
    }
    Component.onDestruction: UiState.closeHakuMenuIfScreen(modelData.name)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            if (!root.panelOpen) UiState.openHakuMenu(root.modelData.name)
        }
        onExited: {
            if (root.panelOpen) UiState.closeHakuMenu()
        }
    }

    Item {
        id: triggerAnchor
        x: root.triggerX
        width: root.triggerWidth
        height: root.triggerHeight
        visible: false
    }

    Flare.FlareMorph {
        id: morph
        anchorItem: triggerAnchor
        shown: root.panelOpen && root.contentReady
        contentW: root.menuWidth
        contentH: root.menuHeight
        minW: 0
        maxW: root.menuWidth
        padX: 0
        padY: 0
        snap: 0
        bounds: ({ start: 0, end: root.width })
        openDuration: HAnimation.hakuMenuOpenDuration
        closeDuration: HAnimation.hakuMenuCloseDuration
        openHeightCurve: HAnimation.hakuMenuOpenCurve
        closeHeightCurve: HAnimation.hakuMenuCloseCurve
    }

    Flare.FlareSurface {
        y: root.menuTop
        start: morph.mStart
        end: morph.mEnd
        currentHeight: morph.mHeight
        bounds: morph.bounds
        r: Theme.radius
        rf: Theme.tipHugRadius
        bottomRadius: Theme.tipHugRadius
        surfaceColor: Theme.surface

        Item {
            id: menu
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.menuWidth
            height: root.menuHeight

            readonly property real innerPad: Theme.pad * 2
            readonly property real innerWidth: Math.max(0, width - innerPad * 2)
            readonly property real stateWidth: Theme.fontSize * 3.5
            readonly property bool showStateRegion: UiState.hakuMenuMode === "theme"

            Rectangle {
                id: tabStrip
                x: menu.innerPad
                width: menu.innerWidth
                height: Theme.fontSize * 4
                radius: Theme.radius
                color: Theme.hoverMuted
            }

            Rectangle {
                id: mainList
                x: menu.innerPad
                y: tabStrip.height + Theme.pad
                width: menu.innerWidth - (menu.showStateRegion ? stateRegion.width + Theme.gap * 2 : 0)
                height: Math.max(0, menu.height - y - menu.innerPad)
                radius: Theme.radius
                color: Theme.hoverMuted
            }

            Rectangle {
                id: stateRegion
                x: mainList.x + mainList.width + Theme.gap * 2
                y: mainList.y
                width: menu.stateWidth
                height: mainList.height
                radius: Theme.radius
                color: Theme.hoverMuted
                visible: menu.showStateRegion
            }
        }
    }
}
