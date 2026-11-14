import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../../services"
import "../motion" as Motion

SettingsActionButton {
    id: root
    // The selector and menu reuse Hikai's morph buttons and liquid selection surface.
    required property var options
    required property var value
    property Item shortcutTarget: null
    property bool searchable: false
    property bool loading: false
    property string statusMessage: ""
    property string searchPlaceholder: "Search…"
    readonly property var visibleOptions: searchable
        ? options.filter(option => {
            var q = search.text.trim().toLowerCase()
            return option.label.toLowerCase().includes(q)
                || (option.subtitle && String(option.subtitle).toLowerCase().includes(q))
        })
        : options
    readonly property int selectedIndex: options.findIndex(option => option.value === value)
    readonly property var selectedOption: selectedIndex >= 0 ? options[selectedIndex] : null
    readonly property string currentLabel: selectedOption ? selectedOption.label : searchable && value ? String(value) : "Choose…"
    readonly property string currentSubtitle: selectedOption && selectedOption.subtitle ? String(selectedOption.subtitle) : ""
    readonly property string currentIcon: selectedOption && selectedOption.icon ? String(selectedOption.icon) : ""
    readonly property bool hasSubtitleOptions: options.some(option => !!(option && option.subtitle && String(option.subtitle).length > 0))
    readonly property real optionRowHeight: Theme.comfortableControlHeight
    readonly property real groupLabelHeight: Math.max(16, Theme.fontSize + 4)
    readonly property real firstGroupHeaderHeight: groupLabelHeight + Theme.spaceXs
    readonly property real nextGroupHeaderHeight: Theme.spaceSm + 1 + Theme.spaceSm + groupLabelHeight + Theme.spaceXs
    readonly property real groupHeadersHeight: {
        var h = 0
        var prev = ""
        for (var i = 0; i < visibleOptions.length; i++) {
            var g = visibleOptions[i] && visibleOptions[i].group ? String(visibleOptions[i].group) : ""
            if (!g || g === prev) continue
            h += prev.length > 0 ? nextGroupHeaderHeight : firstGroupHeaderHeight
            prev = g
        }
        return h
    }
    readonly property real maxPopupHeight: root.Window.window ? Math.min(320, Math.max(200, root.Window.window.height - Theme.spaceMd * 2)) : 320
    readonly property string previewValue: menu.opened && choices.currentIndex >= 0 && choices.currentIndex < visibleOptions.length
        ? String(visibleOptions[choices.currentIndex].value)
        : String(value !== undefined && value !== null ? value : "")
    readonly property bool settingsNavOwnsVertical: menu.visible
    readonly property bool settingsNavOwnsHorizontal: menu.visible
    readonly property bool popupOpen: menu.visible
    signal chosen(var value)
    signal refreshRequested()
    onVisibleOptionsChanged: if (menu.visible) syncChoices()
    implicitHeight: optionRowHeight
    height: implicitHeight
    text: ""
    idleColor: Theme.hoverMuted
    hoverColor: idleColor
    pressedColor: idleColor
    focusColor: idleColor
    foregroundColor: Theme.fg
    radius: height / 2
    border.width: 0
    border.color: activeFocus || menu.visible ? Theme.accent : Theme.hoverMuted
    hoverScaleDelta: 0
    hoverXScaleDelta: 0
    pressScaleDelta: 0
    pressXScaleDelta: 0
    activeFocusOnTab: enabled
    focused: activeFocus
    Accessible.name: currentSubtitle ? currentLabel + ", " + currentSubtitle : currentLabel
    Keys.forwardTo: shortcutTarget ? [shortcutTarget] : []
    onClicked: menu.visible ? menu.close() : menu.open()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    SettingsChoiceOptionContent {
        anchors { left: parent.left; leftMargin: Theme.spaceLg; right: arrow.left; rightMargin: Theme.spaceMd; verticalCenter: parent.verticalCenter }
        iconText: root.currentIcon
        titleText: root.currentLabel
        subtitleText: root.currentSubtitle
        titleColor: root.foreground
        subtitleColor: Theme.fgMuted
        richLayout: root.hasSubtitleOptions
        titleWeight: root.hasSubtitleOptions ? Font.Medium : Font.Normal
    }
    Text {
        id: arrow
        anchors { right: parent.right; rightMargin: Theme.spaceLg; verticalCenter: parent.verticalCenter }
        text: "⌄"
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }
    Popup {
        id: menu
        objectName: "settings-choice-popup"
        parent: root
        x: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        transformOrigin: Item.TopLeft
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: HAnimation.fast; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: HAnimation.fast; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; to: 0.98; duration: 120; easing.type: Easing.OutCubic }
            }
        }
        y: root.height + Theme.spaceSm
        width: root.width
        height: Math.min(root.maxPopupHeight, Math.max(root.optionRowHeight, root.visibleOptions.length * (root.optionRowHeight + choices.spacing) - choices.spacing + root.groupHeadersHeight)
            + (root.searchable ? search.height + Theme.spaceSm : 0) + padding * 2)
        padding: Theme.spaceMd
        margins: Theme.spaceMd
        focus: true
        property bool hoverReady: false
        onAboutToShow: {
            hoverReady = false
            search.text = ""
            root.refreshRequested()
            root.syncChoices()
        }
        onOpened: {
            Qt.callLater(() => {
                if (!menu.visible) return
                if (choices.currentIndex >= 0) choices.positionViewAtIndex(choices.currentIndex, ListView.Contain)
                selectionPill.syncTarget(true)
                menu.hoverReady = true
            })
            root.searchable ? search.focusSearch() : choices.forceActiveFocus()
        }
        onClosed: {
            hoverReady = false
            if (root.visible) root.forceActiveFocus()
        }
        background: Rectangle { color: Theme.surface; radius: Theme.largeRadius; border.width: 0; border.color: Theme.hoverMuted }
        contentItem: Item {
            SettingsSearchField {
                id: search
                objectName: "settings-choice-search"
                visible: root.searchable
                width: parent.width
                placeholderText: root.searchPlaceholder
                accessibleName: "Search options"
                onAccepted: root.choose(choices.currentIndex)
                onNextRequested: if (choices.count) { choices.currentIndex = Math.max(0, choices.currentIndex); choices.forceActiveFocus() }
                onEscapeRequested: text = ""
            }
            Text {
                anchors.centerIn: choices
                width: choices.width
                visible: root.loading || root.statusMessage.length > 0 || !root.visibleOptions.length
                text: root.loading ? "Loading…" : root.statusMessage || "No matching options"
                color: Theme.fgMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            ListView {
                id: choices
                objectName: "settings-choice-list"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: search.visible ? search.height + Theme.spaceSm : 0 }
                clip: true
                focus: true
                enabled: !root.loading && !root.statusMessage.length
                spacing: Theme.spaceXs
                model: root.visibleOptions
                currentIndex: -1
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: Motion.HScrollBar { id: bar }
                Keys.onReturnPressed: root.choose(currentIndex)
                Keys.onEnterPressed: root.choose(currentIndex)
                Keys.onSpacePressed: root.choose(currentIndex)
                Keys.onUpPressed: event => {
                    if (root.searchable && currentIndex <= 0) {
                        search.focusSearch()
                        return
                    }
                    if (count <= 0) return
                    if (currentIndex < 0) currentIndex = 0
                    else if (currentIndex > 0) decrementCurrentIndex()
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }
                Keys.onDownPressed: event => {
                    if (count <= 0) return
                    if (currentIndex < 0) currentIndex = 0
                    else if (currentIndex < count - 1) incrementCurrentIndex()
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }
                // Keep the pill below delegates and in their scrolling coordinate space.
                Motion.SelectionPill {
                    id: selectionPill
                    objectName: "settings-choice-selection"
                    parent: choices.contentItem
                    coordinateSpace: choices.contentItem
                    targetItem: choices.currentItem && choices.currentItem.buttonItem ? choices.currentItem.buttonItem : choices.currentItem
                    z: 0
                }
                delegate: Item {
                    id: rowWrap
                    required property var modelData
                    required property int index
                    readonly property string groupName: modelData.group ? String(modelData.group) : ""
                    readonly property string prevGroupName: index > 0 && root.visibleOptions[index - 1] && root.visibleOptions[index - 1].group
                        ? String(root.visibleOptions[index - 1].group) : ""
                    readonly property bool showHeader: groupName.length > 0 && groupName !== prevGroupName
                    readonly property bool showDivider: showHeader && index > 0
                    readonly property real headerHeight: !showHeader ? 0 : (showDivider ? root.nextGroupHeaderHeight : root.firstGroupHeaderHeight)
                    readonly property Item buttonItem: option
                    width: Math.max(0, choices.width - bar.reservedGutter)
                    height: headerHeight + root.optionRowHeight
                    z: 1
                    Rectangle {
                        visible: rowWrap.showDivider
                        x: Theme.spaceSm
                        y: Theme.spaceSm
                        width: Math.max(0, parent.width - Theme.spaceSm * 2)
                        height: 1
                        color: Theme.hoverMuted
                    }
                    Text {
                        visible: rowWrap.showHeader
                        anchors {
                            left: parent.left
                            leftMargin: Theme.spaceLg
                            right: parent.right
                            rightMargin: Theme.spaceLg
                            bottom: option.top
                            bottomMargin: Theme.spaceXs
                        }
                        text: rowWrap.groupName
                        color: Theme.fgMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    SettingsActionButton {
                        id: option
                        readonly property string optionIcon: rowWrap.modelData.icon ? String(rowWrap.modelData.icon) : ""
                        readonly property string optionSubtitle: rowWrap.modelData.subtitle ? String(rowWrap.modelData.subtitle) : ""
                        y: rowWrap.headerHeight
                        width: parent.width
                        height: root.optionRowHeight
                        radius: height / 2
                        text: ""
                        selected: choices.currentIndex === rowWrap.index
                        idleColor: "transparent"
                        selectedColor: "transparent"
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        focusColor: "transparent"
                        foregroundColor: Theme.fgDim
                        selectedForegroundColor: Theme.onAccentColor
                        hoverForegroundColor: selected ? Theme.onAccentColor : Theme.fg
                        pressedForegroundColor: hoverForegroundColor
                        focusForegroundColor: hoverForegroundColor
                        selectedOverridesHover: true
                        hoverScaleDelta: 0
                        hoverXScaleDelta: 0
                        Accessible.name: optionSubtitle ? rowWrap.modelData.label + ", " + optionSubtitle : rowWrap.modelData.label
                        Accessible.role: Accessible.ListItem
                        Accessible.selected: selected
                        onHoveredChanged: if (hovered && menu.hoverReady) choices.currentIndex = rowWrap.index
                        onClicked: root.choose(rowWrap.index)
                        SettingsChoiceOptionContent {
                            anchors { fill: parent; leftMargin: Theme.spaceLg; rightMargin: Theme.spaceLg }
                            iconText: option.optionIcon
                            titleText: rowWrap.modelData.label
                            subtitleText: option.optionSubtitle
                            titleColor: option.foreground
                            subtitleColor: option.selected ? Theme.onAccentMuted : Theme.fgMuted
                            richLayout: root.hasSubtitleOptions
                            titleObjectName: "settings-choice-option-label"
                            titleWeight: root.hasSubtitleOptions ? (option.selected ? Font.DemiBold : Font.Medium) : Font.Normal
                        }
                    }
                }
            }
        }
    }
    // Reset selection against the filtered model after search or an asynchronous refresh.
    function syncChoices() {
        var index = visibleOptions.findIndex(option => option.value === value)
        choices.currentIndex = index >= 0 ? index : visibleOptions.length ? 0 : -1
        if (choices.currentIndex >= 0) choices.positionViewAtIndex(choices.currentIndex, ListView.Contain)
        selectionPill.syncTarget(true)
    }
    // Commit a listed value once, then return focus to the selector.
    function choose(index) {
        if (loading || statusMessage.length || index < 0 || index >= visibleOptions.length) return
        choices.currentIndex = index
        chosen(visibleOptions[index].value)
        menu.close()
    }
}
