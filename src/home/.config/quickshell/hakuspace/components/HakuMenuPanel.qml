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
    // Keep the established top presentation available for triggers and legacy callers.
    readonly property bool panelOpen: top.panelOpen || floating.panelOpen
    readonly property real targetMenuWidth: top.targetMenuWidth
    HakuMenu.HakuMenuTopFlare { id: top; modelData: root.modelData }
    HakuMenu.HakuMenuDockFloating { id: floating; modelData: root.modelData }
}
