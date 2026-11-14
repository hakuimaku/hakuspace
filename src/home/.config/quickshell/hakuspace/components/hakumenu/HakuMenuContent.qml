import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog
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
    signal wallpaperRequested()
    readonly property bool searchFocused: searchInput.activeFocus
    // Include search controls and both list insets in the editor's requested height.
    readonly property real editorHeight: mode === "general" && generalList.editorHeight > 0
        ? generalList.editorHeight + innerTopPad + innerBottomPad + topRowHeight + Theme.pad + Theme.gap * 2 : 0

    // Presentations request focus when their own geometry is ready.
    function forceSearchFocus() {
        if (generalList.editorRequested && generalList.itemEditor) generalList.itemEditor.focusName()
        else searchInput.forceActiveFocus()
    }
    function clearSearchFocus() { searchInput.focus = false }

    readonly property real innerTopPad: Theme.hakuMenuTopPadding + Theme.pad
    readonly property real innerBottomPad: Theme.hakuMenuBottomPadding
    readonly property real innerLeftPad: Theme.hakuMenuLeftPadding
    readonly property real innerRightPad: Theme.hakuMenuRightPadding
    readonly property real innerPad: innerBottomPad
    readonly property real innerWidth: Math.max(0, width - innerLeftPad - innerRightPad)
    readonly property real stateWidth: Math.max(124, Theme.fontSize * 8.2 + 8)
    readonly property bool showStateRegion: menu.mode === "theme"
    readonly property color controlBg: Theme.surfaceSubtle(1.75)
    readonly property color controlHoverBg: Theme.surfaceSubtle(1.35)
    readonly property color listBg: Theme.surfaceSubtle(2.05)
    readonly property real topRowHeight: Theme.fontSize * 4
    readonly property real controlsY: modeSwitcher.y
    readonly property real switcherWidth: innerWidth * 0.40
    readonly property real searchWidth: Math.max(0, innerWidth - switcherWidth - Theme.gap * 2)
    readonly property int controlsGridRow: controlsAtBottom ? 1 : 0
    readonly property int contentGridRow: controlsAtBottom ? 0 : 1

    function moveTab(delta) {
        var modes = ["general", "drun", "theme"]
        var current = modes.indexOf(menu.mode)
        if (current < 0) return
        var next = Math.max(0, Math.min(modes.length - 1, current + delta))
        if (next === current) return
        UiState.setHakuMenuQuery("")
        UiState.setHakuMenuMode(modes[next])
    }

    GridLayout {
        id: contentGrid
        anchors.fill: parent
        anchors.topMargin: menu.innerTopPad
        anchors.bottomMargin: menu.innerBottomPad
        anchors.leftMargin: menu.innerLeftPad
        anchors.rightMargin: menu.innerRightPad
        columns: 3
        rowSpacing: Theme.pad
        columnSpacing: Theme.gap * 2

        Rectangle {
            id: modeSwitcher
            objectName: "hakumenu-modeSwitcher"
            Layout.row: menu.controlsGridRow
            Layout.column: 0
            Layout.columnSpan: 1
            Layout.preferredWidth: menu.switcherWidth
            Layout.minimumWidth: menu.switcherWidth
            Layout.maximumWidth: menu.switcherWidth
            Layout.preferredHeight: menu.topRowHeight
            Layout.minimumHeight: menu.topRowHeight
            Layout.maximumHeight: menu.topRowHeight
            radius: Theme.largeRadius
            color: menu.controlBg

            readonly property var modes: UiCatalog.hakuMenuModes
            readonly property int selectedIndex: modes.map(function(item) { return item.key }).indexOf(menu.mode)

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
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        selectedColor: "transparent"
                        foregroundColor: Theme.fg
                        hoverForegroundColor: Theme.fg
                        pressedForegroundColor: Theme.fg
                        selectedForegroundColor: Theme.onAccentColor
                        hoverScaleDelta: Theme.hakuMenuHoverScaleDelta
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

        Motion.MorphButton {
            id: searchBox
            objectName: "hakumenu-searchBox"
            Layout.row: menu.controlsGridRow
            Layout.column: 1
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: menu.topRowHeight
            Layout.minimumHeight: menu.topRowHeight
            Layout.maximumHeight: menu.topRowHeight
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
                    if (event.modifiers & Qt.ControlModifier) {
                        UiState.setHakuPanelTab("hakumenu")
                    } else if (!(event.modifiers & Qt.AltModifier)) {
                        menu.moveTab(-1)
                    }
                    event.accepted = true
                }
                Keys.onRightPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        UiState.setHakuPanelTab("taskManager")
                    } else if (!(event.modifiers & Qt.AltModifier)) {
                        menu.moveTab(1)
                    }
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
            Layout.row: menu.contentGridRow
            Layout.column: 0
            Layout.columnSpan: menu.showStateRegion ? 2 : 3
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.largeRadius
            color: menu.mode === "theme" ? "transparent" : menu.listBg
            clip: false

            GeneralList {
                id: generalList
                anchors.fill: parent
                anchors.margins: Theme.gap
                visible: menu.mode === "general"
                query: menu.query
                panelOpen: menu.panelOpen
                onRestoreSearchFocus: if (menu.panelOpen && menu.mode === "general") menu.forceSearchFocus()
                rowHoverColor: menu.controlHoverBg
                rowSelectedColor: Theme.surfaceSubtle(1.18)
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
                rowSelectedColor: Theme.surfaceSubtle(1.18)
                onHighlightedLabelChanged: label => UiState.setHakuMenuSelectionLabel(label)
                onLaunched: UiState.closeHakuMenu()
            }
        }

        Rectangle {
            id: stateRegion
            objectName: "hakumenu-stateRegion"
            Layout.row: menu.contentGridRow
            Layout.column: 2
            Layout.columnSpan: 1
            Layout.preferredWidth: menu.stateWidth
            Layout.minimumWidth: menu.stateWidth
            Layout.maximumWidth: menu.stateWidth
            Layout.fillHeight: true
            radius: Theme.largeRadius
            color: menu.mode === "theme" ? "transparent" : menu.listBg
            visible: menu.showStateRegion
        }
    }

    ThemeList {
        id: themeList
        x: contentGrid.x + mainList.x
        y: contentGrid.y + mainList.y
        width: contentGrid.width
        height: mainList.height
        visible: menu.mode === "theme"
        query: menu.query
        leftColumnWidth: Math.max(0, mainList.width - Theme.gap * 2)
        stateColumnWidth: Math.max(0, stateRegion.width - Theme.gap * 2)
        columnGap: Theme.gap * 4
        rowHoverColor: menu.controlHoverBg
        rowSelectedColor: Theme.surfaceSubtle(1.18)
        onHighlightedLabelChanged: label => UiState.setHakuMenuSelectionLabel(label)
        onWallpaperRequested: menu.wallpaperRequested()
        onLaunched: closeMenu => {
            if (closeMenu) UiState.closeHakuMenu()
        }
    }
}
