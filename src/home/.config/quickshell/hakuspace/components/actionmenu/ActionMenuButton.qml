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

    // Resolve the page once for pointer selection and the rendered selection fade.
    readonly property Item page: {
        var item = parent
        while (item && item.selectionPillOpacity === undefined) item = item.parent
        return item
    }
    readonly property real selectionOpacity: page ? page.selectionPillOpacity : 1
    readonly property color contentForeground: (selected || focused) && page
        ? page.selectionColor(danger ? Theme.danger : Theme.fg, foreground) : foreground
    signal pointerSelected()

    Connections {
        target: root.page
        function onPointerSelectionMoved() { if (root.hovered) root.pointerSelected() }
    }

    // Clear MorphButton's internal center text
    text: ""

    radius: Theme.radius
    implicitHeight: Math.max(Theme.comfortableControlHeight, Theme.fontSize * 2.5)

    selectedOverridesHover: true

    idleColor: danger ? Qt.rgba(1.0, 0.3, 0.3, 0.12) : "transparent"
    hoverColor: (selected || focused) ? "transparent"
                                      : (danger ? Qt.rgba(1.0, 0.3, 0.3, 0.28)
                                                : "transparent")
    pressedColor: (selected || focused) ? "transparent"
                                        : (danger ? Qt.rgba(1.0, 0.3, 0.3, 0.42)
                                                  : Theme.hoverMuted)
    selectedColor: "transparent"
    focusColor: "transparent"

    foregroundColor: danger ? Theme.danger : Theme.fg
    hoverForegroundColor: (selected || focused) ? selectedForegroundColor
                                                : (danger ? "#ffffff" : Theme.fg)
    pressedForegroundColor: selectedForegroundColor
    selectedForegroundColor: danger ? "#ffffff" : Theme.onAccentColor
    Accessible.role: Accessible.Button
    Accessible.name: label + (secondaryText ? ", " + secondaryText : "")
    Accessible.onPressAction: clicked()

    readonly property color targetTrailingForeground:
        (root.selected || root.focused) ? (root.danger ? "#ffffff" : Theme.onAccentColor)
        : root.hovered ? Theme.fg
        : Theme.fgMuted
    property color animatedTrailingForeground: targetTrailingForeground
    readonly property color trailingForeground: (selected || focused) && page
        ? page.selectionColor(Theme.fgMuted, animatedTrailingForeground) : animatedTrailingForeground

    Behavior on animatedTrailingForeground {
        ColorAnimation {
            duration: root.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.transitionCurve
        }
    }

    // Returns button screen coordinates and styling metrics for seed morphing animations.
    function getSurfaceGeometry(surfaceItem) {
        // Match the selection pill's layout bounds while the button is pressed or hovered.
        var screenPt = parent.mapToItem(null, root.x, root.y);
        return {
            screenX: screenPt.x,
            screenY: screenPt.y,
            x: screenPt.x,
            y: screenPt.y,
            width: root.width,
            height: root.height,
            radius: root.radius,
            color: root.danger ? Theme.dangerFill : Theme.accent,
            icon: root.icon,
            label: root.label,
            secondaryText: root.secondaryText
        };
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceLg
        anchors.rightMargin: Theme.spaceLg
        spacing: Theme.spaceMd

        Text {
            id: iconText
            visible: root.icon.length > 0
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            color: root.contentForeground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.preferredWidth: visible ? Theme.fontSize * 1.8 : 0
        }

        Text {
            id: labelText
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: root.contentForeground
            elide: Text.ElideRight
            Layout.fillWidth: true
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: secondaryLabel
            visible: root.secondaryText.length > 0
            text: root.secondaryText
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, Theme.fontSize - 1)
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
            readonly property color normalBackground: Qt.rgba(root.badgeColor.r, root.badgeColor.g, root.badgeColor.b, 0.2)
            color: (root.selected || root.focused) && root.page
                ? root.page.selectionColor(normalBackground, root.danger ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.22))
                : normalBackground
            Layout.alignment: Qt.AlignVCenter

            Behavior on color {
                enabled: root.selectionOpacity >= 0.999
                ColorAnimation {
                    duration: root.transitionDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.transitionCurve
                }
            }

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 4)
                font.weight: Font.Medium
                color: (root.selected || root.focused) && root.page
                    ? root.page.selectionColor(root.badgeColor, root.danger ? "#ffffff" : Theme.onAccentColor)
                    : root.badgeColor

                Behavior on color {
                    enabled: root.selectionOpacity >= 0.999
                    ColorAnimation {
                        duration: root.transitionDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.transitionCurve
                    }
                }
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
