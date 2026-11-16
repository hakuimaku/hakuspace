import QtQuick
import QtQuick.Controls
import "../../services"
import "../base"
import "../motion" as Motion

Column {
    id: root
    property var value: []
    property string label: "Item"
    property Item shortcutTarget: null
    property string error: ""
    signal edited(var value)
    spacing: Theme.spaceSm

    Text {
        visible: !root.value.length
        text: "No items added"
        color: Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    ListView {
        id: listView
        width: parent.width
        height: root.value.length
            ? Math.min(Math.max(contentHeight, root.value.length * (Theme.controlHeight + spacing) - spacing), 210)
            : 0
        visible: root.value.length > 0
        clip: true
        spacing: Theme.spaceXs
        boundsBehavior: Flickable.StopAtBounds
        model: root.value
        ScrollBar.vertical: Motion.HScrollBar { id: scrollBar }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                event.accepted = true
                var maxY = Math.max(0, listView.contentHeight - listView.height)
                if (maxY <= 0) return
                var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : (event.angleDelta.y / 120) * 40
                listView.contentY = Math.max(0, Math.min(maxY, listView.contentY - delta))
            }
        }

        delegate: Rectangle {
            id: entryRow
            required property string modelData
            required property int index
            width: Math.max(0, listView.width - (scrollBar.visible ? scrollBar.width + Theme.spaceXs : 0))
            height: Theme.controlHeight
            radius: Math.min(10, height / 3)
            color: Qt.tint(Theme.surface, Qt.alpha(Theme.overlayInk, 0.06))

            MarqueeText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceMd
                anchors.right: removeBtn.left
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                text: entryRow.modelData
                color: Theme.fg
                fontPixelSize: Theme.fontSize - 1
                horizontalAlignment: Text.AlignLeft
            }

            SettingsActionButton {
                id: removeBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.controlHeight
                height: Theme.controlHeight
                text: "×"
                idleColor: "transparent"
                activeFocusOnTab: true
                focused: activeFocus
                Accessible.name: "Remove " + entryRow.modelData
                onClicked: {
                    var next = root.value.slice()
                    next.splice(entryRow.index, 1)
                    root.edited(next)
                }
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spaceSm
        TextField {
            id: entry
            ContextMenu.menu: null
            property bool settingsNavItem: true
            property string settingsNavRole: "input"
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: Theme.spaceLg
            rightPadding: Theme.spaceLg
            topPadding: Theme.spaceSm
            bottomPadding: Theme.spaceSm
            width: Math.max(0, parent.width - 88)
            height: Theme.comfortableControlHeight
            placeholderText: root.label
            color: Theme.fg
            placeholderTextColor: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            selectByMouse: true
            Accessible.name: "Add " + root.label
            Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
            background: Rectangle { color: Theme.hoverMuted; radius: Theme.radius }
            onAccepted: root.add()
        }
        SettingsActionButton {
            width: 80
            height: Theme.comfortableControlHeight
            text: "Add"
            activeFocusOnTab: true
            focused: activeFocus
            onClicked: root.add()
            Keys.onReturnPressed: clicked()
            Keys.onSpacePressed: clicked()
        }
    }

    Text {
        visible: !!root.error
        text: root.error
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }

    // Reject duplicate or multiline entries before sending a list to the provider.
    function add() {
        var name = entry.text.trim()
        if (!name || /[\r\n\0]/.test(name)) { error = "Enter one item on a single line"; return }
        if (value.includes(name)) { error = "This item is already in the list"; return }
        edited(value.concat([name]))
        entry.text = ""
        error = ""
    }
}
