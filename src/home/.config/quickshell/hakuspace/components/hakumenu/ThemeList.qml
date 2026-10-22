import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"
import "../motion" as Motion

Item {
    id: root

    property string query: ""
    property real leftColumnWidth: width
    property real stateColumnWidth: 0
    property real columnGap: Theme.gap * 2
    property color rowHoverColor: "#202020"
    property color rowSelectedColor: Theme.accent
    readonly property real itemGap: Math.max(3, Math.round(Theme.gap * 0.35) + 1)
    readonly property real rowHeight: Math.max(46, Theme.fontSize * 3.0)
    property var visibleItems: []
    property int refreshGeneration: 0

    signal launched(bool closeMenu)
    signal highlightedLabelChanged(string label)

    readonly property bool hikaiBackend: (backendStateView.text() || "").trim().toLowerCase() === "hikai"

    readonly property var items: [
        { label: "Change Theme", icon: "", action: "Change Theme", toggle: false, showState: false, stateFile: "", statePath: "", stateKind: "bool" },
        { label: "Change Wallpaper", icon: "󰏜", action: "Change Wallpaper", toggle: false, showState: false, stateFile: "", statePath: "", stateKind: "bool" },
        { label: "Taskbar Mode", icon: "󰐃", action: "Taskbar Mode", toggle: true, showState: true, chromeKey: "taskbar" },
        { label: "Cava Underbar", icon: "󰝚", action: "Cava Underbar", toggle: true, showState: true, stateFile: "cava_layer_state", statePath: "", stateKind: "bool" },
        { label: "Cava Position", icon: "󰝚", action: "Cava Position", toggle: true, showState: true, stateFile: "cava_top_state", statePath: "", stateKind: "cavaPosition" },
        { label: "Cava Color Mode", icon: "󰝚", action: "Cava Color Mode", toggle: true, showState: true, stateFile: "cava_color_state", statePath: "", stateKind: "cavaColor" },
        { label: "Desktop Icons", icon: "", action: "Desktop Icons", toggle: true, showState: true, stateFile: "desktop_icons_state", statePath: "", stateKind: "bool" },
        { label: "Dockbar", icon: "󰧨", action: "Dockbar", toggle: true, showState: true, chromeKey: "dockbar" },
        { label: "Auto Random Wallpaper", icon: "", action: "Auto Random Wallpaper", toggle: true, showState: true, stateFile: "", statePath: "/tmp/random_wallpaper_status", stateKind: "bool" },
        { label: "Kill Lively Wallpaper", icon: "󱛹", action: "Kill Lively Wallpaper", toggle: false, showState: false, stateFile: "", statePath: "", stateKind: "bool" },
        { label: "", icon: "󰆧", action: "", toggle: true, showState: false, stateFile: "shell_backend", statePath: "", stateKind: "backend", backendSwitch: true }
    ]

    function labelFor(item) {
        if (item && item.backendSwitch)
            return hikaiBackend ? "Go back to Surface" : "Explore the Abyss"
        return item && item.label ? item.label : ""
    }

    // Native chrome rows distinguish stored requests from topology availability.
    function available(item) { return item.chromeKey !== "dockbar" || ChromeLayout.topBarMode }
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
        var rows = []
        for (var i = 0; i < items.length; ++i) {
            if (matches(items[i])) rows.push(items[i])
        }
        visibleItems = rows
        Qt.callLater(resetSelection)
    }

    function resetSelection() {
        themeList.currentIndex = visibleItems.length > 0 ? 0 : -1
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
    }

    function activateIndex(index) {
        if (index < 0 || index >= visibleItems.length) return
        var item = visibleItems[index]
        if (!item || !available(item)) return

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

    function statePathFor(item) {
        if (item.statePath && item.statePath.length > 0) return item.statePath
        if (item.stateFile && item.stateFile.length > 0) return Env.stateDir + "/" + item.stateFile
        return ""
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
            rebuildModel()
            stateRefreshTimer.restart()
        } else {
            root.highlightedLabelChanged("")
        }
    }

    Component.onCompleted: rebuildModel()

    FileView {
        id: backendStateView
        path: Env.stateDir + "/shell_backend"
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
            z: 0
            normalColor: Theme.accent
        }

        ScrollBar.vertical: Motion.HScrollBar {
            id: vbar
        }

        delegate: Item {
            id: rowWrap
            required property var modelData
            required property int index
            width: themeList.width
            height: root.rowHeight

            readonly property bool hasState: modelData.showState === true && modelData.toggle && (!!modelData.chromeKey || root.statePathFor(modelData).length > 0)
            readonly property bool stateOn: modelData.chromeKey ? root.chromeEnabled(modelData)
                : hasState ? root.parseState(stateView.text(), modelData.stateKind) : false
            readonly property int observedRefreshGeneration: root.refreshGeneration

            onObservedRefreshGenerationChanged: {
                if (hasState && !modelData.chromeKey) stateView.reload()
            }

            FileView {
                id: stateView
                path: rowWrap.hasState && !rowWrap.modelData.chromeKey ? root.statePathFor(rowWrap.modelData) : ""
                watchChanges: rowWrap.hasState && !rowWrap.modelData.chromeKey
                printErrors: false
                onFileChanged: this.reload()
            }

            Motion.MorphButton {
                id: rowButton
                enabled: root.available(rowWrap.modelData)
                opacity: enabled ? 1 : 0.45
                z: 1
                x: 0
                width: root.leftColumnWidth
                height: parent.height
                radius: Theme.radius
                selected: themeList.currentIndex === rowWrap.index
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: (selected || focused) ? "transparent" : root.rowHoverColor
                pressedColor: (selected || focused) ? "transparent" : root.rowHoverColor
                selectedColor: "transparent"
                foregroundColor: Theme.fg
                hoverForegroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                pressedForegroundColor: (selected || focused) ? Theme.onAccentColor : Theme.fg
                selectedForegroundColor: Theme.onAccentColor
                hoverScaleDelta: 0.003
                pressScaleDelta: 0.012

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this
                }

                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this
                }

                onHoveredChanged: {
                    if (hovered) {
                        themeList.currentIndex = rowWrap.index
                        root.syncSelectionLabel()
                    }
                }
                onClicked: root.activateIndex(rowWrap.index)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.pad * 1.5
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad * 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowWrap.modelData.icon + "  " + root.labelFor(rowWrap.modelData)
                        + (root.available(rowWrap.modelData) ? "" : " · Requires TopBar mode")
                    color: rowButton.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: (rowButton.selected || rowButton.focused) ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }
            }

            Motion.MorphButton {
                id: stateButton
                enabled: root.available(rowWrap.modelData)
                opacity: enabled ? 1 : 0.45
                z: 1
                x: root.leftColumnWidth + root.columnGap
                width: Math.max(0, root.stateColumnWidth - vbar.reservedGutter)
                height: parent.height
                visible: rowWrap.hasState
                radius: Theme.radius
                selected: themeList.currentIndex === rowWrap.index
                selectedOverridesHover: false
                idleColor: "transparent"
                hoverColor: root.rowHoverColor
                pressedColor: root.rowHoverColor
                selectedColor: "transparent"
                hoverScaleDelta: 0.003
                pressScaleDelta: 0.012
                onHoveredChanged: {
                    if (hovered) {
                        themeList.currentIndex = rowWrap.index
                        root.syncSelectionLabel()
                    }
                }
                onClicked: root.activateIndex(rowWrap.index)

                Rectangle {
                    id: togglePill
                    readonly property bool isColorKind: rowWrap.modelData.stateKind === "cavaColor"
                    readonly property bool isPositionKind: rowWrap.modelData.stateKind === "cavaPosition"
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Theme.gap * 2, Math.max(94, Theme.fontSize * 6.8))
                    height: Math.max(28, Theme.fontSize * 1.9)
                    radius: height / 2
                    color: rowWrap.stateOn ? Theme.accent : Qt.darker(Theme.hoverMuted, 1.5)
                    border.width: 1
                    border.color: rowWrap.stateOn ? Theme.accent : Qt.darker(Theme.hoverMuted, 1.85)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: rowWrap.stateOn ? Theme.gap + 6 : parent.width - width - Theme.gap - 6
                        text: togglePill.isPositionKind ? (rowWrap.stateOn ? "TOP" : "BOTTOM")
                            : togglePill.isColorKind ? (rowWrap.stateOn ? "ACCENT" : "SURFACE")
                            : (rowWrap.stateOn ? "ON" : "OFF")
                        color: rowWrap.stateOn ? "#000000" : Theme.fgMuted
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
                        color: rowWrap.stateOn ? "#000000" : Theme.accent

                        Behavior on x {
                            NumberAnimation {
                                duration: HAnimation.fast
                                easing.type: Easing.OutCubic
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
