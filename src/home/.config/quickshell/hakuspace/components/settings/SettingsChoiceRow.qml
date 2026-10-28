import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

SettingsActionButton {
    id: root
    // The selector and menu reuse Hikai's morph buttons and liquid selection surface.
    required property var options
    required property var value
    property Item shortcutTarget: null
    property bool searchable: false
    property bool loading: false
    property string statusMessage: ""
    property string searchPlaceholder: "Search…"
    readonly property var visibleOptions: searchable ? options.filter(option => option.label.toLowerCase().includes(search.text.trim().toLowerCase())) : options
    readonly property int selectedIndex: options.findIndex(option => option.value === value)
    readonly property string currentLabel: selectedIndex >= 0 ? options[selectedIndex].label : searchable && value ? String(value) : "Choose…"
    readonly property bool settingsNavOwnsVertical: menu.visible
    readonly property bool settingsNavOwnsHorizontal: menu.visible
    readonly property bool popupOpen: menu.visible
    signal chosen(var value)
    signal refreshRequested()
    onVisibleOptionsChanged: if (menu.visible) syncChoices()
    implicitHeight: Theme.comfortableControlHeight
    height: implicitHeight
    text: ""
    idleColor: Theme.hoverMuted
    hoverColor: idleColor
    pressedColor: idleColor
    focusColor: idleColor
    foregroundColor: Theme.fg
    radius: height / 2
    border.width: 0
    border.color: activeFocus || menu.visible ? Theme.accent : Theme.hoverMuted
    hoverScaleDelta: 0
    hoverXScaleDelta: 0
    pressScaleDelta: 0
    pressXScaleDelta: 0
    activeFocusOnTab: enabled
    focused: activeFocus
    Accessible.name: currentLabel
    Keys.forwardTo: shortcutTarget ? [shortcutTarget] : []
    onClicked: menu.visible ? menu.close() : menu.open()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    Text {
        anchors { left: parent.left; leftMargin: Theme.spaceLg; right: arrow.left; rightMargin: Theme.spaceMd; verticalCenter: parent.verticalCenter }
        text: root.currentLabel
        color: root.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        elide: Text.ElideMiddle
    }
    Text {
        id: arrow
        anchors { right: parent.right; rightMargin: Theme.spaceLg; verticalCenter: parent.verticalCenter }
        text: "⌄"
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }
    Popup {
        id: menu
        objectName: "settings-choice-popup"
        parent: root
        x: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        transformOrigin: Item.TopLeft
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: HAnimation.fast; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: HAnimation.fast; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; to: 0.98; duration: 120; easing.type: Easing.OutCubic }
            }
        }
        y: root.height + Theme.spaceSm
        width: root.width
        height: Math.min(320, Math.max(Theme.comfortableControlHeight, root.visibleOptions.length * (Theme.comfortableControlHeight + choices.spacing) - choices.spacing)
            + (root.searchable ? search.height + Theme.spaceSm : 0) + padding * 2)
        padding: Theme.spaceMd
        margins: Theme.spaceMd
        focus: true
        onAboutToShow: {
            search.text = ""
            root.refreshRequested()
            root.syncChoices()
        }
        onOpened: root.searchable ? search.focusSearch() : choices.forceActiveFocus()
        onClosed: if (root.visible) root.forceActiveFocus()
        background: Rectangle { color: Theme.surface; radius: Theme.largeRadius; border.width: 0; border.color: Theme.hoverMuted }
        contentItem: Item {
            SettingsSearchField {
                id: search
                objectName: "settings-choice-search"
                visible: root.searchable
                width: parent.width
                placeholderText: root.searchPlaceholder
                accessibleName: "Search options"
                onAccepted: root.choose(choices.currentIndex)
                onNextRequested: if (choices.count) { choices.currentIndex = Math.max(0, choices.currentIndex); choices.forceActiveFocus() }
                onEscapeRequested: text = ""
            }
            Text {
                anchors.centerIn: choices
                width: choices.width
                visible: root.loading || root.statusMessage.length > 0 || !root.visibleOptions.length
                text: root.loading ? "Loading…" : root.statusMessage || "No matching options"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            ListView {
                id: choices
                objectName: "settings-choice-list"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: search.visible ? search.height + Theme.spaceSm : 0 }
                clip: true
                focus: true
                enabled: !root.loading && !root.statusMessage.length
                spacing: Theme.spaceXs
                model: root.visibleOptions
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: Motion.HScrollBar { id: bar }
                Keys.onReturnPressed: root.choose(currentIndex)
                Keys.onEnterPressed: root.choose(currentIndex)
                Keys.onSpacePressed: root.choose(currentIndex)
                Keys.onUpPressed: event => {
                    if (root.searchable && currentIndex <= 0) search.focusSearch()
                    else event.accepted = false
                }
                // Keep the pill below delegates and in their scrolling coordinate space.
                Motion.SelectionPill {
                    id: selectionPill
                    objectName: "settings-choice-selection"
                    parent: choices.contentItem
                    coordinateSpace: choices.contentItem
                    targetItem: choices.currentItem
                    z: 0
                }
                delegate: SettingsActionButton {
                    id: option
                    required property var modelData
                    required property int index
                    width: Math.max(0, choices.width - bar.reservedGutter)
                    height: Theme.comfortableControlHeight
                    radius: height / 2
                    z: 1
                    text: ""
                    selected: choices.currentIndex === index
                    idleColor: "transparent"
                    selectedColor: "transparent"
                    hoverColor: "transparent"
                    pressedColor: "transparent"
                    focusColor: "transparent"
                    foregroundColor: Theme.fgDim
                    selectedForegroundColor: Theme.onAccentColor
                    hoverForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                    pressedForegroundColor: hoverForegroundColor
                    focusForegroundColor: hoverForegroundColor
                    selectedOverridesHover: true
                    hoverScaleDelta: 0
                    hoverXScaleDelta: 0
                    Accessible.name: modelData.label
                    Accessible.role: Accessible.ListItem
                    Accessible.selected: selected
                    onHoveredChanged: if (hovered) choices.currentIndex = index
                    onClicked: root.choose(index)
                    Text {
                        objectName: "settings-choice-option-label"
                        anchors { fill: parent; leftMargin: Theme.spaceLg; rightMargin: Theme.spaceLg }
                        verticalAlignment: Text.AlignVCenter
                        text: option.modelData.label
                        color: option.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }
    // Reset selection against the filtered model after search or an asynchronous refresh.
    function syncChoices() {
        var index = visibleOptions.findIndex(option => option.value === value)
        choices.currentIndex = index >= 0 ? index : visibleOptions.length ? 0 : -1
        if (choices.currentIndex >= 0) choices.positionViewAtIndex(choices.currentIndex, ListView.Contain)
        selectionPill.syncTarget(true)
    }
    // Commit a listed value once, then return focus to the selector.
    function choose(index) {
        if (loading || statusMessage.length || index < 0 || index >= visibleOptions.length) return
        chosen(visibleOptions[index].value)
        menu.close()
    }
}
