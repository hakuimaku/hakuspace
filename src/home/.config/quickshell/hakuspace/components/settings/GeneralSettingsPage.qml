import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property string confirmation: ""
    signal reloadRequested()
    signal cancelRequested()
    signal discardRequested()

    Column {
        anchors.fill: parent
        spacing: Theme.pad
        Flickable {
            id: formScroll
            width: parent.width
            height: Math.max(0, parent.height - 51)
            contentWidth: width
            contentHeight: formColumn.y + formColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar {}
            Column {
                id: formColumn
                y: Theme.pad * 2
                width: Math.min(830, Math.max(0, formScroll.width - 14))
                spacing: 4
                Repeater {
                    model: SettingsStore.catalog
                    delegate: Column {
                        id: settingRow
                        required property var modelData
                        required property int index
                        width: formColumn.width
                        spacing: 3
                        readonly property bool editable: SettingsStore.isKeyEditable(modelData.key)
                        readonly property var currentValue: SettingsStore.value(modelData.key)
                        readonly property bool sectionStart: index === 0 || modelData.group !== SettingsStore.catalog[index - 1].group
                        readonly property bool stacked: width < 510
                        Item {
                            visible: settingRow.sectionStart
                            height: visible ? (settingRow.index === 0 ? 37 : 53) : 0
                            width: parent.width
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                width: sectionTitle.implicitWidth + 24
                                height: sectionTitle.implicitHeight + 12
                                radius: Theme.radius
                                color: Theme.accent
                                Text {
                                    id: sectionTitle
                                    anchors.centerIn: parent
                                    text: settingRow.modelData.group
                                    color: "black"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 3
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                        Grid {
                            width: parent.width
                            columns: settingRow.stacked ? 1 : 2
                            columnSpacing: Theme.pad
                            rowSpacing: 5
                            Column {
                                id: metadataColumn
                                width: settingRow.stacked ? settingRow.width : Math.round(settingRow.width * 0.38)
                                spacing: 2
                                HoverHandler { id: metadataHover }
                                SettingsTooltip {
                                    target: metadataColumn
                                    active: metadataHover.hovered
                                    text: settingRow.modelData.hint + "\n" + settingRow.modelData.key
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
                                    text: settingRow.modelData.key + (SettingsStore.validationMessage(settingRow.modelData.key)
                                          ? " · " + SettingsStore.validationMessage(settingRow.modelData.key) : "")
                                    color: SettingsStore.validationMessage(settingRow.modelData.key) ? Theme.accent : Theme.fgMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                    wrapMode: Text.Wrap
                                }
                            }
                            Column {
                                id: controlColumn
                                width: settingRow.stacked ? settingRow.width : Math.max(0, settingRow.width - Math.round(settingRow.width * 0.38) - Theme.pad)
                                spacing: 5
                                SettingsSegmentedToggle {
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
                                    height: visible ? 32 : 0
                                    radius: Theme.radius
                                    text: String(settingRow.currentValue || "") + "  →"
                                    idleColor: Theme.hoverMuted
                                    hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                    pressedColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                    foregroundColor: Theme.fg
                                    hoverForegroundColor: Theme.fg
                                    enabled: settingRow.editable
                                    activeFocusOnTab: enabled && visible
                                    focused: activeFocus
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
                                    height: visible ? 34 : 0
                                    radius: Theme.radius
                                    color: Theme.hoverMuted
                                    opacity: settingRow.editable ? 1 : 0.45
                                    border.width: 1
                                    border.color: input.activeFocus ? Theme.accent : "transparent"
                                    Behavior on border.color { ColorAnimation { duration: HAnimation.buttonFocusDuration } }
                                    HoverHandler { id: valueHover }
                                    SettingsTooltip {
                                        target: valueField
                                        active: valueHover.hovered && !input.activeFocus
                                        text: settingRow.modelData.hint
                                    }
                                    TextInput {
                                        id: input
                                        anchors.fill: parent
                                        anchors.margins: 8
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
                                        width: parent.width
                                        height: childrenRect.height
                                        spacing: 5
                                        Repeater {
                                            model: Array.isArray(settingRow.currentValue) ? settingRow.currentValue : []
                                            delegate: SettingsActionButton {
                                                id: chip
                                                required property string modelData
                                                required property int index
                                                TextMetrics { id: metrics; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: chip.modelData + " ×" }
                                                width: Math.min(controlColumn.width, metrics.width + 22)
                                                height: 26
                                                radius: Theme.radius
                                                text: modelData + " ×"
                                                idleColor: "transparent"
                                                hoverColor: Theme.hoverMuted
                                                pressedColor: Qt.lighter(Theme.hoverMuted, 1.18)
                                                foregroundColor: Theme.fgDim
                                                hoverForegroundColor: Theme.fg
                                                enabled: settingRow.editable
                                                activeFocusOnTab: enabled
                                                focused: activeFocus
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
                                        width: parent.width
                                        spacing: 6
                                        Rectangle {
                                            id: addField
                                            width: Math.min(280, Math.max(70, parent.width - 62))
                                            height: 32
                                            radius: Theme.radius
                                            color: Theme.hoverMuted
                                            border.width: 1
                                            border.color: addInput.activeFocus ? Theme.accent : "transparent"
                                            Behavior on border.color { ColorAnimation { duration: HAnimation.buttonFocusDuration } }
                                            HoverHandler { id: addHover }
                                            SettingsTooltip {
                                                target: addField
                                                active: addHover.hovered && !addInput.activeFocus
                                                text: settingRow.modelData.hint + "\nEnter an application to add to the Exit list."
                                            }
                                            TextInput {
                                                id: addInput
                                                anchors.fill: parent
                                                anchors.margins: 7
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize
                                                enabled: settingRow.editable
                                                activeFocusOnTab: enabled && settingRow.modelData.type === "list"
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
                                            width: 54; height: 32; radius: Theme.radius
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
                        Item { width: 1; height: 8 }
                    }
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.border }
        Row {
            width: parent.width
            height: 35
            spacing: Theme.pad
            Text {
                width: Math.max(80, parent.width - 190)
                anchors.verticalCenter: parent.verticalCenter
                text: root.confirmation ? (root.confirmation === "reload" ? "Discard changes and reload from disk?"
                      : "Discard unsaved Settings changes and close?")
                      : SettingsStore.error || SettingsStore.statusMessage
                        || (SettingsStore.loading ? "Loading…" : SettingsStore.dirty ? "Unsaved changes" : "")
                color: SettingsStore.error ? Theme.accent : Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                elide: Text.ElideRight
            }
            SettingsActionButton {
                id: reloadButton
                width: 76; height: 32; radius: Theme.radius
                text: root.confirmation ? "Keep" : "Reload"
                idleColor: Theme.hoverMuted
                hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
                foregroundColor: Theme.fg
                hoverForegroundColor: Theme.fg
                enabled: !SettingsStore.saving
                activeFocusOnTab: enabled
                focused: activeFocus
                onClicked: { if (root.confirmation) root.cancelRequested(); else root.reloadRequested() }
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
                SettingsTooltip {
                    target: reloadButton
                    active: reloadButton.hovered || reloadButton.activeFocus
                    text: root.confirmation ? "Keep editing without discarding changes."
                          : "Reload General settings from setting.sh."
                }
            }
            SettingsActionButton {
                id: applyButton
                width: 80; height: 32; radius: Theme.radius
                readonly property bool canActivate: root.confirmation || (SettingsStore.ready && SettingsStore.dirty && SettingsStore.valid && !SettingsStore.saving && !SettingsStore.loading)
                text: root.confirmation ? "Discard" : SettingsStore.saving ? "Saving…" : "Apply"
                idleColor: Theme.accent
                hoverColor: Theme.accent
                pressedColor: Theme.accent
                foregroundColor: Theme.onAccentColor
                hoverForegroundColor: Theme.onAccentColor
                enabled: canActivate
                activeFocusOnTab: enabled
                focused: activeFocus
                onClicked: { if (root.confirmation) root.discardRequested(); else SettingsStore.apply() }
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
                SettingsTooltip {
                    target: applyButton
                    active: applyButton.hovered || applyButton.activeFocus
                    text: root.confirmation ? "Discard unsaved changes."
                          : "Save changed General settings to setting.sh."
                }
            }
        }
    }
}
