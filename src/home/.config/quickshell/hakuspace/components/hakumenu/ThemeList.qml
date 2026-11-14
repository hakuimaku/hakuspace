import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    readonly property int upperCount: {
        var count = 0
        for (var i = 0; i < visibleItems.length; ++i) {
            var item = visibleItems[i]
            if (!item.shellLayoutSwitch && !item.cavaPositionSwitch && !item.backendSwitch)
                count++
        }
        return count
    }
    readonly property real upperCardHeight: upperCount > 0
        ? Theme.gap * 2 + upperCount * rowHeight + (upperCount - 1) * itemGap
        : 0

    Rectangle {
        id: upperLeftCard
        visible: root.upperCount > 0
        z: 0
        x: 0
        y: Math.max(0, -(themeList.contentY + Theme.gap))
        width: root.leftColumnWidth + Theme.gap * 2
        height: Math.max(0, Math.min(themeList.height - y, root.upperCardHeight + Math.min(0, -(themeList.contentY + Theme.gap))))
        radius: Theme.largeRadius
        color: Theme.surfaceSubtle(2.05)
    }

    Rectangle {
        id: upperStateCard
        visible: root.upperCount > 0 && root.stateColumnWidth > 0
        z: 0
        x: root.leftColumnWidth + root.columnGap
        y: upperLeftCard.y
        width: root.stateColumnWidth + Theme.gap * 2
        height: upperLeftCard.height
        radius: Theme.largeRadius
        color: Theme.surfaceSubtle(2.05)
    }

    readonly property var items: UiCatalog.hakuMenuThemeItems

    function labelFor(item) {
        if (item && (item.shellLayoutSwitch || item.cavaPositionSwitch) && typeof SettingsCoordinator !== "undefined" && SettingsCoordinator.runtimeError)
            return item.label + " · " + SettingsCoordinator.runtimeError
        if (item && item.stateKind === "colorMode" && ShellSettingsStore.error)
            return item.label + " · " + ShellSettingsStore.error
        if (item && item.backendSwitch)
            return hikaiBackend ? "Go back to Surface" : "Explore the Abyss"
        return item && item.label ? item.label : ""
    }

    // Gate actions on settings IO and native chrome availability.
    function available(item) {
        if (item.shellLayoutSwitch)
            return ShellSettingsStore.ready && (typeof SettingsCoordinator !== "undefined" ? !SettingsCoordinator.busy : true)
        if (item.cavaPositionSwitch)
            return !AppState.cavaDynamicPosition && (typeof SettingsCoordinator !== "undefined" ? !SettingsCoordinator.busy : true)
        if (item.stateKind === "colorMode") return ShellSettingsStore.ready && !ShellSettingsStore.loading && !ShellSettingsStore.saving
        return item.chromeKey !== "dockbar" || (typeof ChromeLayout.statusBarMode !== "undefined" ? ChromeLayout.statusBarMode : true)
    }
    function chromeEnabled(item) {
        return AppState.dockbarManualState
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
            if ((item.shellLayoutSwitch || item.cavaPositionSwitch) && !hikaiBackend) continue
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
        if (item && (item.shellLayoutSwitch || item.cavaPositionSwitch || item.backendSwitch)) {
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
        if (item.shellLayoutSwitch && hikaiBackend) {
            var currentLayout = ChromeLayout.taskbarMode ? "taskbar" : ChromeLayout.leftBarMode ? "leftbar" : "topbar"
            var nextLayout = currentLayout === "topbar" ? "leftbar" : currentLayout === "leftbar" ? "taskbar" : "topbar"
            if (typeof SettingsCoordinator !== "undefined") {
                SettingsCoordinator.set("layout", nextLayout)
            }
            root.launched(false)
            return
        }
        if (item.cavaPositionSwitch && hikaiBackend) {
            if (!AppState.cavaDynamicPosition) {
                var currentPos = AppState.cavaPosition
                var nextPos = currentPos === "top" ? "bottom" : currentPos === "bottom" ? "left" : currentPos === "left" ? "right" : "top"
                if (typeof SettingsCoordinator !== "undefined") {
                    SettingsCoordinator.set("cava-position", nextPos)
                }
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

    Item {
        anchors.fill: parent
        anchors.leftMargin: -Theme.hakuMenuLeftPadding
        anchors.rightMargin: -Theme.hakuMenuRightPadding
        clip: true

        ListView {
            id: themeList
            anchors.fill: parent
            anchors.leftMargin: Theme.hakuMenuLeftPadding
            anchors.rightMargin: Theme.hakuMenuRightPadding
            clip: false
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
                scale: (!root.isLowerSectionActive && targetItem) ? targetItem.scale : 1.0
                transformOrigin: Item.Center

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
                readonly property bool isSpecialOption: !!modelData && (modelData.shellLayoutSwitch === true || modelData.cavaPositionSwitch === true)
                readonly property bool isBackendSwitch: !!modelData && modelData.backendSwitch === true
                readonly property bool isFullWidth: isSpecialOption || isBackendSwitch
                readonly property bool isBottomOption: isFullWidth
                readonly property real sectionGap: (isBottomOption && index === root.upperCount && root.upperCount > 0) ? Theme.pad : 0
                height: (isSpecialOption ? Math.round(specialColumn.implicitHeight + Theme.spaceXs * 2) : root.rowHeight) + sectionGap

                readonly property bool hasState: !isSpecialOption && modelData.showState === true && modelData.toggle && (modelData.stateKind === "colorMode" || !!modelData.chromeKey || root.statePathFor(modelData).length > 0)
                readonly property bool stateOn: modelData.stateKind === "colorMode" ? Theme.isLight
                    : modelData.chromeKey ? root.chromeEnabled(modelData)
                    : hasState ? root.parseState(stateView.text(), modelData.stateKind) : false
                readonly property int observedRefreshGeneration: root.refreshGeneration

                onYChanged: if (rowButton.selected) selectionPill.syncTarget(false)
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

                GridLayout {
                    id: rowGrid
                    anchors.fill: parent
                    anchors.topMargin: rowWrap.sectionGap
                    anchors.leftMargin: Theme.gap
                    anchors.rightMargin: Theme.gap + vbar.reservedGutter
                    columns: 2
                    rowSpacing: 0
                    columnSpacing: root.columnGap

                    Column {
                        id: specialColumn
                        visible: rowWrap.isSpecialOption
                        z: 2
                        Layout.row: 0
                        Layout.column: 0
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
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
                            id: specialOptionTrack
                            visible: rowWrap.isSpecialOption
                            width: parent.width
                            height: Theme.comfortableControlHeight

                            readonly property bool isCavaTrack: rowWrap.modelData.cavaPositionSwitch === true
                            readonly property bool isLocked: isCavaTrack && AppState.cavaDynamicPosition
                            readonly property var trackOptions: isCavaTrack
                                ? [{value: "top", label: "Top"}, {value: "bottom", label: "Bottom"}, {value: "left", label: "Left"}, {value: "right", label: "Right"}]
                                : UiCatalog.statusBarLayouts
                            readonly property int slotCount: trackOptions.length
                            readonly property real slotSpacing: Theme.spaceXs
                            readonly property real slotWidth: slotCount > 0 ? Math.max(0, (width - slotSpacing * (slotCount - 1)) / slotCount) : 0
                            readonly property int activeIndex: isCavaTrack
                                ? (AppState.cavaPosition === "bottom" ? 1 : AppState.cavaPosition === "left" ? 2 : AppState.cavaPosition === "right" ? 3 : 0)
                                : (ChromeLayout.taskbarMode ? 2 : ChromeLayout.leftBarMode ? 1 : 0)
                            property int previewIndex: activeIndex
                            property int hoveredSlot: -1

                            opacity: isLocked ? 0.5 : 1.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.bottomMorphDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: root.bounceCurve
                                }
                            }

                            onActiveIndexChanged: {
                                trackReturnTimer.stop()
                                previewIndex = activeIndex
                            }

                            Timer {
                                id: trackReturnTimer
                                interval: 1000
                                repeat: false
                                onTriggered: specialOptionTrack.previewIndex = specialOptionTrack.activeIndex
                            }

                            HoverHandler {
                                enabled: !specialOptionTrack.isLocked
                                onHoveredChanged: {
                                    if (hovered) {
                                        root.isLowerSectionActive = true
                                        themeList.currentIndex = rowWrap.index
                                        root.syncSelectionLabel()
                                    }
                                }
                            }

                            Rectangle {
                                z: 0
                                anchors.fill: parent
                                radius: 10
                                color: Theme.isLight ? Theme.panel : Theme.surfaceSubtle(1.15)
                                border.width: Theme.isLight ? 1 : 0
                                border.color: Theme.border
                            }

                            Rectangle {
                                id: specialTrackPill
                                z: 1
                                x: specialOptionTrack.previewIndex * (specialOptionTrack.slotWidth + specialOptionTrack.slotSpacing)
                                y: 0
                                width: specialOptionTrack.slotWidth
                                height: parent.height
                                radius: 8
                                color: Theme.accent
                                readonly property bool isPreviewing: specialOptionTrack.previewIndex !== specialOptionTrack.activeIndex
                                opacity: isPreviewing ? 0.5 : 1.0
                                scale: specialOptionTrack.hoveredSlot >= 0 && segmentRepeater.itemAt(specialOptionTrack.hoveredSlot)
                                    ? segmentRepeater.itemAt(specialOptionTrack.hoveredSlot).scale : 1.0
                                transformOrigin: Item.Center

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

                            Repeater {
                                id: segmentRepeater
                                model: specialOptionTrack.trackOptions

                                Motion.MorphButton {
                                    id: segmentBtn
                                    required property var modelData
                                    required property int index
                                    z: 2
                                    x: index * (specialOptionTrack.slotWidth + specialOptionTrack.slotSpacing)
                                    y: 0
                                    width: specialOptionTrack.slotWidth
                                    height: specialOptionTrack.height
                                    radius: 8
                                    enabled: !specialOptionTrack.isLocked && root.available(rowWrap.modelData)
                                    disabledOpacity: specialOptionTrack.isCavaTrack ? 1.0 : 0.45
                                    text: modelData.label
                                    idleColor: "transparent"
                                    hoverColor: "transparent"
                                    pressedColor: "transparent"
                                    selectedColor: "transparent"
                                    foregroundColor: specialOptionTrack.previewIndex === index ? Theme.onAccentColor : Theme.fgMuted
                                    disabledForegroundColor: specialOptionTrack.previewIndex === index ? Theme.onAccentColor : Theme.fgMuted
                                    hoverForegroundColor: Theme.onAccentColor
                                    selectedForegroundColor: Theme.onAccentColor
                                    hoverScaleDelta: Theme.hakuMenuHoverScaleDelta
                                    pressScaleDelta: 0.018
                                    onHoveredChanged: {
                                        if (hovered && enabled) {
                                            specialOptionTrack.hoveredSlot = index
                                            root.isLowerSectionActive = true
                                            themeList.currentIndex = rowWrap.index
                                            root.syncSelectionLabel()
                                            trackReturnTimer.stop()
                                            specialOptionTrack.previewIndex = index
                                        } else if (specialOptionTrack.hoveredSlot === index) {
                                            specialOptionTrack.hoveredSlot = -1
                                            if (specialOptionTrack.previewIndex !== specialOptionTrack.activeIndex) {
                                                trackReturnTimer.restart()
                                            }
                                        }
                                    }
                                    onClicked: {
                                        trackReturnTimer.stop()
                                        themeList.currentIndex = rowWrap.index
                                        root.syncSelectionLabel()
                                        if (typeof SettingsCoordinator !== "undefined") {
                                            SettingsCoordinator.set(specialOptionTrack.isCavaTrack ? "cava-position" : "layout", modelData.value)
                                        }
                                        root.launched(false)
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
                        Layout.row: 0
                        Layout.column: 0
                        Layout.columnSpan: rowWrap.isFullWidth ? 2 : 1
                        Layout.preferredWidth: rowWrap.isFullWidth ? -1 : root.leftColumnWidth
                        Layout.minimumWidth: rowWrap.isFullWidth ? 0 : root.leftColumnWidth
                        Layout.maximumWidth: rowWrap.isFullWidth ? 16777215 : root.leftColumnWidth
                        Layout.fillWidth: rowWrap.isFullWidth
                        Layout.fillHeight: true
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
                        hoverScaleDelta: Theme.hakuMenuHoverScaleDelta
                        pressScaleDelta: 0.012

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
                        Layout.row: 0
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radius
                        selected: themeList.currentIndex === rowWrap.index && !rowWrap.isBottomOption && !root.isLowerSectionActive
                        selectedOverridesHover: false
                        idleColor: "transparent"
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        selectedColor: "transparent"
                        hoverScaleDelta: Theme.hakuMenuHoverScaleDelta
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
}
