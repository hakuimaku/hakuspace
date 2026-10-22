import QtQuick
import "../../services"

Column {
    id: root
    // Keep section content padded inside one shared bordered surface.
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
            text: root.title.toUpperCase()
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }
        Rectangle {
            width: Math.max(0, parent.width - heading.width - parent.spacing)
            height: 1
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.hoverMuted
        }
    }, Rectangle {
        width: parent.width
        height: body.implicitHeight + 32
        radius: Theme.radius
        color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, root.highlighted ? 0.5 : 0.22))
        border.width: 1
        border.color: root.highlighted ? Qt.alpha(Theme.fg, 0.25) : Theme.hoverMuted
        Behavior on color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
        Behavior on border.color { ColorAnimation { duration: HAnimation.buttonHoverDuration } }
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
