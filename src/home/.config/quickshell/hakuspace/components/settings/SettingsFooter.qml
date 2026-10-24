import QtQuick
import "../../services"

Rectangle {
    id: root
    // Pages retain action guards and dispatch; actions never wrap onto a second row.
    required property var page
    readonly property var labels: page.actionLabels
    readonly property bool compact: width < 650 && !!root.page.footerStatus
    readonly property real groupGap: labels.length === 4 ? 20 : 0
    readonly property real buttonWidth: Math.max(0, Math.min(
        labels.reduce((widest, label) => Math.max(widest, actionFont.advanceWidth(label) + 28), 80),
        (width - 40 - Math.max(0, labels.length - 1) * 8 - groupGap) / Math.max(1, labels.length)))
    readonly property real actionWidth: buttonWidth * labels.length + Math.max(0, labels.length - 1) * 8 + groupGap
    implicitHeight: (compact ? status.implicitHeight + Theme.spaceSm : 0) + 36 + Theme.spaceLg * 2
    color: Theme.surface
    FontMetrics { id: actionFont; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 1) }
    Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
    Rectangle {
        x: Theme.spaceLg
        y: status.y + (status.height - height) / 2
        visible: !!root.page.footerStatus || root.page.footerDirty
        width: 6; height: 6; radius: Theme.radius
        color: root.page.footerDirty ? Theme.fg : Theme.fgMuted
    }
    Text {
        id: status
        x: Theme.spaceLg + 14
        y: root.compact ? Theme.spaceLg : (parent.height - height) / 2
        width: Math.max(0, parent.width - x - (root.compact ? Theme.spaceLg : actions.width + Theme.spaceLg * 2))
        text: root.page.footerStatus
        color: root.page.footerError ? Theme.fg : Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
        elide: Text.ElideRight
        HoverHandler { id: statusHover }
        SettingsTooltip { target: status; active: statusHover.hovered; text: status.text }
    }
    Item {
        id: actions
        x: root.width - width - Theme.spaceLg
        y: root.compact ? status.y + status.height + Theme.spaceSm : (root.height - height) / 2
        width: root.actionWidth
        height: 36
        Repeater {
            model: root.labels
            delegate: SettingsActionButton {
                id: action
                settingsNavRole: "footer"
                required property string modelData
                required property int index
                readonly property bool primary: ["Apply", "Save", "Save & Switch"].indexOf(modelData) >= 0
                x: index * (root.buttonWidth + 8) + (root.labels.length === 4 && index >= 2 ? root.groupGap : 0)
                width: root.buttonWidth
                height: 36
                clip: true
                text: modelData
                fontSize: Math.max(10, actionFont.font.pixelSize * Math.min(1, (width - 16) / Math.max(1, actionFont.advanceWidth(modelData))))
                idleColor: primary ? Theme.accent : Theme.hoverMuted
                hoverColor: primary ? Theme.accent : Qt.lighter(Theme.hoverMuted, 1.18)
                foregroundColor: primary ? Theme.onAccentColor : Theme.fg
                hoverForegroundColor: foregroundColor
                disabledColor: Theme.hoverMuted
                disabledForegroundColor: Theme.fgMuted
                enabled: root.page.canActivate(modelData)
                activeFocusOnTab: enabled
                focused: activeFocus
                Accessible.name: modelData
                Accessible.role: Accessible.Button
                Accessible.onPressAction: clicked()
                onClicked: root.page.activateAction(modelData)
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
                SettingsTooltip {
                    target: action
                    active: action.hovered || action.activeFocus
                    text: root.page.actionHints ? root.page.actionHints[action.modelData] || action.modelData : action.modelData
                }
            }
        }
    }
}
