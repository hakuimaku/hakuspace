import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    readonly property var selectedProcess: root.processes.find(row => row.key === root.selectedKey) || null
    property bool detailsOpen: false
    property string killKey: ""
    readonly property bool killConfirmActive: !!root.killKey && !!root.selectedProcess && root.killKey === root.selectedKey
    readonly property int selectedIndex: root.rows.findIndex(row => row.key === root.selectedKey)
    property bool interactionOwned: false
    property var visuals
    property bool compact: false
    property bool ultraCompact: false
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
    radius: Theme.radius
    border.width: 0
    color: visuals ? visuals.paneSurface : Theme.surface
    clip: true

    onQueryChanged: if (search.text !== root.query) search.text = root.query
    onSelectedIndexChanged: Qt.callLater(root.syncSelection)
    onRowsChanged: Qt.callLater(root.syncSelection)
    onProcessesChanged: {
        if (root.selectedKey && !(root.processes || []).some(row => row.key === root.selectedKey)) {
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: visuals.processPanePadding(root.height, root.width * 1.5)
        spacing: root.ultraCompact ? 4 : 8

        RowLayout {
            Layout.fillWidth: true
            spacing: root.compact ? 5 : 8

            Label {
                text: "Processes"
                color: visuals.primaryFg
                font.pixelSize: visuals.sectionTitleSize
            }

            Label {
                Layout.maximumWidth: 140
                color: root.statusError ? Theme.danger : Theme.fgMuted
                font.pixelSize: visuals.metaFontSize
                elide: Text.ElideRight
                text: "· " + (root.statusError || (root.warmingUp ? "Warming up…" : root.processes.length + " total"))
            }

            Item { Layout.preferredWidth: root.compact ? 2 : 4 }

            TextField {
                id: search
                objectName: "taskManagerSearch"
                Layout.fillWidth: true
                Layout.minimumWidth: 70
                Layout.preferredHeight: root.ultraCompact ? 26 : 30
                placeholderText: root.compact ? "Search…" : "Search process, PID… (Ctrl+F)"
                color: visuals.primaryFg
                placeholderTextColor: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: visuals.bodyFontSize
                leftPadding: 10
                rightPadding: 10
                selectByMouse: true
                Accessible.name: "Search processes"
                onTextChanged: root.query = text

                background: Rectangle {
                    radius: 6
                    border.width: 0
                    color: search.activeFocus ? visuals.controlFocusSurface : visuals.controlSurface
                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: HAnimation.fast }
                    }
                    Rectangle {
                        objectName: "taskManagerSearchRail"
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: search.activeFocus ? Math.min(28, parent.width * 0.25) : 0
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

            TaskDropdown {
                id: sortCombo
                objectName: "taskManagerSortCombo"
                Layout.preferredWidth: root.compact ? 80 : 96
                Layout.preferredHeight: root.ultraCompact ? 26 : 30
                visuals: root.visuals
                reducedMotion: root.reducedMotion
                model: ["CPU", "Memory", "PID", "Name"]
                currentIndex: Math.max(0, ["cpu", "memory", "pid", "name"].indexOf(root.sortKey))
                Accessible.name: "Sort processes"
                onActivated: root.sortKey = ["cpu", "memory", "pid", "name"][currentIndex]
            }

            Sidebar.SidebarMorphButton {
                objectName: "taskProcessReverseSortButton"
                Layout.preferredWidth: root.compact ? 26 : 28
                Layout.preferredHeight: root.ultraCompact ? 26 : 30
                radius: 6
                border.width: 0
                hoverScaleDelta: 0
                pressScaleDelta: 0
                fontSize: visuals.bodyFontSize
                idleColor: visuals.controlSurface
                foregroundColor: Theme.fgMuted
                hoverColor: visuals.hoverSurface
                hoverForegroundColor: visuals.primaryFg
                focusColor: visuals.controlFocusSurface
                focusForegroundColor: Theme.accent
                text: root.descending ? "↓" : "↑"
                activeFocusOnTab: true
                focused: activeFocus
                Accessible.role: Accessible.Button
                Accessible.name: "Reverse sort order"
                onClicked: root.descending = !root.descending
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }

            // Refresh interval controls.
            RowLayout {
                spacing: 2
                Layout.preferredHeight: root.ultraCompact ? 26 : 30

                Sidebar.SidebarMorphButton {
                    Layout.preferredWidth: root.compact ? 20 : 24
                    Layout.preferredHeight: root.ultraCompact ? 24 : 26
                    radius: 5
                    border.width: 0
                    hoverScaleDelta: 0
                    pressScaleDelta: 0
                    fontSize: visuals.metaFontSize
                    text: "−"
                    idleColor: visuals.controlSurface
                    foregroundColor: visuals.primaryFg
                    hoverColor: visuals.hoverSurface
                    hoverForegroundColor: Theme.accent
                    focusColor: visuals.controlFocusSurface
                    focusForegroundColor: Theme.accent
                    activeFocusOnTab: false
                    Accessible.name: "Decrease interval"
                    onClicked: TaskManagerService.setIntervalMs(Math.max(100, TaskManagerService.intervalMs - 100))
                }

                Rectangle {
                    Layout.preferredWidth: root.compact ? 48 : 56
                    Layout.preferredHeight: root.ultraCompact ? 24 : 26
                    radius: 5
                    border.width: 0
                    color: visuals.controlSurface

                    readonly property int effectiveIntervalMs: (typeof TaskManagerService.intervalMs === "number" && Number.isFinite(TaskManagerService.intervalMs)) ? TaskManagerService.intervalMs : 1000

                    Label {
                        anchors.centerIn: parent
                        text: (parent.effectiveIntervalMs >= 1000)
                            ? (parent.effectiveIntervalMs / 1000).toFixed(1) + "s"
                            : parent.effectiveIntervalMs + "ms"
                        color: Theme.accent
                        font.bold: true
                        font.pixelSize: visuals.metaFontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onWheel: wheel => {
                            var current = parent.effectiveIntervalMs
                            if (wheel.angleDelta.y > 0) {
                                TaskManagerService.setIntervalMs(Math.max(100, current - 100))
                            } else if (wheel.angleDelta.y < 0) {
                                TaskManagerService.setIntervalMs(Math.min(2000, current + 100))
                            }
                        }
                    }
                }

                Sidebar.SidebarMorphButton {
                    Layout.preferredWidth: root.compact ? 20 : 24
                    Layout.preferredHeight: root.ultraCompact ? 24 : 26
                    radius: 5
                    border.width: 0
                    hoverScaleDelta: 0
                    pressScaleDelta: 0
                    fontSize: visuals.metaFontSize
                    text: "+"
                    idleColor: visuals.controlSurface
                    foregroundColor: visuals.primaryFg
                    hoverColor: visuals.hoverSurface
                    hoverForegroundColor: Theme.accent
                    focusColor: visuals.controlFocusSurface
                    focusForegroundColor: Theme.accent
                    activeFocusOnTab: false
                    Accessible.name: "Increase interval"
                    onClicked: TaskManagerService.setIntervalMs(Math.min(2000, TaskManagerService.intervalMs + 100))
                }
            }
        }

        // Selected process details.
        Rectangle {
            id: detailsDrawer
            objectName: "taskProcessDetailsDrawer"
            readonly property bool isWide: width >= 420
            readonly property int targetHeight: Math.min(180, Math.max(126, btopContent.implicitHeight + 16))
            readonly property int foldedHeight: Math.round(targetHeight * root.detailsFoldProgress)
            visible: root.detailsFoldProgress > 0 && !!root.selectedProcess
            implicitHeight: foldedHeight
            Layout.fillWidth: true
            Layout.preferredHeight: foldedHeight
            Layout.minimumHeight: foldedHeight
            Layout.maximumHeight: foldedHeight
            radius: 6
            border.width: 0
            color: visuals ? visuals.wellSurface : Theme.surface
            clip: true

            Item {
                id: btopContainer
                x: 0
                y: 0
                width: detailsDrawer.width
                height: detailsDrawer.targetHeight
                clip: true

                ColumnLayout {
                    id: btopContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 5

                            Label {
                                text: (root.selectedProcess && root.selectedProcess.pid !== undefined) ? String(root.selectedProcess.pid) : ""
                                color: Theme.accent
                                font.bold: true
                                font.pixelSize: visuals ? visuals.sectionTitleSize : 13
                                Layout.minimumWidth: 0
                            }

                            Label {
                                text: "·"
                                color: Theme.fgMuted
                                font.pixelSize: visuals ? visuals.metaFontSize : 11
                            }

                            Label {
                                text: (root.selectedProcess && root.selectedProcess.name)
                                    ? (visuals ? visuals.truncateEnd(root.selectedProcess.name, 32) : String(root.selectedProcess.name))
                                    : ""
                                color: visuals ? visuals.primaryFg : Theme.fg
                                font.bold: true
                                font.pixelSize: visuals ? visuals.sectionTitleSize : 13
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            visible: detailsDrawer.isWide
                            spacing: 6
                            Layout.preferredWidth: implicitWidth

                            TaskActionButton {
                                text: "terminate"
                                compact: root.compact
                                visuals: root.visuals
                                reducedMotion: root.reducedMotion
                                onClicked: if (root.selectedProcess) root.signalRequested(root.selectedProcess, "TERM")
                            }

                            TaskActionButton {
                                text: "kill"
                                danger: true
                                compact: root.compact
                                visuals: root.visuals
                                reducedMotion: root.reducedMotion
                                onClicked: root.killKey = root.selectedKey
                            }

                            TaskActionButton {
                                text: (root.pinnedKeys || []).includes(root.selectedKey) ? "unpin" : "pin"
                                accent: (root.pinnedKeys || []).includes(root.selectedKey)
                                compact: root.compact
                                visuals: root.visuals
                                reducedMotion: root.reducedMotion
                                onClicked: TaskManagerPins.toggle(root.selectedProcess)
                            }

                            TaskActionButton {
                                text: "hide ↵"
                                compact: root.compact
                                visuals: root.visuals
                                reducedMotion: root.reducedMotion
                                onClicked: root.detailsOpen = false
                            }
                        }
                    }

                    RowLayout {
                        visible: !detailsDrawer.isWide
                        Layout.fillWidth: true
                        spacing: 6

                        Item { Layout.fillWidth: true }

                        TaskActionButton {
                            text: "terminate"
                            compact: root.compact
                            visuals: root.visuals
                            reducedMotion: root.reducedMotion
                            onClicked: if (root.selectedProcess) root.signalRequested(root.selectedProcess, "TERM")
                        }

                        TaskActionButton {
                            text: "kill"
                            danger: true
                            compact: root.compact
                            visuals: root.visuals
                            reducedMotion: root.reducedMotion
                            onClicked: root.killKey = root.selectedKey
                        }

                        TaskActionButton {
                            text: (root.pinnedKeys || []).includes(root.selectedKey) ? "unpin" : "pin"
                            accent: (root.pinnedKeys || []).includes(root.selectedKey)
                            compact: root.compact
                            visuals: root.visuals
                            reducedMotion: root.reducedMotion
                            onClicked: TaskManagerPins.toggle(root.selectedProcess)
                        }

                        TaskActionButton {
                            text: "hide ↵"
                            compact: root.compact
                            visuals: root.visuals
                            reducedMotion: root.reducedMotion
                            onClicked: root.detailsOpen = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        // CPU and thread count.
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            spacing: 2

                            RowLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Label { text: "CPU:"; color: Theme.fgMuted; font.pixelSize: visuals ? visuals.metaFontSize : 11 }
                                Label {
                                    text: root.selectedProcess ? Logic.metric(root.selectedProcess.cpuTotalPercent, "%") : "0.0%"
                                    color: Theme.accent
                                    font.bold: true
                                    font.pixelSize: visuals ? visuals.metaFontSize : 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            RowLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Label { text: "Threads:"; color: Theme.fgMuted; font.pixelSize: visuals ? visuals.metaFontSize : 11 }
                                Label {
                                    text: (root.selectedProcess && root.selectedProcess.threads !== undefined) ? String(root.selectedProcess.threads) : "—"
                                    color: visuals ? visuals.primaryFg : Theme.fg
                                    font.pixelSize: visuals ? visuals.metaFontSize : 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Memory and runtime.
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            spacing: 2

                            RowLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Label { text: "Memory:"; color: Theme.fgMuted; font.pixelSize: visuals ? visuals.metaFontSize : 11 }
                                Label {
                                    text: (root.selectedProcess && root.selectedProcess.rss !== undefined)
                                        ? Logic.bytes(root.selectedProcess.rss) + " (" + Logic.metric(root.selectedProcess.memoryPercent, "%") + ")"
                                        : "0 B"
                                    color: visuals ? visuals.primaryFg : Theme.fg
                                    font.pixelSize: visuals ? visuals.metaFontSize : 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            RowLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Label { text: "Runtime:"; color: Theme.fgMuted; font.pixelSize: visuals ? visuals.metaFontSize : 11 }
                                Label {
                                    text: (root.selectedProcess && root.selectedProcess.runtimeSeconds !== undefined) ? Logic.metric(root.selectedProcess.runtimeSeconds, "s", 0) : "—"
                                    color: visuals ? visuals.primaryFg : Theme.fg
                                    font.pixelSize: visuals ? visuals.metaFontSize : 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // State and process ownership.
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            spacing: 2

                            RowLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Label { text: "State:"; color: Theme.fgMuted; font.pixelSize: visuals ? visuals.metaFontSize : 11 }
                                Label {
                                    text: {
                                        if (!root.selectedProcess || !root.selectedProcess.state) return "—"
                                        var st = root.selectedProcess.state
                                        if (st === "R") return "Running"
                                        if (st === "S") return "Sleeping"
                                        return visuals ? visuals.truncateEnd(st, 16) : String(st)
                                    }
                                    color: visuals ? visuals.primaryFg : Theme.fg
                                    font.pixelSize: visuals ? visuals.metaFontSize : 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            RowLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                Label { text: "User:"; color: Theme.fgMuted; font.pixelSize: visuals ? visuals.metaFontSize : 11 }
                                Label {
                                    text: (root.selectedProcess && root.selectedProcess.user)
                                        ? (visuals ? visuals.truncateEnd(root.selectedProcess.user, 18) : String(root.selectedProcess.user))
                                        : "—"
                                    color: visuals ? visuals.primaryFg : Theme.fg
                                    font.pixelSize: visuals ? visuals.metaFontSize : 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    visible: (root.selectedProcess && root.selectedProcess.ppid !== undefined)
                                    text: "· PPID " + (root.selectedProcess ? root.selectedProcess.ppid : "")
                                    color: Theme.fgMuted
                                    font.pixelSize: visuals ? visuals.metaFontSize : 11
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            text: "CMD"
                            color: Theme.accent
                            font.bold: true
                            font.pixelSize: visuals ? visuals.metaFontSize - 1 : 10
                            Layout.minimumWidth: 0
                        }

                        Label {
                            id: detailsLabel
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            color: visuals ? visuals.primaryFg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: visuals ? visuals.metaFontSize : 11
                            maximumLineCount: 1
                            elide: Text.ElideMiddle
                            text: (root.selectedProcess && (root.selectedProcess.cmdline || root.selectedProcess.name))
                                ? (visuals ? visuals.truncateMiddle(root.selectedProcess.cmdline || root.selectedProcess.name, 88) : String(root.selectedProcess.cmdline || root.selectedProcess.name))
                                : ""
                        }
                    }
                }
            }
        }

        // Share column geometry between the header and process rows.
        Item {
            Layout.fillWidth: true
            implicitHeight: root.ultraCompact ? 18 : 22

            TaskProcessRow {
                id: headerRow
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                header: true
                visuals: root.visuals
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
                anchors.fill: parent
                model: processModel
                clip: true
                focus: true
                spacing: 1
                keyNavigationEnabled: false
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => root.handleKey(event)
                ScrollBar.vertical: ScrollBar {}

                // Scroll the single pill with the content instead of animating viewport offsets.
                HMotion.SelectionPill {
                    objectName: "taskProcessSelectionPill"
                    parent: table.contentItem
                    z: -1
                    targetItem: table.currentItem
                    coordinateSpace: table.contentItem
                    shown: root.selectedIndex >= 0 && targetItem !== null
                    visible: shown
                    duration: root.reducedMotion ? 0 : HAnimation.spatial
                    fadeDuration: root.reducedMotion ? 0 : HAnimation.buttonReleaseDuration
                    onDurationChanged: if (duration === 0) snap()
                    onNormalColorChanged: syncTarget(root.reducedMotion)
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: root.selectedKey === modelData.key
                    width: table.width
                    height: root.ultraCompact ? 25 : 28
                    radius: Theme.radius
                    border.width: 0
                    color: !isSelected && rowHover.hovered ? visuals.rowHoverSurface : "transparent"

                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.pid + " " + modelData.name + " " + Logic.metric(modelData.cpuTotalPercent, "%")

                    HoverHandler { id: rowHover }

                    TaskProcessRow {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        process: row.modelData
                        selected: row.isSelected
                        isPinned: (root.pinnedKeys || []).includes(row.modelData.key)
                        visuals: root.visuals
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

        // Keep kill confirmation in the existing action row.
        Rectangle {
            id: footerZone
            objectName: "taskProcessFooterZone"
            Layout.fillWidth: true
            Layout.topMargin: root.ultraCompact ? 1 : 3
            implicitHeight: root.ultraCompact ? 30 : 34
            radius: 6
            border.width: 0
            color: root.killConfirmActive ? visuals.dangerSurface : "transparent"
            clip: true

            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: HAnimation.taskConfirmationMorphDuration }
            }

            Rectangle {
                objectName: "taskProcessKillRail"
                visible: root.confirmationProgress > 0
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.round((parent.height - 8) * root.confirmationProgress)
                radius: 1.5
                border.width: 0
                color: Theme.danger
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.killConfirmActive ? 10 : 4
                anchors.rightMargin: root.killConfirmActive ? 6 : 0
                spacing: root.compact ? 6 : 8

                Label {
                    objectName: "taskManagerFooterStatus"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 40
                    color: root.killConfirmActive || root.actionError ? Theme.danger : Theme.fgMuted
                    font.pixelSize: visuals.metaFontSize
                    elide: Text.ElideRight
                    text: root.killConfirmActive
                        ? "Force kill PID " + root.selectedProcess.pid + "? Unsaved work may be lost."
                        : (root.actionError || TaskManagerPins.error || root.actionStatus
                            || (root.selectedProcess ? root.selectedProcess.pid + " · " + root.selectedProcess.name : "Select a process"))
                }

                Item {
                    id: actionClusterViewport
                    objectName: "taskProcessActionViewport"
                    readonly property int fullClusterWidth: Math.max(1, actionClusterRow.implicitWidth)
                    readonly property int clippedWidth: Math.max(1, Math.round(fullClusterWidth * root.actionMorphProgress))
                    Layout.preferredWidth: fullClusterWidth
                    Layout.preferredHeight: root.ultraCompact ? 24 : 26
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
                            spacing: root.compact ? 5 : 6

                            Repeater {
                                model: root.killConfirmActive
                                    ? ["Cancel", "Confirm kill"]
                                    : ["Details", ((root.pinnedKeys || []).includes(root.selectedKey) ? "Unpin" : "Pin"), "Terminate", "Force kill"]
                                Sidebar.SidebarMorphButton {
                                    required property string modelData
                                    readonly property bool isDangerConfirm: modelData === "Confirm kill"
                                    readonly property bool isPinAction: modelData === "Pin" || modelData === "Unpin"
                                    width: isDangerConfirm
                                        ? (root.compact ? 84 : 92)
                                        : (isPinAction ? (root.compact ? 56 : 64) : (root.compact ? 68 : 76))
                                    height: root.ultraCompact ? 24 : 26
                                    radius: 6
                                    border.width: 0
                                    hoverScaleDelta: 0
                                    pressScaleDelta: 0
                                    fontSize: visuals.tableFontSize
                                    text: modelData
                                    enabled: !!root.selectedProcess && !root.actionBusy
                                    activeFocusOnTab: true
                                    focused: activeFocus
                                    idleColor: isDangerConfirm
                                        ? Qt.alpha(Theme.dangerFill, Theme.isLight ? 0.18 : 0.24)
                                        : visuals.controlSurface
                                    foregroundColor: isDangerConfirm ? Theme.danger : (isPinAction && (root.pinnedKeys || []).includes(root.selectedKey) ? Theme.accent : visuals.primaryFg)
                                    hoverColor: isDangerConfirm ? Theme.dangerFill : visuals.hoverSurface
                                    hoverForegroundColor: isDangerConfirm ? Theme.onAccentColor : Theme.accent
                                    focusColor: isDangerConfirm ? Theme.dangerFill : visuals.controlFocusSurface
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
