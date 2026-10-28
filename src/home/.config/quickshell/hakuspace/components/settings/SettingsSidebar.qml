import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion
import "SettingsCatalog.js" as Catalog

Rectangle {
    id: root
    // One rail owns all primary Settings navigation.
    property string selected: "Look"
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
                    id: categoryButton
                    required property string modelData
                    objectName: "settings-category-" + modelData
                    settingsNavRole: "sidebar"
                    width: body.width
                    height: Math.max(48, caption.implicitHeight + Theme.spaceLg)
                    // Separate icon and caption metrics keep wrapped categories aligned.
                    Text {
                        id: icon
                        objectName: "settings-sidebar-icon"
                        anchors { left: parent.left; leftMargin: Theme.spaceLg; verticalCenter: parent.verticalCenter }
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: ({Look: "󰏘", Shell: "󰆍", Wallpaper: "󰸉", "Power & Session": "󰐥", Capture: "󰄀", Advanced: "󰒓", About: "󰋽"})[categoryButton.modelData]
                        color: categoryButton.foreground
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 8
                    }
                    Text {
                        id: caption
                        objectName: "settings-sidebar-caption"
                        anchors { left: icon.right; right: parent.right; leftMargin: Theme.spaceMd; rightMargin: Theme.spaceLg; verticalCenter: parent.verticalCenter }
                        text: categoryButton.modelData
                        color: categoryButton.foreground
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2
                        font.weight: categoryButton.selected ? Font.DemiBold : Font.Medium
                        wrapMode: Text.Wrap
                    }
                    Rectangle { anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } width: 5; height: 5; radius: 3; color: Theme.accent; visible: SettingsCoordinator.categoryStatus(modelData) }
                    selected: root.selected === modelData
                    radius: 12
                    border.width: 0
                    idleColor: "transparent"
                    selectedColor: "transparent"
                    hoverColor: "transparent"
                    pressedColor: "transparent"
                    focusColor: "transparent"
                    foregroundColor: Theme.fg
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
