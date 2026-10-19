import QtQuick
import Quickshell
import "../../services"
import "../motion" as Motion

Item {
    id: menu
    // Presentations share behavior while choosing the control row's vertical placement.
    property bool panelOpen: false
    property bool controlsAtBottom: false
    property bool focusOnOpen: true
    property string mode: UiState.hakuMenuMode
    property string query: UiState.hakuMenuQuery
    signal keyboardActivity()
    readonly property bool searchFocused: searchInput.activeFocus

    // Presentations request focus when their own geometry is ready.
    function forceSearchFocus() { searchInput.forceActiveFocus() }
    function clearSearchFocus() { searchInput.focus = false }

    readonly property real innerPad: Theme.pad * 2
    readonly property real innerWidth: Math.max(0, width - innerPad * 2)
    readonly property real stateWidth: Math.max(92, Theme.fontSize * 6.2)
    readonly property bool showStateRegion: menu.mode === "theme"
    readonly property color controlBg: Qt.darker(Theme.hoverMuted, 1.75)
    readonly property color controlHoverBg: Qt.darker(Theme.hoverMuted, 1.35)
    readonly property color listBg: Qt.darker(Theme.hoverMuted, 2.05)
    readonly property real topRowHeight: Theme.fontSize * 4
    readonly property real controlsY: controlsAtBottom ? height - innerPad - topRowHeight : innerPad
    readonly property real switcherWidth: innerWidth * 0.40
    readonly property real searchWidth: innerWidth - switcherWidth - Theme.gap * 2

    Rectangle {
        id: modeSwitcher
        objectName: "hakumenu-modeSwitcher"
        x: menu.innerPad
        y: menu.controlsY
        width: menu.switcherWidth
        height: menu.topRowHeight
        radius: Theme.largeRadius
        color: menu.controlBg

        readonly property var modes: [
            { key: "general", icon: "󰀻", label: "General" },
            { key: "drun", icon: "󰍉", label: "Drun" },
            { key: "theme", icon: "", label: "Theme" }
        ]
        readonly property int selectedIndex: ["general", "drun", "theme"].indexOf(menu.mode)

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
                    selected: menu.mode === modelData.key
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
        var current = modes.indexOf(menu.mode)
        if (current < 0) return
        var next = Math.max(0, Math.min(modes.length - 1, current + delta))
        if (next === current) return
        UiState.setHakuMenuQuery("")
        UiState.setHakuMenuMode(modes[next])
    }

    Motion.MorphButton {
        id: searchBox
        objectName: "hakumenu-searchBox"
        x: modeSwitcher.x + modeSwitcher.width + Theme.gap * 2
        y: menu.controlsY
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
        objectName: "hakumenu-searchInput"
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
            focus: menu.panelOpen && menu.focusOnOpen
            text: menu.query
            onTextEdited: {
                menu.keyboardActivity()
                UiState.setHakuMenuQuery(text)
            }
            Keys.onPressed: menu.keyboardActivity()
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
                if (menu.mode === "general") generalList.moveSelection(1)
                else if (menu.mode === "drun") drunList.moveSelection(1)
                else if (menu.mode === "theme") themeList.moveSelection(1)
            }
            Keys.onUpPressed: {
                if (menu.mode === "general") generalList.moveSelection(-1)
                else if (menu.mode === "drun") drunList.moveSelection(-1)
                else if (menu.mode === "theme") themeList.moveSelection(-1)
            }
            Keys.onReturnPressed: {
                if (menu.mode === "general") generalList.activateCurrent()
                else if (menu.mode === "drun") drunList.activateCurrent()
                else if (menu.mode === "theme") themeList.activateCurrent()
            }
            Keys.onEnterPressed: {
                if (menu.mode === "general") generalList.activateCurrent()
                else if (menu.mode === "drun") drunList.activateCurrent()
                else if (menu.mode === "theme") themeList.activateCurrent()
            }
        }

        HoverHandler {
            id: searchHover
            cursorShape: Qt.IBeamCursor
        }
    }

    Rectangle {
        id: mainList
        objectName: "hakumenu-mainList"
        x: menu.innerPad
        y: menu.controlsAtBottom ? menu.innerPad : menu.innerPad + modeSwitcher.height + Theme.pad
        width: menu.innerWidth - (menu.showStateRegion ? stateRegion.width + Theme.gap * 2 : 0)
        height: Math.max(0, (menu.controlsAtBottom ? menu.controlsY - Theme.pad : menu.height - menu.innerPad) - y)
        radius: Theme.largeRadius
        color: menu.listBg
        clip: true

        GeneralList {
            id: generalList
            anchors.fill: parent
            anchors.margins: Theme.gap
            visible: menu.mode === "general"
            query: menu.query
            rowHoverColor: menu.controlHoverBg
            rowSelectedColor: Qt.darker(Theme.hoverMuted, 1.18)
            onHighlightedLabelChanged: label => UiState.setHakuMenuSelectionLabel(label)
            onLaunched: UiState.closeHakuMenu()
        }

        DrunList {
            id: drunList
            anchors.fill: parent
            anchors.margins: Theme.gap
            visible: menu.mode === "drun"
            query: menu.query
            rowHoverColor: menu.controlHoverBg
            rowSelectedColor: Qt.darker(Theme.hoverMuted, 1.18)
            onHighlightedLabelChanged: label => UiState.setHakuMenuSelectionLabel(label)
            onLaunched: UiState.closeHakuMenu()
        }
    }

    Rectangle {
        id: stateRegion
        objectName: "hakumenu-stateRegion"
        x: mainList.x + mainList.width + Theme.gap * 2
        y: mainList.y
        width: menu.stateWidth
        height: mainList.height
        radius: Theme.largeRadius
        color: menu.listBg
        visible: menu.showStateRegion
    }

    ThemeList {
        id: themeList
        x: mainList.x + Theme.gap
        y: mainList.y + Theme.gap
        width: mainList.width + Theme.gap * 2 + stateRegion.width - Theme.gap * 2
        height: Math.max(0, mainList.height - Theme.gap * 2)
        visible: menu.mode === "theme"
        query: menu.query
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
