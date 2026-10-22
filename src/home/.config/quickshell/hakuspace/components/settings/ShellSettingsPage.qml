import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
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
    readonly property var sectionCards: [layout, appearance, rounded, surface, cavaUnderbar, appbar, dockbar, topbar]
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

    Process {
        id: layoutProc
    }

    Process {
        id: cavaProc
    }

    Timer {
        id: cavaHeightDebounceTimer
        interval: 200
        repeat: false
        onTriggered: root.setCavaHeight(AppState.cavaHeight)
    }

    function setCavaHeight(val) {
        if (!cavaProc.running) {
            cavaProc.command = ["sh", "-c",
                'if [ -x "$1" ]; then exec "$1" --height "$4"; elif [ -x "$2" ]; then exec "$2" --height "$4"; else exec "$3" --height "$4"; fi',
                "--", (Quickshell.env("HOME") || "") + "/.local/bin/cava_manager.sh",
                Env.binDir + "/cava_manager.sh",
                Quickshell.shellPath("../../../../core/app/cava-layer/cava_manager.sh"), val]
            cavaProc.running = true
        }
    }

    function setCavaColorMode(mode) {
        if (AppState.cavaColorMode !== mode && !cavaProc.running) {
            cavaProc.command = ["sh", "-c",
                'if [ -x "$1" ]; then exec "$1" --color-mode "$4"; elif [ -x "$2" ]; then exec "$2" --color-mode "$4"; else exec "$3" --color-mode "$4"; fi',
                "--", (Quickshell.env("HOME") || "") + "/.local/bin/cava_manager.sh",
                Env.binDir + "/cava_manager.sh",
                Quickshell.shellPath("../../../../core/app/cava-layer/cava_manager.sh"), mode]
            cavaProc.running = true
        }
    }

    function setCavaPosition(pos) {
        var wantTop = (pos === "top")
        if (AppState.cavaTopState !== wantTop && !cavaProc.running) {
            cavaProc.command = ["sh", "-c",
                'if [ -x "$1" ]; then exec "$1" --position "$4"; elif [ -x "$2" ]; then exec "$2" --position "$4"; else exec "$3" --position "$4"; fi',
                "--", (Quickshell.env("HOME") || "") + "/.local/bin/cava_manager.sh",
                Env.binDir + "/cava_manager.sh",
                Quickshell.shellPath("../../../../core/app/cava-layer/cava_manager.sh"), pos]
            cavaProc.running = true
        }
    }

    function toggleCavaUnderbar() {
        if (!cavaProc.running) {
            cavaProc.command = ["sh", "-c",
                'if [ -x "$1" ]; then exec "$1" toggle; elif [ -x "$2" ]; then exec "$2" toggle; else exec "$3" toggle; fi',
                "--", (Quickshell.env("HOME") || "") + "/.local/bin/cava_manager.sh",
                Env.binDir + "/cava_manager.sh",
                Quickshell.shellPath("../../../../core/app/cava-layer/cava_manager.sh")]
            cavaProc.running = true
        }
    }

    function setShellLayout(target) {
        var wantTaskbar = (target === "taskbar")
        if (AppState.taskbarManualState !== wantTaskbar && !layoutProc.running) {
            layoutProc.command = ["sh", "-c",
                'if [ -x "$1" ]; then exec "$1" "$4"; elif [ -x "$2" ]; then exec "$2" "$4"; else exec "$3" "$4"; fi',
                "--", (Quickshell.env("HOME") || "") + "/.local/bin/taskbar_manager.sh",
                Env.binDir + "/taskbar_manager.sh",
                Quickshell.shellPath("../../../../core/facade/taskbar_manager.sh"), "--toggle"]
            layoutProc.running = true
        }
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
                    id: layout
                    width: parent.width
                    title: "Layout"
                    Row {
                        id: layoutChoices
                        width: parent.width
                        spacing: 12
                        Repeater {
                            model: [
                                { key: "topbar", label: "Topbar", desc: "Top Bar with Dock" },
                                { key: "taskbar", label: "Taskbar", desc: "Bottom Taskbar" }
                            ]
                            delegate: SettingsActionButton {
                                id: delegateButton
                                settingsNavGroup: layoutChoices
                                required property var modelData
                                width: Math.floor((parent.width - 12) / 2)
                                height: 74
                                selected: modelData.key === "taskbar" ? AppState.taskbarManualState : !AppState.taskbarManualState
                                selectedOverridesHover: true
                                idleColor: Theme.surface
                                hoverColor: Theme.hoverMuted
                                selectedColor: Theme.hoverMuted
                                foregroundColor: Theme.fgDim
                                hoverForegroundColor: Theme.fg
                                selectedForegroundColor: Theme.accent
                                border.color: selected || activeFocus ? Theme.accent : Theme.hoverMuted
                                border.width: selected ? 2 : 1
                                enabled: root.editable && !layoutProc.running
                                activeFocusOnTab: enabled
                                focused: activeFocus
                                Accessible.name: modelData.label + " shell layout"
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: selected
                                Accessible.onPressAction: clicked()
                                onClicked: root.setShellLayout(modelData.key)
                                Keys.onReturnPressed: clicked()
                                Keys.onSpacePressed: clicked()

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 14

                                    Rectangle {
                                        id: wireframe
                                        width: 48
                                        height: 36
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: 4
                                        color: delegateButton.selected ? Qt.alpha(Theme.accent, 0.12) : Theme.hoverMuted
                                        border.width: 1
                                        border.color: delegateButton.selected ? Theme.accent : Theme.hoverMuted

                                        // Topbar indicator
                                        Rectangle {
                                            visible: modelData.key === "topbar"
                                            width: parent.width - 6
                                            height: 4
                                            radius: 2
                                            anchors.top: parent.top
                                            anchors.topMargin: 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: delegateButton.selected ? Theme.accent : (delegateButton.hovered ? Theme.fg : Theme.fgDim)
                                        }
                                        Rectangle {
                                            visible: modelData.key === "topbar"
                                            width: 18
                                            height: 3
                                            radius: 1.5
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: delegateButton.selected ? Theme.accent : (delegateButton.hovered ? Theme.fg : Theme.fgDim)
                                        }

                                        // Taskbar indicator
                                        Rectangle {
                                            visible: modelData.key === "taskbar"
                                            width: parent.width - 6
                                            height: 6
                                            radius: 2
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: delegateButton.selected ? Theme.accent : (delegateButton.hovered ? Theme.fg : Theme.fgDim)
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3
                                        Text {
                                            text: modelData.label
                                            color: delegateButton.selected ? Theme.accent : (delegateButton.hovered ? Theme.fg : Theme.fgDim)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize + 1
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            text: modelData.desc
                                            color: Theme.fgDescription
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
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
                    id: cavaUnderbar
                    width: parent.width
                    title: "Cava Underbar"
                    Row {
                        width: parent.width
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Enable Underbar"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.Medium
                        }
                        Item {
                            width: Math.max(12, parent.width - 240)
                            height: 1
                        }
                        SettingsSegmentedToggle {
                            checked: AppState.cavaLayerState
                            labels: ["Off", "On"]
                            hint: "Toggle Cava Underbar audio visualizer"
                            onToggled: root.toggleCavaUnderbar()
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
                    Text {
                        width: parent.width
                        text: "Color Mode"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                    }
                    Row {
                        id: cavaColorChoices
                        width: parent.width
                        spacing: 12
                        Repeater {
                            model: [
                                { key: "surface", label: "Surface", desc: "Match rounded screen frame" },
                                { key: "accent", label: "Accent", desc: "Use theme accent color" }
                            ]
                            delegate: SettingsActionButton {
                                settingsNavGroup: cavaColorChoices
                                required property var modelData
                                width: Math.floor((parent.width - 12) / 2)
                                height: 56
                                selected: AppState.cavaColorMode === modelData.key
                                selectedOverridesHover: true
                                idleColor: Theme.surface
                                hoverColor: Theme.hoverMuted
                                selectedColor: Theme.hoverMuted
                                foregroundColor: Theme.fgDim
                                hoverForegroundColor: Theme.fg
                                selectedForegroundColor: Theme.accent
                                border.color: selected || activeFocus ? Theme.accent : Theme.hoverMuted
                                border.width: selected ? 2 : 1
                                enabled: root.editable && !cavaProc.running
                                activeFocusOnTab: enabled
                                focused: activeFocus
                                Accessible.name: modelData.label + " cava color mode"
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: selected
                                Accessible.onPressAction: clicked()
                                onClicked: root.setCavaColorMode(modelData.key)
                                Keys.onReturnPressed: clicked()
                                Keys.onSpacePressed: clicked()

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: parent.parent.selected ? Theme.accent : (parent.parent.hovered ? Theme.fg : Theme.fgDim)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize + 1
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.desc
                                        color: Theme.fgDescription
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                    }
                                }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
                    Text {
                        width: parent.width
                        text: "Position"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                    }
                    Row {
                        id: cavaPositionChoices
                        width: parent.width
                        spacing: 12
                        Repeater {
                            model: [
                                { key: "top", label: "Top", desc: "Anchored to screen top edge" },
                                { key: "bottom", label: "Bottom", desc: "Anchored to screen bottom edge" }
                            ]
                            delegate: SettingsActionButton {
                                settingsNavGroup: cavaPositionChoices
                                required property var modelData
                                width: Math.floor((parent.width - 12) / 2)
                                height: 56
                                selected: (modelData.key === "top") ? AppState.cavaTopState : !AppState.cavaTopState
                                selectedOverridesHover: true
                                idleColor: Theme.surface
                                hoverColor: Theme.hoverMuted
                                selectedColor: Theme.hoverMuted
                                foregroundColor: Theme.fgDim
                                hoverForegroundColor: Theme.fg
                                selectedForegroundColor: Theme.accent
                                border.color: selected || activeFocus ? Theme.accent : Theme.hoverMuted
                                border.width: selected ? 2 : 1
                                enabled: root.editable && !cavaProc.running
                                activeFocusOnTab: enabled
                                focused: activeFocus
                                Accessible.name: modelData.label + " cava position"
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: selected
                                Accessible.onPressAction: clicked()
                                onClicked: root.setCavaPosition(modelData.key)
                                Keys.onReturnPressed: clicked()
                                Keys.onSpacePressed: clicked()

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: parent.parent.selected ? Theme.accent : (parent.parent.hovered ? Theme.fg : Theme.fgDim)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize + 1
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.desc
                                        color: Theme.fgDescription
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                    }
                                }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
                    Grid {
                        id: cavaHeightRow
                        width: parent.width
                        columns: width < 540 ? 1 : 2
                        columnSpacing: 16
                        rowSpacing: 10
                        Column {
                            width: cavaHeightRow.columns === 1 ? cavaHeightRow.width : Math.round(cavaHeightRow.width * 0.42)
                            spacing: 3
                            Text {
                                width: parent.width
                                text: "Layer height"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.Medium
                                wrapMode: Text.Wrap
                            }
                            Text {
                                width: parent.width
                                text: "Physical height of the audio underbar"
                                color: Theme.fgDescription
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                wrapMode: Text.Wrap
                            }
                        }
                        Row {
                            width: cavaHeightRow.columns === 1 ? cavaHeightRow.width : cavaHeightRow.width - Math.round(cavaHeightRow.width * 0.42) - 16
                            spacing: 8
                            SettingsSlider {
                                shortcutTarget: root.shortcutTarget
                                width: Math.max(0, parent.width - cavaHeightBadge.width - 8)
                                from: 36
                                to: 160
                                stepSize: 4
                                value: AppState.cavaHeight
                                enabled: root.editable && !cavaProc.running
                                Accessible.name: "Cava underbar layer height"
                                onMoved: {
                                    var nextVal = Math.round(value / stepSize) * stepSize
                                    AppState.cavaHeight = nextVal
                                    cavaHeightDebounceTimer.restart()
                                }
                            }
                            Rectangle {
                                id: cavaHeightBadge
                                width: 64; height: 34
                                radius: Theme.radius
                                color: Theme.surface
                                border.width: 1; border.color: Theme.hoverMuted
                                Text {
                                    anchors.centerIn: parent
                                    text: AppState.cavaHeight + " px"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(10, Theme.fontSize - 1)
                                }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        text: "Surface mode seamlessly melts the underbar waves into the Rounded Screen border. Accent mode highlights audio peaks in your active theme color."
                        wrapMode: Text.Wrap
                        color: Theme.fgDescription
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
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
