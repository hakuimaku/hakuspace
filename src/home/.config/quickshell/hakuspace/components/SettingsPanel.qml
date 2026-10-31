import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services"
import "motion/PanelRevealGeometry.js" as Reveal
import "settings" as SettingsPages
import "settings/SettingsNavigation.js" as Navigation
import "../config/SettingsCatalog.js" as Catalog

PanelWindow {
    id: root
    // Release only after the surface has finished its visual close.
    readonly property bool releaseReady: !panelOpen && !morphAnim.running && morphProgress === 0 && undoPopup.releaseReady
    required property var modelData
    property string selectedCategory: "Look"
    property string highlightedId: ""
    // Lazy page objects leave all editable drafts in their persistent stores.
    readonly property var generalPage: generalLoader.item
    readonly property var shellPage: shellLoader.item
    readonly property var wallpaperPage: wallpaperLoader.item
    readonly property var configPage: configLoader.item
    readonly property var infoPage: infoLoader.item
    property bool configVisited: false

    // Category selection keeps the existing store-specific Apply and confirmation paths.
    function selectCategory(category) {
        selectedCategory = ({General: "Look", Appearance: "Look", Desktop: "Shell", Session: "Power & Session", Recording: "Capture", Configuration: "Advanced", Info: "About"})[category] || category
        if (!Catalog.categories.includes(selectedCategory)) selectedCategory = "Look"
        if (selectedCategory === "Advanced") configVisited = true
        lastContentFocus = null
        contentFocus = ({})
    }

    // Search changes the category, then reveals the matching row after lazy creation.
    function revealResult(result) {
        highlightedId = result.id
        selectCategory(result.category)
        Qt.callLater(function() {
            if (!root || !root.panelOpen) return
            var page = interior.currentPage
            if (page && typeof page.reveal === "function") page.reveal(result.id, result.group || result.section || "")
            highlightTimer.restart()
        })
    }
    Timer { id: highlightTimer; interval: 2500; onTriggered: root.highlightedId = "" }
    property bool closePending: false
    property string confirmation: ""
    // Keep the close dialog open until every submitted draft finishes saving.
    property bool applyingClose: false
    property string confirmationError: ""
    readonly property bool settingsBusy: SettingsStore.loading || SettingsStore.saving
        || ShellSettingsStore.loading || ShellSettingsStore.saving || WallpaperSettingsStore.loading || WallpaperSettingsStore.saving || ConfigEditorStore.busy
    readonly property var dirtyDomains: [SettingsStore.dirty ? "General" : "",
        ShellSettingsStore.dirty ? "Shell" : "", WallpaperSettingsStore.dirty ? "Wallpaper" : "", ConfigEditorStore.dirty ? "Config" : "",
        Object.keys(SettingsCoordinator.runtimePending).length ? "Runtime preferences" : ""].filter(Boolean)
    readonly property string closeSaveProblem: SettingsStore.dirty && (!SettingsStore.ready || !SettingsStore.valid)
        ? "General has invalid values. Keep editing to correct them."
        : ShellSettingsStore.dirty && (!ShellSettingsStore.ready || !ShellSettingsStore.valid)
        ? "Shell settings are not ready to apply. Keep editing to review them."
        : WallpaperSettingsStore.dirty && (!WallpaperSettingsStore.ready || !WallpaperSettingsStore.valid)
        ? "Wallpaper settings are not ready to apply."
        : ConfigEditorStore.dirty && !ConfigEditorStore.canSave && !ConfigEditorStore.busy
        ? "Config cannot be saved. Keep editing to resolve the file conflict or invalid text." : ""
    readonly property bool canApplyAndClose: !settingsBusy && !applyingClose && !closeSaveProblem
    onSettingsBusyChanged: { Qt.callLater(root.finishApplyAndClose); Qt.callLater(root.finishClose) }
    onConfirmationChanged: {
        confirmationError = ""
        if (confirmation.length > 0) confirmationDialog.activeConfirmation = confirmation
    }
    readonly property bool panelOpen: UiState.activePanel === "settings"
                                      && UiState.settingsScreenName === modelData.name
    // Window shortcuts belong only to the open, interactive Settings surface.
    readonly property var focusedItem: root.contentItem.Window.window ? root.contentItem.Window.window.activeFocusItem : null
    // Remember the content control when crossing back through the sidebar.
    property Item lastContentFocus: null
    property var contentFocus: ({})
    onFocusedItemChanged: {
        var target = Navigation.owner(focusedItem)
        if (focusZoneIndex() === 2 && target) {
            lastContentFocus = target
            contentFocus[selectedCategory + "|" + Navigation.section(target, interior.currentPage)] = target
        }
        revealFocus()
    }
    readonly property bool navigationEnabled: panelOpen && interior.enabled && !confirmation && !confirmationDialog.visible && !shortcutHelp.visible && !sidebar.popupOpen && !(selectedCategory === "Advanced" && configPage && configPage.popupOpen)
        && !(focusedItem && focusedItem.inputMethodComposing === true)
    // A hidden Config warning must not disable keyboard navigation on other pages.
    readonly property bool pageConfirmation: selectedCategory === "Advanced" && configPage && configPage.confirmation.length > 0
    readonly property bool pageShortcutsEnabled: navigationEnabled && !pageConfirmation
    // Keep keyboard region order aligned across entry, cycling and arrow navigation.
    readonly property var focusZones: [topbar, sidebar, interior.currentPage, footer, undoPopup]

    // Expose explicit arrow targets without consulting Tab focus metadata.
    function navItems(item, role) { return Navigation.collect(item, role) }
    // Locate the current region even when native controls focus an internal child.
    function focusZoneIndex() { return Navigation.region(focusedItem, focusZones) }
    // Restore only live targets belonging to the selected page and contextual section.
    function focusZone(index, restoreAny) {
        var items = navItems(focusZones[index])
        if (!items.length) return false
        if (index === 2) {
            if (restoreAny && items.includes(lastContentFocus)) return focusItem(lastContentFocus)
            var section = interior.currentPage.activeSection || ""
            var sectionItems = items.filter(item => Navigation.section(item, interior.currentPage) === section)
            if (sectionItems.length) items = sectionItems
            var remembered = contentFocus[selectedCategory + "|" + section]
            if (items.includes(remembered)) return focusItem(remembered)
            if (selectedCategory === "Advanced") return focusItem(items.find(item => item.settingsNavRole === "editor") || items[0])
        }
        var selected = index < 2 ? items.filter(item => item.selected === true || item.settingsNavSelected === true) : []
        return focusItem(selected.length ? selected[selected.length - 1] : items[0])
    }
    // F6 leaves code-editor indentation intact and skips regions without enabled controls.
    function cycleFocusZone(step) {
        if (pageConfirmation) { configPage.focusConfirmation(); return }
        var current = focusZoneIndex()
        var count = focusZones.length
        for (var i = 1; i <= count; ++i) {
            if (focusZone((current + step * i + count * 2) % count)) return
        }
    }
    // Tab changes preserve every page draft and focus the newly selected domain.
    function selectDomain(index) {
        selectCategory(sidebar.categories[(index + sidebar.categories.length) % sidebar.categories.length])
        focusZone(1)
    }
    // Route save and reload shortcuts through each page's existing guards and confirmations.
    function activatePageShortcut(save) {
        if (!pageShortcutsEnabled) return
        if (save && selectedCategory === "Advanced") { configPage.saveFromKeyboard(); return }
        if (selectedCategory === "About" && !save) InfoStore.load()
        if (selectedCategory === "Advanced" && !save) configPage.requestReload()

    }
    // Keep shortcuts inside the layer's key events so reload and shutdown release them safely.
    function handleShortcut(event) {
        if (!panelOpen || !interior.enabled || confirmation || confirmationDialog.visible || shortcutHelp.visible || sidebar.popupOpen) return false
        var modifiers = event.modifiers
        if (modifiers === Qt.NoModifier && event.key === Qt.Key_F1) {
            if (!event.isAutoRepeat) shortcutHelp.toggle()
        } else {
            if (!navigationEnabled) return false
            if (((modifiers === Qt.ControlModifier && [Qt.Key_K, Qt.Key_F].includes(event.key)) || (modifiers === Qt.NoModifier && event.key === Qt.Key_Slash))
                    && !root.textInputFocused()) topbar.focusSearch()
            else if (modifiers === Qt.ControlModifier && [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].includes(event.key))
                focusZone(event.key === Qt.Key_Up ? 0 : event.key === Qt.Key_Left ? 1 : 2)
            else if (modifiers === Qt.NoModifier && handleArrowNavigation(event)) return true
            else if (modifiers === Qt.ControlModifier && event.key === Qt.Key_Tab)
                selectDomain(sidebar.categories.indexOf(selectedCategory) + 1)
            else if (modifiers === (Qt.ControlModifier | Qt.ShiftModifier)
                    && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab))
                selectDomain(sidebar.categories.indexOf(selectedCategory) - 1)
            else if (modifiers === Qt.AltModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && event.key - Qt.Key_1 < sidebar.categories.length)
                selectDomain(event.key - Qt.Key_1)
            else if (event.key === Qt.Key_F6 && (modifiers === Qt.NoModifier || modifiers === Qt.ShiftModifier))
                cycleFocusZone(modifiers === Qt.ShiftModifier ? -1 : 1)
            else if (modifiers === Qt.ControlModifier && event.key === Qt.Key_F) {
                topbar.focusSearch()
            } else if (modifiers === Qt.ControlModifier && event.key === Qt.Key_S) {
                if (!event.isAutoRepeat) activatePageShortcut(true)
            } else if (modifiers === Qt.NoModifier && event.key === Qt.Key_F5) {
                if (!event.isAutoRepeat) activatePageShortcut(false)
            } else return false
        }
        event.accepted = true
        return true
    }
    // Native editing and reading retain their keys before regional navigation runs.
    function controlOwnsKey(event) {
        var target = Navigation.owner(focusedItem)
        if (!target) return false
        var horizontal = event.key === Qt.Key_Left || event.key === Qt.Key_Right
        if (target.settingsNavRole === "input" && [Qt.Key_Home, Qt.Key_End].includes(event.key)) return true
        if (target.settingsNavEditing === true || (horizontal ? target.settingsNavOwnsHorizontal : target.settingsNavOwnsVertical) === true)
            return true
        if (horizontal && target.settingsNavRole === "input")
            return target.selectionStart !== target.selectionEnd
                || (event.key === Qt.Key_Left ? target.cursorPosition > 0 : target.cursorPosition < target.text.length)
        return false
    }
    // Search shortcuts leave text entry and code-editor commands untouched.
    function textInputFocused() {
        var owner = Navigation.owner(focusedItem)
        return !!(owner && ["input", "editor"].includes(owner.settingsNavRole)) || !!(focusedItem && focusedItem.cursorPosition !== undefined)
    }
    // Content follows semantic rows; boundary transitions remain owned by the layer.
    function navigateContent(event) {
        var target = Navigation.next(interior.currentPage, navItems(interior.currentPage),
            Navigation.owner(focusedItem), event.key)
        if (target) return focusItem(target)
        if (event.key === Qt.Key_Left) return focusZone(1)
        if (event.key === Qt.Key_Up) return focusZone(0)
        if (event.key === Qt.Key_Down) return focusZone(3)
        return false
    }
    // Focus movement is separate from activation and never dispatches page actions.
    function focusItem(item) {
        if (!item || !item.visible || !item.enabled || item.width <= 0 || item.height <= 0) return false
        item.forceActiveFocus(Qt.ShortcutFocusReason)
        return true
    }
    // Domain arrows wrap while the help button stays outside the domain sequence.
    function navigateTopbar(event) {
        if (event.key === Qt.Key_Down) return focusZone(1) || focusZone(2)
        if (![Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End].includes(event.key)) return false
        return focusItem(Navigation.listTarget(navItems(topbar), Navigation.owner(focusedItem), event.key, false, false))
    }
    // Context rows focus without selecting a section or switching a dirty file.
    function navigateSidebar(event) {
        if (event.key === Qt.Key_Right) return focusZone(2)
        if (event.key === Qt.Key_Left) return true
        var current = Navigation.owner(focusedItem)
        var items = navItems(sidebar)
        if (event.key === Qt.Key_Up && items.indexOf(current) === 0) return focusZone(0)
        return focusItem(Navigation.listTarget(items, current, event.key, true, false))
    }
    // Footer arrows only choose enabled actions; Up restores page content.
    function navigateFooter(event) {
        if (event.key === Qt.Key_Up) return focusZone(2, true)
        return focusItem(Navigation.listTarget(navItems(footer, "footer"),
            Navigation.owner(focusedItem), event.key, false, false))
    }
    // Each region owns its local contract and the layer owns boundary transitions.
    function handleArrowNavigation(event) {
        if (!navigationEnabled || event.modifiers !== Qt.NoModifier
                || ![Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End].includes(event.key)) return false
        if (controlOwnsKey(event)) return false
        var zone = focusZoneIndex()
        if (zone === 0 && topbar.searching && event.key === Qt.Key_Down) return false
        var moved = zone === 0 ? navigateTopbar(event) : zone === 1 ? navigateSidebar(event)
            : zone === 2 && [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].includes(event.key) ? navigateContent(event)
            : zone === 3 ? navigateFooter(event) : false
        if (moved) event.accepted = true
        return moved
    }
    // Bring keyboard-focused rows into view without moving the pointer or selecting Info cards.
    function revealFocus() {
        if (!navigationEnabled || !focusedItem) return
        for (var view = focusedItem.parent; view; view = view.parent) {
            if (view.contentY === undefined || !view.contentItem || focusedItem.height > view.height) continue
            var top = focusedItem.mapToItem(view.contentItem, 0, 0).y
            var next = Math.min(view.contentY, top)
            if (top + focusedItem.height > next + view.height) next = top + focusedItem.height - view.height
            view.contentY = Math.max(0, Math.min(next, view.contentHeight - view.height))
        }
    }
    // Keep fixed dimensions with 32 px of clearance on smaller outputs.
    readonly property real targetBodyWidth: Math.min(1180, Math.max(0, modelData.width - 64))
    readonly property real targetBodyHeight: Math.min(750, Math.max(0, modelData.height - 64))
    // One reversible value widens the diagonal neck and its centered chassis.
    property real morphProgress: 0
    // Bound the Sidebar easing overshoot before computing the silhouette.
    readonly property real revealProgress: Math.max(0, Math.min(1, morphProgress))
    // Chassis clipping bounds input while the opening animation reveals live controls.
    readonly property bool interactionReady: panelOpen
    // Use the Navigation corner, numbered clockwise from the top-left corner.
    property int revealPosition: ScreenGeometry.bottomAttached ? 7 : 1
    // Keep attachment geometry inside the active status bar and screen rails.
    readonly property rect revealBounds: Qt.rect(ScreenGeometry.leftInset,
        ScreenGeometry.bottomAttached ? ScreenGeometry.topBorderThickness : ScreenGeometry.chromeAttachmentY(height),
        Math.max(0, width - ScreenGeometry.leftInset - ScreenGeometry.rightInset),
        Math.max(0, ScreenGeometry.bottomAttached ? ScreenGeometry.chromeAttachmentY(height) - ScreenGeometry.topBorderThickness
            : height - ScreenGeometry.bottomInset - ScreenGeometry.chromeAttachmentY(height)))
    // Share the fixed-endpoint neck geometry with any other anchored panel.
    readonly property var revealGeometry: Reveal.neck(revealPosition, revealBounds,
        Qt.rect(settingsBody.x, settingsBody.y, settingsBody.width, settingsBody.height), revealProgress, Theme.fontSize * 12)

    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
        easing.type: Easing.BezierSpline
    }

    // Cancel the active confirmation before initiating the existing close flow.
    function handleEscape() {
        if (applyingClose) return
        if (shortcutHelp.visible) shortcutHelp.close()
        else if (confirmation) confirmation = ""
        else if (pageConfirmation) configPage.cancelConfirmation()
        else requestClose()
    }
    // A close request waits for autosave and asks only about actionable unsaved state.
    function requestClose() {
        closePending = true
        SettingsCoordinator.flush()
        finishClose()
    }
    function finishClose() {
        if (!closePending || SettingsCoordinator.busy || ConfigEditorStore.busy) return
        closePending = false
        if (SettingsCoordinator.closeBlocked || SettingsCoordinator.dirty) confirmation = "close"
        else UiState.closeSettings()
    }
    Connections {
        target: SettingsCoordinator
        function onBusyChanged() { Qt.callLater(root.finishClose) }
        function onDirtyChanged() { Qt.callLater(root.finishClose) }
        function onImportingChanged() { Qt.callLater(root.finishClose) }
    }
    // Closing can discard failed preference drafts or the explicit config draft.
    function confirmDiscard() {
        if (settingsBusy || applyingClose || confirmation !== "close") return
        confirmation = ""
        SettingsStore.discard()
        ShellSettingsStore.discard()
        WallpaperSettingsStore.discard()
        SettingsCoordinator.pendingIds = ({})
        SettingsCoordinator.runtimePending = ({})
        SettingsCoordinator.runtimeError = ""
        ConfigEditorStore.discard()
        if (configPage) configPage.cancelConfirmation()
        UiState.closeSettings()
    }
    // Submit all modified pages together and retain failed drafts for review.
    function applyAndClose() {
        if (confirmation !== "close" || !canApplyAndClose) return
        confirmationError = ""
        applyingClose = true
        if (SettingsCoordinator.error) SettingsCoordinator.activateAction("Retry")
        else SettingsCoordinator.flush()
        if (SettingsStore.dirty) SettingsStore.apply()
        if (ShellSettingsStore.dirty) ShellSettingsStore.apply()
        if (WallpaperSettingsStore.dirty) WallpaperSettingsStore.apply()
        if (ConfigEditorStore.dirty) ConfigEditorStore.save(ConfigEditorStore.reloadSupported ? "save-reload" : "write")
        Qt.callLater(root.finishApplyAndClose)
    }
    // Store exit handlers finish updating errors and snapshots before this runs.
    function finishApplyAndClose() {
        if (!applyingClose || settingsBusy) return
        applyingClose = false
        if (dirtyDomains.length) {
            confirmationError = (SettingsStore.dirty ? SettingsStore.error : "")
                || (ShellSettingsStore.dirty ? ShellSettingsStore.error : "")
                || (WallpaperSettingsStore.dirty ? WallpaperSettingsStore.error : "")
                || (ConfigEditorStore.dirty ? ConfigEditorStore.error : "")
                || "Some changes are still unsaved. Keep editing to review them."
            return
        }
        confirmation = ""
        if (configPage) configPage.cancelConfirmation()
        UiState.closeSettings()
    }
    onSelectedCategoryChanged: {
        if (!panelOpen) return
        if (selectedCategory === "Advanced" && !ConfigEditorStore.ready) ConfigEditorStore.loadFiles()
        if (selectedCategory === "About") InfoStore.load()
    }

    Connections {
        target: UiState
        function onSettingsGroupChanged() {
            if (root.panelOpen && UiState.settingsGroup) { var category = UiState.settingsGroup; UiState.settingsGroup = ""; if (category === "appbar") root.revealResult({id: "shell.dock.iconSize", category: "Shell", group: "App Bar"}); else root.selectCategory(category) }
        }
    }
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: UiState.nativeDialogOwner === "settings" ? WlrLayer.Bottom : ShellTransitionState.chromeOverlayLayer
    WlrLayershell.namespace: "hakuspace-settings"
    WlrLayershell.keyboardFocus: panelOpen && UiState.ownsInteraction("settings", modelData.name) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Observe presses before delegates handle them, then pass the event through.
    MouseArea {
        anchors.fill: parent
        z: 10000
        enabled: root.panelOpen && !UiState.nativeDialogOpen
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => { UiState.claimInteraction("settings", root.modelData.name); mouse.accepted = false }
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: panelOpen || morphAnim.running || morphProgress > 0 || !undoPopup.releaseReady
    mask: Region {
        width: root.visible ? root.modelData.width : 0
        height: root.visible ? root.modelData.height : 0
        Region {
            intersection: Intersection.Subtract
            x: UiState.tempNoteRect.x; y: UiState.tempNoteRect.y
            width: UiState.tempNoteScreenName === root.modelData.name ? UiState.tempNoteRect.width : 0
            height: UiState.tempNoteScreenName === root.modelData.name ? UiState.tempNoteRect.height : 0
        }
        Region {
            intersection: Intersection.Subtract
            x: UiState.taskManagerRect.x; y: UiState.taskManagerRect.y
            width: UiState.taskManagerScreenName === root.modelData.name ? UiState.taskManagerRect.width : 0
            height: UiState.taskManagerScreenName === root.modelData.name ? UiState.taskManagerRect.height : 0
        }
        // Settings controls keep precedence where floating utilities are visually covered.
        Region { x: settingsBody.x; y: settingsBody.y; width: settingsBody.width; height: settingsBody.height }
    }
    Component.onDestruction: UiState.closeSettingsIfScreen(modelData.name)
    onPanelOpenChanged: {
        morphAnim.stop()
        morphAnim.to = panelOpen ? 1 : 0
        morphAnim.duration = Math.round((panelOpen ? HAnimation.sidebarToolOpenDuration
            : HAnimation.sidebarToolCloseDuration) * Math.abs(morphAnim.to - morphProgress))
        morphAnim.easing.bezierCurve = panelOpen ? HAnimation.sidebarToolOpenCurve : HAnimation.sidebarToolCloseCurve
        morphAnim.start()
        if (!panelOpen) { shortcutHelp.close(); closePending = false }
        if (panelOpen) {
            if (UiState.settingsGroup) {
                var group = UiState.settingsGroup
                UiState.settingsGroup = ""
                if (group === "appbar") revealResult({id: "shell.dock.iconSize", category: "Shell", group: "App Bar"})
                else selectCategory(group)
            }
            confirmation = ""
            if (!SettingsStore.ready) SettingsStore.load()
            else if (!SettingsStore.dirty) SettingsStore.reload()
            if (!ShellSettingsStore.dirty) ShellSettingsStore.reload()
            if (!WallpaperSettingsStore.dirty) WallpaperSettingsStore.reload()
            if (selectedCategory === "Advanced" && !ConfigEditorStore.ready) ConfigEditorStore.loadFiles()
            if (selectedCategory === "About") InfoStore.load()
            Qt.callLater(function() { if (root && root.panelOpen) keyHandler.forceActiveFocus() })
        }
    }
    Item {
        id: shortcutKeys
        Keys.onPressed: event => root.handleShortcut(event)
    }
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.panelOpen
        Keys.forwardTo: [shortcutKeys]
        Keys.onEscapePressed: event => { root.handleEscape(); event.accepted = true }
    }
    Rectangle { anchors.fill: parent; color: Theme.surface; opacity: 0.22 * root.revealProgress }
    MouseArea { anchors.fill: parent; enabled: root.panelOpen; onClicked: root.requestClose() }

    // Widen the full diagonal from the chosen attachment point to the stationary panel.
    Shape {
        anchors.fill: parent
        visible: root.revealGeometry.path.length > 0
        opacity: settingsBody.opacity
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.surface
            strokeColor: "transparent"
            PathSvg { path: root.revealGeometry.path }
        }
    }

    Rectangle {
        id: settingsBody
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: root.targetBodyWidth * root.revealProgress
        height: root.targetBodyHeight * root.revealProgress
        radius: Math.min(width / 2, height / 2, Theme.largeRadius)
        color: Theme.surface
        opacity: Math.min(1, root.revealProgress / 0.12)
        border.width: 0
        clip: root.revealProgress < 0.999
        MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

        SettingsPages.SettingsShortcutGuide {
            id: shortcutHelp
            parent: root.contentItem
            sourceItem: topbar.shortcutButton
        }
        Dialog {
            id: confirmationDialog
            parent: root.contentItem
            anchors.centerIn: parent
            width: Math.max(0, Math.min(560, root.targetBodyWidth - 24))
            padding: 24
            spacing: 20
            modal: true
            dim: true
            focus: true
            visible: root.panelOpen && root.confirmation.length > 0
            closePolicy: root.applyingClose ? Popup.NoAutoClose : Popup.CloseOnEscape
            property Item previousFocus: null
            property string activeConfirmation: ""
            readonly property string currentAction: activeConfirmation || root.confirmation
            readonly property var labels: ["Keep Editing", "Discard & Close", "Save & Close"]
            onAboutToShow: {
                activeConfirmation = root.confirmation
                previousFocus = root.contentItem.Window.window.activeFocusItem
            }
            onOpened: confirmationActions.itemAt(0).forceActiveFocus()
            onClosed: {
                activeConfirmation = ""
                if (!root.applyingClose) root.confirmation = ""
                if (root.panelOpen) {
                    if (!root.focusItem(previousFocus)) root.focusZone(0)
                }
            }
            enter: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: HAnimation.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.actionLayerOpenCurve
                }
            }
            exit: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 1.0
                    to: 0.0
                    duration: HAnimation.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.actionLayerCloseCurve
                }
            }
            Overlay.modal: Rectangle {
                color: Qt.alpha(Theme.surface, 0.72)
                opacity: confirmationDialog.opacity
            }
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
                    text: "Unsaved changes"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    text: root.applyingClose ? "Saving changes… Please wait."
                        : "Unsaved changes in " + root.dirtyDomains.join(", ") + ". Save retries pending changes; Discard restores saved values. A layout preview is reverted before closing."
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.confirmationError || (confirmationDialog.currentAction === "close" ? root.closeSaveProblem : "")
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }
            }
            footer: Item {
                id: confirmationFooter
                width: confirmationDialog.width
                // Modal action navigation never reaches the background Settings regions.
                Keys.onPressed: event => {
                    if (event.modifiers === Qt.NoModifier) {
                        var target = Navigation.listTarget(Navigation.collect(confirmationFooter),
                            Navigation.owner(root.focusedItem), event.key, false, false)
                        if (target) event.accepted = root.focusItem(target)
                    }
                }
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
                            readonly property bool primary: modelData === "Save & Close"
                            TextMetrics { id: dialogMetrics; font.family: Theme.fontFamily; font.pixelSize: Math.max(10, Theme.fontSize - 1); text: dialogAction.modelData }
                            width: Math.min(dialogButtons.width, Math.max(100, dialogMetrics.width + 28))
                            height: 40
                            text: modelData
                            fontSize: Math.max(10, Theme.fontSize - 1)
                            idleColor: primary ? Theme.accent : Theme.hoverMuted
                            hoverColor: primary ? Theme.accent : Theme.surfaceHighlight(1.18)
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
        // Keep key routing alive when a changing footer replaces its focused button.
        FocusScope {
            id: interior
            // Keep page layout fixed while the surrounding chassis morphs.
            x: root.targetBodyWidth < 760 || root.targetBodyHeight < 560 ? 12 : 24
            y: x
            width: Math.max(0, root.targetBodyWidth - 2 * x)
            height: Math.max(0, root.targetBodyHeight - y)
            clip: true
            // Keep page objects alive so navigation never resets a draft or confirmation.
            readonly property var currentPage: (["Look", "Power & Session", "Capture"].includes(root.selectedCategory) ? generalPage
                : root.selectedCategory === "Shell" ? shellPage : root.selectedCategory === "Wallpaper" ? wallpaperPage
                : root.selectedCategory === "Advanced" ? configPage : infoPage) || emptyPage
            readonly property bool compact: width < 760
            enabled: root.interactionReady
            Keys.onEscapePressed: event => { root.handleEscape(); event.accepted = true }
            Keys.onPressed: event => root.handleShortcut(event)

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
                shortcutTarget: shortcutKeys
                onResultRequested: result => root.revealResult(result)
                onCloseRequested: root.requestClose()
                guideOpen: shortcutHelp.visible
                onShortcutsRequested: shortcutHelp.open()
            }
            SettingsPages.SettingsSidebar {
                id: sidebar
                y: topbar.height
                width: interior.compact ? 178 : parent.width >= 1050 ? 240 : 210
                height: Math.max(0, footer.y - y)
                selected: root.selectedCategory
                onSelectedRequested: category => root.selectCategory(category)
            }
            Item {
                id: viewport
                x: sidebar.width
                y: topbar.height
                width: Math.max(0, parent.width - x)
                height: Math.max(0, footer.y - y)
                clip: true
                Item {
                    anchors.fill: parent
                    anchors.margins: interior.compact ? 16 : 24
                    Item {
                        id: emptyPage
                        readonly property var actionLabels: []
                        readonly property string footerStatus: ""
                        readonly property bool footerDirty: false
                        readonly property bool footerError: false
                        function canActivate(label) { return false }
                    }
                    Loader {
                        id: generalLoader
                        anchors.fill: parent
                        active: ["Look", "Power & Session", "Capture"].includes(root.selectedCategory)
                        sourceComponent: root.selectedCategory === "Power & Session" ? sessionPageComponent : root.selectedCategory === "Capture" ? capturePageComponent : generalPageComponent
                    }
                    Component {
                        id: sessionPageComponent
                        SettingsPages.PowerSessionSettingsPage {
                            highlightedId: root.highlightedId
                            shortcutTarget: shortcutKeys
                        }
                    }
                    Component {
                        id: generalPageComponent
                        SettingsPages.LookSettingsPage {
                            category: root.selectedCategory
                            highlightedId: root.highlightedId
                            shortcutTarget: shortcutKeys
                        }
                    }
                    Component {
                        id: capturePageComponent
                        SettingsPages.CaptureSettingsPage { shortcutTarget: shortcutKeys; highlightedId: root.highlightedId }
                    }
                    Loader {
                        id: shellLoader
                        anchors.fill: parent
                        active: root.selectedCategory === "Shell"
                        sourceComponent: SettingsPages.ShellSettingsPage {
                            category: root.selectedCategory
                            highlightedId: root.highlightedId
                            shortcutTarget: shortcutKeys
                        }
                    }
                    Loader {
                        id: wallpaperLoader
                        anchors.fill: parent
                        active: root.selectedCategory === "Wallpaper"
                        sourceComponent: SettingsPages.WallpaperSettingsPage {
                            highlightedId: root.highlightedId
                            shortcutTarget: shortcutKeys
                        }
                    }
                    // Keep an in-progress file-switch confirmation until the panel closes.
                    Loader {
                        id: configLoader
                        anchors.fill: parent
                        active: root.configVisited
                        visible: root.selectedCategory === "Advanced"
                        sourceComponent: SettingsPages.AdvancedSettingsPage {
                            shortcutTarget: shortcutKeys
                            highlightedId: root.highlightedId
                            onCloseRequested: root.handleEscape()
                        }
                    }
                    Loader {
                        id: infoLoader
                        anchors.fill: parent
                        active: root.selectedCategory === "About"
                        sourceComponent: SettingsPages.InfoPage { }
                    }
                }
                // Page switches animate presentation only; controls keep stable geometry.
                SequentialAnimation {
                    id: pageTransition
                    NumberAnimation { target: viewport; property: "opacity"; from: 0.65; to: 1; duration: 160; easing.type: Easing.OutCubic }
                }
                Connections { target: root; function onSelectedCategoryChanged() { pageTransition.restart() } }
            }
            SettingsPages.SettingsFooter {
                id: footer
                width: parent.width
                height: visible ? implicitHeight : 0
                anchors.bottom: parent.bottom
                visible: SettingsCoordinator.actionLabels.length > 0
                page: SettingsCoordinator
            }
        }
    }
    SettingsPages.SettingsUndoPopup {
        id: undoPopup
        objectName: "settings-undo-popup"
        anchors.fill: parent
        panelRect: Qt.rect((root.width - root.targetBodyWidth) / 2, (root.height - root.targetBodyHeight) / 2, root.targetBodyWidth, root.targetBodyHeight)
        requested: root.interactionReady && !!SettingsCoordinator.message
        shortcutTarget: shortcutKeys
    }
}
