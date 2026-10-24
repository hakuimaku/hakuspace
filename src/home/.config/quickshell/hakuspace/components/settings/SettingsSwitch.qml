import QtQuick
import "../../services"

Item {
    id: root
    // Reuse Hikai's two-state liquid control instead of platform switch chrome.
    property string text: ""
    property bool checked: false
    property Item shortcutTarget: null
    property string settingsNavRole: "control"
    readonly property bool stacked: width < 260 && text.length > 0
    signal toggled(bool value)
    implicitWidth: 260
    implicitHeight: stacked ? caption.implicitHeight + Theme.spaceSm + toggle.height : Math.max(Theme.comfortableControlHeight, caption.implicitHeight)
    Text {
        id: caption
        width: root.stacked ? root.width : Math.max(0, root.width - toggle.width - Theme.spaceSm)
        anchors.verticalCenter: root.stacked ? undefined : parent.verticalCenter
        text: root.text
        visible: text.length > 0
        wrapMode: Text.Wrap
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }
    SettingsSegmentedToggle {
        id: toggle
        x: root.stacked || !root.text ? 0 : root.width - width
        y: root.stacked ? caption.height + Theme.spaceSm : 0
        width: Math.min(126, root.width)
        height: Theme.comfortableControlHeight
        settingsNavRole: root.settingsNavRole
        checked: root.checked
        available: root.enabled
        hint: root.text
        Accessible.name: root.Accessible.name || root.text
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        onToggled: value => root.toggled(value)
    }
}
