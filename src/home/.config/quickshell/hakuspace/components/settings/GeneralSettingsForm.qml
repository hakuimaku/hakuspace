import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import "../../services"
import "SettingsCatalog.js" as Catalog

Column {
    id: root
    // The form is reusable inside Wallpaper, Appearance and session pages.
    property string category: "General"
    property Item shortcutTarget: null
    property string highlightedId: ""
    readonly property var descriptors: Catalog.general.filter(item => item.category === category)
    readonly property var fontOptions: category === "General" ? [SettingsStore.fontValues.family, "monospace", "sans-serif", "serif"].concat(Qt.fontFamilies())
        .filter((family, index, families) => family && families.indexOf(family) === index).sort().map(family => ({label: family, value: family})) : []
    spacing: Theme.spaceLg

    // Reveal a search target without hiding its surrounding category.
    function reveal(id) {
        for (var i = 0; i < rows.count; ++i) {
            var row = rows.itemAt(i)
            if (row.descriptor.id === id) { row.forceActiveFocus(); return row }
        }
        return null
    }
    Repeater {
        id: rows
        model: root.descriptors
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property var descriptor: modelData
            readonly property bool typography: descriptor.store === "theme"
            readonly property bool editable: (typography ? SettingsStore.fontsReady : SettingsStore.isKeyEditable(descriptor.key)) && !SettingsStore.saving && !SettingsStore.loading
            readonly property var value: typography ? SettingsStore.fontValues[descriptor.key] : SettingsStore.value(descriptor.key)
            function setValue(value) { if (typography) SettingsStore.setFontValue(descriptor.key, value); else SettingsStore.setValue(descriptor.key, value) }
            readonly property string settingsNavSection: descriptor.category
            width: root.width
            height: body.implicitHeight + Theme.cardPadding * 2
            radius: Theme.radius
            color: root.highlightedId === descriptor.id ? Theme.hoverMuted : "transparent"
            border.width: root.highlightedId === descriptor.id ? 1 : 0
            border.color: Theme.accent
            Column {
                id: body
                x: Theme.cardPadding; y: Theme.cardPadding
                width: Math.max(0, parent.width - Theme.cardPadding * 2)
                spacing: Theme.spaceSm
                Text { width: parent.width; text: row.descriptor.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.weight: Font.Medium; wrapMode: Text.Wrap }
                Text { width: parent.width; visible: text.length > 0; text: row.descriptor.key === "SCREENSHOT_DIR" && WM.backendName === "niri" ? "Niri’s screenshot keys save to a different folder. Change the screenshot directory in Niri’s config file like: screenshot-path ~/Pictures/Screenshots/screenshot_%Y-%m-%d_%H-%M-%S.png" : row.descriptor.summary; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
                Text { visible: row.descriptor.key !== "SCREENSHOT_DIR"; text: row.typography ? "Applies when you select Apply" : row.descriptor.restartPolicy === "next-session" ? "Applies at next sign-in" : "Applies on the next related action"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                Loader {
                    width: parent.width
                    sourceComponent: row.descriptor.control === "switch" ? booleanControl
                        : row.descriptor.control === "choice" ? choiceControl
                        : row.descriptor.control === "number" ? numberControl
                        : row.descriptor.control === "path" ? pathControl
                        : row.descriptor.control === "list" ? listControl : textControl
                }
                Text { width: parent.width; visible: text.length > 0; text: row.typography ? "" : SettingsStore.validationMessage(row.descriptor.key); color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
            }
            Component {
                id: booleanControl
                SettingsSwitch {
                    shortcutTarget: root.shortcutTarget
                    height: Theme.comfortableControlHeight
                    checked: row.value === true
                    enabled: row.editable
                    Accessible.name: row.descriptor.label
                    onToggled: value => row.setValue(value)
                }
            }
            Component { id: choiceControl; SettingsChoiceRow { options: row.typography ? root.fontOptions : row.descriptor.options; value: row.value; enabled: row.editable; shortcutTarget: root.shortcutTarget; Accessible.name: row.descriptor.label; onChosen: value => row.setValue(value) } }
            Component { id: numberControl; SettingsNumberRow { descriptor: row.descriptor; value: row.value; enabled: row.editable; shortcutTarget: root.shortcutTarget; onEdited: value => row.setValue(value) } }
            Component {
                id: pathControl
                Column {
                    spacing: Theme.spaceSm
                    width: parent.width
                    Text { width: parent.width; text: String(row.value || "No folder selected"); color: Theme.fgDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideMiddle }
                    SettingsActionButton { width: 170; height: Theme.comfortableControlHeight; text: "󰉋  Choose folder…"; idleColor: Theme.hoverMuted; border.width: 0; enabled: row.editable; activeFocusOnTab: true; focused: activeFocus; Accessible.name: row.descriptor.label + ": choose folder"; onClicked: { folder.lease = UiState.beginNativeDialog("settings"); folder.open() } Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                    FolderDialog {
                        id: folder
                        title: "Choose " + row.descriptor.label.toLowerCase()
                        property int lease: 0
                        currentFolder: WallpaperService.fileUrl(Catalog.folderPath(row.value, Quickshell.env("HOME")))
                        onAccepted: {
                            row.setValue(decodeURIComponent(String(selectedFolder).substring(7)))
                            UiState.endNativeDialog(lease)
                        }
                        onRejected: UiState.endNativeDialog(lease)
                        Component.onDestruction: UiState.endNativeDialog(lease)
                    }
                }
            }
            Component {
                id: textControl
                TextField {
                    property bool settingsNavItem: true
                    property string settingsNavRole: "input"
                    height: Theme.comfortableControlHeight
                    text: String(row.value || "")
                    enabled: row.editable
                    color: Theme.fg
                    selectByMouse: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    leftPadding: Theme.spaceLg
                    rightPadding: Theme.spaceLg
                    Accessible.name: row.descriptor.label
                    Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                    background: Rectangle { radius: Theme.radius; color: Theme.hoverMuted; border.width: parent.activeFocus ? 1 : 0; border.color: Theme.accent }
                    onTextEdited: row.setValue(text)
                }
            }
            Component {
                id: listControl
                Column {
                    width: parent.width
                    spacing: Theme.spaceSm
                    Flow {
                        width: parent.width; spacing: Theme.spaceSm
                        Repeater {
                            model: Array.isArray(row.value) ? row.value : []
                            delegate: SettingsActionButton {
                                id: chip
                                required property string modelData
                                required property int index
                                width: Math.min(260, chipMetrics.width + 32); height: Theme.controlHeight
                                text: modelData + " ×"
                                enabled: row.editable
                                activeFocusOnTab: true; focused: activeFocus
                                Accessible.name: "Remove " + modelData
                                TextMetrics { id: chipMetrics; text: chip.text; font.pixelSize: Theme.fontSize }
                                onClicked: { var next = row.value.slice(); next.splice(index, 1); row.setValue(next) }
                                Keys.onReturnPressed: clicked()
                                Keys.onSpacePressed: clicked()
                            }
                        }
                    }
                    Row {
                        width: parent.width; spacing: Theme.spaceSm
                        TextField {
                            id: entry
                            property bool settingsNavItem: true
                            property string settingsNavRole: "input"
                            width: Math.max(0, parent.width - 88); height: Theme.comfortableControlHeight
                            enabled: row.editable
                            placeholderText: row.descriptor.entryLabel || row.descriptor.label
                            color: Theme.fg; placeholderTextColor: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            leftPadding: Theme.spaceLg
                            rightPadding: Theme.spaceLg
                            Accessible.name: "Add to " + row.descriptor.label.toLowerCase()
                            Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                            background: Rectangle { radius: Theme.radius; color: Theme.hoverMuted }
                            // Reject empty, duplicate and multiline list entries.
                            function add() {
                                var name = text.trim()
                                var values = Array.isArray(row.value) ? row.value : []
                                if (!name || /[\r\n\0]/.test(name) || values.includes(name)) return
                                row.setValue(values.concat([name]))
                                text = ""
                            }
                            onAccepted: add()
                        }
                        SettingsActionButton { width: 80; height: Theme.comfortableControlHeight; text: "Add"; enabled: row.editable; activeFocusOnTab: true; focused: activeFocus; onClicked: entry.add(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                    }
                }
            }
        }
    }
}
