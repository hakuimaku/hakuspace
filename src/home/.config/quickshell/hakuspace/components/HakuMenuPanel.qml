import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "base" as Base
import "base/SafeZoneGeometry.js" as SafeZoneGeometry
import "flare" as Flare
import "hakumenu" as HakuMenu
import "motion" as Motion

Item {
    id: root
    required property var modelData

    readonly property bool panelOpen: UiState.activePanel === "hakumenu"
        && UiState.hakuMenuMode !== "closed"
        && UiState.hakuMenuScreenName === modelData.name
    readonly property real triggerHeight: 4
    readonly property real triggerWidth: modelData.width * 0.20
    readonly property real maxMenuWidth: modelData.width * 0.42
    readonly property real targetMenuWidth: {
        if (UiState.hakuMenuMode === "general") return modelData.width * 0.38
        if (UiState.hakuMenuMode === "theme") return modelData.width * 0.42
        return modelData.width * 0.40
    }
    readonly property real menuHeight: modelData.height * 0.40
    readonly property real menuTop: FlareEdges.topOriginY
    readonly property real bounceHeadroom: menuHeight * HAnimation.hakuMenuBounceHeadroom
    readonly property real windowWidth: Math.max(triggerWidth, maxMenuWidth + Theme.hugRadius * 2)
    readonly property real windowHeight: menuTop + menuHeight + bounceHeadroom
    readonly property real triggerX: (modelData.width - triggerWidth) / 2
    readonly property bool contentReady: isFinite(menu.width) && menu.width > 0
                                         && isFinite(menu.height) && menu.height > 0
    readonly property bool safeExpanded: panelOpen || morph.mHeight > 0.01
    readonly property var safeZones: {
        var empty = SafeZoneGeometry.rect(0, 0, 0, 0)
        var trigger = SafeZoneGeometry.rect(triggerX, 0, triggerWidth, triggerHeight)
        var anchor = safeExpanded ? SafeZoneGeometry.inflate(trigger,
            Interaction.safeZoneAnchorMargin) : trigger
        var target = SafeZoneGeometry.rect((modelData.width - maxMenuWidth) / 2,
            menuTop, maxMenuWidth, menuHeight + bounceHeadroom)
        var current = SafeZoneGeometry.rect(morph.mStart, menuTop,
            Math.max(0, morph.mEnd - morph.mStart), morph.mHeight)
        var menuZone = safeExpanded ? SafeZoneGeometry.clampRect(SafeZoneGeometry.inflate(
            SafeZoneGeometry.unionBounds(current, target), Interaction.safeZoneMargin),
            modelData.width, modelData.height) : empty
        return [SafeZoneGeometry.clampRect(anchor, modelData.width, modelData.height),
                // The 20% wide trigger needs a vertical handoff along its full width.
                safeExpanded ? SafeZoneGeometry.clampRect(SafeZoneGeometry.rect(
                    triggerX, triggerHeight, triggerWidth, Math.max(0, menuTop - triggerHeight)),
                    modelData.width, modelData.height) : empty,
                menuZone]
    }
    function safeZone(index) { return safeZones[index] || SafeZoneGeometry.rect(0, 0, 0, 0) }

    Base.SafeZoneController {
        id: lifetime
        active: root.panelOpen
        containsPoint: function(x, y) { return SafeZoneGeometry.containsAny(root.safeZones, x, y) }
        onCloseRequested: UiState.closeHakuMenu()
    }

    width: windowWidth
    height: windowHeight

    Component.onDestruction: UiState.closeHakuMenuIfScreen(modelData.name)

    onPanelOpenChanged: {
        if (panelOpen) {
            Qt.callLater(function() {
                if (root.panelOpen) searchInput.forceActiveFocus()
            })
        } else {
            searchInput.focus = false
        }
    }

    // Top-layer visual shell. This remains a pure visual surface: it owns the
    // Flare/body silhouette but no content, focus or pointer input. Fullscreen
    // clients may cover this layer while the Overlay content layer below in
    // this component still remains visible and usable.
    PanelWindow {
        id: topVisualLayer
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hakuspace-hakumenu-flare"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: root.modelData.width
        implicitHeight: root.windowHeight
        color: "transparent"
        mask: Region {}

        Flare.FlareSurface {
            y: root.menuTop
            start: morph.mStart
            end: morph.mEnd
            currentHeight: morph.mHeight
            bounds: morph.bounds
            r: Theme.giantRadius
            rf: Theme.hugRadius
            bottomRadius: Theme.hugRadius
            surfaceColor: Theme.surface
        }
    }

    // Overlay content shell. This is the only interactive HakuMenu window and
    // therefore continues to work over fullscreen clients. It deliberately
    // draws a rounded body without Flare ears; those belong to topVisualLayer.
    PanelWindow {
        id: contentLayer
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hakuspace-hakumenu-content"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"

        mask: Region {
            Region {
                x: root.safeZone(0).x; y: root.safeZone(0).y
                width: root.safeZone(0).width; height: root.safeZone(0).height
            }
            Region {
                x: root.safeZone(1).x; y: root.safeZone(1).y
                width: root.safeZone(1).width; height: root.safeZone(1).height
            }
            Region {
                x: root.safeZone(2).x; y: root.safeZone(2).y
                width: root.safeZone(2).width; height: root.safeZone(2).height
            }
        }

        HoverHandler {
            id: safeZoneHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (!hovered) lifetime.pointerExited()
                else {
                    lifetime.pointerEntered(point.position.x, point.position.y)
                    if (root.panelOpen) searchInput.forceActiveFocus()
                }
            }
            onPointChanged: lifetime.pointerMoved(point.position.x, point.position.y)
        }

        Base.SafeZoneDebugOverlay {
            anchors.fill: parent
            z: 999
            closePending: lifetime.closePending
            zones: root.safeZones.map(function(zone, index) {
                return { rect: zone, kind: index === 0 ? "anchor"
                    : index === 1 ? "corridor"
                    : morph.mHeight > 0.01 && morph.mHeight < root.menuHeight
                        ? "animation" : "surface" }
            })
        }

        Item {
            id: fallbackKeyHandler
            anchors.fill: parent
            focus: root.panelOpen
            Keys.onEscapePressed: event => {
                UiState.closeHakuMenu()
                event.accepted = true
            }
        }

        Item {
            id: triggerAnchor
            x: root.triggerX
            y: 0
            width: root.triggerWidth
            height: root.triggerHeight

            HoverHandler {
                id: triggerHover
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: {
                    if (hovered && !root.panelOpen) {
                        UiState.openHakuMenu(root.modelData.name)
                    }
                }
                onPointChanged: if (root.panelOpen)
                    lifetime.pointerMoved(root.triggerX + point.position.x, point.position.y)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    if (!root.panelOpen) {
                        UiState.openHakuMenu(root.modelData.name)
                    }
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
            bounds: ({ start: 0, end: root.modelData.width })
            openDuration: HAnimation.hakuMenuOpenDuration
            closeDuration: HAnimation.hakuMenuCloseDuration
            retargetDuration: HAnimation.hakuMenuResizeDuration
            retargetWidthCurve: HAnimation.hakuMenuResizeCurve
            openHeightCurve: HAnimation.hakuMenuOpenCurve
            closeHeightCurve: HAnimation.hakuMenuCloseCurve
        }

        Rectangle {
            id: contentSurface
            x: morph.mStart
            y: root.menuTop
            width: Math.max(0, morph.mEnd - morph.mStart)
            height: morph.mHeight
            radius: Math.min(Theme.hugRadius, width / 2, height / 2)
            color: Theme.surface
            clip: true
            visible: width > 0.01 && height > 0.01

            // Absorb clicks so clicking inside the menu body does not dismiss
            MouseArea {
                anchors.fill: parent
            }

            HoverHandler {
                id: surfaceHover
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onPointChanged: if (root.panelOpen)
                    lifetime.pointerMoved(contentSurface.x + point.position.x,
                        contentSurface.y + point.position.y)
            }

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
                readonly property real stateWidth: Math.max(92, Theme.fontSize * 6.2)
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
                    y: menu.innerPad
                    width: menu.switcherWidth
                    height: menu.topRowHeight
                    radius: Theme.largeRadius
                    color: menu.controlBg

                    readonly property var modes: [
                        { key: "general", icon: "󰀻", label: "General" },
                        { key: "drun", icon: "󰍉", label: "Drun" },
                        { key: "theme", icon: "", label: "Theme" }
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
                                radius: Theme.radius
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
                                text: modelData.icon
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.label
                                fontSize: Theme.fontSize + 5
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
                    y: menu.innerPad
                    width: menu.searchWidth
                    height: menu.topRowHeight
                    radius: Theme.hugRadius
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
                        font.pixelSize: Theme.fontSize + 1
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
                        font.pixelSize: Theme.fontSize + 1
                        clip: true
                        focus: root.panelOpen
                        text: UiState.hakuMenuQuery
                        onTextEdited: {
                            lifetime.beginKeyboardLease()
                            UiState.setHakuMenuQuery(text)
                        }
                        Keys.onPressed: lifetime.beginKeyboardLease()
                        Keys.onEscapePressed: event => {
                            UiState.closeHakuMenu()
                            event.accepted = true
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
                            else if (UiState.hakuMenuMode === "theme") themeList.moveSelection(1)
                        }
                        Keys.onUpPressed: {
                            if (UiState.hakuMenuMode === "general") generalList.moveSelection(-1)
                            else if (UiState.hakuMenuMode === "drun") drunList.moveSelection(-1)
                            else if (UiState.hakuMenuMode === "theme") themeList.moveSelection(-1)
                        }
                        Keys.onReturnPressed: {
                            if (UiState.hakuMenuMode === "general") generalList.activateCurrent()
                            else if (UiState.hakuMenuMode === "drun") drunList.activateCurrent()
                            else if (UiState.hakuMenuMode === "theme") themeList.activateCurrent()
                        }
                        Keys.onEnterPressed: {
                            if (UiState.hakuMenuMode === "general") generalList.activateCurrent()
                            else if (UiState.hakuMenuMode === "drun") drunList.activateCurrent()
                            else if (UiState.hakuMenuMode === "theme") themeList.activateCurrent()
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
                    y: menu.innerPad + modeSwitcher.height + Theme.pad
                    width: menu.innerWidth - (menu.showStateRegion ? stateRegion.width + Theme.gap * 2 : 0)
                    height: Math.max(0, menu.height - y - menu.innerPad)
                    radius: Theme.largeRadius
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
                    radius: Theme.largeRadius
                    color: menu.listBg
                    visible: menu.showStateRegion
                }

                HakuMenu.ThemeList {
                    id: themeList
                    x: mainList.x + Theme.gap
                    y: mainList.y + Theme.gap
                    width: mainList.width + Theme.gap * 2 + stateRegion.width - Theme.gap * 2
                    height: Math.max(0, mainList.height - Theme.gap * 2)
                    visible: UiState.hakuMenuMode === "theme"
                    query: UiState.hakuMenuQuery
                    leftColumnWidth: Math.max(0, mainList.width - Theme.gap * 2)
                    stateColumnWidth: Math.max(0, stateRegion.width - Theme.gap * 2)
                    columnGap: Theme.gap * 4
                    rowHoverColor: menu.controlHoverBg
                    rowSelectedColor: Qt.darker(Theme.hoverMuted, 1.18)
                    onHighlightedLabelChanged: label => UiState.setHakuMenuSelectionLabel(label)
                    onLaunched: closeMenu => {
                        if (closeMenu) UiState.closeHakuMenu()
                    }
                }
            }
        }
    }
}
