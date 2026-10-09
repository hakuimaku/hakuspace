import QtQuick
import Quickshell
import "../../services"
import ".."

TopModule {
    id: root
    icon: "󰮯"
    isAccent: true
    color: Theme.accent
    foregroundColor: Theme.onAccentColor
    iconFontSize: Theme.fontSize + (hovered ? 2 : 0)
    
    implicitWidth: implicitHeight + (hovered ? Theme.pad : 0)
    radius: height / 2
    
    tooltip: "Have a nice day!\n(HakuMenu will be added in M4)"
    
    onClicked: {
        UiState.toggle("hakumenu");
    }
}
