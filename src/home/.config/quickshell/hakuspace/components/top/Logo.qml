import QtQuick
import Quickshell
import "../../services"
import ".."

TopModule {
    id: root
    icon: "󰮯"
    isAccent: true
    
    // Circular
    implicitWidth: implicitHeight
    radius: height / 2
    
    tooltip: "Have a nice day!\n(HakuMenu will be added in M4)"
    
    onClicked: {
        UiState.toggle("hakumenu");
    }
}
