import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property int clicks: 0
    // Keep the native client alive independently of shell configuration reloads.
    FloatingWindow {
        id: client
        title: "Leftbar frame primary"
        screen: Quickshell.screens[0]
        visible: true
        maximized: true
        color: Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_BACKGROUND") || "#385568"
        MouseArea { anchors.fill: parent; onClicked: root.clicks++ }
    }
    // The frame matrix measures both outputs without changing the normal input fixture.
    FloatingWindow {
        id: secondary
        title: "Leftbar frame secondary"
        screen: Quickshell.screens.find(output => output.name !== client.screen.name) || Quickshell.screens[0]
        visible: Quickshell.env("HAKUSPACE_LEFTBAR_FRAME_ONLY") === "1"
        maximized: true
        color: Quickshell.env("HAKUSPACE_LEFTBAR_WALLPAPER_BACKGROUND") || "#385568"
    }
    IpcHandler {
        target: "leftbarClient"
        function geometry(): string {
            return JSON.stringify({clicks: root.clicks, width: client.width, height: client.height, screen: {name: client.screen.name},
                clients: (Quickshell.env("HAKUSPACE_LEFTBAR_FRAME_ONLY") === "1" ? [client, secondary] : [client]).map(window => ({width: window.width, height: window.height, screen: {name: window.screen.name}}))})
        }
    }
}
