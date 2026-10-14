import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "motion" as Motion
import "settings" as SettingsPages

PanelWindow {
    id: root
    required property var modelData
    property string selectedGroup: "General"
    property string confirmation: ""
    readonly property var settingsTabs: ["General", "Config", "Info"]
    readonly property bool panelOpen: UiState.activePanel === "settings"
                                      && UiState.settingsScreenName === modelData.name
    // Preferred widths keep 32 px of space on each side when the screen is smaller.
    readonly property real normalPreferredWidth: 1150 * 0.90
    readonly property real normalWidth: Math.min(normalPreferredWidth, Math.max(0, modelData.width - 64))
    readonly property real configWidth: Math.min(normalPreferredWidth * 1.10, Math.max(0, modelData.width - 64))
    readonly property real infoWidth: Math.min(normalPreferredWidth * 0.95, Math.max(0, modelData.width - 64))

    function requestClose() {
        if (SettingsStore.dirty || ConfigEditorStore.dirty) confirmation = "close"
        else UiState.closeSettings()
    }
    function requestReload() {
        if (SettingsStore.dirty) confirmation = "reload"
        else SettingsStore.reload()
    }
    // Reload discards General only; closing discards both editable pages.
    function confirmDiscard() {
        var action = confirmation
        confirmation = ""
        if (action === "reload") SettingsStore.reload()
        else {
            SettingsStore.discard()
            ConfigEditorStore.discard()
            configPage.confirmation = ""
            UiState.closeSettings()
        }
    }
    onSelectedGroupChanged: {
        if (!panelOpen) return
        if (selectedGroup === "Config" && !ConfigEditorStore.ready) ConfigEditorStore.loadFiles()
        if (selectedGroup === "Info") InfoStore.load()
    }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-settings"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen
    mask: Region {
        width: root.panelOpen ? root.modelData.width : 0
        height: root.panelOpen ? root.modelData.height : 0
    }
    Component.onDestruction: UiState.closeSettingsIfScreen(modelData.name)
    onPanelOpenChanged: {
        if (panelOpen) {
            confirmation = ""
            if (!SettingsStore.ready) SettingsStore.load()
            else if (!SettingsStore.dirty) SettingsStore.reload()
            if (selectedGroup === "Config" && !ConfigEditorStore.ready) ConfigEditorStore.loadFiles()
            if (selectedGroup === "Info") InfoStore.load()
            Qt.callLater(function() { if (root.panelOpen) keyHandler.forceActiveFocus() })
        }
    }
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onEscapePressed: event => {
            if (root.confirmation) root.confirmation = ""
            else if (configPage.confirmation) configPage.cancelConfirmation()
            else root.requestClose()
            event.accepted = true
        }
    }
    Rectangle { anchors.fill: parent; color: Theme.surface; opacity: 0.22 }
    MouseArea { anchors.fill: parent; enabled: root.panelOpen; onClicked: root.requestClose() }

    Rectangle {
        id: settingsBody
        anchors.centerIn: parent
        width: root.selectedGroup === "Config" ? root.configWidth
             : root.selectedGroup === "Info" ? root.infoWidth : root.normalWidth
        height: Math.min(690, Math.max(0, root.modelData.height - 64))
        radius: Theme.largeRadius
        color: Theme.surface
        border.color: Theme.border
        border.width: Theme.borderWidth
        Behavior on width {
            NumberAnimation {
                duration: HAnimation.settingsResizeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.settingsResizeCurve
            }
        }
        MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.pad * 2
            spacing: Theme.pad
            Row {
                width: parent.width
                height: 48
                spacing: Theme.pad
                Text {
                    text: "Settings"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(Theme.fontSize * 1.4)
                    font.weight: Font.DemiBold
                    width: Math.max(120, parent.width * 0.35)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.selectedGroup === "Config" ? "~/hakucfg/wm · ~/hakucfg/config"
                          : root.selectedGroup === "Info" ? "HakuSpace · " + (InfoStore.loading ? "detecting…"
                              : InfoStore.repo.detected ? InfoStore.repo.version : "version unavailable")
                          : SettingsStore.settingVersion ? "setting.sh · " + SettingsStore.settingVersion : "~/hakucfg/setting.sh"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideLeft
                    width: Math.max(0, parent.width - Math.max(120, parent.width * 0.35) - Theme.pad)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Item {
                width: parent.width
                height: 38
                Item {
                    id: tabLane
                    // The strip stays compact while the selected page uses the full body width.
                    x: 24
                    width: Math.min(380, Math.max(0, parent.width - 24))
                    height: parent.height
                    readonly property real slotSpacing: 4
                    readonly property real slotWidth: Math.max(0, (width - slotSpacing * (root.settingsTabs.length - 1)) / root.settingsTabs.length)
                    Motion.SelectionPill {
                        z: 0
                        shown: true
                        targetIndex: root.settingsTabs.indexOf(root.selectedGroup)
                        slotCount: root.settingsTabs.length
                        slotSpacing: tabLane.slotSpacing
                    }
                    Repeater {
                        model: root.settingsTabs
                        delegate: Motion.MorphButton {
                            id: tabButton
                            required property string modelData
                            required property int index
                            x: index * (tabLane.slotWidth + tabLane.slotSpacing)
                            z: 1
                            width: tabLane.slotWidth
                            height: tabLane.height
                            radius: Theme.radius
                            text: modelData
                            hoverScaleDelta: 0.004
                            pressScaleDelta: 0.018
                            selected: root.selectedGroup === modelData
                            selectedOverridesHover: true
                            idleColor: "transparent"
                            hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                            pressedColor: Qt.lighter(Theme.hoverMuted, 1.18)
                            selectedColor: "transparent"
                            foregroundColor: Theme.fgDim
                            hoverForegroundColor: Theme.fg
                            pressedForegroundColor: Theme.fg
                            selectedForegroundColor: Theme.onAccentColor
                            activeFocusOnTab: true
                            focused: activeFocus
                            border.width: activeFocus ? 1 : 0
                            border.color: Theme.fg
                            onClicked: root.selectedGroup = modelData
                            Keys.onReturnPressed: root.selectedGroup = modelData
                            Keys.onSpacePressed: root.selectedGroup = modelData
                            SettingsPages.SettingsTooltip {
                                target: tabButton
                                active: tabButton.hovered || tabButton.activeFocus
                                text: tabButton.modelData === "General" ? "Edit options in setting.sh."
                                      : tabButton.modelData === "Config" ? "Browse and edit configuration files."
                                      : "View HakuSpace and system information."
                            }
                        }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Item {
                width: parent.width
                // Fill the space left by the header, tab strip, dividers, and Column gaps.
                height: Math.max(0, parent.height - 48 - 38 - 2 - Theme.pad * 4)
                SettingsPages.GeneralSettingsPage {
                    anchors.fill: parent
                    visible: root.selectedGroup === "General"
                    confirmation: root.confirmation
                    onReloadRequested: root.requestReload()
                    onCancelRequested: root.confirmation = ""
                    onDiscardRequested: root.confirmDiscard()
                }
                SettingsPages.ConfigEditorPage {
                    id: configPage
                    anchors.fill: parent
                    visible: root.selectedGroup === "Config"
                    onCloseRequested: root.requestClose()
                }
                SettingsPages.InfoPage {
                    anchors.fill: parent
                    visible: root.selectedGroup === "Info"
                }
            }
        }
        Rectangle {
            visible: root.selectedGroup !== "General" && root.confirmation === "close"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.pad * 2
            height: 52
            radius: Theme.radius
            color: Theme.surface
            border.color: Theme.accent
            Row {
                anchors.fill: parent
                anchors.margins: Theme.pad
                spacing: Theme.pad
                Text {
                    width: Math.max(80, parent.width - 180)
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsStore.dirty && ConfigEditorStore.dirty ? "Discard unsaved General and Config changes?"
                          : SettingsStore.dirty ? "Discard unsaved General changes and close?"
                          : "Discard changes to " + ConfigEditorStore.selectedFileId + " and close?"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }
                SettingsPages.SettingsActionButton {
                    id: keepButton
                    width: 72; height: 30; radius: Theme.radius
                    text: "Keep"
                    idleColor: Theme.hoverMuted
                    hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                    foregroundColor: Theme.fg
                    hoverForegroundColor: Theme.fg
                    activeFocusOnTab: true
                    focused: activeFocus
                    onClicked: root.confirmation = ""
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    SettingsPages.SettingsTooltip {
                        target: keepButton
                        active: keepButton.hovered || keepButton.activeFocus
                        text: "Keep unsaved edits and stay in Settings."
                    }
                }
                SettingsPages.SettingsActionButton {
                    id: discardButton
                    width: 82; height: 30; radius: Theme.radius
                    text: "Discard"
                    idleColor: Theme.accent
                    hoverColor: Theme.accent
                    foregroundColor: Theme.onAccentColor
                    hoverForegroundColor: Theme.onAccentColor
                    activeFocusOnTab: true
                    focused: activeFocus
                    onClicked: root.confirmDiscard()
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    SettingsPages.SettingsTooltip {
                        target: discardButton
                        active: discardButton.hovered || discardButton.activeFocus
                        text: "Discard unsaved edits and close Settings."
                    }
                }
            }
        }
    }
}
