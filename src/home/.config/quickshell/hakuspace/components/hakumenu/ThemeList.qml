import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog
import "../motion" as Motion
import "../settings" as Settings

Item {
    id: root

    property string query: ""
    property real leftColumnWidth: width
    property real stateColumnWidth: 0
    property real columnGap: Theme.gap * 2
    property color rowHoverColor: Theme.hoverMuted
    property color rowSelectedColor: Theme.accent
    readonly property real itemGap: Math.max(3, Math.round(Theme.gap * 0.35) + 1)
    readonly property real rowHeight: Math.max(46, Theme.fontSize * 3.0)
    property var visibleItems: []
    property int refreshGeneration: 0
    property bool isLowerSectionActive: false
    property int lastUpperIndex: 0
    property Item lastUpperItem: null
    readonly property int bottomMorphDuration: 520
    readonly property list<real> bounceCurve: [0.30, 1.38, 0.32, 1.0, 1, 1]

    signal launched(bool closeMenu)
    signal wallpaperRequested()
    signal highlightedLabelChanged(string label)

    readonly property bool hikaiBackend: (backendStateView.text() || "").trim().toLowerCase() === "hikai"

    readonly property var items: UiCatalog.hakuMenuThemeItems

    function labelFor(item) {
        if (item && (item.statusEdgeSwitch || item.chromeKey === "taskbar") && typeof SettingsCoordinator !== "undefined" && SettingsCoordinator.runtimeError)
            return item.label + " · " + SettingsCoordinator.runtimeError
        if (item && item.stateKind === "colorMode" && ShellSettingsStore.error)
            return item.label + " · " + ShellSettingsStore.error
        if (item && item.backendSwitch)
            return hikaiBackend ? "Go back to Surface" : "Explore the Abyss"
        return item && item.label ? item.label : ""
    }

    // Gate actions on settings IO and native chrome availability.
    function available(item) {
        if (item.statusEdgeSwitch || item.chromeKey === "taskbar" && hikaiBackend)
            return ShellSettingsStore.ready && (typeof SettingsCoordinator !== "undefined" ? !SettingsCoordinator.busy : true)
        if (item.stateKind === "colorMode") return ShellSettingsStore.ready && !ShellSettingsStore.loading && !ShellSettingsStore.saving
        return item.chromeKey !== "dockbar" || (typeof ChromeLayout.statusBarMode !== "undefined" ? ChromeLayout.statusBarMode : true)
    }
    function chromeEnabled(item) {
        return item.chromeKey === "taskbar" ? AppState.taskbarManualState : AppState.dockbarManualState
    }

    function actionFor(item) {
        if (item && item.backendSwitch) return labelFor(item)
        return item && item.action ? item.action : ""
    }

    function normalizedQuery() {
        var text = query.trim()
        if (text.startsWith("~")) text = text.slice(1)
        return text.trim().toLowerCase()
    }

    function matches(item) {
        var q = normalizedQuery()
        if (q.length === 0) return true
        return labelFor(item).toLowerCase().indexOf(q) >= 0
    }

    function rebuildModel() {
        var previous = visibleItems[themeList.currentIndex]
        var rows = []
        for (var item of items) {
            if (item.statusEdgeSwitch && (!hikaiBackend || ChromeLayout.taskbarMode)) continue
            if (matches(item)) rows.push(item)
        }
        visibleItems = rows
        Qt.callLater(function() {
            if (!root) return
            themeList.currentIndex = rows.length ? Math.max(0, rows.indexOf(previous)) : -1
            if (themeList.currentIndex >= 0) themeList.positionViewAtIndex(themeList.currentIndex, ListView.Contain)
            syncSelectionLabel()
        })
    }

    function resetSelection() {
        themeList.currentIndex = visibleItems.length > 0 ? 0 : -1
        root.isLowerSectionActive = false
        if (themeList.currentIndex >= 0)
            themeList.positionViewAtIndex(themeList.currentIndex, ListView.Beginning)
        syncSelectionLabel()
    }

    function syncSelectionLabel() {
        if (!visible) return
        var index = themeList.currentIndex
        if (index < 0 || index >= visibleItems.length) {
            root.highlightedLabelChanged("")
            return
        }
        root.highlightedLabelChanged(root.labelFor(visibleItems[index]))
    }

    function moveSelection(delta) {
        var count = visibleItems.length
        if (count === 0) return
        var next = themeList.currentIndex
        if (next < 0) next = 0
        else next = Math.max(0, Math.min(count - 1, next + delta))
        themeList.currentIndex = next
        themeList.positionViewAtIndex(next, ListView.Contain)
        syncSelectionLabel()
        var item = visibleItems[next]
        if (item && (item.statusEdgeSwitch || item.chromeKey === "taskbar" || item.backendSwitch)) {
            root.isLowerSectionActive = true
        } else {
            root.isLowerSectionActive = false
            root.lastUpperIndex = next
        }
    }

    function activateIndex(index) {
        if (index < 0 || index >= visibleItems.length) return
        var item = visibleItems[index]
        if (!item || !available(item)) return
        if (item.statusEdgeSwitch || item.chromeKey === "taskbar" && hikaiBackend) {
            var target = item.statusEdgeSwitch ? (ChromeLayout.leftBarMode ? "topbar" : "leftbar")
                : ChromeLayout.taskbarMode ? (ShellSettingsStore.statusEdge === "left" ? "leftbar" : "topbar") : "taskbar"
            if (typeof SettingsCoordinator !== "undefined") {
                SettingsCoordinator.set("layout", target)
            }
            root.launched(false)
            return
        }
        // Persist mode changes through the shared store and keep the menu open.
        if (item.stateKind === "colorMode") {
            ShellSettingsStore.applyColorMode(Theme.isLight ? "dark" : "light")
            root.launched(false)
            return
        }
        if (item.action === "Change Wallpaper") { wallpaperRequested(); return }

        actionProcess.running = false
        actionProcess.command = [Env.binDir + "/hm_theme.sh", root.actionFor(item)]
        actionProcess.running = true

        // Toggle actions intentionally keep HakuMenu open. Non-toggle actions
        // launch an external picker/action and retain the old close-on-launch UX.
        root.launched(!item.toggle)
    }

    function activateCurrent() {
        activateIndex(themeList.currentIndex)
    }

    // Resolve static state identifiers through the runtime environment.
    function statePathFor(item) {
        if (item.stateKey === "randomWallpaper") return "/tmp/random_wallpaper_status"
        return item.stateKey ? Env[item.stateKey] : ""
    }

    function parseState(text, kind) {
        var value = (text || "").trim().toLowerCase()
        if (kind === "backend") return value === "hikai"
        if (kind === "cavaColor") return value === "1" || value === "accent" || value === "white"
        if (kind === "cavaPosition") return value !== "0" && value !== "bottom"
        return value === "1" || value === "true" || value === "on" || value === "enabled" || value === "yes"
    }

    onQueryChanged: rebuildModel()
    onVisibleChanged: {
        if (visible) {
            root.isLowerSectionActive = false
            rebuildModel()
            stateRefreshTimer.restart()
        } else {
            root.highlightedLabelChanged("")
        }
    }

    Connections {
        target: ChromeLayout
        ignoreUnknownSignals: true
        function onStatusEdgeChanged() { root.rebuildModel() }
    }
    Component.onCompleted: rebuildModel()

    FileView {
        id: backendStateView
        path: Env.stateShellBackend
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onTextChanged: {
            root.refreshGeneration++
            root.rebuildModel()
        }
    }

    Timer {
        id: stateRefreshTimer
        interval: 220
        repeat: false
        onTriggered: root.refreshGeneration++
    }

    Process {
        id: actionProcess
        onExited: stateRefreshTimer.restart()
    }

    ListView {
        id: themeList
        anchors.fill: parent
        clip: true
        spacing: root.itemGap
        topMargin: Theme.gap
        bottomMargin: Theme.gap
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: count > 0 ? 0 : -1
        model: root.visibleItems
        onCurrentIndexChanged: {
            root.syncSelectionLabel()
            if (currentIndex < 0) selectionPill.targetItem = null
        }

        Motion.SelectionPill {
            id: selectionPill
            parent: themeList.contentItem
            z: 1
            normalColor: root.isLowerSectionActive ? Theme.hoverMuted : Theme.accent
            onNormalColorChanged: syncTarget(false)
            opacity: shown ? (root.isLowerSectionActive ? 0.5 : 1.0) : 0
            shown: targetItem !== null
            duration: HAnimation.spatial

            Behavior on opacity {
                NumberAnimation {
                    duration: HAnimation.spatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.spatialCurve
                }
            }
        }

        ScrollBar.vertical: Motion.HScrollBar {
            id: vbar
        }

        delegate: Item {
            id: rowWrap
            required property var modelData
            required property int index
            width: themeList.width
            readonly property bool isSpecialOption: !!modelData && (modelData.statusEdgeSwitch === true || modelData.chromeKey === "taskbar")
            readonly property bool isBackendSwitch: !!modelData && modelData.backendSwitch === true
            readonly property bool isFullWidth: isSpecialOption || isBackendSwitch
            readonly property bool isBottomOption: isFullWidth
            height: isSpecialOption ? Math.round(specialColumn.implicitHeight + Theme.spaceXs * 2) : root.rowHeight

            readonly property bool hasState: !isSpecialOption && modelData.showState === true && modelData.toggle && (modelData.stateKind === "colorMode" || !!modelData.chromeKey || root.statePathFor(modelData).length > 0)
            readonly property bool stateOn: modelData.stateKind === "colorMode" ? Theme.isLight
                : modelData.chromeKey ? root.chromeEnabled(modelData)
                : hasState ? root.parseState(stateView.text(), modelData.stateKind) : false
            readonly property int observedRefreshGeneration: root.refreshGeneration

            onObservedRefreshGenerationChanged: {
                if (hasState && root.statePathFor(modelData)) stateView.reload()
            }

            FileView {
                id: stateView
                path: rowWrap.hasState ? root.statePathFor(rowWrap.modelData) : ""
                watchChanges: path.length > 0
                printErrors: false
                onFileChanged: this.reload()
            }

            Rectangle {
                id: columnMask
                visible: rowWrap.isBottomOption
                z: 0
                x: 0
                y: rowWrap.index === 0 ? 0 : -root.itemGap / 2
                width: parent.width
                height: parent.height + (rowWrap.index === themeList.count - 1 ? 500 : (rowWrap.index === 0 ? 0 : root.itemGap / 2))
                color: Theme.surface
            }

            Column {
                id: specialColumn
                visible: rowWrap.isSpecialOption
                z: 2
                x: Theme.gap
                width: Math.max(0, parent.width - Theme.gap * 2 - vbar.reservedGutter)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceXs

                Item {
                    id: specialTitleItem
                    width: parent.width
                    height: Math.max(24, specialTitleText.implicitHeight + 4)

                    Text {
                        id: specialTitleText
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.pad * 1.5
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.pad * 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowWrap.modelData.icon + "  " + root.labelFor(rowWrap.modelData)
                        color: root.available(rowWrap.modelData) ? Theme.fg : Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                root.isLowerSectionActive = true
                                themeList.currentIndex = rowWrap.index
                                root.syncSelectionLabel()
                            }
                        }
                    }

                    TapHandler {
                        onTapped: {
                            themeList.currentIndex = rowWrap.index
                            root.syncSelectionLabel()
                            root.activateIndex(rowWrap.index)
                        }
                    }
                }

                Item {
                    id: statusEdgeTrack
                    visible: rowWrap.modelData.statusEdgeSwitch === true
                    width: parent.width
                    height: Theme.comfortableControlHeight

                    readonly property real slotSpacing: Theme.spaceXs
                    readonly property real slotWidth: Math.max(0, (width - slotSpacing) / 2)
                    readonly property int activeIndex: ChromeLayout.leftBarMode ? 1 : 0
                    property int previewIndex: activeIndex
                    onActiveIndexChanged: {
                        statusReturnTimer.stop()
                        previewIndex = activeIndex
                    }

                    Timer {
                        id: statusReturnTimer
                        interval: 1000
                        repeat: false
                        onTriggered: statusEdgeTrack.previewIndex = statusEdgeTrack.activeIndex
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                root.isLowerSectionActive = true
                                themeList.currentIndex = rowWrap.index
                                root.syncSelectionLabel()
                            }
                        }
                    }

                    Rectangle {
                        id: statusPill
                        z: 1
                        x: statusEdgeTrack.previewIndex * (statusEdgeTrack.slotWidth + statusEdgeTrack.slotSpacing)
                        y: 0
                        width: statusEdgeTrack.slotWidth
                        height: parent.height
                        radius: 8
                        color: Theme.accent
                        readonly property bool isPreviewing: statusEdgeTrack.previewIndex !== statusEdgeTrack.activeIndex
                        opacity: isPreviewing ? 0.5 : 1.0

                        Behavior on x {
                            NumberAnimation {
                                duration: root.bottomMorphDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.bounceCurve
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.bottomMorphDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.bounceCurve
                            }
                        }
                    }

                    Motion.MorphButton {
                        id: topbarBtn
                        z: 2
                        x: 0
                        y: 0
                        width: statusEdgeTrack.slotWidth
                        height: parent.height
                        radius: 8
                        enabled: root.available(rowWrap.modelData)
                        opacity: enabled ? 1 : 0.45
                        text: "Topbar"
                        idleColor: "transparent"
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        selectedColor: "transparent"
                        foregroundColor: statusEdgeTrack.previewIndex === 0 ? Theme.onAccentColor : Theme.fgMuted
                        hoverForegroundColor: Theme.onAccentColor
                        selectedForegroundColor: Theme.onAccentColor
                        onHoveredChanged: {
                            if (hovered) {
                                root.isLowerSectionActive = true
                                themeList.currentIndex = rowWrap.index
                                root.syncSelectionLabel()
                                statusReturnTimer.stop()
                                statusEdgeTrack.previewIndex = 0
                            } else if (!leftbarBtn.hovered) {
                                if (statusEdgeTrack.previewIndex !== statusEdgeTrack.activeIndex) {
                                    statusReturnTimer.restart()
                                }
                            }
                        }
                        onClicked: {
                            statusReturnTimer.stop()
                            themeList.currentIndex = rowWrap.index
                            root.syncSelectionLabel()
                            if (ChromeLayout.leftBarMode && typeof SettingsCoordinator !== "undefined") {
                                SettingsCoordinator.set("layout", "topbar")
                            }
                            root.launched(false)
                        }
                    }

                    Motion.MorphButton {
                        id: leftbarBtn
                        z: 2
                        x: statusEdgeTrack.slotWidth + statusEdgeTrack.slotSpacing
                        y: 0
                        width: statusEdgeTrack.slotWidth
                        height: parent.height
                        radius: 8
                        enabled: root.available(rowWrap.modelData)
                        opacity: enabled ? 1 : 0.45
                        text: "Leftbar"
                        idleColor: "transparent"
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        selectedColor: "transparent"
                        foregroundColor: statusEdgeTrack.previewIndex === 1 ? Theme.onAccentColor : Theme.fgMuted
                        hoverForegroundColor: Theme.onAccentColor
                        selectedForegroundColor: Theme.onAccentColor
                        onHoveredChanged: {
                            if (hovered) {
                                root.isLowerSectionActive = true
                                themeList.currentIndex = rowWrap.index
                                root.syncSelectionLabel()
                                statusReturnTimer.stop()
                                statusEdgeTrack.previewIndex = 1
                            } else if (!topbarBtn.hovered) {
                                if (statusEdgeTrack.previewIndex !== statusEdgeTrack.activeIndex) {
                                    statusReturnTimer.restart()
                                }
                            }
                        }
                        onClicked: {
                            statusReturnTimer.stop()
                            themeList.currentIndex = rowWrap.index
                            root.syncSelectionLabel()
                            if (!ChromeLayout.leftBarMode && typeof SettingsCoordinator !== "undefined") {
                                SettingsCoordinator.set("layout", "leftbar")
                            }
                            root.launched(false)
                        }
                    }
                }

                Item {
                    id: taskbarTrack
                    visible: rowWrap.modelData.chromeKey === "taskbar"
                    width: parent.width
                    height: Theme.comfortableControlHeight

                    readonly property real slotSpacing: Theme.spaceXs
                    readonly property real slotWidth: Math.max(0, (width - slotSpacing) / 2)
                    readonly property int activeIndex: ChromeLayout.taskbarMode ? 1 : 0
                    property int previewIndex: activeIndex
                    onActiveIndexChanged: {
                        taskbarReturnTimer.stop()
                        previewIndex = activeIndex
                    }

                    Timer {
                        id: taskbarReturnTimer
                        interval: 1000
                        repeat: false
                        onTriggered: taskbarTrack.previewIndex = taskbarTrack.activeIndex
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                root.isLowerSectionActive = true
                                themeList.currentIndex = rowWrap.index
                                root.syncSelectionLabel()
                            }
                        }
                    }

                    Rectangle {
                        id: taskbarPill
                        z: 1
                        x: taskbarTrack.previewIndex * (taskbarTrack.slotWidth + taskbarTrack.slotSpacing)
                        y: 0
                        width: taskbarTrack.slotWidth
                        height: parent.height
                        radius: 8
                        color: Theme.accent
                        readonly property bool isPreviewing: taskbarTrack.previewIndex !== taskbarTrack.activeIndex
                        opacity: isPreviewing ? 0.5 : 1.0

                        Behavior on x {
                            NumberAnimation {
                                duration: root.bottomMorphDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.bounceCurve
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.bottomMorphDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.bounceCurve
                            }
                        }
                    }

                    Motion.MorphButton {
                        id: offBtn
                        z: 2
                        x: 0
                        y: 0
                        width: taskbarTrack.slotWidth
                        height: parent.height
                        radius: 8
                        enabled: root.available(rowWrap.modelData)
                        opacity: enabled ? 1 : 0.45
                        text: "Off"
                        idleColor: "transparent"
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        selectedColor: "transparent"
                        foregroundColor: taskbarTrack.previewIndex === 0 ? Theme.onAccentColor : Theme.fgMuted
                        hoverForegroundColor: Theme.onAccentColor
                        selectedForegroundColor: Theme.onAccentColor
                        onHoveredChanged: {
                            if (hovered) {
                                root.isLowerSectionActive = true
                                themeList.currentIndex = rowWrap.index
                                root.syncSelectionLabel()
                                taskbarReturnTimer.stop()
                                taskbarTrack.previewIndex = 0
                            } else if (!onBtn.hovered) {
                                if (taskbarTrack.previewIndex !== taskbarTrack.activeIndex) {
                                    taskbarReturnTimer.restart()
                                }
                            }
                        }
                        onClicked: {
                            taskbarReturnTimer.stop()
                            themeList.currentIndex = rowWrap.index
                            root.syncSelectionLabel()
                            if (ChromeLayout.taskbarMode) {
                                root.activateIndex(rowWrap.index)
                            }
                        }
                    }

                    Motion.MorphButton {
                        id: onBtn
                        z: 2
                        x: taskbarTrack.slotWidth + taskbarTrack.slotSpacing
                        y: 0
                        width: taskbarTrack.slotWidth
                        height: parent.height
                        radius: 8
                        enabled: root.available(rowWrap.modelData)
                        opacity: enabled ? 1 : 0.45
                        text: "On"
                        idleColor: "transparent"
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        selectedColor: "transparent"
                        foregroundColor: taskbarTrack.previewIndex === 1 ? Theme.onAccentColor : Theme.fgMuted
                        hoverForegroundColor: Theme.onAccentColor
                        selectedForegroundColor: Theme.onAccentColor
                        onHoveredChanged: {
                            if (hovered) {
                                root.isLowerSectionActive = true
                                themeList.currentIndex = rowWrap.index
                                root.syncSelectionLabel()
                                taskbarReturnTimer.stop()
                                taskbarTrack.previewIndex = 1
                            } else if (!offBtn.hovered) {
                                if (taskbarTrack.previewIndex !== taskbarTrack.activeIndex) {
                                    taskbarReturnTimer.restart()
                                }
                            }
                        }
                        onClicked: {
                            taskbarReturnTimer.stop()
                            themeList.currentIndex = rowWrap.index
                            root.syncSelectionLabel()
                            if (!ChromeLayout.taskbarMode) {
                                root.activateIndex(rowWrap.index)
                            }
                        }
                    }
                }
            }

            Motion.MorphButton {
                id: rowButton
                visible: !rowWrap.isSpecialOption
                enabled: root.available(rowWrap.modelData)
                opacity: enabled ? 1 : 0.45
                z: 2
                x: Theme.gap
                width: rowWrap.isFullWidth ? Math.max(0, parent.width - Theme.gap * 2 - vbar.reservedGutter) : root.leftColumnWidth
                height: parent.height
                radius: Theme.radius
                selected: !rowWrap.isBottomOption && themeList.currentIndex === rowWrap.index && !root.isLowerSectionActive
                selectedOverridesHover: !rowWrap.isBottomOption
                idleColor: "transparent"
                hoverColor: rowWrap.isBottomOption ? "transparent" : ((selected || focused) ? "transparent" : root.rowHoverColor)
                pressedColor: rowWrap.isBottomOption ? "transparent" : ((selected || focused) ? "transparent" : root.rowHoverColor)
                selectedColor: "transparent"
                foregroundColor: Theme.fg
                hoverForegroundColor: rowWrap.isBottomOption ? Theme.fg : ((selected || focused) ? Theme.onAccentColor : Theme.fg)
                pressedForegroundColor: rowWrap.isBottomOption ? Theme.fg : ((selected || focused) ? Theme.onAccentColor : Theme.fg)
                selectedForegroundColor: rowWrap.isBottomOption ? Theme.fg : Theme.onAccentColor
                hoverScaleDelta: rowWrap.isBackendSwitch ? 0 : 0.003
                pressScaleDelta: rowWrap.isBackendSwitch ? 0 : 0.012

                scale: rowWrap.isBackendSwitch ? (hovered ? 1.1 : 1.0) : 1.0
                transformOrigin: Item.Center

                Behavior on scale {
                    NumberAnimation {
                        duration: root.bottomMorphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.bounceCurve
                    }
                }

                Component.onCompleted: {
                    if (rowWrap.index === 0 && !rowWrap.isBottomOption) {
                        root.lastUpperIndex = 0
                        root.lastUpperItem = this
                        selectionPill.targetItem = this
                    }
                }

                onSelectedChanged: {
                    if (selected && !rowWrap.isBottomOption) {
                        root.lastUpperIndex = rowWrap.index
                        root.lastUpperItem = this
                        selectionPill.targetItem = this
                    }
                }

                onHoveredChanged: {
                    if (hovered) {
                        if (rowWrap.isBottomOption) {
                            root.isLowerSectionActive = true
                            themeList.currentIndex = rowWrap.index
                            root.syncSelectionLabel()
                        } else {
                            root.isLowerSectionActive = false
                            root.lastUpperIndex = rowWrap.index
                            root.lastUpperItem = this
                            themeList.currentIndex = rowWrap.index
                            root.syncSelectionLabel()
                            selectionPill.targetItem = this
                        }
                    }
                }
                onClicked: root.activateIndex(rowWrap.index)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad * 1.5
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad * 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: rowWrap.isBackendSwitch ? Text.AlignHCenter : Text.AlignLeft
                    text: rowWrap.modelData.icon + "  " + root.labelFor(rowWrap.modelData)
                        + (root.available(rowWrap.modelData) ? "" : " · Requires status bar mode")
                    color: rowButton.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: (rowButton.selected || rowButton.focused) ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }
            }

            Motion.MorphButton {
                id: stateButton
                visible: !rowWrap.isFullWidth && rowWrap.hasState
                enabled: root.available(rowWrap.modelData)
                opacity: enabled ? 1 : 0.45
                z: 2
                x: Theme.gap + root.leftColumnWidth + root.columnGap
                width: Math.max(0, root.stateColumnWidth - vbar.reservedGutter)
                height: parent.height
                radius: Theme.radius
                selected: themeList.currentIndex === rowWrap.index && !rowWrap.isBottomOption && !root.isLowerSectionActive
                selectedOverridesHover: false
                idleColor: "transparent"
                hoverColor: root.rowHoverColor
                pressedColor: root.rowHoverColor
                selectedColor: "transparent"
                hoverScaleDelta: 0.003
                pressScaleDelta: 0.012
                onHoveredChanged: {
                    if (hovered) {
                        root.isLowerSectionActive = false
                        root.lastUpperIndex = rowWrap.index
                        root.lastUpperItem = rowButton
                        themeList.currentIndex = rowWrap.index
                        root.syncSelectionLabel()
                        selectionPill.targetItem = rowButton
                    }
                }
                onClicked: root.activateIndex(rowWrap.index)

                Rectangle {
                    id: togglePill
                    readonly property bool isColorKind: rowWrap.modelData.stateKind === "cavaColor"
                    readonly property bool isPositionKind: rowWrap.modelData.stateKind === "cavaPosition"
                    // The mode pill shows the active palette instead of ON/OFF.
                    readonly property bool isModeKind: rowWrap.modelData.stateKind === "colorMode"
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Theme.gap * 2, Math.max(102, Theme.fontSize * 6.8 + 8))
                    height: Math.max(28, Theme.fontSize * 1.9)
                    radius: height / 2
                    color: rowWrap.stateOn ? Theme.accent : Theme.surfaceSubtle(1.5)
                    border.width: 1
                    border.color: rowWrap.stateOn ? Theme.accent : Theme.surfaceSubtle(1.85)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: rowWrap.stateOn ? Theme.gap + 6 : parent.width - width - Theme.gap - 6
                        text: togglePill.isPositionKind ? (rowWrap.stateOn ? "TOP" : "BOTTOM")
                            : togglePill.isColorKind ? (rowWrap.stateOn ? "ACCENT" : "SURFACE")
                            : togglePill.isModeKind ? (rowWrap.stateOn ? "LIGHT" : "DARK")
                            : (rowWrap.stateOn ? "ON" : "OFF")
                        color: rowWrap.stateOn ? Theme.onAccentColor : Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Theme.fontSize - 2)
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        id: toggleDot
                        width: togglePill.height - 6
                        height: width
                        radius: width / 2
                        y: 3
                        x: rowWrap.stateOn ? togglePill.width - width - 3 : 3
                        color: rowWrap.stateOn ? Theme.onAccentColor : Theme.accent

                        Behavior on x {
                            NumberAnimation {
                                duration: HAnimation.spatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: HAnimation.spatialCurve
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.normalizedQuery().length > 0 ? "No Theme actions found" : "No Theme actions"
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            visible: themeList.count === 0
        }
    }
}
