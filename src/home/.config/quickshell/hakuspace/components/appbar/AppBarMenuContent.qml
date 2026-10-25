import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property var app: null
    property string screenName: ""
    readonly property real rowHeight: Math.max(30, Math.round(Theme.fontSize * 2.1))
    readonly property bool isRunning: !!root.app && root.app.runningCount > 0
    implicitWidth: Math.min(260, Math.max(200, Math.round(Theme.fontSize * 15)))
    implicitHeight: layout.implicitHeight + 8
    clip: true

    signal dismissed()

    Column {
        id: layout
        width: parent.width
        y: 4
        spacing: 2

        // App Header
        Item {
            width: parent.width
            height: Math.max(30, Math.round(Theme.fontSize * 2.1))
            visible: !!root.app

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad + 4
                anchors.rightMargin: Theme.pad + 4
                spacing: Theme.gap

                IconImage {
                    id: headerIcon
                    width: Math.round(Theme.fontSize * 1.3)
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    source: root.app ? (DockApps.iconSourcesReady && DockApps.iconSources[root.app.icon]
                        ? DockApps.iconSources[root.app.icon]
                        : (root.app.icon && root.app.icon.startsWith("/")
                            ? "file://" + root.app.icon
                            : Quickshell.iconPath(root.app.icon || "application-x-executable"))) : ""
                    backer.cache: false
                    visible: status !== Image.Error
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.app ? root.app.name : ""
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - headerIcon.width - Theme.gap * 2
                }
            }
        }

        // Separator below header
        Item {
            width: parent.width
            height: 9
            visible: !!root.app

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.pad * 2
                height: 1
                color: Theme.hoverMuted
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.pad * 2
                height: 1
                color: Theme.fg
                opacity: 0.12
            }
        }

        // Action 1: End task (Đóng app) - Only visible and takes space when app is running
        Item {
            id: endTaskRow
            width: parent.width
            height: visible ? root.rowHeight : 0
            visible: root.isRunning

            Motion.MorphButton {
                id: endTaskBtn
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                radius: Theme.radius
                enabled: parent.visible
                idleColor: Theme.surface
                hoverColor: Theme.surfaceHi
                pressedColor: Theme.surfaceHi
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.onAccentColor
                onClicked: {
                    if (root.app && root.app.runningCount > 0) {
                        if (root.app.windows && root.app.windows.length > 0) {
                            for (var w of root.app.windows) {
                                try { w.close() } catch(e) {}
                            }
                        }
                        DockApps.terminate(root.app, [])
                    }
                    root.dismissed()
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad
                    anchors.rightMargin: Theme.pad
                    spacing: Theme.gap

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"
                        color: endTaskBtn.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "End task"
                        color: endTaskBtn.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }

        // Action 2: Pin app / Unpin app
        Item {
            width: parent.width
            height: root.rowHeight
            opacity: enabled ? 1.0 : 0.4
            enabled: !!root.app && root.app.type === "app" && !TaskbarPins.busy

            Motion.MorphButton {
                id: pinBtn
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                radius: Theme.radius
                enabled: parent.enabled
                idleColor: Theme.surface
                hoverColor: Theme.surfaceHi
                pressedColor: Theme.surfaceHi
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.onAccentColor
                onClicked: {
                    if (root.app && root.app.type === "app" && !TaskbarPins.busy) {
                        var action = root.app.pinned ? "remove" : "add"
                        var id = root.app.pinned ? root.app.pinId : (root.app.desktopId || root.app.appId)
                        TaskbarPins.run(action, [id])
                    }
                    root.dismissed()
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad
                    anchors.rightMargin: Theme.pad
                    spacing: Theme.gap

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.app && root.app.pinned ? "󰤉" : "󰐃"
                        color: pinBtn.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.app && root.app.pinned ? "Unpin from App Bar" : "Pin to App Bar"
                        color: pinBtn.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }

        // Separator between upper actions and Settings
        Item {
            width: parent.width
            height: 9

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.pad * 2
                height: 1
                color: Theme.hoverMuted
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.pad * 2
                height: 1
                color: Theme.fg
                opacity: 0.12
            }
        }

        // Action 3: App Bar Settings
        Item {
            width: parent.width
            height: root.rowHeight

            Motion.MorphButton {
                id: settingsBtn
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                radius: Theme.radius
                idleColor: Theme.surface
                hoverColor: Theme.surfaceHi
                pressedColor: Theme.surfaceHi
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.onAccentColor
                onClicked: {
                    UiState.settingsGroup = "appbar"
                    UiState.openSettings(root.screenName)
                    root.dismissed()
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad
                    anchors.rightMargin: Theme.pad
                    spacing: Theme.gap

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰒓"
                        color: settingsBtn.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "App Bar Settings"
                        color: settingsBtn.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
}
