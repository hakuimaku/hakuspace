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
    readonly property int selectedIndex: options.findIndex(option => option.value === value)
    readonly property string currentLabel: selectedIndex >= 0 ? options[selectedIndex].label : "Choose…"
    readonly property bool settingsNavOwnsVertical: menu.visible
    readonly property bool settingsNavOwnsHorizontal: menu.visible
    readonly property bool popupOpen: menu.visible
    signal chosen(var value)
    implicitHeight: Theme.comfortableControlHeight
    height: implicitHeight
    text: ""
    idleColor: Theme.surface
    hoverColor: idleColor
    pressedColor: idleColor
    focusColor: idleColor
    foregroundColor: Theme.fg
    radius: height / 2
    border.width: 1
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
        height: Math.min(320, Math.max(0, root.options.length * (Theme.comfortableControlHeight + choices.spacing) - choices.spacing) + padding * 2)
        padding: Theme.spaceMd
        margins: Theme.spaceMd
        focus: true
        onAboutToShow: {
            choices.currentIndex = Math.max(0, root.selectedIndex)
            choices.positionViewAtIndex(choices.currentIndex, ListView.Contain)
            selectionPill.syncTarget(true)
        }
        onOpened: choices.forceActiveFocus()
        onClosed: if (root.visible) root.forceActiveFocus()
        background: Rectangle { color: Theme.surface; radius: Theme.largeRadius; border.width: 1; border.color: Theme.hoverMuted }
        contentItem: ListView {
            id: choices
            objectName: "settings-choice-list"
            clip: true
            focus: true
            spacing: Theme.spaceXs
            model: root.options
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar { id: bar }
            Keys.onReturnPressed: root.choose(currentIndex)
            Keys.onEnterPressed: root.choose(currentIndex)
            Keys.onSpacePressed: root.choose(currentIndex)
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
    // Commit a listed value once, then return focus to the selector.
    function choose(index) {
        if (index < 0 || index >= options.length) return
        chosen(options[index].value)
        menu.close()
    }
}
