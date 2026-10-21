import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services"
import "flare" as Flare
import "settings" as SettingsPages

PanelWindow {
    id: root
    required property var modelData
    property string selectedGroup: "General"
    property string confirmation: ""
    // Keep the close dialog open until every submitted draft finishes saving.
    property bool applyingClose: false
    property string confirmationError: ""
    readonly property bool settingsBusy: SettingsStore.loading || SettingsStore.saving
        || ShellSettingsStore.loading || ShellSettingsStore.saving || ConfigEditorStore.busy
    readonly property var dirtyDomains: [SettingsStore.dirty ? "General" : "",
        ShellSettingsStore.dirty ? "Shell" : "", ConfigEditorStore.dirty ? "Config" : ""].filter(Boolean)
    readonly property string closeSaveProblem: SettingsStore.dirty && (!SettingsStore.ready || !SettingsStore.valid)
        ? "General has invalid values. Keep editing to correct them."
        : ShellSettingsStore.dirty && (!ShellSettingsStore.ready || !ShellSettingsStore.valid)
        ? "Shell settings are not ready to apply. Keep editing to review them."
        : ConfigEditorStore.dirty && !ConfigEditorStore.canSave && !ConfigEditorStore.busy
        ? "Config cannot be saved. Keep editing to resolve the file conflict or invalid text." : ""
    readonly property bool canApplyAndClose: !settingsBusy && !applyingClose && !closeSaveProblem
    onSettingsBusyChanged: Qt.callLater(root.finishApplyAndClose)
    onConfirmationChanged: confirmationError = ""
    readonly property bool panelOpen: UiState.activePanel === "settings"
                                      && UiState.settingsScreenName === modelData.name
    // Preferred widths keep 32 px of space on each side when the screen is smaller.
    readonly property real normalPreferredWidth: 1180
    readonly property real normalWidth: Math.min(normalPreferredWidth, Math.max(0, modelData.width - 64))
    readonly property real targetBodyWidth: normalWidth
    readonly property real targetBodyHeight: Math.min(750, Math.max(0, modelData.height - 64))
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

    // Cancel the active confirmation before initiating the existing close flow.
    function handleEscape() {
        if (applyingClose) return
        if (confirmation) confirmation = ""
        else if (configPage.confirmation) configPage.cancelConfirmation()
        else requestClose()
    }
    function requestClose() {
        if (settingsBusy) return
        if (dirtyDomains.length) confirmation = "close"
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
        if (settingsBusy || applyingClose) return
        var action = confirmation
        confirmation = ""
        if (action === "reset-shell") ShellSettingsStore.reset()
        else if (action === "discard-shell") ShellSettingsStore.discard()
        else if (action === "reload-shell") ShellSettingsStore.reload()
        else if (action === "reload") SettingsStore.reload()
        else if (action === "close") {
            SettingsStore.discard()
            ShellSettingsStore.discard()
            ConfigEditorStore.discard()
            configPage.confirmation = ""
            UiState.closeSettings()
        }
    }
    // Submit all modified pages together and retain failed drafts for review.
    function applyAndClose() {
        if (confirmation !== "close" || !canApplyAndClose) return
        confirmationError = ""
        applyingClose = true
        if (SettingsStore.dirty) SettingsStore.apply()
        if (ShellSettingsStore.dirty) ShellSettingsStore.apply()
        if (ConfigEditorStore.dirty) ConfigEditorStore.save()
        Qt.callLater(root.finishApplyAndClose)
    }
    // Store exit handlers finish updating errors and snapshots before this runs.
    function finishApplyAndClose() {
        if (!applyingClose || settingsBusy) return
        applyingClose = false
        if (dirtyDomains.length) {
            confirmationError = (SettingsStore.dirty ? SettingsStore.error : "")
                || (ShellSettingsStore.dirty ? ShellSettingsStore.error : "")
                || (ConfigEditorStore.dirty ? ConfigEditorStore.error : "")
                || "Some changes are still unsaved. Keep editing to review them."
            return
        }
        confirmation = ""
        configPage.cancelConfirmation()
        UiState.closeSettings()
    }
    onSelectedGroupChanged: {
        if (!panelOpen) return
        if (selectedGroup === "Config" && !ConfigEditorStore.ready) ConfigEditorStore.loadFiles()
        if (selectedGroup === "Info") InfoStore.load()
    }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: ShellTransitionState.chromeOverlayLayer
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
        Keys.onEscapePressed: event => { root.handleEscape(); event.accepted = true }
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
        border.width: 0
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

        Dialog {
            id: confirmationDialog
            parent: root.contentItem
            anchors.centerIn: parent
            width: Math.max(0, Math.min(560, root.normalWidth - 24))
            padding: 24
            spacing: 20
            modal: true
            dim: true
            focus: true
            visible: root.panelOpen && root.confirmation.length > 0
            closePolicy: root.applyingClose ? Popup.NoAutoClose : Popup.CloseOnEscape
            property Item previousFocus: null
            readonly property var labels: root.confirmation === "close"
                ? ["Keep Editing", "Discard & Close", "Apply & Close"]
                : ["Keep Editing", root.confirmation === "reset-shell" ? "Reset to Defaults"
                    : root.confirmation === "discard-shell" ? "Discard Changes" : "Discard & Reload"]
            onAboutToShow: previousFocus = root.contentItem.Window.window.activeFocusItem
            onOpened: confirmationActions.itemAt(0).forceActiveFocus()
            onClosed: {
                if (!root.applyingClose) root.confirmation = ""
                if (root.panelOpen && previousFocus) previousFocus.forceActiveFocus()
            }
            Overlay.modal: Rectangle { color: Qt.alpha(Theme.surface, 0.72) }
            background: Rectangle {
                radius: Theme.largeRadius
                color: Theme.surface
                border.width: 1
                border.color: Theme.hoverMuted
            }
            contentItem: Column {
                spacing: 12
                Text {
                    width: parent.width
                    text: root.confirmation === "close" ? "Unsaved changes"
                        : root.confirmation === "reset-shell" ? "Reset Shell settings?"
                        : root.confirmation === "discard-shell" ? "Discard Shell changes?" : "Reload saved settings?"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    text: root.applyingClose ? "Applying changes… Please wait."
                        : root.confirmation === "close" ? "Unsaved changes in " + root.dirtyDomains.join(", ")
                            + ". Apply saves all modified pages. Discard restores their saved values before closing."
                        : root.confirmation === "reset-shell" ? "Preview default Shell settings. Your current draft will be replaced. Nothing is saved until you choose Apply."
                        : root.confirmation === "discard-shell" ? "Undo unsaved Shell edits and restore the saved settings, including live previews."
                        : "Discard unsaved " + (root.confirmation === "reload-shell" ? "Shell" : "General") + " edits and reload the saved settings from disk."
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.confirmationError || (root.confirmation === "close" ? root.closeSaveProblem : "")
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }
            }
            footer: Item {
                width: confirmationDialog.width
                implicitHeight: dialogButtons.height + 24
                Flow {
                    id: dialogButtons
                    x: 24
                    width: Math.max(0, parent.width - 48)
                    height: childrenRect.height
                    spacing: 8
                    Repeater {
                        id: confirmationActions
                        model: confirmationDialog.labels
                        delegate: SettingsPages.SettingsActionButton {
                            id: dialogAction
                            required property string modelData
                            readonly property bool primary: modelData === "Apply & Close"
                            TextMetrics { id: dialogMetrics; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 1); text: dialogAction.modelData }
                            width: Math.min(dialogButtons.width, Math.max(100, dialogMetrics.width + 28))
                            height: 40
                            text: modelData
                            fontSize: Math.max(10, Theme.fontSize - 1)
                            idleColor: primary ? Theme.accent : Theme.hoverMuted
                            hoverColor: primary ? Theme.accent : Qt.lighter(Theme.hoverMuted, 1.18)
                            foregroundColor: primary ? Theme.onAccentColor : Theme.fg
                            hoverForegroundColor: foregroundColor
                            disabledColor: Theme.hoverMuted
                            disabledForegroundColor: Theme.fgMuted
                            enabled: !root.applyingClose && (primary ? root.canApplyAndClose : !root.settingsBusy)
                            activeFocusOnTab: enabled
                            focused: activeFocus
                            onClicked: {
                                if (!enabled) return
                                if (modelData === "Keep Editing") root.confirmation = ""
                                else if (primary) root.applyAndClose()
                                else root.confirmDiscard()
                            }
                            Keys.onReturnPressed: clicked()
                            Keys.onSpacePressed: clicked()
                        }
                    }
                }
            }
        }
        Item {
            id: interior
            anchors.fill: parent
            anchors.margins: parent.width < 760 || parent.height < 560 ? 12 : 24
            clip: true
            // Keep page objects alive so navigation never resets a draft or confirmation.
            readonly property var currentPage: root.selectedGroup === "General" ? generalPage
                : root.selectedGroup === "Shell" ? shellPage : root.selectedGroup === "Config" ? configPage : infoPage
            readonly property bool compact: width < 760
            opacity: Math.max(0, Math.min(1, (root.expandProgress - 0.55) / 0.4))
            enabled: root.panelOpen && root.expandProgress >= 0.95
            Keys.onEscapePressed: event => { root.handleEscape(); event.accepted = true }

            // A static, faint grid adds texture without input handlers or animation.
            Item {
                anchors.fill: parent
                visible: width >= 760 && height >= 450
                opacity: 0.025
                Repeater {
                    model: Math.floor(interior.height / 28)
                    Rectangle { required property int index; y: (index + 1) * 28; width: interior.width; height: 1; color: Theme.fg }
                }
                Repeater {
                    model: Math.floor(interior.width / 28)
                    Rectangle { required property int index; x: (index + 1) * 28; width: 1; height: interior.height; color: Theme.fg }
                }
            }
            SettingsPages.SettingsTopBar {
                id: topbar
                width: parent.width
                height: implicitHeight
                selected: root.selectedGroup
                source: root.selectedGroup === "Shell" ? "~/hakucfg/hikai/hikai-shell.json"
                    : root.selectedGroup === "Config" ? "~/hakucfg/wm · ~/hakucfg/config"
                    : root.selectedGroup === "Info" ? "HakuSpace · " + (InfoStore.loading ? "detecting…"
                        : InfoStore.repo.detected ? InfoStore.repo.version : "version unavailable")
                    : SettingsStore.settingVersion ? "setting.sh · " + SettingsStore.settingVersion : "~/hakucfg/setting.sh"
                onSelectedRequested: domain => root.selectedGroup = domain
            }
            SettingsPages.SettingsSidebar {
                id: sidebar
                y: topbar.height
                width: interior.compact ? parent.width : parent.width >= 1050 ? 220 : 180
                height: interior.compact ? 44 : Math.max(0, footer.y - y)
                page: interior.currentPage
                compact: interior.compact
                configBrowser: root.selectedGroup === "Config"
                onFileSelected: fileId => configPage.requestSelect(fileId)
            }
            Item {
                id: viewport
                x: interior.compact ? 0 : sidebar.width
                y: interior.compact ? sidebar.y + sidebar.height : topbar.height
                width: Math.max(0, parent.width - x)
                height: Math.max(0, footer.y - y)
                clip: true
                Item {
                    anchors.fill: parent
                    anchors.margins: interior.compact ? 16 : 24
                    SettingsPages.GeneralSettingsPage {
                        id: generalPage
                        anchors.fill: parent
                        visible: root.selectedGroup === "General"
                        onReloadRequested: root.requestReload()
                    }
                    SettingsPages.ShellSettingsPage {
                        id: shellPage
                        anchors.fill: parent
                        visible: root.selectedGroup === "Shell"
                        onReloadRequested: root.requestReload()
                        onConfirmationRequested: action => root.confirmation = action
                    }
                    SettingsPages.ConfigEditorPage {
                        id: configPage
                        anchors.fill: parent
                        visible: root.selectedGroup === "Config"
                        onCloseRequested: root.handleEscape()
                    }
                    SettingsPages.InfoPage {
                        id: infoPage
                        anchors.fill: parent
                        visible: root.selectedGroup === "Info"
                    }
                }
                // Page switches animate presentation only; controls keep stable geometry.
                SequentialAnimation {
                    id: pageTransition
                    NumberAnimation { target: viewport; property: "opacity"; from: 0.65; to: 1; duration: 160; easing.type: Easing.OutCubic }
                }
                Connections { target: root; function onSelectedGroupChanged() { pageTransition.restart() } }
            }
            SettingsPages.SettingsFooter {
                id: footer
                width: parent.width
                height: implicitHeight
                anchors.bottom: parent.bottom
                page: interior.currentPage
            }
        }
    }
}
