import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Item {
    id: root
    signal reloadRequested()
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

    Column {
        anchors.fill: parent
        spacing: Theme.pad
        Flickable {
            id: scroll
            width: parent.width
            height: Math.max(0, parent.height - footer.implicitHeight - Theme.pad)
            contentWidth: width
            contentHeight: form.implicitHeight + Theme.pad * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar {}
            Column {
                id: form
                y: Theme.pad
                width: Math.max(0, scroll.width - 18)
                spacing: Theme.pad
                Repeater {
                    model: [
                        {section: "appearance", key: "baseRadius", heading: "Appearance", label: "Shell radius", min: 4, max: 24},
                        {section: "roundedScreen", key: "radius", heading: "Rounded Screen", label: "Corner radius", min: 0, max: 24},
                        {section: "roundedScreen", key: "borderThickness", heading: "", label: "Border thickness", min: 0, max: 6}
                    ]
                    delegate: Column {
                        required property var modelData
                        width: form.width
                        spacing: Theme.pad
                        Text {
                            visible: modelData.heading !== ""
                            text: modelData.heading
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 3
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: modelData.label
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Row {
                            width: parent.width
                            spacing: Theme.pad
                            SettingsSlider {
                                width: Math.max(0, Math.min(360, parent.width - 80 - Theme.pad))
                                from: modelData.min
                                to: modelData.max
                                stepSize: 1
                                Accessible.name: modelData.section === "roundedScreen" ? "Rounded Screen " + modelData.label : modelData.label
                                value: ShellSettingsStore.values[modelData.section][modelData.key]
                                enabled: root.editable
                                onMoved: ShellSettingsStore.setValue(modelData.section, modelData.key, Math.round(value))
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ShellSettingsStore.values[modelData.section][modelData.key] + " px"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: "Border applies to left, right and bottom edges. The top edge is owned by TopBar."
                    wrapMode: Text.Wrap
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                }
                Text {
                    text: "Surface"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.weight: Font.DemiBold
                }
                Item {
                    id: presets
                    width: Math.min(420, parent.width)
                    height: 38
                    readonly property real slotWidth: (width - 8) / 3
                    Motion.SelectionPill {
                        shown: true
                        targetIndex: ["ink", "dark", "soft"].indexOf(ShellSettingsStore.surfaceTone)
                        slotCount: 3
                        slotSpacing: 4
                    }
                    Repeater {
                        model: [{key: "ink", label: "Ink", color: "#000000"},
                            {key: "dark", label: "Dark", color: "#0b0b0b"},
                            {key: "soft", label: "Soft", color: "#171717"}]
                        delegate: SettingsActionButton {
                            required property var modelData
                            required property int index
                            x: index * (presets.slotWidth + 4)
                            width: presets.slotWidth
                            height: presets.height
                            radius: Theme.radius
                            text: modelData.label
                            selected: ShellSettingsStore.surfaceTone === modelData.key
                            selectedOverridesHover: true
                            idleColor: "transparent"
                            hoverColor: Theme.hoverMuted
                            selectedColor: "transparent"
                            foregroundColor: Theme.fgDim
                            hoverForegroundColor: Theme.fg
                            selectedForegroundColor: Theme.onAccentColor
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
                            Rectangle {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12
                                radius: 3
                                color: modelData.color
                                border.width: 1
                                border.color: Theme.fgDim
                            }
                        }
                    }
                }
                // Dock controls share the existing draft, Apply and Discard lifecycle.
                Text {
                    text: "Dock"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: [{key: "style", label: "Style", labels: ["Dock", "Full bar"], hint: "Use a compact Dock or a full-width gradient taskbar."},
                        {key: "visibilityMode", label: "Visibility", labels: ["Auto Hide", "Always"], hint: "Reveal at the bottom center or keep the Dock visible."},
                        {key: "exclusiveSpace", label: "Reserve space", labels: ["Off", "On"], hint: "Reserve space while shown; release it when hidden."},
                        {key: "showTrash", label: "Trash", labels: ["Hide", "Show"], hint: "Show the Trash shortcut."},
                        {key: "showDevices", label: "Mounted devices", labels: ["Hide", "Show"], hint: "Show mounted storage shortcuts."}]
                    delegate: Row {
                        required property var modelData
                        width: form.width
                        spacing: Theme.pad
                        Text {
                            width: Math.max(0, parent.width - 186 - Theme.pad)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        SettingsSegmentedToggle {
                            width: 186
                            labels: modelData.labels
                            available: root.editable
                            checked: modelData.key === "style" ? ShellSettingsStore.dockStyle === "bar"
                                : modelData.key === "visibilityMode" ? ShellSettingsStore.dockVisibilityMode === "always"
                                : ShellSettingsStore.values.dock[modelData.key]
                            hint: modelData.hint
                            onToggled: value => ShellSettingsStore.setValue("dock", modelData.key,
                                modelData.key === "style" ? (value ? "bar" : "dock")
                                    : modelData.key === "visibilityMode" ? (value ? "always" : "autohide") : value)
                        }
                    }
                }
                Text {
                    text: "Icon size · " + ShellSettingsStore.dockIconSize + " px"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                SettingsSlider {
                    width: Math.min(360, parent.width)
                    from: 32
                    to: 72
                    stepSize: 4
                    value: ShellSettingsStore.dockIconSize
                    enabled: root.editable
                    Accessible.name: "Dock icon size"
                    onMoved: ShellSettingsStore.setValue("dock", "iconSize", Math.round(value / 4) * 4)
                }
                Text {
                    text: "Hover lift · " + ShellSettingsStore.dockHoverLift + " px"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                SettingsSlider {
                    width: Math.min(360, parent.width)
                    from: 0
                    to: 48
                    value: ShellSettingsStore.dockHoverLift
                    enabled: root.editable
                    Accessible.name: "Dock hover lift"
                    onMoved: ShellSettingsStore.setValue("dock", "hoverLift", Math.round(value))
                }
                Text {
                    text: "Hover enlargement · " + ShellSettingsStore.dockHoverScale + "%"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                SettingsSlider {
                    width: Math.min(360, parent.width)
                    from: 0
                    to: 100
                    value: ShellSettingsStore.dockHoverScale
                    enabled: root.editable
                    Accessible.name: "Dock hover enlargement"
                    onMoved: ShellSettingsStore.setValue("dock", "hoverScale", Math.round(value))
                }
                Text {
                    text: "Top Bar"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: "Applies to every monitor. Logo / Navigation stays enabled."
                    wrapMode: Text.Wrap
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Repeater {
                    model: root.modules
                    delegate: Row {
                        required property var modelData
                        width: form.width
                        spacing: Theme.pad
                        Text {
                            width: Math.max(0, parent.width - 126 - Theme.pad)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            wrapMode: Text.Wrap
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        SettingsSegmentedToggle {
                            enabled: root.editable
                            Accessible.role: Accessible.CheckBox
                            Accessible.name: modelData.label
                            Accessible.checked: checked
                            Accessible.onToggleAction: toggled(!checked)
                            checked: ShellSettingsStore.values.topbar[modelData.key]
                            available: root.editable
                            hint: modelData.hint
                            onToggled: value => ShellSettingsStore.setValue("topbar", modelData.key, value)
                        }
                    }
                }
            }
        }
        Column {
            id: footer
            width: parent.width
            spacing: 5
            Text {
                width: parent.width
                text: ShellSettingsStore.error || ShellSettingsStore.statusMessage
                      || (ShellSettingsStore.migrationPending ? "Legacy settings loaded · Apply to upgrade" : ShellSettingsStore.loading ? "Loading…" : ShellSettingsStore.dirty ? "Unsaved changes · Live preview" : "Live preview · Apply to save")
                color: ShellSettingsStore.error ? Theme.accent : Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                wrapMode: Text.Wrap
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: ["Reload", "Reset", "Discard", "Apply"]
                    delegate: SettingsActionButton {
                        required property string modelData
                        width: 82
                        height: 32
                        radius: Theme.radius
                        text: modelData === "Apply" && ShellSettingsStore.saving ? "Saving…" : modelData
                        idleColor: modelData === "Apply" ? Theme.accent : Theme.hoverMuted
                        hoverColor: idleColor
                        foregroundColor: modelData === "Apply" ? Theme.onAccentColor : Theme.fg
                        hoverForegroundColor: foregroundColor
                        enabled: modelData === "Reload" ? !ShellSettingsStore.loading && !ShellSettingsStore.saving
                                 : root.editable && (modelData === "Reset" || ShellSettingsStore.dirty || (modelData === "Apply" && ShellSettingsStore.migrationPending))
                                   && (modelData !== "Apply" || ShellSettingsStore.valid)
                        activeFocusOnTab: enabled
                        focused: activeFocus
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData
                        Accessible.onPressAction: clicked()
                        onClicked: {
                            if (modelData === "Reload") root.reloadRequested()
                            else if (modelData === "Reset") ShellSettingsStore.reset()
                            else if (modelData === "Discard") ShellSettingsStore.discard()
                            else ShellSettingsStore.apply()
                        }
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                    }
                }
            }
        }
    }
}
