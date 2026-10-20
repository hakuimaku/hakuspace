import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare
import "motion" as Motion
import "settings" as SettingsPages

PanelWindow {
    id: root
    required property var modelData
    property string selectedGroup: "General"
    property string confirmation: ""
    readonly property var settingsTabs: ["General", "Shell", "Config", "Info"]
    readonly property bool panelOpen: UiState.activePanel === "settings"
                                      && UiState.settingsScreenName === modelData.name
    // Preferred widths keep 32 px of space on each side when the screen is smaller.
    readonly property real normalPreferredWidth: 1150 * 0.90
    readonly property real normalWidth: Math.min(normalPreferredWidth, Math.max(0, modelData.width - 64))
    readonly property real configWidth: Math.min(normalPreferredWidth * 1.10, Math.max(0, modelData.width - 64))
    readonly property real infoWidth: Math.min(normalPreferredWidth * 0.95, Math.max(0, modelData.width - 64))
    readonly property real targetBodyWidth: selectedGroup === "Config" ? configWidth
                                             : selectedGroup === "Info" ? infoWidth : normalWidth
    readonly property real targetBodyHeight: Math.min(690, Math.max(0, modelData.height - 64))
    readonly property real circleSize: Math.min(96, normalWidth, targetBodyHeight)
    property real slideProgress: 0
    property real expandProgress: 0
    property real closeProgress: 0
    readonly property bool phaseOrderValid: expandProgress <= 0.001 || slideProgress >= 0.999
    onPhaseOrderValidChanged: console.assert(phaseOrderValid, "Settings must reach center before expanding")

    SequentialAnimation {
        id: openAnimation
        ParallelAnimation {
            NumberAnimation {
                id: slideIn
                target: root; property: "slideProgress"; to: 1
                easing.type: Easing.BezierSpline
                easing.bezierCurve: HAnimation.dashboardOpenCurve
            }
            NumberAnimation {
                id: recoverClose
                target: root; property: "closeProgress"; to: 0
            }
        }
        NumberAnimation {
            id: expandIn
            target: root; property: "expandProgress"; to: 1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.32, 0.05, 0.55, 1.18, 1, 1]
        }
    }
    NumberAnimation {
        id: closeAnimation
        target: root; property: "closeProgress"; to: 1
        duration: 480
        easing.type: Easing.OutCubic
        onFinished: {
            root.expandProgress = 0
            root.slideProgress = 0
            root.closeProgress = 0
        }
    }

    function requestClose() {
        if (ShellSettingsStore.saving || ShellSettingsStore.loading) return
        if (SettingsStore.dirty || ShellSettingsStore.dirty || ConfigEditorStore.dirty) confirmation = "close"
        else UiState.closeSettings()
    }
    function requestReload() {
        if (selectedGroup === "Shell") {
            if (ShellSettingsStore.dirty) confirmation = "reload-shell"
            else ShellSettingsStore.reload()
            return
        }
        if (SettingsStore.dirty) confirmation = "reload"
        else SettingsStore.reload()
    }
    // Reload replaces its own domain; closing restores every editable draft.
    function confirmDiscard() {
        var action = confirmation
        confirmation = ""
        if (action === "reload-shell") ShellSettingsStore.reload()
        else if (action === "reload") SettingsStore.reload()
        else {
            SettingsStore.discard()
            ShellSettingsStore.discard()
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
    visible: panelOpen || slideProgress > 0.001 || expandProgress > 0.001
    mask: Region {
        width: root.visible ? root.modelData.width : 0
        height: root.visible ? root.modelData.height : 0
    }
    Component.onDestruction: UiState.closeSettingsIfScreen(modelData.name)
    onPanelOpenChanged: {
        openAnimation.stop()
        closeAnimation.stop()
        if (panelOpen) {
            slideIn.duration = Math.round(280 * Math.max(0, 1 - slideProgress))
            recoverClose.duration = Math.round(220 * closeProgress)
            expandIn.duration = Math.round(350 * Math.max(0, 1 - expandProgress))
            openAnimation.start()
        } else {
            closeAnimation.duration = Math.round(480 * Math.max(0, 1 - closeProgress))
            closeAnimation.start()
        }
        if (panelOpen) {
            confirmation = ""
            if (!SettingsStore.ready) SettingsStore.load()
            else if (!SettingsStore.dirty) SettingsStore.reload()
            if (!ShellSettingsStore.dirty) ShellSettingsStore.reload()
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
    Rectangle { anchors.fill: parent; color: Theme.surface; opacity: 0.22 * Math.min(1, root.expandProgress) * (1 - root.closeProgress) }
    MouseArea { anchors.fill: parent; enabled: root.panelOpen; onClicked: root.requestClose() }

    Shape {
        id: dropTail
        readonly property real diameter: root.circleSize
        readonly property real tail: Math.min(60, diameter * 0.65)
                                     * Math.pow(Math.sin(Math.PI * Math.max(0, Math.min(1, root.slideProgress))), 2)
        x: settingsBody.x - tail
        y: settingsBody.y
        width: tail + diameter
        height: diameter
        visible: root.panelOpen && tail > 0.01 && root.expandProgress <= 0.001
        preferredRendererType: Shape.CurveRenderer
        transform: Rotation {
            origin.x: dropTail.tail + dropTail.diameter / 2
            origin.y: dropTail.diameter / 2
            angle: Math.atan2(root.height / 2 - ScreenGeometry.attachedBodyY(root.height, root.circleSize) - root.circleSize / 2,
                              root.width / 2 - ScreenGeometry.leftInset - root.circleSize / 2) * 180 / Math.PI
        }
        ShapePath {
            fillColor: Theme.surface
            strokeColor: "transparent"
            startX: 0
            startY: dropTail.diameter / 2
            PathCubic {
                control1X: dropTail.tail * 0.3; control1Y: dropTail.diameter * 0.43
                control2X: dropTail.tail * 0.68; control2Y: dropTail.diameter * 0.08
                x: dropTail.tail + dropTail.diameter * 0.42; y: dropTail.diameter * 0.08
            }
            PathCubic {
                control1X: dropTail.tail + dropTail.diameter * 0.78; control1Y: dropTail.diameter * 0.22
                control2X: dropTail.tail + dropTail.diameter * 0.78; control2Y: dropTail.diameter * 0.78
                x: dropTail.tail + dropTail.diameter * 0.42; y: dropTail.diameter * 0.92
            }
            PathCubic {
                control1X: dropTail.tail * 0.68; control1Y: dropTail.diameter * 0.92
                control2X: dropTail.tail * 0.3; control2Y: dropTail.diameter * 0.57
                x: 0; y: dropTail.diameter / 2
            }
        }
    }

    Flare.FlareSurface {
        x: settingsBody.x
        y: settingsBody.y
        width: settingsBody.width
        height: settingsBody.height
        start: 0
        end: width
        currentHeight: height
        bounds: ({start: 0, end: root.modelData.width})
        r: Theme.giantRadius * Math.max(0, 1 - root.expandProgress)
        rf: Theme.hugRadius * Math.max(0, 1 - root.expandProgress)
        opacity: Math.min(1, root.expandProgress * 4) * Math.max(0, 1 - root.expandProgress) * (1 - root.closeProgress)
    }

    Rectangle {
        id: settingsBody
        x: ScreenGeometry.leftInset + (root.width / 2 - width / 2 - ScreenGeometry.leftInset) * root.slideProgress
        y: ScreenGeometry.attachedBodyY(root.height, root.circleSize)
           + (root.height / 2 - height / 2 - ScreenGeometry.attachedBodyY(root.height, root.circleSize)) * root.slideProgress
        width: root.circleSize + (root.targetBodyWidth - root.circleSize) * root.expandProgress
        height: root.circleSize + (root.targetBodyHeight - root.circleSize) * root.expandProgress
        radius: root.circleSize / 2 + (Theme.largeRadius - root.circleSize / 2) * root.expandProgress
        color: Theme.surface
        opacity: 1 - root.closeProgress
        scale: 1 - 0.2 * root.closeProgress
        border.color: Theme.border
        border.width: Theme.borderWidth
        clip: root.expandProgress < 0.999
        Behavior on width {
            enabled: root.expandProgress >= 0.999 && !openAnimation.running && !closeAnimation.running
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
            anchors.rightMargin: 24
            spacing: Theme.pad
            opacity: Math.max(0, Math.min(1, (root.expandProgress - 0.55) / 0.4))
            enabled: root.panelOpen && root.expandProgress >= 0.95
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
                    text: root.selectedGroup === "Shell" ? "~/hakucfg/hikai/hikai-shell.json"
                          : root.selectedGroup === "Config" ? "~/hakucfg/wm · ~/hakucfg/config"
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
                                      : tabButton.modelData === "Shell" ? "Preview shell appearance and TopBar modules."
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
                SettingsPages.ShellSettingsPage {
                    anchors.fill: parent
                    visible: root.selectedGroup === "Shell"
                    onReloadRequested: root.requestReload()
                }
                SettingsPages.InfoPage {
                    anchors.fill: parent
                    visible: root.selectedGroup === "Info"
                }
            }
        }
        Rectangle {
            visible: root.selectedGroup !== "General" && root.confirmation !== ""
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
                    text: root.confirmation === "reload-shell" ? "Discard Shell changes and reload from disk?"
                          : "Discard unsaved Settings changes and close?"
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
