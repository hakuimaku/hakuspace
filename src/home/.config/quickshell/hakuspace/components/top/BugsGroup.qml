import QtQuick
import "../../services"
import ".."

TopModule {
    id: root
    required property string screenName
    property bool compact: false

    visible: ShellHealth.showIndicator
    hoverAxis: compact ? "vertical" : "horizontal"
    compactVisual: compact

    // Render custom centered row on horizontal bars so icon/label padding matches Logo and Workspaces.
    icon: compact ? "" : ""
    text: ""
    implicitWidth: verticalPresentation
        ? ScreenGeometry.leftModuleTouchSize
        : Math.max(implicitHeight, pillRow.implicitWidth + Theme.pad * 2 + (hovered ? 12 : 0))
    radius: compact ? Theme.radius : height / 2
    color: hovered ? Theme.danger : Theme.dangerFill
    foregroundColor: Theme.onAccentColor
    tooltip: {
        if (!ShellHealth.hasIssues) return ""
        var lines = ["Hikai service issues (" + ShellHealth.issueCount + ") — click to open Backend Switcher"]
        var list = ShellHealth.issues
        for (var i = 0; i < Math.min(list.length, 3); i++) {
            lines.push("• " + list[i].label + ": " + list[i].detail)
        }
        if (list.length > 3) lines.push("• +" + (list.length - 3) + " more")
        return lines.join("\n")
    }

    Accessible.role: Accessible.Button
    Accessible.name: "Hikai service bugs"

    Row {
        id: pillRow
        visible: !root.compact
        anchors.centerIn: parent
        spacing: Theme.spaceXs + 2
        scale: root.visualScale

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.foregroundColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Bugs" + (ShellHealth.issueCount > 1 ? " (" + ShellHealth.issueCount + ")" : "")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Bold
            color: root.foregroundColor
        }
    }

    onClicked: {
        TooltipManager.dismiss()
        UiState.openActionMenu(root.screenName, "backend")
    }
}
