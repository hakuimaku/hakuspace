import QtQuick
import QtQuick.Dialogs
import "../../services"

Item {
    id: root
    required property string screenName
    readonly property bool releaseReady: settled
    property int lease: 0
    property bool settled: false

    function settle(acceptedFile) {
        if (settled) return
        var serial = lease
        lease = 0
        UiState.endNativeDialog(serial)
        if (acceptedFile) {
            Avatar.lastError = ""
            if (!ImageEditor.openAvatar(acceptedFile, root.screenName))
                UiState.reopenDashboardAfterAvatar()
        } else {
            UiState.reopenDashboardAfterAvatar()
        }
        settled = true
    }

    FileDialog {
        id: dialog
        title: "Select Avatar"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)", "All files (*)"]
        onAccepted: root.settle(selectedFile)
        onRejected: root.settle("")
    }

    Component.onCompleted: {
        lease = UiState.nativeDialogSerial
        if (UiState.nativeDialogOwner === "avatarPicker" && lease > 0) dialog.open()
        else settled = true
    }
    Component.onDestruction: {
        if (!settled && lease > 0) UiState.endNativeDialog(lease)
    }
}
