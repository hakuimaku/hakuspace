import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property Item shortcutTarget: null
    signal reloadRequested()
    signal confirmationRequested(string action)
    // Freeze edits during IO so a completed save cannot replace a newer draft.
    readonly property bool editable: ShellSettingsStore.ready && !ShellSettingsStore.loading && !ShellSettingsStore.saving
    readonly property var modules: [
        {key: "workspaces", label: "Left · Workspaces", hint: "Show workspaces when supported by the window manager."},
        {key: "windowTitle", label: "Left · Window title", hint: "Show the focused window title."},
        {key: "center", label: "Center · Center module", hint: "Show the dynamic center module."},
        {key: "cava", label: "Center · Cava visualizer", hint: "Allow Cava when media, audio and available space permit."},
        {key: "tray", label: "Right · System tray", hint: "Show system tray icons. Hiding them closes the tray menu."},
        {key: "quickControls", label: "Right · Quick controls", hint: "Show audio, brightness and system controls."},
        {key: "recorder", label: "Right · Recorder", hint: "Hide the idle recorder. Active recording always keeps its indicator visible."},
        {key: "clock", label: "Right · Clock", hint: "Show the TopBar clock. Dashboard and calendar keep working."},
        {key: "notifications", label: "Right · Notifications", hint: "Show the bell. Popups, history and DND keep working."}
    ]
    // Section anchors and the footer expose presentation without owning draft state.
    readonly property var sectionCards: [appearance, rounded, surface, appbar, dockbar, topbar]
    readonly property var sidebarSections: sectionCards.map(card => card.title)
    readonly property string activeSection: {
        if (scroll.contentY > 0 && scroll.contentY >= scroll.contentHeight - scroll.height - 1)
            return sidebarSections[sidebarSections.length - 1]
        var current = sidebarSections[0]
        for (var card of sectionCards) {
            if (card.y <= scroll.contentY + 24) current = card.title
        }
        return current
    }
    readonly property var actionLabels: ["Reload", "Reset", "Discard", "Apply"]
    readonly property var actionHints: ({
        Reload: "Read saved Shell settings from disk. Unsaved edits require confirmation.",
        Reset: "Preview default Shell settings. Apply saves them.",
        Discard: "Undo unsaved Shell edits and restore the saved settings, including live previews.",
        Apply: "Save Shell settings and keep Settings open."
    })
    readonly property string footerStatus: ShellSettingsStore.error || ShellSettingsStore.statusMessage
        || (ShellSettingsStore.migrationPending ? "Legacy settings loaded · Apply to upgrade" : ShellSettingsStore.loading ? "Loading…"
            : ShellSettingsStore.saving ? "Saving…" : ShellSettingsStore.dirty ? "Unsaved changes · Apply to save" : "All changes saved · Shell settings")
    readonly property bool footerDirty: ShellSettingsStore.dirty || ShellSettingsStore.migrationPending
    readonly property bool footerError: !!ShellSettingsStore.error

    // Scroll section cards without changing live-bound preferences.
    function scrollToSection(name) {
        for (var card of sectionCards) {
            if (card.title === name) scroll.contentY = Math.max(0, Math.min(card.y, scroll.contentHeight - scroll.height))
        }
    }
    // Keep migration, validation and IO guards identical to the original footer.
    function canActivate(label) {
        return label === "Reload" ? !ShellSettingsStore.loading && !ShellSettingsStore.saving
            : editable && (label === "Reset" || ShellSettingsStore.dirty || (label === "Apply" && ShellSettingsStore.migrationPending))
              && (label !== "Apply" || ShellSettingsStore.valid)
    }
    // Apply and Discard continue to operate on the shared live preview.
    function activateAction(label) {
        if (label === "Reload") reloadRequested()
        else if (label === "Reset" || label === "Discard") confirmationRequested(label.toLowerCase() + "-shell")
        else ShellSettingsStore.apply()
    }


    Column {
        anchors.fill: parent
        spacing: 6
        Text { text: "Shell"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 5; font.weight: Font.DemiBold }
        Text { width: parent.width; text: "Tune your shell. Changes preview across every monitor."; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 1); wrapMode: Text.Wrap }
        Flickable {
            id: scroll
            width: parent.width
            height: Math.max(0, parent.height - y)
            contentWidth: width
            contentHeight: form.implicitHeight + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar {}
            Column {
                id: form
                y: 12
                width: Math.max(0, scroll.width - 14)
                spacing: 22
                SettingsSectionCard {
                    id: appearance
                    width: parent.width
                    title: "Appearance"
                    SettingsSliderRow { shortcutTarget: root.shortcutTarget; available: root.editable; modelData: ({section: "appearance", key: "baseRadius", label: "Shell radius", min: 4, max: 24}) }
                }
                SettingsSectionCard {
                    id: rounded
                    width: parent.width
                    title: "Rounded Screen"
                    SettingsSliderRow { shortcutTarget: root.shortcutTarget; available: root.editable; modelData: ({section: "roundedScreen", key: "radius", label: "Corner radius", accessible: "Rounded Screen Corner radius", min: 0, max: 24}) }
                    Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
                    SettingsSliderRow { shortcutTarget: root.shortcutTarget; available: root.editable; modelData: ({section: "roundedScreen", key: "borderThickness", label: "Border thickness", accessible: "Rounded Screen Border thickness", min: 0, max: 6}) }
                    Text { width: parent.width; text: "Border applies to left, right and bottom edges. The top edge is owned by TopBar."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                }
                SettingsSectionCard {
                    id: surface
                    width: parent.width
                    title: "Surface"
                    Row {
                        id: surfaceChoices
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: [{key: "ink", label: "Ink"}, {key: "dark", label: "Dark"}, {key: "soft", label: "Soft"}]
                            delegate: SettingsActionButton {
                                settingsNavGroup: surfaceChoices
                                required property var modelData
                                width: Math.min(104, (parent.width - 12) / 3)
                                height: 32
                                text: modelData.label
                                selected: ShellSettingsStore.surfaceTone === modelData.key
                                selectedOverridesHover: true
                                idleColor: Theme.surface
                                hoverColor: Theme.hoverMuted
                                selectedColor: Theme.hoverMuted
                                foregroundColor: Theme.fgDim
                                hoverForegroundColor: Theme.fg
                                selectedForegroundColor: Theme.accent
                                border.color: selected || activeFocus ? Theme.accent : Theme.hoverMuted
                                border.width: 1
                                enabled: root.editable
                                activeFocusOnTab: enabled
                                focused: activeFocus
                                Accessible.name: modelData.label + " surface"
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: selected
                                Accessible.onPressAction: clicked()
                                onClicked: ShellSettingsStore.setValue("appearance", "surfaceTone", modelData.key)
                                Keys.onReturnPressed: clicked()
                                Keys.onSpacePressed: clicked()
                            }
                        }
                    }
                }
                SettingsSectionCard {
                    id: appbar
                    width: parent.width
                    title: "App Bar"
                    Repeater {
                        model: [{key: "showTrash", label: "Trash", labels: ["Hide", "Show"], hint: "Show the Trash shortcut."},
                            {key: "showDevices", label: "Mounted devices", labels: ["Hide", "Show"], hint: "Show mounted storage shortcuts."}]
                        delegate: SettingsToggleRow { available: root.editable }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
                    SettingsSliderRow { shortcutTarget: root.shortcutTarget; available: root.editable; modelData: ({section: "dock", key: "iconSize", label: "Icon size", accessible: "App bar icon size", min: 24, max: 72, step: 4}) }
                    SettingsSliderRow { shortcutTarget: root.shortcutTarget; available: root.editable; modelData: ({section: "dock", key: "hoverLift", label: "Hover lift", accessible: "App bar hover lift", min: 0, max: 48}) }
                    SettingsSliderRow { shortcutTarget: root.shortcutTarget; available: root.editable; modelData: ({section: "dock", key: "hoverScale", label: "Hover enlargement", accessible: "App bar hover enlargement", min: 0, max: 100, unit: "%"}) }
                }
                SettingsSectionCard {
                    id: dockbar
                    width: parent.width
                    title: "Dockbar"
                    Text { width: parent.width; text: "Dockbar is available only while Taskbar Mode is off."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                    Repeater {
                        model: [{key: "visibilityMode", label: "Visibility", labels: ["Auto Hide", "Always"]},
                            {key: "exclusiveSpace", label: "Reserve space", labels: ["Off", "On"]}]
                        delegate: SettingsToggleRow { available: root.editable }
                    }
                }
                SettingsSectionCard {
                    id: topbar
                    width: parent.width
                    title: "Top Bar"
                    Text { width: parent.width; text: "Applies to every monitor. Logo / Navigation stays enabled."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                    Repeater {
                        model: root.modules
                        delegate: SettingsToggleRow { available: root.editable; section: "topbar" }
                    }
                }
            }
        }
    }
}
