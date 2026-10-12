import QtQuick
import QtQuick.Layouts
import "../../services"
import "../motion" as Motion

Motion.MorphButton {
    id: root

    property string icon: ""
    property string label: ""
    property string secondaryText: ""
    property string badge: ""
    property color badgeColor: Theme.accent
    property bool danger: false
    property bool hasSubmenu: false

    // Clear MorphButton's internal center text
    text: ""

    radius: Theme.radius > 0 ? Theme.radius : 10
    implicitHeight: Math.max(44, Theme.fontSize * 2.8)

    selectedOverridesHover: true

    idleColor: danger ? Qt.rgba(1.0, 0.3, 0.3, 0.12) : "transparent"
    hoverColor: (selected || focused) ? "transparent"
                                      : (danger ? Qt.rgba(1.0, 0.3, 0.3, 0.28)
                                                : Qt.darker(Theme.hoverMuted, 1.18))
    pressedColor: (selected || focused) ? "transparent"
                                        : (danger ? Qt.rgba(1.0, 0.3, 0.3, 0.42)
                                                  : Qt.darker(Theme.hoverMuted, 1.35))
    selectedColor: "transparent"
    focusColor: "transparent"

    foregroundColor: (selected || focused) ? (danger ? "#ffffff" : Theme.onAccentColor)
                                           : (danger ? "#ff6b6b" : Theme.fg)
    hoverForegroundColor: (selected || focused) ? foregroundColor
                                                : (danger ? "#ffffff" : Theme.fg)
    selectedForegroundColor: danger ? "#ffffff" : Theme.onAccentColor

    readonly property color trailingForeground:
        (root.selected || root.focused) ? (root.danger ? "#ffffff" : Theme.onAccentColor)
        : root.hovered ? Theme.fg
        : Theme.fgMuted

    // Returns button screen coordinates and styling metrics for seed morphing animations.
    function getSurfaceGeometry(surfaceItem) {
        var screenPt = mapToItem(null, 0, 0);
        return {
            screenX: screenPt.x,
            screenY: screenPt.y,
            x: screenPt.x,
            y: screenPt.y,
            width: root.width,
            height: root.height,
            radius: root.radius,
            color: root.danger ? "#e05555" : Theme.accent,
            icon: root.icon,
            label: root.label,
            secondaryText: root.secondaryText
        };
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pad * 1.2
        anchors.rightMargin: Theme.pad * 1.2
        spacing: Theme.pad

        Text {
            id: iconText
            visible: root.icon.length > 0
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            color: root.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.preferredWidth: visible ? Theme.fontSize * 1.8 : 0
        }

        Text {
            id: labelText
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            color: root.foreground
            elide: Text.ElideRight
            Layout.fillWidth: true
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: secondaryLabel
            visible: root.secondaryText.length > 0
            text: root.secondaryText
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Math.round((Theme.fontSize + 1) * 0.82))
            color: root.trailingForeground
            elide: Text.ElideLeft
            Layout.maximumWidth: parent.width * 0.4
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            id: badgeRect
            visible: root.badge.length > 0
            implicitWidth: badgeText.implicitWidth + 8
            implicitHeight: Math.max(16, Theme.fontSize * 1.2)
            radius: 4
            color: (root.selected || root.focused)
                ? (root.danger ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.22))
                : Qt.rgba(root.badgeColor.r, root.badgeColor.g, root.badgeColor.b, 0.2)
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 4)
                font.weight: Font.Medium
                color: (root.selected || root.focused)
                    ? (root.danger ? "#ffffff" : Theme.onAccentColor)
                    : root.badgeColor
            }
        }

        Text {
            id: chevronText
            visible: root.hasSubmenu
            text: "󰅂"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: root.trailingForeground
            verticalAlignment: Text.AlignVCenter
        }
    }
}
