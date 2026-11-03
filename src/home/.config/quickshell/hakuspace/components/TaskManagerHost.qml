import QtQuick
import "../services"
import "base" as Base

Base.LifecycleLoader {
    id: root
    required property var modelData
    // Retain output ownership even when a screen disappears during teardown.
    property string outputName: ""
    requested: !!modelData && UiState.taskManagerOpen && UiState.taskManagerScreenName === modelData.name

    // Loading completion, not an animation delay, decides whether a transfer failed.
    function checkHandoff() {
        if (TaskManagerService.handoffScreenName === outputName && requested && !loading && !item)
            UiState.closeTaskManagerIfScreen(outputName)
    }
    onLoadingChanged: Qt.callLater(checkHandoff)
    onItemChanged: Qt.callLater(checkHandoff)
    onRequestedChanged: Qt.callLater(checkHandoff)
    Component.onCompleted: {
        outputName = modelData ? modelData.name : ""
        Qt.callLater(checkHandoff)
    }
    Component.onDestruction: {
        if (outputName) {
            UiState.closeTaskManagerIfScreen(outputName)
            TaskManagerService.finishHandoff(outputName)
        }
    }
    TaskManagerOverlay {
        id: overlay
        modelData: root.modelData
        presentationOwned: root.active && root.item === overlay
    }
}
