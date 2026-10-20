import QtQuick
import "../services"
import "hakumenu" as HakuMenu

Item {
    id: root
    required property var modelData
    // Retain ownership through a screen becoming null during delegate teardown.
    property string outputName: ""
    Component.onCompleted: outputName = modelData.name
    Component.onDestruction: UiState.closeHakuMenuIfScreen(outputName)
    // Route each presentation through one edge-specific owner.
    readonly property bool panelOpen: top.panelOpen || bottom.panelOpen || floating.panelOpen
    readonly property real targetMenuWidth: ChromeLayout.taskbarMode ? bottom.targetMenuWidth : top.targetMenuWidth
    HakuMenu.HakuMenuTopFlare { id: top; modelData: root.modelData }
    HakuMenu.HakuMenuBottomFlare { id: bottom; modelData: root.modelData }
    HakuMenu.HakuMenuDockFloating { id: floating; modelData: root.modelData }
}
