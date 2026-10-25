import QtQuick
import Quickshell
import "../../services"
import "../base" as Base
import "../base/SafeZoneGeometry.js" as Safe
import "../dock" as Dock

Item {
    id: root
    required property var modelData
    required property var hostWindow
    required property var inputLifetime
    required property string activationSource
    required property var safeRect
    property bool active: false
    property bool shown: false
    property bool suppressTooltips: false
    property real bottomInset: 0
    property real sideInset: 0
    property real targetHeight: ScreenGeometry.appBarHeight
    property real visualHeight: targetHeight
    property real viewportLimit: width
    property real pointerX: NaN
    property real pointerY: NaN
    readonly property int iconSize: ShellSettingsStore.dockIconSize
    readonly property real hoverPadding: iconSize * ShellSettingsStore.dockHoverScale / 200
    readonly property real headroom: ShellSettingsStore.dockHoverLift + hoverPadding * 2 + 4
    readonly property real hoverX: shown && !reorderKey
        && pointerY >= height - bottomInset - targetHeight - headroom && pointerY <= height - bottomInset
        ? pointerX - viewport.x + viewport.contentX - items.x : NaN
    readonly property real contentWidth: items.implicitWidth
    readonly property real viewportWidth: viewport.width
    readonly property real tooltipHeight: tooltipLayer.surfaceHeight
    property bool statsSubscribed: false
    // Confirmation belongs to the app and is dismissed when its hover ends.
    property string terminationKey: ""
    property string terminationMessage: ""
    property var terminationRoots: []
    // Keep pin feedback local to the output that requested the mutation.
    property var pendingPin: null
    property string pinMessage: ""
    // Keep the shared pin order unchanged until a valid drop commits one move.
    property string reorderKey: ""
    property string reorderPin: ""
    property string reorderTarget: ""
    property real reorderPointerX: 0
    property real reorderPointerY: 0
    property real reorderGrabX: 0
    property var reorderSnapshot: []
    property rect reorderMarker: Qt.rect(0, 0, 0, 0)
    readonly property var places: ShellSettingsStore.dockShowDevices ? SysStats.mounts.filter(function(mount) {
        return mount.target && mount.target !== "/" && !/^\/(boot|home|usr|var|etc|nix)(\/|$)/.test(mount.target)
    }) : []
    readonly property bool tooltipsEnabled: shown && !suppressTooltips && !reorderKey && !pinMessage
        && !(UiState.activePanel === "appMenu" && !!UiState.appMenu && UiState.appMenu.screenName === root.modelData.name)

    // Balance subscriptions and cancel pending gestures when a host loses ownership.
    onActiveChanged: {
        syncStats()
        if (!active) {
            cancelTermination(); cancelReorder(); clearPinFeedback()
            if (TooltipManager.activeBar === hostWindow) TooltipManager.dismiss()
        }
    }
    onShownChanged: if (!shown) { cancelTermination(); cancelReorder(); clearPinFeedback() }
    Component.onCompleted: syncStats()
    Component.onDestruction: if (statsSubscribed) SysStats.releaseExtended()
    // Only actual key or pointer input changes the tooltip's interaction mode.
    function setInputMode(keyboard) {
        if (keyboard) root.inputLifetime.beginKeyboardLease()
        else root.inputLifetime.forcePointerMode()
    }
    // Translate the real scrolled icon from the bounded bottom window into output-local coordinates.
    function menuAnchor(item) {
        var point = item.mapToItem(hostWindow.contentItem, item.iconRect.x, item.iconRect.y)
        return {x: sideInset + point.x, y: modelData.height - hostWindow.height + point.y,
            width: item.iconRect.width, height: item.iconRect.height}
    }
    // Acquire the shared mount feed once per enabled output.
    function syncStats() {
        if (statsSubscribed === active) return
        statsSubscribed = active
        if (statsSubscribed) SysStats.acquireExtended()
        else SysStats.releaseExtended()
    }
    // Pin mutations use the canonical shared file without opening a menu.
    function togglePin(app) {
        cancelTermination()
        if (!app || app.type !== "app" || TaskbarPins.busy) return
        pendingPin = {action: app.pinned ? "remove" : "add", id: app.pinned ? app.pinId : app.desktopId || app.appId, name: app.name}
        TaskbarPins.run(pendingPin.action, [pendingPin.id])
    }
    // Expire feedback and release autohide when another interaction takes over.
    function clearPinFeedback() {
        pinMessage = ""
        pinFeedbackTimer.stop()
        root.inputLifetime.releaseExternalLease("dock-pin-feedback", false)
    }
    // A second middle click confirms the same process roots or native windows.
    function terminate(app) {
        if (!app || !app.runningCount || DockApps.terminationBusy) return
        clearPinFeedback()
        var roots = terminationKey === app.key ? terminationRoots : []
        cancelTermination()
        terminationKey = app.key
        if (!DockApps.terminate(app, roots)) terminationMessage = "Could not identify this app’s process."
    }
    // Clear pending confirmation when the item or Dock loses its input lifetime.
    function cancelTermination() {
        terminationKey = ""
        terminationMessage = ""
        terminationRoots = []
    }
    // Hold the autohide lease while a grabbed icon can leave the input envelope.
    function beginReorder(app, item, x, y) {
        if (!shown || !app || TaskbarPins.busy || (!app.pinned && app.type !== "system")) return
        clearPinFeedback()
        cancelTermination()
        reorderSnapshot = TaskbarPins.pins.map(function(pin) { return pin.id })
        reorderPin = app.pinId
        reorderTarget = reorderPin
        reorderGrabX = x
        var point = item.mapToItem(items, x, y)
        reorderPointerX = point.x
        reorderPointerY = point.y
        reorderKey = app.key
        root.inputLifetime.acquireExternalLease("dock-reorder")
    }
    // Compare fixed slots while only the grabbed artwork follows the pointer.
    function updateReorder(item, x, y) {
        if (!reorderKey) return
        var point = item.mapToItem(items, x, y)
        reorderPointerX = point.x
        reorderPointerY = point.y
        updateReorderTarget()
    }
    // Select the nearest pin slot after pointer motion or edge scrolling.
    function updateReorderTarget() {
        var nearest = null
        var distance = Infinity
        for (var index = 0; index < appSlots.count; ++index) {
            var slot = appSlots.itemAt(index)
            if (!slot || !slot.app || (!slot.app.pinned && slot.app.type !== "system")) continue
            var delta = Math.abs(reorderPointerX - slot.x - slot.width / 2)
            if (delta < distance) { nearest = slot; distance = delta }
        }
        if (!nearest) return
        reorderTarget = nearest.app.pinId
        var forward = reorderSnapshot.indexOf(reorderPin) < reorderSnapshot.indexOf(reorderTarget)
        reorderMarker = Qt.rect(nearest.x + (forward ? nearest.width + items.spacing / 2 : -items.spacing / 2),
            items.y + 4, 2, iconSize)
    }
    // Cancel outside drops and stale snapshots instead of moving a different pin.
    function finishReorder(item, x, y) {
        if (!reorderKey) return
        updateReorder(item, x, y)
        var point = item.mapToItem(hostWindow.contentItem, x, y)
        var from = reorderSnapshot.indexOf(reorderPin)
        var to = reorderSnapshot.indexOf(reorderTarget)
        var valid = Safe.contains(safeRect, point.x, point.y) && !TaskbarPins.busy
            && JSON.stringify(reorderSnapshot) === JSON.stringify(TaskbarPins.pins.map(function(pin) { return pin.id }))
        cancelReorder()
        if (valid && from >= 0 && to >= 0 && from !== to) TaskbarPins.move(from, to)
    }
    // Release the pointer lease for drop, Escape, manual OFF or external edits.
    function cancelReorder() {
        if (!reorderKey) return
        reorderKey = ""
        reorderPin = ""
        reorderTarget = ""
        reorderSnapshot = []
        root.inputLifetime.releaseExternalLease("dock-reorder", false)
    }
    Connections {
        target: TaskbarPins
        function onPinsChanged() { if (root.reorderKey) root.cancelReorder() }
        function onMutationFinished(action, id, success) {
            if (!root.pendingPin || root.pendingPin.action !== action || root.pendingPin.id !== id) return
            var name = root.pendingPin.name
            root.pendingPin = null
            if (!root.shown) return
            root.pinMessage = success ? (action === "add" ? "Pinned “" : "Unpinned “") + name + "”" : TaskbarPins.error
            root.inputLifetime.acquireExternalLease("dock-pin-feedback")
            pinFeedbackTimer.restart()
        }
    }
    Timer { id: pinFeedbackTimer; interval: 2000; onTriggered: root.clearPinFeedback() }
    Connections {
        target: DockApps
        function onTerminationFinished(key, result) {
            if (key !== root.terminationKey || !root.shown) return
            if (result.status === "confirmation") {
                root.terminationRoots = result.roots
                root.terminationMessage = result.message || (Math.round(result.ramMb) + " MB RAM (warning at " + result.thresholdMb
                    + " MB).\nMiddle-click again to close. Esc to cancel.")
            } else if (result.status === "error") root.terminationMessage = result.message
            else root.cancelTermination()
        }
    }


    Base.TooltipLayer {
        id: tooltipLayer
        y: root.height - root.targetHeight
        bottomAttached: true
    }
    // Paint transient feedback above the lifted icons without taking pointer input.
    Rectangle {
        objectName: "dock-pin-feedback"
        x: (root.hostWindow.width - width) / 2
        y: (root.hostWindow.height - root.bottomInset - root.visualHeight) - root.headroom - height - 10
        width: Math.min(380, root.hostWindow.width - 16, pinLabel.implicitWidth + 24)
        height: pinLabel.implicitHeight + 16
        radius: Theme.radius / 2
        color: Theme.hoverMuted
        visible: root.shown && !!root.pinMessage
        z: 30
        Accessible.role: Accessible.AlertMessage
        Accessible.name: root.pinMessage
        Text {
            id: pinLabel
            anchors.fill: parent
            anchors.margins: 8
            text: root.pinMessage
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
    // Scroll crowded docks inside a bounded surface while retaining fixed icon slots.
    Flickable {
        id: viewport
        x: (root.hostWindow.width - width) / 2
        y: root.hostWindow.height - root.bottomInset - height
        width: Math.max(0, Math.min(contentWidth, root.viewportLimit))
        height: Math.max(0, root.visualHeight - 4) + root.headroom
        contentWidth: items.implicitWidth + root.hoverPadding * 2
        contentHeight: height
        clip: true
        interactive: !root.reorderKey && contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        visible: root.visualHeight > 1
        enabled: root.shown
        opacity: Math.min(1, root.visualHeight / root.targetHeight)
        // Scroll crowded pins at the edge while keeping the grabbed icon under the pointer.
        Timer {
            interval: 16
            repeat: true
            running: !!root.reorderKey && viewport.contentWidth > viewport.width
            onTriggered: {
                var x = items.x + root.reorderPointerX - viewport.contentX
                var y = items.y + root.reorderPointerY
                if (y < 0 || y > viewport.height) return
                var step = x < 24 ? -4 : x > viewport.width - 24 ? 4 : 0
                var next = Math.max(0, Math.min(viewport.contentWidth - viewport.width, viewport.contentX + step))
                var delta = next - viewport.contentX
                viewport.contentX = next
                root.reorderPointerX += delta
                root.updateReorderTarget()
            }
        }
        Rectangle {
            x: items.x - viewport.contentX + root.reorderMarker.x
            y: root.reorderMarker.y
            width: root.reorderMarker.width
            height: root.reorderMarker.height
            color: Theme.accent
            visible: !!root.reorderKey && root.reorderTarget !== root.reorderPin
            z: 20
        }
        Row {
            id: items
            x: root.hoverPadding
            y: viewport.height - root.targetHeight + 4
            spacing: 4
            ScriptModel { id: apps; values: DockApps.renderedApps.map(function(app) { return app.key }) }
            Repeater {
                id: appSlots
                model: apps
                delegate: Row {
                    id: appSlot
                    required property string modelData
                    readonly property var app: DockApps.renderedApps.find(function(value) { return value.key === appSlot.modelData })
                    spacing: 4
                    z: root.reorderKey === modelData ? 10 : 0
                    Dock.DockItem {
                        id: appIcon
                        iconSize: root.iconSize
                        hoverX: root.hoverX - appSlot.x
                        label: appSlot.app ? appSlot.app.name + (runningCount ? " · " + runningCount + " window" + (runningCount === 1 ? "" : "s") : "") : ""
                        icon: appSlot.app ? appSlot.app.icon : "application-x-executable"
                        runningCount: appSlot.app ? appSlot.app.runningCount : 0
                        active: !!appSlot.app && appSlot.app.active
                        appActions: !!appSlot.app && appSlot.app.type === "app"
                        reorderable: !!appSlot.app && (appSlot.app.pinned || appSlot.app.type === "system") && !TaskbarPins.busy
                        reordering: root.reorderKey === appSlot.modelData
                        reorderOffset: reordering ? root.reorderPointerX - appSlot.x - root.reorderGrabX : 0
                        tooltipEnabled: root.tooltipsEnabled
                        keyboardMode: root.inputLifetime.keyboardLease
                        onInputModeRequested: keyboard => root.setInputMode(keyboard)
                        onReorderStarted: (x, y) => root.beginReorder(appSlot.app, appIcon, x, y)
                        onReorderMoved: (x, y) => root.updateReorder(appIcon, x, y)
                        onReorderFinished: (x, y) => root.finishReorder(appIcon, x, y)
                        onReorderCanceled: root.cancelReorder()
                        actionMessage: root.terminationKey === appSlot.modelData ? root.terminationMessage : ""
                        onRunningCountChanged: if (!runningCount && root.terminationKey === appSlot.modelData) root.cancelTermination()
                        onHoveredChanged: if (!hovered && root.terminationKey === appSlot.modelData) root.cancelTermination()
                        onDismissRequested: root.cancelTermination()
                        onActivated: {
                            if (!appSlot.app || !root.active) return
                            root.cancelTermination()
                            if (appSlot.app.type === "system") UiState.toggleHakuMenu(root.modelData.name, "drun", root.activationSource, root.menuAnchor(appIcon))
                            else DockApps.activate(appSlot.app)
                        }
                        onContextMenuRequested: {
                            if (!appSlot.app || !root.active) return
                            root.cancelTermination()
                            UiState.openAppMenu(appSlot.app, root.modelData.name, root.menuAnchor(appIcon))
                        }
                        onPinRequested: root.togglePin(appSlot.app)
                        onTerminateRequested: root.terminate(appSlot.app)
                    }
                    Rectangle {
                        width: 1
                        height: root.iconSize * 0.6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!appSlot.app && appSlot.app.type === "system"
                        color: Theme.border
                    }
                }
            }
            Rectangle {
                visible: ShellSettingsStore.dockShowTrash || root.places.length > 0
                width: 1; height: root.iconSize * 0.6; y: 12; color: Theme.border
            }
            Repeater {
                model: root.places
                delegate: Dock.DockItem {
                    required property var modelData
                    tooltipEnabled: root.tooltipsEnabled
                    keyboardMode: root.inputLifetime.keyboardLease
                    onInputModeRequested: keyboard => root.setInputMode(keyboard)
                    iconSize: root.iconSize
                    hoverX: root.hoverX - x
                    label: modelData.target + " · " + modelData.percent + "% used"
                    icon: "drive-removable-media"
                    onActivated: Quickshell.execDetached(["gio", "open", modelData.target])
                }
            }
            Dock.DockItem {
                visible: ShellSettingsStore.dockShowTrash
                tooltipEnabled: root.tooltipsEnabled
                keyboardMode: root.inputLifetime.keyboardLease
                onInputModeRequested: keyboard => root.setInputMode(keyboard)
                iconSize: root.iconSize
                hoverX: root.hoverX - x
                label: "Trash"
                icon: "user-trash"
                onActivated: Quickshell.execDetached(["gio", "open", "trash:///"])
            }
        }
    }
}
