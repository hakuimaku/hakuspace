import QtQuick
import QtQuick.Controls
import "../../services"
import "SettingsArguments.js" as Arguments

Column {
    id: root
    property string preference: "REC_OPTS"
    property Item shortcutTarget: null
    readonly property string raw: String(SettingsCoordinator.read(preference) || "")
    readonly property var flags: preference === "REC_OPTS" ? Arguments.recording : Arguments.wallpaper
    readonly property var parsed: Arguments.parse(raw, flags, converted)
    property bool converted: false
    property bool advanced: false
    property string error: ""
    spacing: Theme.spaceMd
    // Unrecognized shell syntax remains editable verbatim, with no automatic rewrite.
    function update(key, value) {
        var next = Arguments.replace(raw, flags, key, value, converted)
        if (next !== null) SettingsCoordinator.set(preference, next)
    }
    Text { width: parent.width; visible: !root.parsed.safe; text: "Custom shell syntax detected. Edit the raw arguments in Advanced; structured controls cannot safely rewrite this value."; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
    SettingsActionButton {
        visible: !root.parsed.safe && Arguments.parse(root.raw, root.flags, true).safe
        width: 280; height: 36; text: "Convert to structured options"
        activeFocusOnTab: true; focused: activeFocus
        onClicked: root.converted = true
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()
    }
    SettingsReveal {
        width: parent.width
        expanded: root.parsed.safe
        expandedHeight: options.implicitHeight
        Column {
            id: options
            width: parent.width; spacing: Theme.spaceMd
            Repeater {
                model: Object.keys(root.flags)
                delegate: Column {
                    id: flag
                    required property string modelData
                    width: parent.width; spacing: Theme.spaceSm
                    Text { text: flag.modelData === "--max-fps" ? "Maximum frame rate" : flag.modelData === "--transition-duration" ? "Transition duration (seconds)" : flag.modelData.substring(2).replace(/-/g, " "); color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold }
                    Loader {
                        width: parent.width
                        sourceComponent: flag.modelData === "--transition-type" ? transitionType : flag.modelData === "--transition-duration" ? freeText : numeric
                        Component {
                            id: numeric
                            SettingsValueSlider {
                                descriptor: ({label: flag.modelData, min: 1, max: flag.modelData === "--transition-step" ? 255 : 999, step: 1, unit: flag.modelData.indexOf("fps") >= 0 ? "fps" : ""})
                                value: Number(root.parsed.values[flag.modelData] || 60)
                                shortcutTarget: root.shortcutTarget
                                onEdited: value => { var next = Arguments.replace(root.raw, root.flags, flag.modelData, value, root.converted); if (next !== null) SettingsCoordinator.set(root.preference, next, true) }
                                onEditingFinished: SettingsCoordinator.flush()
                            }
                        }
                        Component {
                            id: transitionType
                            SettingsChoiceRow {
                                options: ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"].map(v => ({value: v, label: v}))
                                value: root.parsed.values[flag.modelData] || "random"; shortcutTarget: root.shortcutTarget
                                onChosen: value => root.update(flag.modelData, value)
                            }
                        }
                        Component {
                            id: freeText
                            TextField {
                                property bool settingsNavItem: true
                                property string settingsNavRole: "input"
                                verticalAlignment: TextInput.AlignVCenter
                                leftPadding: Theme.spaceLg; rightPadding: Theme.spaceLg
                                topPadding: Theme.spaceSm; bottomPadding: Theme.spaceSm
                                width: parent.width; height: Theme.comfortableControlHeight
                                text: root.parsed.values[flag.modelData] || ""
                                placeholderText: "Use application default"; placeholderTextColor: Theme.fgMuted
                                color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; selectByMouse: true
                                Accessible.name: flag.modelData
                                Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                                background: Rectangle { radius: Theme.radius; color: Theme.hoverMuted }
                                onEditingFinished: root.update(flag.modelData, text)
                            }
                        }
                    }

                }
            }
            SettingsActionButton { width: 260; height: 34; text: root.advanced ? "Hide advanced options" : root.preference === "REC_OPTS" ? "Advanced recording options" : "Extra transition arguments"; activeFocusOnTab: true; focused: activeFocus; onClicked: root.advanced = !root.advanced; Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
            SettingsReveal {
                width: parent.width
                expanded: root.advanced
                expandedHeight: extraField.height
                TextField {
                    id: extraField
                    property bool settingsNavItem: true
                    property string settingsNavRole: "input"
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: Theme.spaceLg; rightPadding: Theme.spaceLg
                    topPadding: Theme.spaceSm; bottomPadding: Theme.spaceSm
                    width: parent.width; height: Theme.comfortableControlHeight
                    text: root.parsed.extraArguments
                    placeholderText: "Extra arguments"; placeholderTextColor: Theme.fgMuted
                    color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; selectByMouse: true
                    Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                    background: Rectangle { radius: Theme.radius; color: Theme.hoverMuted }
                    onEditingFinished: { var next = Arguments.extras(root.raw, root.flags, text, root.converted); if (next !== null) { SettingsCoordinator.set(root.preference, next); root.error = "" } else root.error = "Use Advanced for shell syntax or known flags" }
                }
            }
            Text { visible: !!root.error; text: root.error; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
        }
    }
}
