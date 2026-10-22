import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../motion" as Motion

ClippingRectangle {
    id: root
    required property var windowEntry
    required property bool selected
    signal hovered()
    signal chosen()
    // The contour grows inward, preserving the atlas cell and pointer footprint.
    readonly property real selection: feedback.selectProgress
    contentInsideBorder: false
    radius: Theme.largeRadius + (1 - selection) * 8
    color: Theme.surface
    border.width: selected ? 3 : 0
    border.color: Theme.fg
    Motion.ButtonMotion { id: feedback; selected: root.selected }
    ClippingRectangle {
        x: 13; y: 13
        width: Math.max(0, parent.width - 26)
        height: Math.max(0, parent.height - 77)
        radius: Math.max(0, root.radius - 13)
        color: Theme.hoverMuted
        WindowPreview {
            anchors.fill: parent
            windowEntry: root.windowEntry
            generation: WindowNavigator.previewGeneration
        }
    }
    // A width reveal expands the selected metadata rail within stable card bounds.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 51
        width: Math.max(0, (parent.width - 32) * (0.8 + 0.2 * root.selection))
        height: 35
        radius: height / 2
        color: root.selected ? Theme.fg : Theme.hoverMuted
        clip: true
        Image {
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            source: Quickshell.iconPath(root.windowEntry.icon, "application-x-executable")
            fillMode: Image.PreserveAspectFit
        }
        Text {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 2 * Math.max(38, chip.width + 26))
            horizontalAlignment: Text.AlignHCenter
            text: root.windowEntry.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.selected ? Theme.surface : Theme.fg
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
        }
        Text {
            id: chip
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: (root.windowEntry.urgent ? "! · " : "")
                + (root.windowEntry.special ? "◇ " : "") + root.windowEntry.workspaceName.replace(/^special:/, "")
                + (root.windowEntry.monitorName !== WindowNavigator.screenName ? " · " + root.windowEntry.monitorName : "")
            color: root.selected ? Theme.surface : Theme.fg
            font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 3)
            width: Math.min(implicitWidth, parent.width * 0.45)
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: if (containsMouse) root.hovered()
        onClicked: root.chosen()
        onWheel: wheel => wheel.accepted = true
    }
    Accessible.role: Accessible.Button
    Accessible.name: windowEntry.appName + ": " + windowEntry.title + ", workspace " + windowEntry.workspaceName
    Accessible.onPressAction: chosen()
}
