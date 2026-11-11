import QtQuick
import Quickshell
import "../../services"
import "../motion" as Motion
import "../taskmanager" as TaskManager
import "../../config/UiCatalog.js" as Catalog

FocusScope {
    id: root
    // Hosts retain this page and its geometry through the closing animation.
    property bool panelOpen: false
    property bool bottomAttached: UiState.hakuMenuStyle === "bottomFlare"
    property bool focusOnOpen: true
    property bool interactionOwned: false
    property string tab: "hakumenu"
    property string mode: UiState.hakuMenuMode
    property string query: UiState.hakuMenuQuery
    readonly property bool taskManagerTab: tab === "taskManager"
    readonly property bool reducedMotion: Quickshell.env("HAKUSPACE_REDUCED_MOTION") === "1"
    readonly property int switchDuration: reducedMotion ? 0 : HAnimation.hakuMenuResizeDuration
    // Load on first visit and retain UI state until the host finishes closing.
    property bool miniLoaded: false
    readonly property alias mini: miniLoader.item
    // Include the root tabs and insets when sizing the embedded dashboard.
    readonly property real miniHeight: tabs.y + tabs.height + Theme.spaceSm + 8 + Theme.hakuMenuBottomPadding
        + (mini ? mini.content.implicitHeight : 0)
    // Carry the General editor's preferred size through the root tab header.
    readonly property real editorHeight: menu.editorHeight > 0
        ? tabs.y + tabs.height - Theme.pad + menu.editorHeight : 0
    signal keyboardActivity()
    signal wallpaperRequested()
    focus: panelOpen && interactionOwned

    // Delegate focus only after the host has claimed keyboard ownership.
    function forcePrimaryFocus() {
        if (!panelOpen || !interactionOwned) return
        if (tab === "taskManager") {
            if (miniLoader.item) miniLoader.item.forcePrimaryFocus()
        } else menu.forceSearchFocus()
    }
    function clearPrimaryFocus() {
        menu.clearSearchFocus()
        if (miniLoader.item) miniLoader.item.clearPrimaryFocus()
    }
    // Retain each page's query and submode across root navigation.
    function syncPage() {
        clearPrimaryFocus()
        if (panelOpen && tab === "taskManager") miniLoaded = true
        if (focusOnOpen || interactionOwned) Qt.callLater(forcePrimaryFocus)
    }
    onTabChanged: syncPage()
    onPanelOpenChanged: syncPage()
    onInteractionOwnedChanged: {
        if (interactionOwned) Qt.callLater(forcePrimaryFocus)
        else clearPrimaryFocus()
    }
    Component.onCompleted: syncPage()
    Keys.priority: Keys.AfterItem
    Keys.onPressed: event => {
        keyboardActivity()
        if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
            UiState.setHakuPanelTab(taskManagerTab ? "hakumenu" : "taskManager")
            event.accepted = true
        }
    }
    Keys.onEscapePressed: event => {
        UiState.closeHakuMenu()
        event.accepted = true
    }

    // Match root navigation before either page consumes arrow keys in its search.
    Shortcut {
        sequence: "Alt+Left"
        context: Qt.WindowShortcut
        enabled: root.panelOpen && root.interactionOwned
        onActivated: {
            root.keyboardActivity()
            UiState.setHakuPanelTab("hakumenu")
        }
    }
    Shortcut {
        sequence: "Alt+Right"
        context: Qt.WindowShortcut
        enabled: root.panelOpen && root.interactionOwned
        onActivated: {
            root.keyboardActivity()
            UiState.setHakuPanelTab("taskManager")
        }
    }

    Item {
        id: tabs
        objectName: "hakumenu-root-tabs"
        x: Theme.hakuMenuLeftPadding
        y: Theme.hakuMenuTopPadding + (root.bottomAttached ? 8 : 0)
        width: Math.max(0, parent.width - Theme.hakuMenuLeftPadding - Theme.hakuMenuRightPadding)
        height: Theme.fontSize * 2.4 + Theme.gap * 2

        Rectangle {
            id: bottomDivider
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: -8
                leftMargin: Theme.gap
                rightMargin: Theme.gap
            }
            height: 1
            color: Qt.alpha(Theme.fgMuted, 0.25)
        }

        Item {
            id: lane
            anchors.fill: parent
            anchors.leftMargin: Theme.gap
            anchors.rightMargin: Theme.gap
            onWidthChanged: tabSelectionPill.syncTarget(false)

            Motion.SelectionPill {
                id: tabSelectionPill
                coordinateSpace: lane
                targetItem: tabRepeater.count > 0
                    ? (tabRepeater.itemAt(root.taskManagerTab ? 1 : 0) ? tabRepeater.itemAt(root.taskManagerTab ? 1 : 0).indicatorTarget : null)
                    : null
                duration: root.reducedMotion ? 0 : HAnimation.fast
                trailFactor: 1.15
                fadeDuration: root.reducedMotion ? 0 : HAnimation.fast
                curve: HAnimation.moduleCurve
            }
            Repeater {
                id: tabRepeater
                // Menu: Haku Menu, Performance: Task Manager
                model: ["Menu", "Performance"]
                Motion.MorphButton {
                    id: tabButton
                    required property string modelData
                    required property int index
                    readonly property alias indicatorTarget: underlineAnchor
                    x: index * (width + Theme.gap)
                    width: Math.max(0, (lane.width - Theme.gap) / 2)
                    height: lane.height + 8
                    radius: Theme.radius
                    selected: root.taskManagerTab === (index === 1)
                    idleColor: "transparent"
                    hoverColor: "transparent"
                    pressedColor: "transparent"
                    selectedColor: "transparent"
                    hoverScaleDelta: 0
                    pressScaleDelta: 0
                    activeFocusOnTab: true
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData
                    Accessible.selected: selected
                    onClicked: {
                        root.keyboardActivity()
                        UiState.setHakuPanelTab(index === 0 ? "hakumenu" : "taskManager")
                        root.forcePrimaryFocus()
                    }
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()

                    Item {
                        id: underlineAnchor
                        readonly property real radius: 1.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: Math.max(48, Math.ceil(tabLabel.implicitWidth) + Theme.spaceMd)
                        height: 2.5
                    }

                    // Fit stacked labels inside the existing tab height above the underline.
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -4
                        width: parent.width
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: font.pixelSize
                            text: tabButton.index === 0 ? Catalog.taskManagerIcons.menu : Catalog.taskManagerIcons.overview
                            color: tabButton.selected ? Theme.accent : Theme.fgMuted
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Math.round(Theme.fontSize * 1.7)
                            verticalAlignment: Text.AlignVCenter
                            Accessible.ignored: true
                        }
                        Text {
                            id: tabLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, implicitWidth)
                            height: font.pixelSize + 2
                            text: tabButton.modelData
                            color: tabButton.selected ? Theme.accent : Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            font.weight: tabButton.selected ? Font.Medium : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    HakuMenuContent {
        id: menu
        anchors { top: tabs.bottom; topMargin: -Theme.pad; left: parent.left; right: parent.right; bottom: parent.bottom }
        panelOpen: root.panelOpen && !root.taskManagerTab
        focusOnOpen: false
        mode: root.mode
        query: root.query
        enabled: panelOpen
        opacity: root.taskManagerTab ? 0 : 1
        visible: opacity > 0
        onKeyboardActivity: root.keyboardActivity()
        onWallpaperRequested: root.wallpaperRequested()
        Behavior on opacity { NumberAnimation { duration: root.switchDuration; easing.bezierCurve: HAnimation.hakuMenuResizeCurve } }
    }

    Loader {
        id: miniLoader
        anchors {
            top: tabs.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Theme.hakuMenuLeftPadding
            rightMargin: Theme.hakuMenuRightPadding
            bottomMargin: Theme.hakuMenuBottomPadding
            topMargin: Theme.spaceSm + 8
        }
        active: root.miniLoaded
        enabled: root.panelOpen && root.taskManagerTab
        opacity: root.taskManagerTab ? 1 : 0
        visible: opacity > 0
        onLoaded: if (root.focusOnOpen) root.forcePrimaryFocus()
        Behavior on opacity { NumberAnimation { duration: root.switchDuration; easing.bezierCurve: HAnimation.hakuMenuResizeCurve } }
        sourceComponent: TaskManager.TaskManagerMini {
            active: root.panelOpen && root.taskManagerTab
            interactionOwned: root.interactionOwned
            reducedMotion: root.reducedMotion
        }
    }
}
