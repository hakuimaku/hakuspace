import QtQuick
import "../../services"

Column {
    id: root
    // Keep section content padded inside one shared tonal surface.
    property string title: ""
    readonly property string settingsNavSection: title
    // Allow the owning page to highlight the active card.
    property bool highlighted: false
    default property alias content: body.data
    spacing: 10

    data: [Row {
        width: parent.width
        spacing: 10
        Text {
            id: heading
            text: root.title
            width: Math.min(implicitWidth, parent.width)
            wrapMode: Text.Wrap
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
            font.weight: Font.DemiBold
        }
    }, Rectangle {
        width: parent.width
        height: body.implicitHeight + 32
        radius: Theme.radius
        color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, root.highlighted ? 0.7 : 0.4))
        border.width: 0
        border.color: root.highlighted ? Qt.alpha(Theme.fg, 0.25) : Theme.hoverMuted
        Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
        Column {
            id: body
            x: 16
            y: 16
            width: Math.max(0, parent.width - 32)
            spacing: 14
        }
    }
    ]
}
