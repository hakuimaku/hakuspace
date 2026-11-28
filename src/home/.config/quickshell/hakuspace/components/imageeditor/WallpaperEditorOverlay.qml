import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../services/WallpaperStackModel.js" as StackModel
import "../motion" as Motion
import "../settings" as Settings
import "../wallpaper" as Wallpaper

PanelWindow {
    id: root
    required property var modelData
    readonly property bool panelOpen: !!modelData && UiState.activePanel === "imageEditor"
        && UiState.imageEditorScreenName === modelData.name && ImageEditor.mode === "wallpaper"
    readonly property bool opening: panelOpen && !ImageEditor.closing
    readonly property bool releaseReady: !panelOpen && expansion === 0 && !motion.running
    property real expansion: 0
    property string outputStem: ""
    property string outputExt: ".png"
    property string activeRatioId: "free"

    readonly property real screenRatio: modelData && modelData.height > 0 ? modelData.width / modelData.height : 16 / 9
    readonly property int screenPixelWidth: modelData ? Math.round(modelData.width * (modelData.devicePixelRatio || 1)) : 1920
    readonly property int screenPixelHeight: modelData ? Math.round(modelData.height * (modelData.devicePixelRatio || 1)) : 1080
    readonly property var sourceParts: StackModel.splitPath(ImageEditor.sourcePath)
    readonly property var dirSiblings: sourceParts.dir ? WallpaperLibrary.siblingsInDir(sourceParts.dir) : ({paths: [], stems: []})
    readonly property var savePlan: ImageEditor.sourcePath
        ? StackModel.classifyOutputName(ImageEditor.sourcePath, outputStem, outputExt, dirSiblings.paths)
        : ({valid: false, error: "", targetPath: "", overwrite: false, stacksWithSource: false, targetBase: ""})
    readonly property bool canSave: ImageEditor.ready && workspace.imageReady && savePlan.valid
    readonly property bool belowScreenResolution: ImageEditor.ready
        && (ImageEditor.outputSize.width < screenPixelWidth || ImageEditor.outputSize.height < screenPixelHeight)

    readonly property int titleFontSize: Theme.fontSize + 6
    readonly property int bodyFontSize: Theme.fontSize + 1
    readonly property int metaFontSize: Theme.fontSize
    readonly property int actionHeight: Math.max(46, Math.round(Theme.fontSize * 3.1))
    readonly property int barHeight: Math.max(48, Math.round(Theme.fontSize * 3.2))
    readonly property int laneInset: 6

    readonly property var ratioOptions: [
        {id: "free", label: "Free", ratio: 0},
        {id: "screen", label: "Screen", ratio: screenRatio},
        {id: "16:9", label: "16:9", ratio: 16 / 9},
        {id: "16:10", label: "16:10", ratio: 16 / 10},
        {id: "21:9", label: "21:9", ratio: 21 / 9},
        {id: "4:3", label: "4:3", ratio: 4 / 3},
        {id: "1:1", label: "1:1", ratio: 1}
    ]
    readonly property var formatOptions: [
        {label: "PNG", ext: ".png"},
        {label: "JPG", ext: ".jpg"},
        {label: "WebP", ext: ".webp"}
    ]
    readonly property int activeRatioIndex: {
        var idx = ratioOptions.findIndex(function(option) { return option.id === activeRatioId })
        return idx >= 0 ? idx : 0
    }
    readonly property int activeFormatIndex: {
        var idx = formatOptions.findIndex(function(option) { return option.ext === outputExt })
        return idx >= 0 ? idx : 0
    }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: panelOpen || expansion > 0
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hakuspace-wallpaper-editor"
    WlrLayershell.keyboardFocus: opening && UiState.ownsInteraction("imageEditor", modelData.name)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: scene; width: root.opening ? scene.width : 0; height: root.opening ? scene.height : 0 }

    function initOutputDefaults() {
        if (!ImageEditor.sourcePath) return
        var src = StackModel.splitPath(ImageEditor.sourcePath)
        var siblings = WallpaperLibrary.siblingsInDir(src.dir)
        outputStem = StackModel.defaultEditStem(src.stem, siblings.stems)
        outputExt = StackModel.defaultOutputExtension(src.ext)
        activeRatioId = "free"
    }
    function selectRatio(option) {
        activeRatioId = option.id
        ImageEditor.setRatio(option.ratio)
    }
    function syncRatioFromEditor() {
        var current = ratioOptions.find(function(option) { return option.id === activeRatioId })
        if (current && Math.abs(current.ratio - ImageEditor.cropRatio) < 0.001) return
        var match = ratioOptions.find(function(option) { return Math.abs(option.ratio - ImageEditor.cropRatio) < 0.001 })
        activeRatioId = match ? match.id : ""
    }
    function animate() {
        motion.stop(); motion.to = opening ? 1 : 0
        if (expansion !== motion.to) motion.start()
        else if (!opening) Qt.callLater(finishClose)
        if (opening) scene.forceActiveFocus()
    }
    function finishClose() {
        if (expansion === 0 && !opening && modelData && ImageEditor.screenName === modelData.name) ImageEditor.finishClose()
    }
    function save(applyNow) {
        if (!canSave) return
        ImageEditor.save(savePlan.targetPath, {overwrite: savePlan.overwrite, applyAfterSave: !!applyNow})
    }

    onOpeningChanged: {
        if (opening) initOutputDefaults()
        animate()
    }
    Component.onCompleted: {
        if (opening) initOutputDefaults()
        animate()
    }

    Connections {
        target: ImageEditor
        function onSourcePathChanged() { if (root.opening) root.initOutputDefaults() }
        function onCropRatioChanged() { root.syncRatioFromEditor() }
    }

    NumberAnimation {
        id: motion; target: root; property: "expansion"; duration: HAnimation.slow
        easing.type: Easing.InOutCubic
        onFinished: root.finishClose()
    }

    FocusScope {
        id: scene
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { ImageEditor.close(); event.accepted = true }
            else if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_Z) { ImageEditor.undo(!!(event.modifiers & Qt.ShiftModifier)); event.accepted = true }
                else if (event.key === Qt.Key_S) { root.save(!!(event.modifiers & Qt.ShiftModifier)); event.accepted = true }
            }
        }

        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.surface, root.expansion * 0.72) }

        Item {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.9, 1440)
            height: Math.min(parent.height * 0.9, 960)
            clip: true
            Item {
                anchors.centerIn: parent
                width: panel.width * root.expansion
                height: panel.height * (0.08 + root.expansion * 0.92)
                clip: true

                Rectangle {
                    id: surfaceRect
                    anchors.fill: parent
                    radius: Theme.largeRadius
                    color: Theme.surface
                    border.width: 0
                    clip: true

                    // Match the static ink grid texture used by Settings and ActionMenu.
                    Item {
                        anchors.fill: parent
                        opacity: 0.025
                        Repeater {
                            model: Math.floor(surfaceRect.height / 28)
                            Rectangle { required property int index; y: (index + 1) * 28; width: surfaceRect.width; height: 1; color: Theme.fg }
                        }
                        Repeater {
                            model: Math.floor(surfaceRect.width / 28)
                            Rectangle { required property int index; x: (index + 1) * 28; width: 1; height: surfaceRect.height; color: Theme.fg }
                        }
                    }
                }

                ColumnLayout {
                    id: body
                    width: panel.width - Theme.actionLayerPadding * 2
                    height: panel.height - Theme.actionLayerPadding * 2
                    anchors.centerIn: parent
                    spacing: Theme.actionLayerSectionSpacing

                    RowLayout {
                        id: header
                        Layout.fillWidth: true
                        spacing: Theme.spaceMd

                        Settings.SettingsActionButton {
                            objectName: "wallpaper-editor-cancel"
                            Layout.preferredHeight: root.actionHeight
                            Layout.preferredWidth: Math.max(92, cancelMetrics.advanceWidth + 36)
                            radius: Theme.radius
                            border.width: 0
                            idleColor: Theme.hoverMuted
                            hoverColor: Theme.hoverMuted
                            fontSize: root.bodyFontSize
                            text: "Cancel"
                            enabled: !ImageEditor.busy
                            activeFocusOnTab: true
                            hoverScaleDelta: 0.05; hoverXScaleDelta: 0
                            pressScaleDelta: 0.03; pressXScaleDelta: 0
                            TextMetrics { id: cancelMetrics; text: "Cancel"; font.family: Theme.fontFamily; font.pixelSize: root.bodyFontSize }
                            onClicked: ImageEditor.close()
                            Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.spaceSm
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: "Edit wallpaper"
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: root.titleFontSize
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: root.sourceParts.filename.length > 0
                                text: root.sourceParts.filename
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                color: Theme.fgMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: root.metaFontSize
                            }
                        }

                        Row {
                            spacing: Theme.spaceSm
                            Settings.SettingsActionButton {
                                objectName: "wallpaper-editor-undo"
                                width: Math.max(76, undoMetrics.advanceWidth + 28)
                                height: root.actionHeight
                                radius: Theme.radius
                                border.width: 0
                                idleColor: Theme.hoverMuted
                                hoverColor: Theme.hoverMuted
                                fontSize: root.bodyFontSize
                                text: "Undo"
                                enabled: !ImageEditor.busy && ImageEditor.undoStack.length > 0
                                activeFocusOnTab: true
                                hoverScaleDelta: 0.05; hoverXScaleDelta: 0
                                pressScaleDelta: 0.03; pressXScaleDelta: 0
                                TextMetrics { id: undoMetrics; text: "Undo"; font.family: Theme.fontFamily; font.pixelSize: root.bodyFontSize }
                                onClicked: ImageEditor.undo(false)
                                Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                            }
                            Settings.SettingsActionButton {
                                objectName: "wallpaper-editor-redo"
                                width: Math.max(76, redoMetrics.advanceWidth + 28)
                                height: root.actionHeight
                                radius: Theme.radius
                                border.width: 0
                                idleColor: Theme.hoverMuted
                                hoverColor: Theme.hoverMuted
                                fontSize: root.bodyFontSize
                                text: "Redo"
                                enabled: !ImageEditor.busy && ImageEditor.redoStack.length > 0
                                activeFocusOnTab: true
                                hoverScaleDelta: 0.05; hoverXScaleDelta: 0
                                pressScaleDelta: 0.03; pressXScaleDelta: 0
                                TextMetrics { id: redoMetrics; text: "Redo"; font.family: Theme.fontFamily; font.pixelSize: root.bodyFontSize }
                                onClicked: ImageEditor.undo(true)
                                Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                            }
                            Settings.SettingsActionButton {
                                objectName: "wallpaper-editor-reset"
                                width: Math.max(82, resetMetrics.advanceWidth + 28)
                                height: root.actionHeight
                                radius: Theme.radius
                                border.width: 0
                                idleColor: Theme.hoverMuted
                                hoverColor: Theme.hoverMuted
                                fontSize: root.bodyFontSize
                                text: "Reset"
                                enabled: !ImageEditor.busy && ImageEditor.dirty
                                activeFocusOnTab: true
                                hoverScaleDelta: 0.05; hoverXScaleDelta: 0
                                pressScaleDelta: 0.03; pressXScaleDelta: 0
                                TextMetrics { id: resetMetrics; text: "Reset"; font.family: Theme.fontFamily; font.pixelSize: root.bodyFontSize }
                                onClicked: ImageEditor.reset()
                                Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                            }
                        }

                        Settings.SettingsActionButton {
                            objectName: "wallpaper-editor-save-apply"
                            Layout.preferredHeight: root.actionHeight
                            Layout.preferredWidth: Math.max(156, saveApplyMetrics.advanceWidth + 36)
                            radius: Theme.radius
                            border.width: 0
                            idleColor: Theme.hoverMuted
                            hoverColor: Theme.hoverMuted
                            fontSize: root.bodyFontSize
                            text: root.savePlan.overwrite ? "Save & Apply" : "Save As & Apply"
                            enabled: root.canSave
                            activeFocusOnTab: true
                            hoverScaleDelta: 0.05; hoverXScaleDelta: 0
                            pressScaleDelta: 0.03; pressXScaleDelta: 0
                            TextMetrics { id: saveApplyMetrics; text: root.savePlan.overwrite ? "Save & Apply" : "Save As & Apply"; font.family: Theme.fontFamily; font.pixelSize: root.bodyFontSize }
                            onClicked: root.save(true)
                            Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }

                        Settings.SettingsActionButton {
                            objectName: "wallpaper-editor-save"
                            Layout.preferredHeight: root.actionHeight
                            Layout.preferredWidth: Math.max(128, savePrimaryMetrics.advanceWidth + 40)
                            radius: Theme.radius
                            border.width: 0
                            fontSize: root.bodyFontSize
                            text: ImageEditor.busy ? "Saving…" : root.savePlan.overwrite ? "Overwrite" : "Save As"
                            enabled: root.canSave
                            selected: true
                            activeFocusOnTab: true
                            hoverScaleDelta: 0.05; hoverXScaleDelta: 0
                            pressScaleDelta: 0.03; pressXScaleDelta: 0
                            TextMetrics { id: savePrimaryMetrics; text: ImageEditor.busy ? "Saving…" : root.savePlan.overwrite ? "Overwrite" : "Save As"; font.family: Theme.fontFamily; font.pixelSize: root.bodyFontSize }
                            onClicked: root.save(false)
                            Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked()
                        }
                    }

                    ImageEditorWorkspace {
                        id: workspace
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        showAnnotations: false
                        circularGuide: false
                        backgroundRadius: Theme.largeRadius
                    }

                    RowLayout {
                        id: controlBar
                        Layout.fillWidth: true
                        spacing: Theme.spaceLg
                        enabled: ImageEditor.ready

                        Rectangle {
                            id: ratioLane
                            objectName: "wallpaper-editor-ratios"
                            Layout.preferredWidth: ratioButtons.implicitWidth + root.laneInset * 2
                            Layout.preferredHeight: root.barHeight
                            radius: Theme.largeRadius
                            color: Theme.hoverMuted
                            border.width: 0
                            Motion.SelectionPill {
                                id: ratioPill
                                coordinateSpace: ratioLane
                                color: Theme.accent
                                shown: root.activeRatioIndex >= 0
                                targetItem: ratioRepeater.count > 0 && root.activeRatioIndex >= 0
                                    ? ratioRepeater.itemAt(root.activeRatioIndex) : null
                            }
                            Row {
                                id: ratioButtons
                                z: 1
                                anchors.centerIn: parent
                                spacing: Theme.spaceXs
                                onPositioningComplete: ratioPill.syncTarget(true)
                                Repeater {
                                    id: ratioRepeater
                                    model: root.ratioOptions
                                    delegate: Wallpaper.WallpaperActionButton {
                                        id: ratioButton
                                        required property var modelData
                                        objectName: "wallpaper-editor-ratio-" + modelData.id
                                        width: Math.max(66, ratioLabelMetrics.advanceWidth + 28)
                                        height: ratioLane.height - root.laneInset * 2
                                        radius: Math.max(6, ratioLane.radius - root.laneInset)
                                        border.width: 0
                                        expandedVisual: false
                                        hoverScaleDelta: 0.05
                                        hoverXScaleDelta: 0
                                        pressScaleDelta: 0.03
                                        pressXScaleDelta: 0
                                        idleColor: "transparent"
                                        hoverColor: "transparent"
                                        selectedColor: "transparent"
                                        pressedColor: "transparent"
                                        focusColor: "transparent"
                                        foregroundColor: Theme.fgMuted
                                        hoverForegroundColor: selected ? selectedForegroundColor : Theme.fg
                                        selectedForegroundColor: Theme.onAccentColor
                                        selected: root.activeRatioId === modelData.id
                                        fontSize: root.bodyFontSize
                                        text: modelData.label
                                        Accessible.name: "Crop ratio " + modelData.label
                                        TextMetrics {
                                            id: ratioLabelMetrics
                                            text: ratioButton.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: ratioButton.fontSize
                                        }
                                        onClicked: root.selectRatio(modelData)
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Row {
                            id: transformRow
                            spacing: Theme.spaceSm
                            Repeater {
                                model: [
                                    {label: "Rotate left", icon: "󰑥", operation: "ccw"},
                                    {label: "Rotate right", icon: "󰑧", operation: "cw"},
                                    {label: "Flip H", icon: "󱃧", operation: "horizontal"},
                                    {label: "Flip V", icon: "󱃨", operation: "vertical"}
                                ]
                                Wallpaper.WallpaperToolbarButton {
                                    required property var modelData
                                    objectName: "wallpaper-editor-transform-" + modelData.operation
                                    height: root.barHeight
                                    width: root.barHeight
                                    radius: Theme.largeRadius
                                    border.width: 0
                                    idleColor: Theme.hoverMuted
                                    hoverColor: Theme.hoverMuted
                                    hoverScaleDelta: 0.05
                                    hoverXScaleDelta: 0
                                    pressScaleDelta: 0.03
                                    icon: modelData.icon
                                    iconSize: Theme.fontSize + 6
                                    description: modelData.label
                                    useSettingsTooltip: true
                                    onClicked: ImageEditor.orient(modelData.operation)
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: saveBar
                        Layout.fillWidth: true
                        spacing: Theme.spaceLg

                        Text {
                            id: nameLabel
                            text: "File name"
                            color: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.bodyFontSize
                            font.weight: Font.Medium
                        }

                        TextField {
                            id: nameField
                            objectName: "wallpaper-editor-filename"
                            ContextMenu.menu: null
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.barHeight
                            text: root.outputStem
                            placeholderText: "Wallpaper name…"
                            color: Theme.fg
                            placeholderTextColor: Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.bodyFontSize + 1
                            leftPadding: 20
                            rightPadding: 20
                            selectByMouse: true
                            enabled: !ImageEditor.busy
                            Accessible.name: "Output wallpaper file name"
                            background: Rectangle {
                                color: nameField.activeFocus ? Theme.surfaceHighlight(1.18) : Theme.hoverMuted
                                radius: Theme.largeRadius
                                border.width: 0
                                Behavior on color {
                                    ColorAnimation { duration: HAnimation.fast; easing.type: Easing.OutCubic }
                                }
                                // Borderless bottom indicator signals focus or inline validation errors.
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.max(0, parent.width - Theme.largeRadius * 2)
                                    height: 2
                                    radius: 1
                                    visible: nameField.activeFocus || (!root.savePlan.valid && root.outputStem.length > 0)
                                    color: !root.savePlan.valid && root.outputStem.length > 0 ? Theme.danger : Theme.accent
                                }
                            }
                            onTextEdited: root.outputStem = text
                            Keys.onReturnPressed: event => {
                                root.save(!!(event.modifiers & Qt.ShiftModifier))
                                event.accepted = true
                            }
                            Keys.onEnterPressed: event => {
                                root.save(!!(event.modifiers & Qt.ShiftModifier))
                                event.accepted = true
                            }
                            Keys.onEscapePressed: event => {
                                ImageEditor.close()
                                event.accepted = true
                            }
                        }

                        Rectangle {
                            id: formatLane
                            objectName: "wallpaper-editor-format"
                            Layout.preferredWidth: 236
                            Layout.preferredHeight: root.barHeight
                            radius: Theme.largeRadius
                            color: Theme.hoverMuted
                            border.width: 0
                            Item {
                                id: formatTrack
                                anchors.fill: parent
                                anchors.margins: root.laneInset
                                Motion.SelectionPill {
                                    targetIndex: root.activeFormatIndex
                                    slotCount: root.formatOptions.length
                                    slotSpacing: Theme.spaceXs
                                    radius: Math.max(6, formatLane.radius - root.laneInset)
                                }
                                Row {
                                    z: 1
                                    anchors.fill: parent
                                    spacing: Theme.spaceXs
                                    Repeater {
                                        model: root.formatOptions
                                        delegate: Wallpaper.WallpaperActionButton {
                                            required property var modelData
                                            objectName: "wallpaper-editor-ext-" + modelData.label.toLowerCase()
                                            width: (formatTrack.width - Theme.spaceXs * 2) / 3
                                            height: formatTrack.height
                                            radius: Math.max(6, formatLane.radius - root.laneInset)
                                            border.width: 0
                                            expandedVisual: false
                                            hoverScaleDelta: 0.05
                                            hoverXScaleDelta: 0
                                            pressScaleDelta: 0.03
                                            pressXScaleDelta: 0
                                            idleColor: "transparent"
                                            hoverColor: "transparent"
                                            selectedColor: "transparent"
                                            pressedColor: "transparent"
                                            focusColor: "transparent"
                                            foregroundColor: Theme.fgMuted
                                            hoverForegroundColor: selected ? selectedForegroundColor : Theme.fg
                                            selectedForegroundColor: Theme.onAccentColor
                                            selected: root.outputExt === modelData.ext
                                            fontSize: root.bodyFontSize
                                            text: modelData.label
                                            enabled: !ImageEditor.busy
                                            onClicked: root.outputExt = modelData.ext
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: statusRow
                        Layout.fillWidth: true
                        spacing: Theme.spaceLg

                        Text {
                            id: resolutionInfo
                            text: ImageEditor.ready
                                ? (ImageEditor.orientedWidth + " × " + ImageEditor.orientedHeight + "  →  "
                                    + ImageEditor.outputSize.width + " × " + ImageEditor.outputSize.height
                                    + (root.belowScreenResolution ? "  ·  Below " + root.screenPixelWidth + "×" + root.screenPixelHeight : ""))
                                : "Loading image…"
                            textFormat: Text.PlainText
                            color: root.belowScreenResolution ? Theme.warning : Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.metaFontSize
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            id: saveHint
                            objectName: "wallpaper-editor-save-hint"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            text: ImageEditor.lastError
                                ? ImageEditor.lastError
                                : !root.savePlan.valid
                                    ? root.savePlan.error
                                    : root.savePlan.overwrite
                                        ? "Overwrites this edited wallpaper"
                                        : root.savePlan.stacksWithSource
                                            ? "Stacks with " + root.savePlan.targetBase
                                            : "Saves as standalone wallpaper"
                            textFormat: Text.PlainText
                            color: ImageEditor.lastError || !root.savePlan.valid
                                ? Theme.danger
                                : root.savePlan.overwrite
                                    ? Theme.warning
                                    : root.savePlan.stacksWithSource
                                        ? Theme.accent
                                        : Theme.fgMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: root.metaFontSize
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
