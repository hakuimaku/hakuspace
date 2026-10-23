import QtQuick
import "../services"
import "hakumenu" as HakuMenu
import "base" as Base

Item {
    id: root
    required property var modelData
    // Retain ownership through a screen becoming null during delegate teardown.
    property string outputName: ""
    Component.onCompleted: outputName = modelData.name
    Component.onDestruction: UiState.closeHakuMenuIfScreen(outputName)
    // Route each presentation through one edge-specific owner.
    readonly property bool panelOpen: !!((top.active && top.item && top.item.panelOpen) || (bottom.active && bottom.item && bottom.item.panelOpen) || (floating.active && floating.item && floating.item.panelOpen))
    readonly property real targetMenuWidth: ChromeLayout.taskbarMode ? (bottom.active && bottom.item ? bottom.item.targetMenuWidth : (modelData ? modelData.width * 0.4 : 0)) : (top.active && top.item ? top.item.targetMenuWidth : (modelData ? modelData.width * 0.4 : 0))
    readonly property int loadedCount: Number(top.active) + Number(bottom.active) + Number(floating.active)
    // Resident trigger preserves hover activation while all menu content is unloaded.
    HakuMenu.HakuMenuTrigger { modelData: root.modelData; owner: top.active ? top.item : null }
    Base.LifecycleLoader {
        id: top
        requested: UiState.activePanel === "hakumenu" && UiState.hakuMenuScreenName === root.modelData.name
            && UiState.hakuMenuStyle === "topFlare"
        HakuMenu.HakuMenuAttachedFlare { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: bottom
        requested: UiState.activePanel === "hakumenu" && UiState.hakuMenuScreenName === root.modelData.name
            && UiState.hakuMenuStyle === "bottomFlare"
        HakuMenu.HakuMenuBottomFlare { modelData: root.modelData }
    }
    Base.LifecycleLoader {
        id: floating
        requested: UiState.activePanel === "hakumenu" && UiState.hakuMenuScreenName === root.modelData.name
            && UiState.hakuMenuStyle === "dockFloating"
        HakuMenu.HakuMenuDockFloating { modelData: root.modelData }
    }
}
