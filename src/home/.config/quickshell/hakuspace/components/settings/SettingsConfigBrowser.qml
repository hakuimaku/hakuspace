import QtQuick
import QtQuick.Controls
import "../../services"
import "../motion" as Motion
import "ConfigTreeModel.js" as TreeModel

Item {
    id: root
    // Browser styles share the same files, active selection and draft protection.
    property bool compact: false
    property bool buttonsView: false
    // Handle layer shortcuts before the compact selector performs type-ahead.
    property Item shortcutTarget: null
    readonly property bool popupOpen: compactFiles.popup.visible
    signal fileSelected(string fileId)
    SettingsSegmentedToggle {
        id: viewTabs
        settingsNavRole: "sidebar"
        x: root.compact ? 4 : 14
        y: root.compact ? 4 : 14
        width: root.compact ? Math.min(190, root.width * 0.4) : Math.max(0, root.width - 28)
        height: 36
        labels: ["Tree", "Buttons"]
        checked: root.buttonsView
        hint: "Choose how configuration files are displayed."
        onToggled: value => root.buttonsView = value
    }
    ComboBox {
        id: compactFiles
        readonly property bool settingsNavSelected: currentIndex >= 0
        property bool settingsNavItem: true
        property string settingsNavRole: "selector"
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        x: viewTabs.x + viewTabs.width + 8
        y: 4
        width: Math.max(0, parent.width - x - 4)
        height: 36
        visible: root.compact
        enabled: count > 0
        model: ConfigEditorStore.files
        textRole: "id"
        currentIndex: ConfigEditorStore.files.findIndex(file => file.id === ConfigEditorStore.selectedFileId)
        displayText: ConfigEditorStore.selectedFileId ? (root.buttonsView ? TreeModel.title(ConfigEditorStore.selectedFileId) : ConfigEditorStore.selectedFileId) : "Select a config file"
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: compactFiles.width
            text: root.buttonsView ? TreeModel.title(modelData.id) : modelData.id
            font.family: Theme.fontFamily
            highlighted: index === compactFiles.highlightedIndex
        }
        font.family: Theme.fontFamily
        palette.button: Theme.surface
        palette.buttonText: Theme.fg
        palette.base: Theme.surface
        palette.text: Theme.fg
        palette.highlight: Theme.accent
        palette.highlightedText: "#000000"
        Accessible.name: "Configuration files"
        onActivated: index => root.fileSelected(ConfigEditorStore.files[index].id)
    }
    Column {
        anchors.fill: parent
        anchors.topMargin: 64
        anchors.bottomMargin: 14
        visible: !root.compact
        spacing: 14
        Flickable {
            id: fileScroll
            x: 14
            width: Math.max(0, parent.width - 28)
            height: Math.max(0, parent.height - 50)
            contentWidth: width
            contentHeight: root.buttonsView ? buttonColumn.implicitHeight : fileColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))
            ScrollBar.vertical: Motion.HScrollBar { id: fileBar }
            // Each browser view keeps one moving highlight for its selected file.
            Motion.SelectionPill {
                id: treeSelection
                parent: fileScroll.contentItem
                coordinateSpace: fileScroll.contentItem
                shown: !root.buttonsView && targetItem !== null
                z: 0
                duration: HAnimation.slow
                trailFactor: 1.15
            }
            Motion.SelectionPill {
                id: buttonSelection
                parent: fileScroll.contentItem
                coordinateSpace: fileScroll.contentItem
                shown: root.buttonsView && targetItem !== null
                z: 0
                duration: HAnimation.slow
                trailFactor: 1.15
            }
            Column {
                id: fileColumn
                visible: !root.buttonsView
                z: 1
                onPositioningComplete: treeSelection.syncTarget(false)

                // Reserve space only while the scrollbar is visible.
                width: Math.max(0, fileScroll.width - fileBar.reservedGutter)
                // Gap between the wm and config groups.
                spacing: 18
                Repeater {
                    model: ["wm", "config"]
                    delegate: Column {
                        id: fileGroup
                        onPositioningComplete: treeSelection.syncTarget(false)
                        required property string modelData
                        // Tree rows are sorted directories first, then files by name.
                        readonly property var groupRows: TreeModel.rows(ConfigEditorStore.files, modelData)
                        width: fileColumn.width
                        z: 1
                        // Keep tree rows adjacent so continuation lines stay unbroken.
                        spacing: 0
                        // Adjust height and text margins to change accent header padding.
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: Theme.radius
                            color: "transparent"
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: modelData
                                color: Theme.fgMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                            }
                        }
                        Item { width: 1; height: 3 }
                        Repeater {
                            model: fileGroup.groupRows
                            delegate: Item {
                                id: treeRow
                                required property var modelData
                                width: fileColumn.width
                                height: 36
                                SettingsActionButton {
                                    id: fileRow
                                    settingsNavRole: "sidebar"
                                    anchors.fill: parent
                                    visible: treeRow.modelData.type === "file"
                                    text: ""
                                    Accessible.name: treeRow.modelData.fileId
                                    selected: ConfigEditorStore.selectedFileId === treeRow.modelData.fileId
                                    selectedOverridesHover: true
                                    idleColor: "transparent"
                                    hoverColor: Theme.hoverMuted
                                    pressedColor: selected ? "transparent" : Theme.hoverMuted
                                    selectedColor: "transparent"
                                    foregroundColor: Theme.fgDim
                                    selectedForegroundColor: "#000000"
                                    hoverForegroundColor: Theme.fg
                                    pressedForegroundColor: selected ? "#000000" : Theme.fg
                                    onSelectedChanged: { if (selected) treeSelection.targetItem = fileRow }
                                    Component.onCompleted: {
                                        if (selected) treeSelection.targetItem = fileRow
                                    }
                                    activeFocusOnTab: true
                                    focused: activeFocus
                                    onClicked: root.fileSelected(treeRow.modelData.fileId)
                                    Keys.onReturnPressed: clicked()
                                    Keys.onSpacePressed: clicked()
                                    SettingsTooltip {
                                        target: fileRow
                                        active: fileRow.hovered || fileRow.activeFocus
                                        text: treeRow.modelData.fileId
                                    }
                                }
                                Row {
                                    z: 2
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 4
                                    ConfigTreeConnector {
                                        height: parent.height
                                        depth: treeRow.modelData.depth
                                        ancestorLast: treeRow.modelData.ancestorLast
                                        isLast: treeRow.modelData.isLast
                                        lineColor: treeRow.modelData.type === "file" ? fileRow.foreground : Theme.fgMuted
                                    }
                                    Text {
                                        width: Math.max(0, parent.width - (treeRow.modelData.depth + 1) * 14 - 4 - parent.spacing)
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        text: treeRow.modelData.label
                                        color: treeRow.modelData.type === "file" ? fileRow.foreground : Theme.fgDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Math.max(10, Theme.fontSize - 1)
                                        font.weight: treeRow.modelData.type === "directory" ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Column {
                id: buttonColumn
                z: 1
                visible: root.buttonsView
                width: Math.max(0, fileScroll.width - fileBar.reservedGutter)
                spacing: 10
                onPositioningComplete: buttonSelection.syncTarget(false)
                Repeater {
                    model: ConfigEditorStore.files
                    delegate: SettingsActionButton {
                        id: fileButton
                        settingsNavRole: "sidebar"
                        required property var modelData
                        width: buttonColumn.width
                        height: 40
                        text: TreeModel.title(modelData.id)
                        fontSize: Math.max(10, Theme.fontSize - 1)
                        selected: ConfigEditorStore.selectedFileId === modelData.id
                        selectedOverridesHover: true
                        idleColor: "transparent"
                        hoverColor: Theme.hoverMuted
                        selectedColor: "transparent"
                        pressedColor: selected ? "transparent" : Theme.hoverMuted
                        foregroundColor: Theme.fgDim
                        selectedForegroundColor: "#000000"
                        hoverForegroundColor: Theme.fg
                        pressedForegroundColor: selected ? "#000000" : Theme.fg
                        onSelectedChanged: { if (selected) buttonSelection.targetItem = fileButton }
                        Component.onCompleted: {
                            if (selected) buttonSelection.targetItem = fileButton
                        }
                        activeFocusOnTab: true
                        focused: activeFocus
                        onClicked: root.fileSelected(modelData.id)
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                        SettingsTooltip {
                            target: fileButton
                            active: fileButton.hovered || fileButton.activeFocus
                            text: fileButton.modelData.id
                        }
                    }
                }
            }
        }
        SettingsActionButton {
            id: refreshButton
            settingsNavRole: "sidebar"
            x: 14
            width: Math.max(0, parent.width - 28)
            height: 36
            text: "Refresh files"
            idleColor: Theme.hoverMuted
            hoverColor: Qt.lighter(Theme.hoverMuted, 1.18)
            foregroundColor: Theme.fg
            hoverForegroundColor: Theme.fg
            activeFocusOnTab: true
            focused: activeFocus
            onClicked: ConfigEditorStore.refreshFiles()
            Keys.onReturnPressed: clicked()
            Keys.onSpacePressed: clicked()
            SettingsTooltip {
                target: refreshButton
                active: refreshButton.hovered || refreshButton.activeFocus
                text: "Scan wm and config folders for files again."
            }
        }
    }
}
