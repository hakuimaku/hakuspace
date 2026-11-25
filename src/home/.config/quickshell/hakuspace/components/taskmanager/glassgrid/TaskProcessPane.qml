import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../services"
import "../../sidebar" as Sidebar
import "../../motion" as HMotion
import "../TaskManagerLogic.js" as Logic
import "TaskManagerMotion.js" as Motion

Rectangle {
    id: root
    property var processes: []
    property string statusError: ""
    property bool warmingUp: false
    property string actionError: ""
    property string actionStatus: ""
    property bool actionBusy: false
    property string query: ""
    property string sortKey: "cpu"
    property bool descending: true
    readonly property var pinnedKeys: TaskManagerPins.pinnedKeys
    readonly property var rows: Logic.processRows(root.processes, root.query, root.sortKey, root.descending, root.pinnedKeys)
    property string selectedKey: ""
    readonly property var selectedProcess: root.processes.find(function(row) { return row.key === root.selectedKey }) || null
    property bool detailsOpen: false
    property string killKey: ""
    readonly property bool killConfirmActive: !!root.killKey && !!root.selectedProcess && root.killKey === root.selectedKey
    readonly property int selectedIndex: root.rows.findIndex(function(row) { return row.key === root.selectedKey })
    property bool interactionOwned: false
    property bool reducedMotion: false

    property real detailsFoldProgress: 0.0
    property real confirmationProgress: 0.0
    property real actionMorphProgress: 1.0

    function _syncDetailsFold() {
        detailsFoldAnim.stop()
        var target = (root.detailsOpen && !!root.selectedProcess) ? 1.0 : 0.0
        var dur = Motion.reversibleDuration(HAnimation.taskDetailsFoldDuration, root.detailsFoldProgress, target, root.reducedMotion)
        if (dur <= 0) {
            root.detailsFoldProgress = target
        } else {
            detailsFoldAnim.to = target
            detailsFoldAnim.duration = dur
            detailsFoldAnim.start()
        }
    }

    function _syncConfirmationMorph() {
        confirmationAnim.stop()
        actionMorphAnim.stop()
        var target = root.killConfirmActive ? 1.0 : 0.0
        if (root.reducedMotion) {
            root.confirmationProgress = target
            root.actionMorphProgress = 1.0
        } else {
            var dur = Motion.reversibleDuration(HAnimation.taskConfirmationMorphDuration, root.confirmationProgress, target, false)
            if (dur <= 0) {
                root.confirmationProgress = target
            } else {
                confirmationAnim.to = target
                confirmationAnim.duration = dur
                confirmationAnim.start()
            }
            root.actionMorphProgress = 0.0
            actionMorphAnim.duration = HAnimation.taskConfirmationMorphDuration
            actionMorphAnim.start()
        }
    }

    onDetailsOpenChanged: _syncDetailsFold()
    onSelectedProcessChanged: _syncDetailsFold()
    onKillConfirmActiveChanged: _syncConfirmationMorph()

    NumberAnimation {
        id: detailsFoldAnim
        target: root
        property: "detailsFoldProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.taskDetailsFoldCurve
    }
    NumberAnimation {
        id: confirmationAnim
        target: root
        property: "confirmationProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.taskConfirmationMorphCurve
    }
    NumberAnimation {
        id: actionMorphAnim
        target: root
        property: "actionMorphProgress"
        to: 1.0
        duration: HAnimation.taskConfirmationMorphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.taskConfirmationMorphCurve
    }

    signal closeRequested()
    signal signalRequested(var process, string signalName)

    objectName: "taskProcessPane"
    radius: Theme.largeRadius
    border.width: 0
    color: Theme.isLight ? Theme.surfaceSubtle(1.04) : Theme.surfaceSubtle(1.22)
    clip: true

    onQueryChanged: if (search.text !== root.query) search.text = root.query
    onSelectedIndexChanged: Qt.callLater(root.syncSelection)
    onRowsChanged: Qt.callLater(root.syncSelection)
    onProcessesChanged: {
        if (root.selectedKey && !(root.processes || []).some(function(row) { return row.key === root.selectedKey })) {
            root.selectedKey = ""
            root.killKey = ""
            root.detailsOpen = false
        }
    }

    function setDetailsFoldProgress(value) {
        detailsFoldAnim.stop()
        root.detailsFoldProgress = Motion.clamp01(value)
    }

    function setConfirmationProgress(value) {
        confirmationAnim.stop()
        actionMorphAnim.stop()
        var p = Motion.clamp01(value)
        root.confirmationProgress = p
        root.actionMorphProgress = root.killConfirmActive ? p : 1.0
    }

    function forceFocus() {
        if (!search.activeFocus) table.forceActiveFocus()
    }

    function focusSearch() {
        search.forceActiveFocus()
    }

    function moveSelection(delta) {
        if (!root.rows.length) return
        var index = Math.max(0, Math.min(root.rows.length - 1, root.selectedIndex < 0 ? 0 : root.selectedIndex + delta))
        root.selectedKey = root.rows[index].key
        root.killKey = ""
        table.positionViewAtIndex(index, ListView.Contain)
    }

    // ListView may adjust its index during keyed model moves; restore the selected process afterward.
    function syncSelection() {
        if (root && table) table.currentIndex = root.selectedIndex
    }

    function handleEscape() {
        if (root.killKey) root.killKey = ""
        else if (search.activeFocus || root.query) {
            search.text = ""
            root.query = ""
            table.forceActiveFocus()
        } else if (root.detailsOpen) root.detailsOpen = false
        else root.closeRequested()
    }

    function handleKey(event) {
        if (!root.interactionOwned) return
        if (event.key === Qt.Key_Escape) handleEscape()
        else if ((event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))
                 || (event.key === Qt.Key_Slash && !search.activeFocus)) search.forceActiveFocus()
        else if (event.key === Qt.Key_Down && !search.activeFocus) moveSelection(1)
        else if (event.key === Qt.Key_Up && !search.activeFocus) moveSelection(-1)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                 && root.selectedProcess && !search.activeFocus && table.activeFocus) {
            root.detailsOpen = !root.detailsOpen
        } else return
        event.accepted = true
    }

    function toggleSort(colKey) {
        if (root.sortKey === colKey) {
            root.descending = !root.descending
        } else {
            root.sortKey = colKey
            root.descending = colKey !== "name"
        }
    }

    function cycleRefreshInterval() {
        var cur = (typeof TaskManagerService.intervalMs === "number" && Number.isFinite(TaskManagerService.intervalMs))
            ? TaskManagerService.intervalMs : 2000
        if (cur < 900) TaskManagerService.setIntervalMs(1000)
        else if (cur < 1900) TaskManagerService.setIntervalMs(2000)
        else TaskManagerService.setIntervalMs(500)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.cardPadding
        spacing: Theme.spaceMd

        // Minimal toolbar: Search pill + Refresh interval pill.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            TextField {
                id: search
                ContextMenu.menu: null
                objectName: "taskManagerSearch"
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.preferredHeight: Theme.comfortableControlHeight
                placeholderText: "Search process or PID… (Ctrl+F)"
                color: Theme.fg
                placeholderTextColor: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                leftPadding: Theme.spaceLg
                rightPadding: Theme.spaceLg
                selectByMouse: true
                Accessible.name: "Search processes"
                onTextChanged: root.query = text

                background: Rectangle {
                    radius: height / 2
                    border.width: 0
                    color: search.activeFocus ? Theme.hoverMuted : Theme.surface
                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: HAnimation.fast }
                    }
                    Rectangle {
                        objectName: "taskManagerSearchRail"
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: search.activeFocus ? Math.min(36, parent.width * 0.25) : 0
                        height: 2
                        radius: 1
                        border.width: 0
                        color: Theme.accent
                        Behavior on width {
                            enabled: !root.reducedMotion
                            NumberAnimation {
                                duration: HAnimation.taskBarFillDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: HAnimation.moduleCurve
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: intervalPill
                objectName: "taskManagerIntervalPill"
                readonly property int effectiveIntervalMs: (typeof TaskManagerService.intervalMs === "number" && Number.isFinite(TaskManagerService.intervalMs))
                    ? TaskManagerService.intervalMs : 2000
                readonly property string labelText: effectiveIntervalMs >= 1000
                    ? (effectiveIntervalMs / 1000).toFixed(1) + "s"
                    : effectiveIntervalMs + "ms"

                Layout.preferredWidth: Math.max(72, Math.round(Theme.fontSize * 5.2))
                Layout.preferredHeight: Theme.comfortableControlHeight
                radius: height / 2
                border.width: 0
                color: intervalMouse.containsMouse || intervalPill.activeFocus ? Theme.hoverMuted : Theme.surface
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Refresh interval " + labelText
                Keys.onReturnPressed: event => { root.cycleRefreshInterval(); event.accepted = true }
                Keys.onEnterPressed: event => { root.cycleRefreshInterval(); event.accepted = true }
                Keys.onSpacePressed: event => { root.cycleRefreshInterval(); event.accepted = true }

                Behavior on color {
                    enabled: !root.reducedMotion
                    ColorAnimation { duration: HAnimation.fast }
                }

                Label {
                    anchors.centerIn: parent
                    text: intervalPill.labelText
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    id: intervalMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.cycleRefreshInterval()
                    onWheel: wheel => {
                        var current = intervalPill.effectiveIntervalMs
                        if (wheel.angleDelta.y > 0) {
                            TaskManagerService.setIntervalMs(Math.max(100, current - 100))
                        } else if (wheel.angleDelta.y < 0) {
                            TaskManagerService.setIntervalMs(Math.min(2000, current + 100))
                        }
                    }
                }
            }
        }

        // Selected process details (read-only metadata; actions remain in Footer).
        Rectangle {
            id: detailsDrawer
            objectName: "taskProcessDetailsDrawer"
            readonly property int targetHeight: Math.min(180, Math.max(118, detailsContent.implicitHeight + Theme.spaceLg))
            readonly property int foldedHeight: Math.round(targetHeight * root.detailsFoldProgress)
            visible: root.detailsFoldProgress > 0 && !!root.selectedProcess
            implicitHeight: foldedHeight
            Layout.fillWidth: true
            Layout.preferredHeight: foldedHeight
            Layout.minimumHeight: foldedHeight
            Layout.maximumHeight: foldedHeight
            radius: Theme.radius
            border.width: 0
            color: Theme.surface
            clip: true

            Item {
                x: 0
                y: 0
                width: detailsDrawer.width
                height: detailsDrawer.targetHeight
                clip: true

                ColumnLayout {
                    id: detailsContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spaceMd
                    spacing: Theme.spaceSm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm

                        Label {
                            text: (root.selectedProcess && root.selectedProcess.pid !== undefined)
                                ? ("PID " + String(root.selectedProcess.pid)) : ""
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Label {
                            text: "·"
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: (root.selectedProcess && root.selectedProcess.name) ? String(root.selectedProcess.name) : ""
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fontSize - 1
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            spacing: 2

                            RowLayout {
                                spacing: Theme.spaceXs
                                Layout.fillWidth: true
                                Label { text: "CPU:"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                                Label {
                                    Layout.fillWidth: true
                                    text: root.selectedProcess ? Logic.metric(root.selectedProcess.cpuTotalPercent, "%") : "0.0%"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }
                            RowLayout {
                                spacing: Theme.spaceXs
                                Layout.fillWidth: true
                                Label { text: "Threads:"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                                Label {
                                    Layout.fillWidth: true
                                    text: (root.selectedProcess && root.selectedProcess.threads !== undefined) ? String(root.selectedProcess.threads) : "—"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            spacing: 2

                            RowLayout {
                                spacing: Theme.spaceXs
                                Layout.fillWidth: true
                                Label { text: "Memory:"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                                Label {
                                    Layout.fillWidth: true
                                    text: (root.selectedProcess && root.selectedProcess.rss !== undefined)
                                        ? Logic.bytes(root.selectedProcess.rss) + " (" + Logic.metric(root.selectedProcess.memoryPercent, "%") + ")"
                                        : "0 B"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }
                            RowLayout {
                                spacing: Theme.spaceXs
                                Layout.fillWidth: true
                                Label { text: "Runtime:"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                                Label {
                                    Layout.fillWidth: true
                                    text: (root.selectedProcess && root.selectedProcess.runtimeSeconds !== undefined)
                                        ? Logic.metric(root.selectedProcess.runtimeSeconds, "s", 0) : "—"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            spacing: 2

                            RowLayout {
                                spacing: Theme.spaceXs
                                Layout.fillWidth: true
                                Label { text: "State:"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                                Label {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!root.selectedProcess || !root.selectedProcess.state) return "—"
                                        var st = root.selectedProcess.state
                                        if (st === "R") return "Running"
                                        if (st === "S") return "Sleeping"
                                        return String(st)
                                    }
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }
                            RowLayout {
                                spacing: Theme.spaceXs
                                Layout.fillWidth: true
                                Label { text: "User:"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                                Label {
                                    Layout.fillWidth: true
                                    text: {
                                        var u = (root.selectedProcess && root.selectedProcess.user) ? String(root.selectedProcess.user) : "—"
                                        var ppid = (root.selectedProcess && root.selectedProcess.ppid !== undefined) ? (" · PPID " + root.selectedProcess.ppid) : ""
                                        return u + ppid
                                    }
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm

                        Label {
                            text: "CMD"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Label {
                            id: detailsLabel
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            maximumLineCount: 1
                            elide: Text.ElideMiddle
                            text: (root.selectedProcess && (root.selectedProcess.cmdline || root.selectedProcess.name))
                                ? String(root.selectedProcess.cmdline || root.selectedProcess.name)
                                : ""
                        }
                    }
                }
            }
        }

        // Clickable 3-column table header.
        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(28, Math.round(Theme.fontSize * 2.0))

            TaskProcessRow {
                id: headerRow
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd + table.rowScaleInset
                anchors.rightMargin: Theme.spaceMd + table.rowScaleInset + processScrollBar.reservedGutter
                header: true
                sortKey: root.sortKey
                descending: root.descending
                onSortRequested: key => root.toggleSort(key)
            }
        }

        ScriptModel {
            id: processModel
            values: root.rows
            objectProp: "key"
            comparisonMode: ObjectComparison.Structure
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40
            clip: true

            ListView {
                id: table
                objectName: "taskManagerProcesses"
                readonly property int rowScaleInset: Math.max(18, Math.ceil(width * 0.028))
                anchors.fill: parent
                topMargin: 3
                bottomMargin: 3
                model: processModel
                clip: true
                focus: true
                spacing: 2
                keyNavigationEnabled: false
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => root.handleKey(event)
                ScrollBar.vertical: HMotion.HScrollBar {
                    id: processScrollBar
                    policy: ScrollBar.AsNeeded
                }

                // Scroll the single pill with the content instead of animating viewport offsets.
                HMotion.SelectionPill {
                    id: selectionPill
                    objectName: "taskProcessSelectionPill"
                    readonly property bool hoveredTarget: !!(table.currentItem && table.currentItem.rowHovered)
                    parent: table.contentItem
                    z: -1
                    targetItem: table.currentItem ? table.currentItem.visualItem : null
                    coordinateSpace: table.contentItem
                    shown: root.selectedIndex >= 0 && targetItem !== null
                    visible: shown
                    scale: (hoveredTarget && !root.reducedMotion) ? 1.05 : 1.0
                    duration: root.reducedMotion ? 0 : HAnimation.spatial
                    fadeDuration: root.reducedMotion ? 0 : HAnimation.buttonReleaseDuration
                    onDurationChanged: if (duration === 0) snap()
                    onNormalColorChanged: syncTarget(root.reducedMotion)

                    Behavior on scale {
                        enabled: !root.reducedMotion
                        NumberAnimation {
                            duration: selectionPill.hoveredTarget ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: selectionPill.hoveredTarget ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                        }
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: root.selectedKey === modelData.key
                    readonly property bool rowHovered: rowHover.hovered
                    readonly property alias visualItem: rowSurface
                    width: table.width
                    height: Math.max(38, Math.round(Theme.fontSize * 2.7))
                    z: rowHover.hovered ? 2 : 0

                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.pid + " " + modelData.name + " " + Logic.metric(modelData.cpuTotalPercent, "%")

                    Rectangle {
                        id: rowSurface
                        x: table.rowScaleInset
                        y: 0
                        width: Math.max(1, row.width - processScrollBar.reservedGutter - table.rowScaleInset * 2)
                        height: row.height
                        radius: Theme.radius
                        border.width: 0
                        color: "transparent"
                        scale: (rowHover.hovered && !root.reducedMotion) ? 1.05 : 1.0

                        Behavior on scale {
                            enabled: !root.reducedMotion
                            NumberAnimation {
                                duration: rowHover.hovered ? HAnimation.buttonHoverDuration : HAnimation.buttonReleaseDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: rowHover.hovered ? HAnimation.buttonHoverCurve : HAnimation.buttonReleaseCurve
                            }
                        }

                        HoverHandler { id: rowHover }

                        TaskProcessRow {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceMd
                            anchors.rightMargin: Theme.spaceMd
                            process: row.modelData
                            selected: row.isSelected
                            isPinned: (root.pinnedKeys || []).includes(row.modelData.key)
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    TaskManagerPins.toggle(row.modelData)
                                } else {
                                    root.selectedKey = row.modelData.key
                                    root.killKey = ""
                                    table.forceActiveFocus()
                                }
                            }
                            onDoubleClicked: root.detailsOpen = !root.detailsOpen
                        }
                    }
                }
            }
        }

        // Single footer action row (Details, Pin/Unpin, Terminate, Force kill + kill confirm).
        Rectangle {
            id: footerZone
            objectName: "taskProcessFooterZone"
            Layout.fillWidth: true
            implicitHeight: Math.max(Theme.controlHeight + 6, 42)
            radius: Theme.radius
            border.width: 0
            color: root.killConfirmActive ? Qt.alpha(Theme.dangerFill, Theme.isLight ? 0.14 : 0.18) : "transparent"
            clip: true

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.taskConfirmationMorphDuration }
            }

            Rectangle {
                objectName: "taskProcessKillRail"
                visible: root.confirmationProgress > 0
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.round((parent.height - 10) * root.confirmationProgress)
                radius: 1.5
                border.width: 0
                color: Theme.danger
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.killConfirmActive ? Theme.spaceMd : Theme.spaceXs
                anchors.rightMargin: root.killConfirmActive ? Theme.spaceSm : 0
                spacing: Theme.spaceSm

                Label {
                    objectName: "taskManagerFooterStatus"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 40
                    color: root.killConfirmActive || root.actionError || root.statusError ? Theme.danger : Theme.fgMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                    text: root.killConfirmActive
                        ? "Force kill PID " + root.selectedProcess.pid + "? Unsaved work may be lost."
                        : (root.actionError || root.statusError || TaskManagerPins.error || root.actionStatus
                            || (root.selectedProcess
                                ? root.selectedProcess.pid + " · " + root.selectedProcess.name
                                : (root.warmingUp ? "Warming up…" : "Select a process")))
                }

                Item {
                    id: actionClusterViewport
                    objectName: "taskProcessActionViewport"
                    readonly property int fullClusterWidth: Math.max(1, actionClusterRow.implicitWidth)
                    readonly property int clippedWidth: Math.max(1, Math.round(fullClusterWidth * root.actionMorphProgress))
                    Layout.preferredWidth: fullClusterWidth
                    Layout.preferredHeight: Math.max(Theme.controlHeight, 36)
                    clip: true

                    Item {
                        id: actionClusterClip
                        x: actionClusterViewport.fullClusterWidth - width
                        y: 0
                        width: actionClusterViewport.clippedWidth
                        height: parent.height
                        clip: true

                        Row {
                            id: actionClusterRow
                            x: -(actionClusterClip.x)
                            y: 0
                            height: parent.height
                            spacing: Theme.spaceSm

                            Repeater {
                                model: root.killConfirmActive
                                    ? ["Cancel", "Confirm kill"]
                                    : ["Details", ((root.pinnedKeys || []).includes(root.selectedKey) ? "Unpin" : "Pin"), "Terminate", "Force kill"]
                                Sidebar.SidebarMorphButton {
                                    required property string modelData
                                    readonly property bool isDangerConfirm: modelData === "Confirm kill"
                                    readonly property bool isPinAction: modelData === "Pin" || modelData === "Unpin"
                                    width: Math.max(68, Math.round(Theme.fontSize * (isDangerConfirm ? 7.8 : (isPinAction ? 5.2 : 6.6))))
                                    height: Math.max(Theme.controlHeight, 36)
                                    radius: height / 2
                                    border.width: 0
                                    hoverScaleDelta: 0
                                    pressScaleDelta: 0
                                    fontSize: Theme.fontSize - 1
                                    text: modelData
                                    enabled: !!root.selectedProcess && !root.actionBusy
                                    activeFocusOnTab: true
                                    focused: activeFocus
                                    idleColor: isDangerConfirm
                                        ? Qt.alpha(Theme.dangerFill, Theme.isLight ? 0.18 : 0.24)
                                        : Theme.surface
                                    foregroundColor: isDangerConfirm
                                        ? Theme.danger
                                        : (isPinAction && (root.pinnedKeys || []).includes(root.selectedKey) ? Theme.accent : Theme.fg)
                                    hoverColor: isDangerConfirm ? Theme.dangerFill : Theme.hoverMuted
                                    hoverForegroundColor: isDangerConfirm ? Theme.onAccentColor : Theme.accent
                                    focusColor: isDangerConfirm ? Theme.dangerFill : Theme.hoverMuted
                                    focusForegroundColor: isDangerConfirm ? Theme.onAccentColor : Theme.accent
                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData
                                    onClicked: {
                                        if (modelData === "Details") root.detailsOpen = !root.detailsOpen
                                        else if (modelData === "Pin" || modelData === "Unpin") TaskManagerPins.toggle(root.selectedProcess)
                                        else if (modelData === "Terminate") root.signalRequested(root.selectedProcess, "TERM")
                                        else if (modelData === "Force kill") root.killKey = root.selectedKey
                                        else if (modelData === "Confirm kill") {
                                            if (root.killKey === root.selectedKey) root.signalRequested(root.selectedProcess, "KILL")
                                            root.killKey = ""
                                        } else root.killKey = ""
                                    }
                                    Keys.onReturnPressed: clicked()
                                    Keys.onSpacePressed: clicked()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
