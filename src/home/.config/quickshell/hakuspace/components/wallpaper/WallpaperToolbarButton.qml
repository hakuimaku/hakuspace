import QtQuick
import "../../services"
import "../base" as Base
import "../settings" as Settings

// Icon and label fonts stay independent while the hitbox and padding remain stable.
WallpaperActionButton {
    id: root
    property string caption: ""
    property string icon: ""
    property string description: caption
    property bool showTooltip: true
    property bool useSettingsTooltip: false
    property real horizontalPadding: 12
    property real iconSize: 20
    readonly property bool wallpaperTooltipTarget: !useSettingsTooltip
    text: ""
    implicitWidth: Math.max(height, buttonContent.implicitWidth + horizontalPadding * 2)
    implicitHeight: Math.max(24, Math.floor(Theme.topBarHeight - 12))
    height: implicitHeight
    expandedVisual: false
    hoverXScaleDelta: 0
    pressXScaleDelta: 0
    hoverScaleDelta: 0
    pressScaleDelta: 0
    radius: Math.min(8, height / 2)
    idleColor: "transparent"
    hoverColor: Qt.lighter(Theme.hoverMuted, 1.3)
    Accessible.name: description
    Row {
        id: buttonContent
        objectName: "wallpaper-button-content"
        z: 1
        anchors.centerIn: parent
        spacing: root.icon && root.caption ? 6 : 0
        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.foreground
            anchors.verticalCenter: parent.verticalCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.iconSize
        }
        Text {
            visible: root.caption.length > 0
            text: root.caption
            color: root.foreground
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
        }
    }
    Base.HTooltip {
        target: root
        text: root.description
        active: !root.useSettingsTooltip && root.showTooltip && root.hovered && root.enabled && root.visible
    }
    Loader {
        objectName: "wallpaper-settings-tooltip-loader"
        active: root.useSettingsTooltip
        sourceComponent: Settings.SettingsTooltip {
            objectName: "wallpaper-settings-tooltip"
            target: root
            text: root.description
            active: root.showTooltip && root.hovered && root.enabled && root.visible
        }
    }
}
