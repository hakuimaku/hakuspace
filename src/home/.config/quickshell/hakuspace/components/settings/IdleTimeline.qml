import QtQuick
import "../../services"
import "SettingsValueLogic.js" as Logic
import "SettingsNavigation.js" as Navigation

Column {
    id: root
    property Item shortcutTarget: null
    enabled: ShellSettingsStore.ready && ShellTransitionState.chromeEnabled && ["hyprland", "niri", "mango"].includes(WM.backendName)
    readonly property var policy: ShellSettingsStore.values.idle
    readonly property var stages: Logic.timeline(policy)
    readonly property int total: stages[stages.length - 1].absolute
    property real dragLimit: 0
    // Freeze only pointer conversion; later milestones still expand the preview range.
    readonly property real limit: Math.max(600, total * 1.2)
    // Reveal the enabled-stage switch or its interval editor without changing policy.
    function reveal(id) {
        for (var i = 0; i < stageRows.count; i++) {
            var row = stageRows.itemAt(i)
            if (id !== "idle-" + row.modelData.key + "Timeout" && id !== "idle-" + row.modelData.key + "Enabled") continue
            var targets = Navigation.collect(row)
            var target = id.endsWith("Timeout") ? targets.find(item => item.settingsNavRole === "input") || targets[0] : targets[0]
            if (target) target.forceActiveFocus()
            return row
        }
        return null
    }
    spacing: Theme.spaceMd
    Text { width: parent.width; text: AppState.idleInhibited ? "Paused by Keep Awake" : IdleService.settings.inhibitOnAudio && IdleService.customInhibit.audio ? "Paused by audio playback policy" : !policy.enabled ? "Idle management is disabled" : "Time since inactivity began"; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
    Item {
        id: graph
        objectName: "settings-idle-preview"
        width: parent.width; height: 76
        Rectangle { x: 8; y: 34; width: parent.width - 16; height: 3; radius: 2; color: Theme.hoverMuted }
        Text { y: 8; text: "0"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
        Repeater {
            // Preserve the MouseArea and its grab while editing the policy.
            model: root.stages.length
            delegate: Item {
                id: marker
                required property int index
                readonly property var modelData: root.stages[index]
                objectName: "settings-idle-milestone-" + modelData.key
                visible: modelData.enabled
                x: Math.max(0, Math.min(graph.width - width, 8 + modelData.absolute / root.limit * Math.max(0, graph.width - 32)))
                y: 28; width: 16; height: 16
                Rectangle { anchors.fill: parent; radius: 8; color: Theme.accent }
                Text {
                    objectName: "settings-idle-time-" + marker.modelData.key
                    anchors.bottom: parent.top; anchors.bottomMargin: 6
                    width: Math.min(implicitWidth, graph.width)
                    x: Math.max(-marker.x, Math.min((marker.width - width) / 2, graph.width - marker.x - width))
                    elide: Text.ElideRight
                    text: Math.floor(marker.modelData.absolute / 60) + ":" + String(marker.modelData.absolute % 60).padStart(2, "0")
                    color: Theme.fgDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.SizeHorCursor
                    onPressed: root.dragLimit = root.limit
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var absolute = Math.max(0, mapToItem(graph, mouse.x, mouse.y).x - 8) / Math.max(1, graph.width - 32) * (root.dragLimit || root.limit)
                        SettingsCoordinator.set("idle-" + marker.modelData.key + "Timeout", Logic.intervalAt(root.policy, marker.modelData.key, absolute), true)
                    }
                    onReleased: { root.dragLimit = 0; SettingsCoordinator.flush() }
                    onCanceled: { root.dragLimit = 0; SettingsCoordinator.flush() }
                }
                SettingsTooltip { target: marker; active: markerHover.hovered; text: marker.modelData.label + " · Drag to adjust time since inactivity began" }
                HoverHandler { id: markerHover }
            }
        }
    }
    Text { width: parent.width; text: root.policy.suspendEnabled ? "Total time to suspend: " + Logic.duration(root.total) : "Suspend disabled · Final action after " + Logic.duration(root.total); color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; wrapMode: Text.Wrap }
    Repeater {
        id: stageRows
        model: root.stages.length
        delegate: Column {
            id: stage
            required property int index
            readonly property var modelData: root.stages[index]
            width: parent.width; spacing: Theme.spaceSm
            SettingsSwitch { width: parent.width; text: stage.modelData.label; checked: stage.modelData.enabled; shortcutTarget: root.shortcutTarget; onToggled: value => SettingsCoordinator.set("idle-" + stage.modelData.key + "Enabled", value) }
            SettingsReveal {
                width: parent.width
                expanded: stage.modelData.enabled
                expandedHeight: milestone.implicitHeight
                Text { id: milestone; width: parent.width; wrapMode: Text.Wrap; text: "At " + Logic.duration(stage.modelData.absolute) + " of inactivity"; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            }
            SettingsDurationField { width: parent.width; descriptor: ({label: stage.modelData.label, min: 10, max: 86400, step: 10}); value: stage.modelData.interval; enabled: stage.modelData.enabled; shortcutTarget: root.shortcutTarget; onEdited: value => SettingsCoordinator.set("idle-" + stage.modelData.key + "Timeout", value) }
        }
    }
}
