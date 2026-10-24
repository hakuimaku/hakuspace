import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion
import "SettingsCatalog.js" as Catalog

Rectangle {
    id: root
    // One rail owns all primary Settings navigation.
    property string selected: "General"
    readonly property var categories: Catalog.categories
    readonly property bool popupOpen: false
    signal selectedRequested(string category)
    color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.13))
    clip: true
    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: Motion.HScrollBar {}
        // One moving surface morphs between the selected category rows.
        Motion.SelectionPill {
            id: selectionPill
            objectName: "settings-sidebar-selection"
            parent: scroll.contentItem
            coordinateSpace: scroll.contentItem
            z: 0
        }
        Column {
            id: body
            z: 1
            onPositioningComplete: selectionPill.syncTarget(true)
            width: scroll.width
            spacing: Theme.spaceSm
            Repeater {
                model: Catalog.categories
                delegate: SettingsActionButton {
                    required property string modelData
                    objectName: "settings-category-" + modelData
                    settingsNavRole: "sidebar"
                    width: body.width; height: Theme.comfortableControlHeight
                    text: modelData
                    selected: root.selected === modelData
                    radius: height / 2
                    border.width: 0
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
                    Component.onCompleted: if (selected) selectionPill.targetItem = this
                    onSelectedChanged: if (selected) selectionPill.targetItem = this
                    activeFocusOnTab: true; focused: activeFocus
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData
                    Accessible.selected: selected
                    onClicked: root.selectedRequested(modelData)
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                }
            }
        }
    }
}
