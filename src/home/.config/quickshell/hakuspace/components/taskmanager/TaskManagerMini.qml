import QtQuick
import "../../services"

Item {
    id: root
    // Only the visible root page owns a collector subscription.
    property bool active: false
    property bool interactionOwned: false
    property bool reducedMotion: false
    property bool serviceLeaseHeld: false
    // Preserve the last frame while the shared service stops or warms up.
    property var snapshot: ({})
    readonly property alias content: content

    // Ignore the service's empty shutdown frame so metric bars retain their level.
    function retainSnapshot() {
        if (!active || !TaskManagerService.ready) return
        snapshot = TaskManagerService.snapshot
    }

    // Balance one lease through tab changes, closure and destruction.
    function syncServiceLease() {
        if (active && !serviceLeaseHeld) {
            serviceLeaseHeld = true
            TaskManagerService.acquire()
            retainSnapshot()
        } else if (!active && serviceLeaseHeld) {
            serviceLeaseHeld = false
            TaskManagerService.release()
        }
    }

    // Route focus to the dashboard's standalone handoff control.
    function forcePrimaryFocus() { if (active && interactionOwned) content.forcePrimaryFocus() }
    function clearPrimaryFocus() { content.clearPrimaryFocus() }

    onActiveChanged: {
        syncServiceLease()
        if (!active) {
            clearPrimaryFocus()
        }
    }
    Component.onCompleted: syncServiceLease()
    Component.onDestruction: if (serviceLeaseHeld) TaskManagerService.release()

    Connections {
        target: TaskManagerService
        function onSnapshotChanged() { root.retainSnapshot() }
    }

    TaskManagerMiniDashboard {
        id: content
        anchors.fill: parent
        reducedMotion: root.reducedMotion
        snapshot: root.snapshot
        onOpenFullRequested: UiState.openTaskManagerFromHakuMenu()
    }
}
