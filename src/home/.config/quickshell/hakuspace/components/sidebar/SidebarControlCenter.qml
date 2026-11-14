import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog
import "../motion" as Motion

FocusScope {
    id: root
    signal closeRequested(bool keyboard)
    signal railFocusRequested()
    signal actionRequested(string key)
    signal powerActionRequested(string id)

    property int selectedIndex: 0
    property int preferredColumn: 0
    property bool keyboardCursor: false
    property bool horizontal: false
    property var toggleStates: ({})
    property string errorMessage: ""
    property string statusOutput: ""
    property bool powerMenuOpen: false
    property Item hoveredTooltipTarget: null
    property string hoveredTooltipText: ""

    readonly property var actions: UiCatalog.sidebarControlCenterActions
    readonly property var powerActions: UiCatalog.actionMenuPowerActions

    readonly property int columnCount: 4
    readonly property int rowCount: 5
    readonly property real cellSpacing: 8
    readonly property real cellWidth: Math.max(1, (width - (columnCount - 1) * cellSpacing) / columnCount)
    readonly property real cellHeight: Math.max(1, (height - (rowCount - 1) * cellSpacing) / rowCount)

    property bool servicesSubscribed: false
    property int displayBrightness: 0
    property bool brightnessWriting: false
    property int pendingBrightness: -1
    property int lastWrittenBrightness: -1
    property int displayVolume: 0
    property bool volumeWriting: false
    property int pendingVolume: -1
    property int lastWrittenVolume: -1

    readonly property int backendBrightness: Brightness.level
    readonly property int backendVolume: Audio.volume
    readonly property bool backlightAvailable: backendBrightness >= 0
    readonly property bool audioAvailable: backendVolume >= 0
    readonly property var brightnessIcons: ["", "", "", "", "", "", "", "", ""]
    readonly property string brightnessIcon: brightnessIcons[Math.max(0, Math.min(8, Math.floor((displayBrightness / 100) * 9)))]
    readonly property string volumeIcon: Audio.muted ? "󰝟"
        : displayVolume > 60 ? "" : (displayVolume > 30 ? "" : "")
    readonly property var powerProfileIcons: ({performance: "", balanced: "", "power-saver": ""})
    readonly property string powerProfileLabel: PpdProfile.profile === "performance" ? "Performance"
        : PpdProfile.profile === "balanced" ? "Balanced"
        : PpdProfile.profile === "power-saver" ? "Power Saver"
        : "Power Profile"

    component ControlTile: SidebarMorphButton {
        id: controlTile
        property string tileIcon: ""
        property string tileLabel: ""
        width: root.cellWidth
        height: root.cellHeight
        radius: Theme.radius
        focusColor: Theme.accent
        focusForegroundColor: Theme.onAccentColor
        border.width: 0
        hoverScaleDelta: 0.04
        interactive: !root.powerMenuOpen

        Text {
            anchors.centerIn: parent
            text: controlTile.tileIcon
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(32, Math.round(Theme.fontSize * 2.4))
            color: controlTile.foreground
        }

        // Track hover passively so disabled tiles (e.g. Dockbar in Taskbar mode) still show tooltips.
        HoverHandler {
            id: tileHover
            enabled: !root.powerMenuOpen
            onHoveredChanged: {
                if (hovered) root.setHoverTooltip(controlTile, controlTile.tileLabel)
                else root.clearHoverTooltip(controlTile)
            }
        }

        Accessible.name: tileLabel
        onTileLabelChanged: {
            if (tileHover.hovered && root.hoveredTooltipTarget === controlTile)
                root.hoveredTooltipText = tileLabel
        }
    }

    function setHoverTooltip(item, label) {
        hoveredTooltipTarget = item
        hoveredTooltipText = label || ""
    }

    function clearHoverTooltip(item) {
        if (hoveredTooltipTarget === item) {
            hoveredTooltipTarget = null
            hoveredTooltipText = ""
        }
    }

    function forceFocus() { root.forceActiveFocus() }

    function stateFor(key) {
        if (key === "dockbar" && ChromeLayout.taskbarMode)
            return {available: false, enabled: AppState.dockbarManualState}
        return toggleStates[key] || { available: false, enabled: false }
    }

    function syncSubscriptions() {
        var active = visible
        if (active === servicesSubscribed) return
        servicesSubscribed = active
        if (active) {
            Brightness.acquire()
            Audio.acquire()
            PpdProfile.acquire()
        } else {
            Brightness.release()
            Audio.release()
            PpdProfile.release()
        }
    }

    onVisibleChanged: {
        syncSubscriptions()
        if (!visible) {
            powerMenuOpen = false
            hoveredTooltipTarget = null
            hoveredTooltipText = ""
            controlTooltip.resetImmediate()
        }
    }

    onBackendBrightnessChanged: {
        if (!brightnessSlider.dragging && !brightnessWriting && backendBrightness >= 0)
            displayBrightness = Math.max(0, Math.min(100, backendBrightness))
    }

    onBackendVolumeChanged: {
        if (!volumeSlider.dragging && !volumeWriting && backendVolume >= 0)
            displayVolume = Math.max(0, Math.min(100, backendVolume))
    }

    // Refresh toggle states from system owners after each completed toggle.
    function refresh() {
        statusOutput = ""
        statusProc.running = true
    }

    function levelCommand(kind, target) {
        return kind === "brightness"
            ? ["brightnessctl", "-n2", "set", target + "%"]
            : ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", target + "%"]
    }

    // Coalesce continuous slider drags to the latest target without dropping the final step.
    function queueLevel(kind, nextValue) {
        var isBrightness = kind === "brightness"
        if (isBrightness ? !backlightAvailable : !audioAvailable) return
        var target = Math.max(0, Math.min(100, Math.round(nextValue)))
        var proc = isBrightness ? brightnessWriteProc : volumeWriteProc
        if (isBrightness) {
            displayBrightness = target
            brightnessWriting = true
            if (proc.running) { pendingBrightness = target; return }
            pendingBrightness = -1
            lastWrittenBrightness = target
        } else {
            displayVolume = target
            volumeWriting = true
            if (proc.running) { pendingVolume = target; return }
            pendingVolume = -1
            lastWrittenVolume = target
        }
        proc.command = levelCommand(kind, target)
        proc.running = true
    }

    function finishLevel(kind) {
        var isBrightness = kind === "brightness"
        var pending = isBrightness ? pendingBrightness : pendingVolume
        var last = isBrightness ? lastWrittenBrightness : lastWrittenVolume
        if (pending >= 0 && pending !== last) {
            if (isBrightness) { pendingBrightness = -1; lastWrittenBrightness = pending }
            else { pendingVolume = -1; lastWrittenVolume = pending }
            var proc = isBrightness ? brightnessWriteProc : volumeWriteProc
            proc.command = levelCommand(kind, pending)
            proc.running = true
            return
        }
        if (isBrightness) {
            pendingBrightness = -1
            brightnessWriting = false
            Brightness.refresh()
        } else {
            pendingVolume = -1
            volumeWriting = false
            Audio.refresh()
        }
    }

    function toggleMute() {
        if (!audioAvailable || muteProc.running) return
        muteProc.running = true
    }

    function openPowerMenu() {
        clearHoverTooltip(powerAnchor)
        powerList.currentIndex = 0
        powerList.forceLayout()
        powerPill.syncTarget(true)
        powerMenuOpen = true
        powerList.forceActiveFocus()
    }

    function closePowerMenu(restoreFocus) {
        if (!powerMenuOpen) return
        powerMenuOpen = false
        if (restoreFocus && root.visible) root.forceFocus()
    }

    function triggerPowerIndex(index) {
        if (index < 0 || index >= powerActions.length) return
        var action = powerActions[index]
        closePowerMenu(false)
        powerActionRequested(action.id)
    }

    // Keep toggle commands serialized and leave navigation close policy to parent.
    function activate(index) {
        if (index >= 0 && index < actions.length) {
            var action = actions[index]
            if (!action.toggle) { actionRequested(action.key); return }
            if (!stateFor(action.key).available || toggleProc.running || statusProc.running) return
            errorMessage = ""
            toggleProc.command = [Env.binDir + "/quick_actions_ctl.py", "toggle", action.key]
            toggleProc.running = true
            return
        }
        if (index === 9) { toggleMute(); return }
        if (index === 10) { powerMenuOpen ? closePowerMenu(true) : openPowerMenu(); return }
        if (index === 11) { if (PpdProfile.profile !== "") PpdProfile.cycle(); return }
        if (index === 12) { actionRequested("settings"); return }
    }

    // Navigate the 5x4 grid: rows 0-1 (1x1), rows 2-3 (1x4 sliders), row 4 (1x2, 1x1, 1x1).
    function moveSelection(dx, dy) {
        keyboardCursor = true
        if (selectedIndex < 8) {
            var row = Math.floor(selectedIndex / columnCount)
            var col = selectedIndex % columnCount
            if (!horizontal && dx < 0 && col === 0) { railFocusRequested(); return }
            if (dx !== 0) {
                var nextCol = Math.max(0, Math.min(columnCount - 1, col + dx))
                selectedIndex = row * columnCount + nextCol
                preferredColumn = nextCol
            } else if (dy < 0) {
                if (row > 0) selectedIndex -= columnCount
                else if (horizontal) { railFocusRequested(); return }
            } else if (dy > 0) {
                if (row === 0) selectedIndex += columnCount
                else selectedIndex = 8
            }
            return
        }
        if (selectedIndex === 8) {
            if (dy < 0) selectedIndex = 4 + Math.max(0, Math.min(3, preferredColumn))
            else if (dy > 0) selectedIndex = 9
            else if (dx !== 0) queueLevel("brightness", displayBrightness + dx * 5)
            return
        }
        if (selectedIndex === 9) {
            if (dy < 0) selectedIndex = 8
            else if (dy > 0) selectedIndex = preferredColumn <= 1 ? 10 : (preferredColumn === 2 ? 11 : 12)
            else if (dx !== 0) queueLevel("volume", displayVolume + dx * 5)
            return
        }
        if (dx < 0) {
            if (selectedIndex === 10) {
                if (!horizontal) railFocusRequested()
                return
            }
            selectedIndex -= 1
            preferredColumn = selectedIndex === 10 ? 0 : 2
        } else if (dx > 0 && selectedIndex < 12) {
            selectedIndex += 1
            preferredColumn = selectedIndex === 11 ? 2 : 3
        } else if (dy < 0) {
            selectedIndex = 9
        }
    }

    Component.onCompleted: {
        refresh()
        syncSubscriptions()
        if (backendBrightness >= 0) displayBrightness = Math.max(0, Math.min(100, backendBrightness))
        if (backendVolume >= 0) displayVolume = Math.max(0, Math.min(100, backendVolume))
    }
    Component.onDestruction: {
        powerMenuOpen = false
        if (servicesSubscribed) {
            Brightness.release()
            Audio.release()
            PpdProfile.release()
            servicesSubscribed = false
        }
    }

    Keys.onLeftPressed: event => { moveSelection(-1, 0); event.accepted = true }
    Keys.onRightPressed: event => { moveSelection(1, 0); event.accepted = true }
    Keys.onUpPressed: event => { moveSelection(0, -1); event.accepted = true }
    Keys.onDownPressed: event => { moveSelection(0, 1); event.accepted = true }
    Keys.onReturnPressed: event => { keyboardCursor = true; activate(selectedIndex); event.accepted = true }
    Keys.onEnterPressed: event => { keyboardCursor = true; activate(selectedIndex); event.accepted = true }
    Keys.onSpacePressed: event => { keyboardCursor = true; activate(selectedIndex); event.accepted = true }
    Keys.onEscapePressed: event => {
        if (powerMenuOpen) { closePowerMenu(true); event.accepted = true; return }
        closeRequested(true)
        event.accepted = true
    }

    Process {
        id: statusProc
        command: [Env.binDir + "/quick_actions_ctl.py", "status"]
        stdout: SplitParser { onRead: data => root.statusOutput += data }
        onExited: (code, status) => {
            if (code !== 0) { root.errorMessage = "Could not read control states"; return }
            try { root.toggleStates = JSON.parse(root.statusOutput.trim()) }
            catch (error) { root.errorMessage = "Invalid control states" }
        }
    }
    Process {
        id: toggleProc
        onExited: (code, status) => {
            if (code !== 0) root.errorMessage = "Could not change action"
            root.refresh()
        }
    }
    Process { id: brightnessWriteProc; onExited: root.finishLevel("brightness") }
    Process { id: volumeWriteProc; onExited: root.finishLevel("volume") }
    Process {
        id: muteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: Audio.refresh()
    }

    Column {
        anchors.fill: parent
        spacing: root.cellSpacing

        Grid {
            width: parent.width
            columns: root.columnCount
            spacing: root.cellSpacing

            Repeater {
                model: root.actions
                delegate: ControlTile {
                    required property int index
                    required property var modelData
                    readonly property bool checked: Boolean(modelData.toggle && root.stateFor(modelData.key).enabled)
                    readonly property bool cursor: root.keyboardCursor && root.activeFocus && root.selectedIndex === index
                    tileIcon: modelData.icon
                    tileLabel: modelData.key === "dockbar" && ChromeLayout.taskbarMode ? "Dockbar (TopBar only)" : modelData.label
                    enabled: !modelData.toggle || Boolean(root.stateFor(modelData.key).available)
                    selected: checked || cursor
                    focused: cursor
                    onClicked: {
                        root.selectedIndex = index
                        root.preferredColumn = index % root.columnCount
                        root.activate(index)
                    }
                }
            }
        }

        SidebarControlSlider {
            id: brightnessSlider
            width: parent.width
            height: root.cellHeight
            title: "Backlight"
            icon: root.backlightAvailable ? root.brightnessIcon : ""
            valueText: root.backlightAvailable ? root.displayBrightness + "%" : "Unavailable"
            value: root.displayBrightness
            available: root.backlightAvailable
            hoverEnabled: !root.powerMenuOpen
            focused: root.keyboardCursor && root.activeFocus && root.selectedIndex === 8
            onMovedValue: nextValue => {
                root.selectedIndex = 8
                root.queueLevel("brightness", nextValue)
            }
        }

        SidebarControlSlider {
            id: volumeSlider
            width: parent.width
            height: root.cellHeight
            title: "Volume"
            icon: root.volumeIcon
            valueText: root.audioAvailable ? (Audio.muted ? "Muted · " + root.displayVolume + "%" : root.displayVolume + "%") : "Unavailable"
            value: root.displayVolume
            available: root.audioAvailable
            hoverEnabled: !root.powerMenuOpen
            focused: root.keyboardCursor && root.activeFocus && root.selectedIndex === 9
            iconInteractive: true
            onIconClicked: {
                root.selectedIndex = 9
                root.toggleMute()
            }
            onMovedValue: nextValue => {
                root.selectedIndex = 9
                root.queueLevel("volume", nextValue)
            }
        }

        Row {
            id: bottomRow
            width: parent.width
            height: root.cellHeight
            spacing: root.cellSpacing

            Item {
                id: powerAnchor
                width: root.cellWidth * 2 + root.cellSpacing
                height: root.cellHeight

                SidebarMorphButton {
                    id: powerButton
                    readonly property bool cursor: root.keyboardCursor && root.activeFocus && root.selectedIndex === 10
                    anchors.fill: parent
                    radius: Theme.radius
                    selected: root.powerMenuOpen || cursor
                    focused: cursor
                    focusColor: Theme.accent
                    focusForegroundColor: Theme.onAccentColor
                    border.width: 0
                    hoverScaleDelta: 0.03
                    Accessible.name: "Power"
                    onHoveredChanged: {
                        if (hovered) root.setHoverTooltip(powerAnchor, "Power")
                        else root.clearHoverTooltip(powerAnchor)
                    }
                    onClicked: {
                        root.selectedIndex = 10
                        root.preferredColumn = 0
                        root.powerMenuOpen ? root.closePowerMenu(false) : root.openPowerMenu()
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 12
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰐥"
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(32, Math.round(Theme.fontSize * 2.4))
                            color: powerButton.foreground
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.powerMenuOpen ? "⌃" : "⌄"
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(16, Math.round(Theme.fontSize * 1.25))
                            color: powerButton.foreground
                        }
                    }
                }
            }

            ControlTile {
                readonly property bool cursor: root.keyboardCursor && root.activeFocus && root.selectedIndex === 11
                tileIcon: root.powerProfileIcons[PpdProfile.profile] || ""
                tileLabel: PpdProfile.profile !== "" ? ("Power Profile: " + root.powerProfileLabel) : "Power Profile"
                enabled: PpdProfile.profile !== ""
                selected: cursor
                focused: cursor
                onClicked: {
                    root.selectedIndex = 11
                    root.preferredColumn = 2
                    root.activate(11)
                }
            }

            ControlTile {
                readonly property bool cursor: root.keyboardCursor && root.activeFocus && root.selectedIndex === 12
                tileIcon: "󰒓"
                tileLabel: "Settings"
                selected: cursor
                focused: cursor
                onClicked: {
                    root.selectedIndex = 12
                    root.preferredColumn = 3
                    root.activate(12)
                }
            }
        }
    }

    MouseArea {
        id: powerMenuBackdrop
        anchors.fill: parent
        z: 45
        visible: root.powerMenuOpen
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.closePowerMenu(false)
    }

    // Keep the droplist inside the NavigationLayer visual tree so safe-zone hover stays continuous.
    Rectangle {
        id: powerMenu
        z: 50
        x: bottomRow.x + powerAnchor.x
        y: bottomRow.y - height - 8
        width: Math.min(root.width, Math.max(powerAnchor.width, Math.round(root.width * 0.64)))
        height: Math.min(Math.max(140, root.height - root.cellHeight - 24),
            root.powerActions.length * 48 + Math.max(0, root.powerActions.length - 1) * 5 + 20)
        color: Theme.surfaceSubtle(1.18)
        radius: Theme.largeRadius
        border.width: 2
        border.color: Theme.accent
        transformOrigin: Item.BottomLeft
        opacity: root.powerMenuOpen ? 1 : 0
        scale: root.powerMenuOpen ? 1 : 0.96
        visible: root.powerMenuOpen || opacity > 0.001
        enabled: root.powerMenuOpen

        Behavior on opacity {
            NumberAnimation {
                duration: root.powerMenuOpen ? HAnimation.fast : 120
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.powerMenuOpen ? HAnimation.fast : 120
                easing.type: Easing.OutCubic
            }
        }

        // Absorb hover across list margins and row spacing so underlying tiles stay unhovered.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: 0
        }

        ListView {
            id: powerList
            z: 1
            anchors {
                fill: parent
                margins: 10
            }
            clip: true
            focus: root.powerMenuOpen
            spacing: 5
            model: root.powerActions
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds

            Keys.onUpPressed: event => { decrementCurrentIndex(); event.accepted = true }
            Keys.onDownPressed: event => { incrementCurrentIndex(); event.accepted = true }
            Keys.onEscapePressed: event => { root.closePowerMenu(true); event.accepted = true }
            Keys.onReturnPressed: event => { root.triggerPowerIndex(currentIndex); event.accepted = true }
            Keys.onEnterPressed: event => { root.triggerPowerIndex(currentIndex); event.accepted = true }
            Keys.onSpacePressed: event => { root.triggerPowerIndex(currentIndex); event.accepted = true }

            Motion.SelectionPill {
                id: powerPill
                parent: powerList.contentItem
                coordinateSpace: powerList.contentItem
                targetItem: powerList.currentItem
                normalColor: (powerList.currentIndex >= 0 && root.powerActions[powerList.currentIndex].danger)
                    ? Theme.dangerFill : Theme.accent
                z: 0
            }

            delegate: SidebarMorphButton {
                id: powerItem
                required property var modelData
                required property int index
                z: 1
                width: powerList.width
                height: 48
                radius: Theme.radius
                selected: powerList.currentIndex === index
                focused: selected
                selectedOverridesHover: true
                idleColor: "transparent"
                hoverColor: "transparent"
                pressedColor: "transparent"
                selectedColor: "transparent"
                focusColor: "transparent"
                foregroundColor: modelData.danger ? Theme.danger : Theme.fg
                hoverForegroundColor: selected ? (modelData.danger ? "#ffffff" : Theme.onAccentColor)
                    : (modelData.danger ? Theme.danger : Theme.fg)
                pressedForegroundColor: hoverForegroundColor
                focusForegroundColor: selectedForegroundColor
                selectedForegroundColor: modelData.danger ? "#ffffff" : Theme.onAccentColor
                border.width: 0
                hoverScaleDelta: 0.01
                onHoveredChanged: if (hovered) powerList.currentIndex = index
                onClicked: root.triggerPowerIndex(index)

                Row {
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 14
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: powerItem.modelData.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(20, Math.round(Theme.fontSize * 1.5))
                        color: powerItem.foreground
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: powerItem.modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(13, Math.round(Theme.fontSize * 1.05))
                        font.weight: powerItem.selected ? Font.DemiBold : Font.Normal
                        color: powerItem.foreground
                    }
                }
            }
        }
    }

    SidebarControlTooltip {
        id: controlTooltip
        boundsItem: root
        target: root.hoveredTooltipTarget
        text: root.hoveredTooltipText
        active: root.visible && !root.powerMenuOpen && root.hoveredTooltipTarget !== null && root.hoveredTooltipText.length > 0
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        visible: root.errorMessage.length > 0
        text: root.errorMessage
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(9, Theme.fontSize - 3)
        z: 20
    }
}
