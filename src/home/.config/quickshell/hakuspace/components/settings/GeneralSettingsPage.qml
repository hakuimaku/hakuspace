import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Item {
    id: root
    // Text controls forward layer shortcuts before interpreting typed characters.
    property Item shortcutTarget: null
    // Keep keyboard search on the same filter used by pointer interaction.
    function focusSearch() { search.focusSearch() }
    signal reloadRequested()
    // Filter catalog rows without replacing the catalog or its editable drafts.
    readonly property string query: search.text.trim().toLowerCase()
    onQueryChanged: {
        formScroll.contentY = 0
        if (visible && !search.inputFocused) search.focusSearch()
    }
    readonly property var sectionNames: [...new Set(SettingsStore.catalog.map(item => item.group))]
    readonly property var sidebarSections: sectionNames.filter(group => SettingsStore.catalog.some(item => item.group === group && matches(item)))
    readonly property string activeSection: {
        if (formScroll.contentY > 0 && formScroll.contentY >= formScroll.contentHeight - formScroll.height - 1)
            return sidebarSections[sidebarSections.length - 1] || ""
        var current = sidebarSections[0] || ""
        for (var i = 0; i < groups.count; ++i) {
            var card = groups.itemAt(i)
            if (card && card.visible && card.y <= formScroll.contentY + 24) current = card.title
        }
        return current
    }
    // Footer guards mirror General's existing Reload and Apply rules.
    readonly property var actionLabels: ["Reload", "Apply"]
    readonly property string footerStatus: SettingsStore.error || SettingsStore.statusMessage
        || (SettingsStore.loading ? "Loading…" : SettingsStore.saving ? "Saving…" : SettingsStore.dirty ? "Unsaved changes" : "setting.sh · All changes saved")
    readonly property bool footerDirty: SettingsStore.dirty
    readonly property bool footerError: !!SettingsStore.error
    readonly property bool canKeepConfirmation: !SettingsStore.saving
    readonly property var actionHints: ({Reload: "Reload General settings from setting.sh.", Apply: "Save changed General settings to setting.sh."})

    // Search labels, keys, groups and hints using the existing catalog metadata.
    function matches(item) {
        return !query || [item.label, item.key, item.group, item.hint].join(" ").toLowerCase().includes(query)
    }
    // Scroll to a visible card while respecting the viewport's lower bound.
    function scrollToSection(name) {
        for (var i = 0; i < groups.count; ++i) {
            var card = groups.itemAt(i)
            if (card && card.visible && card.title === name)
                formScroll.contentY = Math.max(0, Math.min(card.y, formScroll.contentHeight - formScroll.height))
        }
    }
    // Preserve the original action availability during backend operations.
    function canActivate(label) {
        return label === "Reload" ? !SettingsStore.saving
            : SettingsStore.ready && SettingsStore.dirty && SettingsStore.valid && !SettingsStore.saving && !SettingsStore.loading
    }
    // Reload confirmations remain owned by the panel.
    function activateAction(label) {
        if (label === "Reload") reloadRequested()
        else SettingsStore.apply()
    }

    Column {
        anchors.fill: parent
        spacing: 14
        Column {
            width: parent.width
            spacing: 6
            Row {
                width: parent.width
                Text {
                    width: parent.width > 420 ? parent.width - 230 : parent.width * 0.38
                    height: 38
                    verticalAlignment: Text.AlignVCenter
                    text: "General"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 5
                    font.weight: Font.DemiBold
                }
                SettingsSearchField { id: search; width: parent.width - x; height: 38; shortcutTarget: root.shortcutTarget }
            }
            Text {
                width: parent.width
                text: "Preferences for your HakuSpace session."
                color: Theme.fgDescription
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 1)
                wrapMode: Text.Wrap
            }
        }
        Flickable {
            id: formScroll
            width: parent.width
            height: Math.max(0, parent.height - y)
            contentWidth: width
            contentHeight: formColumn.implicitHeight + 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar {}
            Column {
                id: formColumn
                width: Math.max(0, formScroll.width - 14)
                spacing: 22
                Text {
                    visible: root.sidebarSections.length === 0
                    text: "No settings match your search."
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Repeater {
                    id: groups
                    model: root.sectionNames
                    delegate: SettingsSectionCard {
                        id: groupCard
                        required property string modelData
                        title: modelData
                        width: formColumn.width
                        visible: root.sidebarSections.indexOf(title) >= 0
                        Repeater {
                            model: SettingsStore.catalog.filter(item => item.group === groupCard.title)
                            delegate: Column {
                                id: settingRow
                                required property var modelData
                                required property int index
                                width: parent.width
                                spacing: 14
                                visible: root.matches(modelData)
                                // Controls continue reading and editing the same catalog key.
                                readonly property bool editable: SettingsStore.isKeyEditable(modelData.key)
                                readonly property var currentValue: SettingsStore.value(modelData.key)
                                readonly property bool stacked: width < 540
                                Grid {
                                    width: parent.width
                                    columns: settingRow.stacked ? 1 : 2
                                    columnSpacing: Theme.pad
                                    rowSpacing: 5
                                    Column {
                                        id: metadataColumn
                                        width: settingRow.stacked ? settingRow.width : Math.round(settingRow.width * 0.46)
                                        spacing: 6
                                        HoverHandler { id: metadataHover }
                                        SettingsTooltip {
                                            target: metadataColumn
                                            active: metadataHover.hovered
                                            text: settingRow.modelData.hint
                                                  + (SettingsStore.validationMessage(settingRow.modelData.key)
                                                     ? "\n" + SettingsStore.validationMessage(settingRow.modelData.key) : "")
                                        }
                                        Text {
                                            width: parent.width
                                            text: settingRow.modelData.label
                                            color: settingRow.editable ? Theme.fg : Theme.fgDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            visible: text.length > 0
                                            text: SettingsStore.validationMessage(settingRow.modelData.key)
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                            wrapMode: Text.Wrap
                                        }
                                        Text {
                                            width: parent.width
                                            text: settingRow.modelData.hint
                                            color: Theme.fgDescription
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Column {
                                        id: controlColumn
                                        width: settingRow.stacked ? settingRow.width : Math.max(0, settingRow.width - Math.round(settingRow.width * 0.46) - Theme.pad)
                                        spacing: 8
                                        SettingsSegmentedToggle {
                                            Accessible.name: settingRow.modelData.label
                                            visible: settingRow.modelData.type === "bool"
                                            checked: settingRow.currentValue === true
                                            available: settingRow.editable
                                            hint: settingRow.modelData.hint
                                            onToggled: value => SettingsStore.setValue(settingRow.modelData.key, value)
                                        }
                                        SettingsActionButton {
                                            id: modeButton
                                            visible: settingRow.modelData.type === "enum"
                                            width: Math.min(controlColumn.width, 230)
                                            height: visible ? 36 : 0
                                            text: String(settingRow.currentValue || "") + "  →"
                                            idleColor: Theme.hoverMuted
                                            hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                            pressedColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                            foregroundColor: Theme.fg
                                            hoverForegroundColor: Theme.fg
                                            enabled: settingRow.editable
                                            activeFocusOnTab: enabled && visible
                                            focused: activeFocus
                                            // Cycle through the store's supported accent modes.
                                            function nextMode() {
                                                var modes = ["vivid", "dominant", "brightest", "saturated"]
                                                SettingsStore.setValue(settingRow.modelData.key, modes[(modes.indexOf(settingRow.currentValue) + 1) % modes.length])
                                            }
                                            onClicked: nextMode()
                                            Keys.onReturnPressed: nextMode()
                                            Keys.onSpacePressed: nextMode()
                                            SettingsTooltip {
                                                target: modeButton
                                                active: modeButton.hovered || modeButton.activeFocus
                                                text: settingRow.modelData.hint + "\nClick to choose the next mode."
                                            }
                                        }
                                        Rectangle {
                                            id: valueField
                                            visible: ["int", "path", "text", "required"].indexOf(settingRow.modelData.type) >= 0
                                            width: Math.min(controlColumn.width, settingRow.modelData.type === "int" ? 160 : 405)
                                            height: visible ? 38 : 0
                                            radius: Theme.radius
                                            color: Theme.hoverMuted
                                            opacity: settingRow.editable ? 1 : 0.45
                                            border.width: 1
                                            border.color: input.activeFocus ? Theme.accent : Theme.hoverMuted
                                            Behavior on border.color { ColorAnimation { duration: HAnimation.buttonFocusDuration } }
                                            HoverHandler { id: valueHover }
                                            SettingsTooltip {
                                                target: valueField
                                                active: valueHover.hovered && !input.activeFocus
                                                text: settingRow.modelData.hint
                                            }
                                            TextInput {
                                                id: input
                                                property bool settingsNavItem: true
                                                property string settingsNavRole: "input"
                                                Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: Theme.fg
                                                selectionColor: Theme.accent
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                                clip: true
                                                enabled: settingRow.editable
                                                activeFocusOnTab: enabled && parent.visible
                                                text: settingRow.currentValue === undefined ? "" : String(settingRow.currentValue)
                                                onTextEdited: SettingsStore.setValue(settingRow.modelData.key, text)
                                            }
                                        }
                                        Column {
                                            visible: settingRow.modelData.type === "list"
                                            width: controlColumn.width
                                            spacing: 5
                                            Flow {
                                                id: chips
                                                width: parent.width
                                                height: childrenRect.height
                                                spacing: 5
                                                Repeater {
                                                    model: Array.isArray(settingRow.currentValue) ? settingRow.currentValue : []
                                                    delegate: SettingsActionButton {
                                                        id: chip
                                                        settingsNavGroup: chips
                                                        required property string modelData
                                                        required property int index
                                                        TextMetrics { id: metrics; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: chip.modelData + " ×" }
                                                        width: Math.min(controlColumn.width, metrics.width + 28)
                                                        height: 30
                                                        text: modelData + " ×"
                                                        idleColor: "transparent"
                                                        hoverColor: Theme.hoverMuted
                                                        pressedColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                                        foregroundColor: Theme.fgDim
                                                        hoverForegroundColor: Theme.fg
                                                        enabled: settingRow.editable
                                                        activeFocusOnTab: enabled
                                                        focused: activeFocus
                                                        // Remove this entry from the shared list draft.
                                                        function removeItem() {
                                                            var next = settingRow.currentValue.slice()
                                                            next.splice(index, 1)
                                                            SettingsStore.setValue(settingRow.modelData.key, next)
                                                        }
                                                        onClicked: removeItem()
                                                        Keys.onReturnPressed: removeItem()
                                                        Keys.onSpacePressed: removeItem()
                                                        Keys.onDeletePressed: removeItem()
                                                        SettingsTooltip {
                                                            target: chip
                                                            active: chip.hovered || chip.activeFocus
                                                            text: settingRow.modelData.hint + "\nRemove " + chip.modelData + " from the Exit list."
                                                        }
                                                    }
                                                }
                                            }
                                            Row {
                                                id: addRow
                                                width: parent.width
                                                spacing: 6
                                                Rectangle {
                                                    id: addField
                                                    width: Math.min(280, Math.max(70, parent.width - 72))
                                                    height: 36
                                                    radius: Theme.radius
                                                    color: Theme.hoverMuted
                                                    border.width: 1
                                                    border.color: addInput.activeFocus ? Theme.accent : Theme.hoverMuted
                                                    Behavior on border.color { ColorAnimation { duration: HAnimation.buttonFocusDuration } }
                                                    HoverHandler { id: addHover }
                                                    SettingsTooltip {
                                                        target: addField
                                                        active: addHover.hovered && !addInput.activeFocus
                                                        text: settingRow.modelData.hint + "\nEnter an application to add to the Exit list."
                                                    }
                                                    TextInput {
                                                        id: addInput
                                                        property Item settingsNavGroup: addRow
                                                        property bool settingsNavItem: true
                                                        property string settingsNavRole: "input"
                                                        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                                                        anchors.fill: parent
                                                        anchors.margins: 9
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        color: Theme.fg
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fontSize
                                                        enabled: settingRow.editable
                                                        activeFocusOnTab: enabled && settingRow.modelData.type === "list"
                                                        // Accept unique, nonempty entries on one line.
                                                        function add() {
                                                            var item = text.trim()
                                                            if (!item || /[\r\n\0]/.test(item) || settingRow.currentValue.indexOf(item) >= 0) return
                                                            SettingsStore.setValue(settingRow.modelData.key, settingRow.currentValue.concat([item]))
                                                            text = ""
                                                        }
                                                        onAccepted: add()
                                                    }
                                                }
                                                SettingsActionButton {
                                                    id: addButton
                                                    settingsNavGroup: addRow
                                                    width: 64; height: 36
                                                    text: "Add"
                                                    idleColor: Theme.hoverMuted
                                                    hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                                    foregroundColor: Theme.fg
                                                    hoverForegroundColor: Theme.fg
                                                    enabled: settingRow.editable
                                                    activeFocusOnTab: enabled
                                                    focused: activeFocus
                                                    onClicked: addInput.add()
                                                    Keys.onReturnPressed: addInput.add()
                                                    Keys.onSpacePressed: addInput.add()
                                                    SettingsTooltip {
                                                        target: addButton
                                                        active: addButton.hovered || addButton.activeFocus
                                                        text: settingRow.modelData.hint + "\nAdd this application to the Exit list."
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted; opacity: 0.5 }
                            }
                        }
                    }
                }
            }
        }
    }
}
