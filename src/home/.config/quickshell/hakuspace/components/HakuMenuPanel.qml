import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare
import "hakumenu" as HakuMenu
import "motion" as Motion

PanelWindow {
    id: root
    required property var modelData
    readonly property bool panelOpen: UiState.activePanel === "hakumenu"
        && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    readonly property real triggerHeight: 4
    readonly property real triggerWidth: modelData.width * 0.20
    readonly property real triggerX: (width - triggerWidth) / 2
    readonly property real maxMenuWidth: modelData.width * 0.40
    readonly property real targetMenuWidth: UiState.hakuMenuMode === "general"
                                                   ? modelData.width * 0.38
                                                   : maxMenuWidth
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: Math.max(triggerWidth, maxMenuWidth + Theme.tipHugRadius * 2)
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

    onPanelOpenChanged: {
        if (panelOpen) {
            // Keep keyboard navigation/search deterministic regardless of whether
            // the menu was opened or the current row was selected with the mouse.
            Qt.callLater(function() {
                if (root.panelOpen) searchInput.forceActiveFocus()
            })
        } else {
            searchInput.focus = false
        }
    }

    // Opening and lifetime tracking are intentionally separate.  Only the
    // physical trigger is allowed to open the menu.  The passive root hover
    // handler only closes an already-open menu when the pointer leaves.  This
    // prevents a programmatic close after launching an app from immediately
    // reopening just because the pointer is still over the old menu position.
    HoverHandler {
        id: lifecycleHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: {
            if (!hovered && root.panelOpen) UiState.closeHakuMenu()
        }
    }

    Item {
        id: triggerAnchor
        x: root.triggerX
        width: root.triggerWidth
        height: root.triggerHeight

        HoverHandler {
            id: triggerHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered && !root.panelOpen)
                    UiState.openHakuMenu(root.modelData.name)
            }
        }
    }

    Flare.FlareMorph {
        id: morph
        anchorItem: triggerAnchor
        shown: root.panelOpen && root.contentReady
        contentW: root.targetMenuWidth
        contentH: root.menuHeight
        minW: 0
        maxW: root.maxMenuWidth
        padX: 0
        padY: 0
        snap: 0
        bounds: ({ start: 0, end: root.width })
        openDuration: HAnimation.hakuMenuOpenDuration
        closeDuration: HAnimation.hakuMenuCloseDuration
        retargetDuration: HAnimation.hakuMenuResizeDuration
        retargetWidthCurve: HAnimation.hakuMenuResizeCurve
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
            width: root.targetMenuWidth

            Behavior on width {
                NumberAnimation {
                    duration: HAnimation.hakuMenuResizeDuration
                    easing.bezierCurve: HAnimation.hakuMenuResizeCurve
                }
            }
            height: root.menuHeight

            readonly property real innerPad: Theme.pad * 2
            readonly property real innerWidth: Math.max(0, width - innerPad * 2)
            readonly property real stateWidth: Theme.fontSize * 3.5
            readonly property bool showStateRegion: UiState.hakuMenuMode === "theme"
            readonly property color controlBg: Qt.darker(Theme.hoverMuted, 1.75)
            readonly property color controlHoverBg: Qt.darker(Theme.hoverMuted, 1.35)
            readonly property color listBg: Qt.darker(Theme.hoverMuted, 2.05)
            readonly property real topRowHeight: Theme.fontSize * 4
            readonly property real switcherWidth: innerWidth * 0.40
            readonly property real searchWidth: innerWidth - switcherWidth - Theme.gap * 2

            Rectangle {
                id: modeSwitcher
                x: menu.innerPad
                width: menu.switcherWidth
                height: menu.topRowHeight
                radius: Theme.radius
                color: menu.controlBg

                readonly property var modes: [
                    { key: "general", label: "General" },
                    { key: "drun", label: "Drun" },
                    { key: "theme", label: "Theme" }
                ]
                readonly property int selectedIndex: ["general", "drun", "theme"].indexOf(UiState.hakuMenuMode)

                Item {
                    id: tabLane
                    anchors.fill: parent
                    anchors.margins: Theme.gap
                    readonly property real spacing: Theme.gap
                    readonly property real slotWidth: (width - spacing * 2) / 3

                    Motion.SelectionPill {
                        z: 0
                        shown: modeSwitcher.selectedIndex >= 0
                        targetIndex: modeSwitcher.selectedIndex
                        slotCount: modeSwitcher.modes.length
                        slotSpacing: tabLane.spacing
                    }

                    Repeater {
                        model: modeSwitcher.modes

                        Motion.MorphButton {
                            required property var modelData
                            required property int index
                            z: 1
                            x: index * (tabLane.slotWidth + tabLane.spacing)
                            width: tabLane.slotWidth
                            height: tabLane.height
                            radius: Theme.radiusSm
                            selected: UiState.hakuMenuMode === modelData.key
                            selectedOverridesHover: true
                            idleColor: "transparent"
                            hoverColor: menu.controlHoverBg
                            pressedColor: menu.controlHoverBg
                            selectedColor: "transparent"
                            foregroundColor: Theme.fg
                            hoverForegroundColor: Theme.fg
                            pressedForegroundColor: Theme.fg
                            selectedForegroundColor: Theme.onAccentColor
                            hoverScaleDelta: 0.004
                            pressScaleDelta: 0.018
                            text: modelData.label
                            onClicked: {
                                UiState.setHakuMenuQuery("")
                                UiState.setHakuMenuMode(modelData.key)
                            }
                        }
                    }
                }
            }

            function moveTab(delta) {
                var modes = ["general", "drun", "theme"]
                var current = modes.indexOf(UiState.hakuMenuMode)
                if (current < 0) return
                var next = Math.max(0, Math.min(modes.length - 1, current + delta))
                if (next === current) return
                UiState.setHakuMenuQuery("")
                UiState.setHakuMenuMode(modes[next])
            }

            Motion.MorphButton {
                id: searchBox
                x: modeSwitcher.x + modeSwitcher.width + Theme.gap * 2
                width: menu.searchWidth
                height: menu.topRowHeight
                radius: Theme.radius
                interactive: false
                externalHovered: searchHover.hovered
                focused: searchInput.activeFocus
                idleColor: menu.controlBg
                hoverColor: menu.controlHoverBg
                focusColor: menu.controlHoverBg
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.fg
                focusForegroundColor: Theme.fg
                hoverScaleDelta: 0
                pressScaleDelta: 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad * 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search…   > General   ~ Theme"
                    color: Theme.fgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    visible: searchInput.text.length === 0
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad * 1.5
                    anchors.rightMargin: Theme.pad * 1.5
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccentColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true
                    text: UiState.hakuMenuQuery
                    onTextEdited: UiState.setHakuMenuQuery(text)
                    Keys.onEscapePressed: {
                        UiState.setHakuMenuQuery("")
                        focus = false
                    }
                    Keys.onLeftPressed: event => {
                        menu.moveTab(-1)
                        event.accepted = true
                    }
                    Keys.onRightPressed: event => {
                        menu.moveTab(1)
                        event.accepted = true
                    }
                    Keys.onDownPressed: {
                        if (UiState.hakuMenuMode === "general") generalList.moveSelection(1)
                        else if (UiState.hakuMenuMode === "drun") drunList.moveSelection(1)
                    }
                    Keys.onUpPressed: {
                        if (UiState.hakuMenuMode === "general") generalList.moveSelection(-1)
                        else if (UiState.hakuMenuMode === "drun") drunList.moveSelection(-1)
                    }
                    Keys.onReturnPressed: {
                        if (UiState.hakuMenuMode === "general") generalList.activateCurrent()
                        else if (UiState.hakuMenuMode === "drun") drunList.activateCurrent()
                    }
                    Keys.onEnterPressed: {
                        if (UiState.hakuMenuMode === "general") generalList.activateCurrent()
                        else if (UiState.hakuMenuMode === "drun") drunList.activateCurrent()
                    }
                }

                HoverHandler {
                    id: searchHover
                    cursorShape: Qt.IBeamCursor
                }
            }

            Rectangle {
                id: mainList
                x: menu.innerPad
                y: modeSwitcher.height + Theme.pad
                width: menu.innerWidth - (menu.showStateRegion ? stateRegion.width + Theme.gap * 2 : 0)
                height: Math.max(0, menu.height - y - menu.innerPad)
                radius: Theme.radius
                color: menu.listBg
                clip: true

                HakuMenu.GeneralList {
                    id: generalList
                    anchors.fill: parent
                    anchors.margins: Theme.gap
                    visible: UiState.hakuMenuMode === "general"
                    query: UiState.hakuMenuQuery
                    rowHoverColor: menu.controlHoverBg
                    rowSelectedColor: Qt.darker(Theme.hoverMuted, 1.18)
                    onHighlightedLabelChanged: label => UiState.setHakuMenuSelectionLabel(label)
                    onLaunched: UiState.closeHakuMenu()
                }

                HakuMenu.DrunList {
                    id: drunList
                    anchors.fill: parent
                    anchors.margins: Theme.gap
                    visible: UiState.hakuMenuMode === "drun"
                    query: UiState.hakuMenuQuery
                    rowHoverColor: menu.controlHoverBg
                    rowSelectedColor: Qt.darker(Theme.hoverMuted, 1.18)
                    onHighlightedLabelChanged: label => UiState.setHakuMenuSelectionLabel(label)
                    onLaunched: UiState.closeHakuMenu()
                }
            }

            Rectangle {
                id: stateRegion
                x: mainList.x + mainList.width + Theme.gap * 2
                y: mainList.y
                width: menu.stateWidth
                height: mainList.height
                radius: Theme.radius
                color: menu.listBg
                visible: menu.showStateRegion
            }
        }
    }
}
