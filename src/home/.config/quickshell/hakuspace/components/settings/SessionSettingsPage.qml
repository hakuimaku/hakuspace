import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"
import "../motion" as Motion

Item {
    id: root
    // Compose native idle and existing exit preferences without introducing another store.
    property Item shortcutTarget: null
    property string highlightedId: ""
    property string actionError: ""
    signal reloadRequested()
    readonly property var sidebarSections: ["Idle & Power", "Session Exit"]
    readonly property string activeSection: scroll.contentY >= exitCard.y - 24 ? "Session Exit" : "Idle & Power"
    readonly property var actionLabels: ["Reload", "Apply"]
    readonly property var actionHints: ({Reload: "Read saved Session preferences.", Apply: "Save modified Session preferences."})
    readonly property bool editable: ShellSettingsStore.ready && !ShellSettingsStore.loading && !ShellSettingsStore.saving
    readonly property bool footerDirty: SettingsStore.dirty || ShellSettingsStore.dirty || ShellSettingsStore.migrationPending
    readonly property bool footerError: !!(SettingsStore.error || ShellSettingsStore.error || actionError)
    readonly property string footerStatus: actionError || ShellSettingsStore.error || SettingsStore.error
        || (footerDirty ? "Unsaved changes · Apply to save" : "All preferences saved")
    // Descriptor keys also serve as stable search targets.
    readonly property var controls: [
        {key: "enabled", label: "Enable idle management", hint: "Manage inactivity in Hikai."},
        {key: "dimEnabled", label: "Screen dim"},
        {key: "dimTimeout", label: "Dim after", min: 10, max: 86400, step: 10, unit: "s", hint: "Inactivity before dimming the screen."},
        {key: "dimPercent", label: "Dim brightness", min: 1, max: 100, step: 5, unit: "%"},
        {key: "lockEnabled", label: "Lock after inactivity"},
        {key: "lockTimeout", label: "Lock after", min: 10, max: 86400, step: 10, unit: "s", hint: "Delay after screen dim before locking the session."},
        {key: "displayOffEnabled", label: "Turn displays off"},
        {key: "displayOffTimeout", label: "Display off after", min: 10, max: 86400, step: 10, unit: "s", hint: "Delay after lock before turning displays off."},
        {key: "suspendEnabled", label: "Suspend after inactivity"},
        {key: "suspendTimeout", label: "Suspend after", min: 10, max: 86400, step: 10, unit: "s", hint: "Delay after displays turn off before suspending the system."},
        {key: "respectAppInhibitors", label: "Respect application inhibitors"},
        {key: "inhibitOnAudio", label: "Prevent idle while audio is playing", hint: "Automatically pauses Hikai idle actions while an active audio stream is detected."}
    ]

    // Keep stepper edits within their descriptor bounds.
    function idleDescriptor(descriptor) {
        return descriptor
    }

    // Explain saved runtime policy independently from unsaved settings edits.
    readonly property string idleStatus: !IdleService.owner ? "Idle management is inactive in Classic."
        : !IdleService.settings.enabled ? "Idle management is disabled. Apply to activate your changes."
        : !IdleService.enabled ? "Idle management is waiting for session services or display recovery."
        : IdleService.customInhibit.manual ? "Keep Awake is on. Idle actions are paused."
        : (IdleService.settings.inhibitOnAudio && IdleService.customInhibit.audio) ? "Audio keep-awake is active. Idle actions are paused."
        : IdleService.customInhibit.error ? "Could not check idle inhibitors. Idle actions are paused."
        : !IdleService.customInhibit.known ? "Checking idle inhibitors…"
        : "Idle management is active. Waiting for inactivity."
    Component.onCompleted: IdleService.refreshInhibit()

    // Save only dirty domains and retain the existing validation guards.
    function canActivate(label) {
        if (SettingsStore.loading || SettingsStore.saving || ShellSettingsStore.loading || ShellSettingsStore.saving) return false
        return label === "Reload" || (editable && SettingsStore.ready && footerDirty && SettingsStore.valid && ShellSettingsStore.valid)
    }
    // Delegate reload confirmation to the panel that owns both dirty domains.
    function activateAction(label) {
        if (label === "Reload") reloadRequested()
        else {
            if (SettingsStore.dirty) SettingsStore.apply()
            if (ShellSettingsStore.dirty || ShellSettingsStore.migrationPending) ShellSettingsStore.apply()
        }
    }
    // Reveal idle controls or the original exit rows in their composed page.
    function reveal(id) {
        var target = null
        for (var i = 0; i < idleRows.count; ++i) {
            if ("idle-" + idleRows.itemAt(i).modelData.key === id) target = idleRows.itemAt(i)
        }
        if (id === "idle-keep-awake") target = keepAwake
        if (!target) target = exitForm.reveal(id)
        if (target) {
            target.forceActiveFocus()
            scroll.contentY = Math.max(0, Math.min(target.mapToItem(content, 0, 0).y, scroll.contentHeight - scroll.height))
        }
    }
    // Align sidebar anchors with the two independent preference groups.
    function scrollToSection(name) {
        scroll.contentY = name === "Session Exit" ? Math.min(exitCard.y, Math.max(0, scroll.contentHeight - scroll.height)) : 0
    }
    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: Motion.HScrollBar {}
        Column {
            id: content
            width: scroll.width
            spacing: Theme.sectionGap
            Text { text: "Session"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold }
            SettingsSectionCard {
                width: parent.width
                title: "Idle & Power"
                Text { width: parent.width; text: "Stages execute in sequence: Dim → Lock → Display off → Suspend. Timers are cumulative (each stage counts after the previous stage completes). Changes take effect after Apply."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                Text { width: parent.width; text: root.idleStatus; wrapMode: Text.Wrap; color: Theme.fgDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; Accessible.name: text }
                Repeater {
                    id: idleRows
                    model: root.controls
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: Theme.spaceSm
                        Rectangle { width: parent.width; height: 1; color: root.highlightedId === "idle-" + modelData.key ? Theme.accent : Theme.hoverMuted }
                        Text { text: modelData.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                        Text {
                            width: parent.width
                            visible: !!modelData.hint
                            text: modelData.hint || ""
                            color: Theme.fgDescription
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: modelData.key === "inhibitOnAudio" && ShellSettingsStore.values.idle.inhibitOnAudio !== ShellSettingsStore.savedValues.idle.inhibitOnAudio
                            text: "Change pending Apply"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            wrapMode: Text.Wrap
                        }
                        Loader {
                            width: parent.width
                            property var descriptor: modelData
                            sourceComponent: modelData.min !== undefined ? numeric : toggle
                        }
                    }
                }
                SettingsSwitch {
                    id: keepAwake
                    width: parent.width
                    text: "Keep Awake"
                    checked: AppState.idleInhibited
                    shortcutTarget: root.shortcutTarget
                    enabled: !caffeine.running
                    onToggled: { root.actionError = ""; caffeine.running = true }
                }
            }
            SettingsSectionCard {
                id: exitCard
                width: parent.width
                title: "Session Exit"
                GeneralSettingsForm { id: exitForm; width: parent.width; category: "Session"; shortcutTarget: root.shortcutTarget; highlightedId: root.highlightedId }
            }
        }
    }
    Process {
        id: caffeine
        command: [Env.binDir + "/quick_actions_ctl.py", "toggle", "idleInhibit"]
        onExited: code => { if (code !== 0) root.actionError = "Could not change Keep Awake" }
    }
    Timer {
        interval: 2000
        running: root.visible && IdleService.owner
        repeat: true
        onTriggered: IdleService.refreshInhibit()
    }
    Component {
        id: toggle
        SettingsSwitch {
            checked: ShellSettingsStore.values.idle[descriptor.key]
            enabled: root.editable
            shortcutTarget: root.shortcutTarget
            Accessible.name: descriptor.label
            onToggled: value => ShellSettingsStore.setValue("idle", descriptor.key, value)
        }
    }
    Component {
        id: numeric
        SettingsNumberRow {
            descriptor: root.idleDescriptor(parent.descriptor)
            showSlider: false
            value: ShellSettingsStore.values.idle[descriptor.key]
            enabled: root.editable
            shortcutTarget: root.shortcutTarget
            onEdited: value => ShellSettingsStore.setValue("idle", descriptor.key, value)
        }
    }
}
