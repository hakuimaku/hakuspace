import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell.Io
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog
import "../base" as Base
import "../motion" as Motion
import "../flare" as Flare

FocusScope {
    id: root
    // Keep the existing browser API backed by the shared lightweight session.
    property string presentation: "quick"
    readonly property bool workspace: presentation === "workspace"
    property real reveal: 1
    // Closing opacity can lag behind the geometric zoom progress.
    property real contentOpacity: reveal
    property real spread: 1
    property real selectedPulse: 1
    property bool refreshOnShow: true
    // Only the requested settings section owns a disposable editor tree.
    property string settingsSection: ""
    readonly property var items: WallpaperLibrary.items
    property string query: WallpaperLibrary.query
    onQueryChanged: {
        if (carousel) carousel.stopIntro()
        if (WallpaperLibrary.query !== query) WallpaperLibrary.query = query
    }
    property string filter: WallpaperLibrary.filter
    onFilterChanged: {
        if (filter !== "video") settingsSection = ""
        if (carousel) carousel.stopIntro()
        if (WallpaperLibrary.filter !== filter) WallpaperLibrary.filter = filter
    }
    readonly property string profile: WallpaperSettingsStore.savedValues.playback.profile
    readonly property bool refreshPending: WallpaperLibrary.refreshPending
    readonly property bool loading: WallpaperLibrary.loading
    readonly property bool openingReady: WallpaperLibrary.initialized && !loading && carousel.thumbnailsSettled
    readonly property bool interactionReady: visible && !loading && WallpaperLibrary.initialized
    readonly property var filteredItems: WallpaperLibrary.filteredItems
    readonly property var selected: WallpaperLibrary.selected
    // Bound Unicode characters as well as pixels so long filenames cannot crowd controls.
    readonly property string selectedTitle: {
        var characters = Array.from(selected ? selected.label : "Choose a wallpaper")
        return characters.length > 48 ? characters.slice(0, 47).join("") + "…" : characters.join("")
    }
    // Probe only the hovered source; the backend reuses fingerprinted metadata.
    readonly property string tooltipSourceKey: selected ? selected.path + ":" + (selected.previewVersion || "") : ""
    property string inspectedKey: ""
    property var inspectedMetadata: ({})
    readonly property var selectedMetadata: selected && selected.metadata ? selected.metadata
        : tooltipSourceKey === inspectedKey ? inspectedMetadata : ({})
    readonly property string selectedTooltip: {
        if (!selected) return ""
        var metadata = selectedMetadata
        var lines = [selected.kind === "video" ? "Lively Wallpaper" : "Image Wallpaper"]
        if (metadata.width > 0 && metadata.height > 0)
            lines.push("Original: " + metadata.width + " × " + metadata.height + (selected.kind === "video" && metadata.fps > 0 ? " · " + Number(metadata.fps.toFixed(2)) + " FPS" : ""))
        var bytes = metadata.fileSize || selected.fileSize
        if (bytes > 0) {
            var unit = bytes >= 1073741824 ? "GiB" : bytes >= 1048576 ? "MiB" : bytes >= 1024 ? "KiB" : "B"
            var divisor = unit === "GiB" ? 1073741824 : unit === "MiB" ? 1048576 : unit === "KiB" ? 1024 : 1
            lines.push("Size: " + Number((bytes / divisor).toFixed(2)) + " " + unit)
        }
        if (metadata.codec) lines.push("Format: " + metadata.codec.toUpperCase())
        if (metadata.durationMs > 0 && selected.kind === "video") {
            var seconds = Math.round(metadata.durationMs / 1000)
            lines.push("Duration: " + Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0"))
        }
        if (selected.kind === "video") lines.push("Playback quality: " + (profile === "low-memory" ? "720p / 24 FPS" : profile === "screen" ? "Screen" : "Original"))
        if (!metadata.width) lines.push(tooltipSourceKey === inspectedKey && !metadataProbe.running ? "Metadata unavailable" : "Reading metadata…")
        return lines.join("\n")
    }
    onTooltipSourceKeyChanged: requestMetadata()

    // Keep a late result associated with its source while coalescing hover changes.
    function requestMetadata() {
        if (!workspace || !titleTooltip || !titleTooltip.active || !selected || selected.metadata || inspectedKey === tooltipSourceKey || metadataProbe.running) return
        inspectedKey = tooltipSourceKey
        inspectedMetadata = ({})
        metadataProbe.command = WallpaperService.command(["inspect", selected.path])
        metadataProbe.running = true
    }
    Process {
        id: metadataProbe
        stdout: StdioCollector { id: metadataOutput }
        onExited: code => {
            try { root.inspectedMetadata = code === 0 ? JSON.parse(metadataOutput.text) : ({}) }
            catch (error) { root.inspectedMetadata = ({}) }
            metadataFollowup.restart()
        }
    }
    Timer { id: metadataFollowup; interval: 0; onTriggered: root.requestMetadata() }
    readonly property var kinds: UiCatalog.wallpaperKinds
    // The quick input region surrounds controls without painting a container.
    readonly property Item quickInputItem: quickBounds
    readonly property Item topInputItem: workspaceControls
    readonly property Item bottomInputItem: bottomBounds
    readonly property Item settingsInputItem: details
    readonly property Item selectedInputItem: workspace ? carousel.currentItem : null
    readonly property real topPanelHeight: Theme.topBarHeight
    readonly property real toolbarControlHeight: Math.max(24, Math.floor(topPanelHeight - 12))
    readonly property real bottomPanelHeight: height * 0.15
    readonly property real panelPadding: 16
    readonly property real mediaTabHeight: Math.max(44, toolbarControlHeight + 12)
    readonly property real mediaTabWidth: Math.min(Math.max(320, Theme.fontSize * 20), width - panelPadding * 4)
    // Reserve category navigation above the gallery in both presentations.
    readonly property real categoryTabHeight: Math.max(32, toolbarControlHeight)
    readonly property real panelTopPadding: mediaTabHeight + Theme.gap + categoryTabHeight + panelPadding * 2
    // Overlay surfaces match the bars without changing their state or reservations.
    readonly property real bottomBarHeight: ScreenGeometry.taskbarHeight
    // Every visual in a panel shares one translation, including open settings.
    readonly property real topSlide: -(topPanelHeight + Math.max(ScreenGeometry.roundedRadius + topPanel.seamOverlap, details.travelHeight)) * (1 - reveal)
    readonly property real bottomSlide: (bottomPanel.height + bottomBarHeight) * (1 - reveal)
    signal closeRequested()
    signal settingsRequested()

    Connections {
        target: WallpaperLibrary
        function onQueryChanged() { root.query = WallpaperLibrary.query }
        function onFilterChanged() { root.filter = WallpaperLibrary.filter }
        function onActiveCategoryChanged() { carousel.stopIntro() }
        function onSelectedPathChanged() {
            if (!root.workspace && root.enabled && root.interactionReady && root.reveal === 1
                    && !carousel.introRunning && !carousel.introPending) navigationBounce.restart()
        }
    }

    // Public callers delegate selection and refresh to the same session.
    function refresh() { WallpaperLibrary.refresh() }
    function move(step) { carousel.move(step) }
    function playIntro() { carousel.playIntro() }
    function pauseIntro() { carousel.pauseIntro() }
    function resumeIntro() { carousel.resumeIntro() }
    function applySelected() {
        carousel.stopIntro()
        var accepted = WallpaperLibrary.applySelected()
        if (accepted && !workspace) dismiss()
        return accepted
    }
    function dismiss() { closeRequested() }
    // Shuffle changes only browsing selection, including video items.
    function shuffle() {
        if (filteredItems.length > 1) move(1 + Math.floor(Math.random() * (filteredItems.length - 1)))
    }
    // Category arrows and shortcuts stop at either end of the current media's list.
    function moveCategory(step) {
        var categories = WallpaperLibrary.categories
        var index = categories.indexOf(WallpaperLibrary.activeCategory)
        WallpaperLibrary.setCategory(categories[Math.max(0, Math.min(categories.length - 1, index + step))])
    }

    // Parent-priority dispatch keeps apply and navigation consistent inside inputs.
    function handleShortcut(event) {
        var control = event.modifiers === Qt.ControlModifier
        // Alt navigates categories without consuming the media selector's Ctrl shortcuts.
        var alt = event.modifiers === Qt.AltModifier
        var plain = event.modifiers === Qt.NoModifier
        if (plain && event.key === Qt.Key_Escape) dismiss()
        else if (settingsSection) return false
        else if (control && [Qt.Key_Return, Qt.Key_Enter].includes(event.key)) UiState.enterWallpaperWorkspace()
        else if (plain && [Qt.Key_Return, Qt.Key_Enter].includes(event.key) && !categoryLane.activeFocus) applySelected()
        else if ((control && event.key === Qt.Key_F) || (plain && event.key === Qt.Key_Slash && !search.activeFocus)) search.forceActiveFocus()
        else if ((control || alt) && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            var step = [Qt.Key_Left, Qt.Key_Up].includes(event.key) ? -1 : 1
            if (control) filter = kinds[(kinds.findIndex(choice => choice.id === filter) + step + kinds.length) % kinds.length].id
            else {
                moveCategory(step)
                if (categoryLane.activeFocus) {
                    // Keep Enter/Space on the category selected by the shortcut.
                    var button = categoryButtons.children.find(item => item.modelData === WallpaperLibrary.activeCategory)
                    if (button) button.forceActiveFocus()
                }
            }
        } else if (plain && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key) && (!search.activeFocus || [Qt.Key_Up, Qt.Key_Down].includes(event.key))) {
            search.focus = false
            carousel.forceActiveFocus()
            move([Qt.Key_Left, Qt.Key_Up].includes(event.key) ? -1 : 1)
        } else return false
        event.accepted = true
        return true
    }
    Keys.onPressed: event => handleShortcut(event)
    onVisibleChanged: if (visible && refreshOnShow) refresh()
    Component.onCompleted: if (visible && refreshOnShow) refresh()

    // Panel surfaces and their content slide together without resizing the host.
    Flare.FlareSurface {
        id: topPanel
        objectName: "wallpaperTopPanel"
        y: root.topSlide
        visible: root.workspace
        width: root.width
        attach: Flare.FlareHost.Top
        start: ScreenGeometry.leftInset
        end: root.width - ScreenGeometry.rightInset
        currentHeight: root.topPanelHeight
        bounds: ScreenGeometry.horizontalBounds(root.width)
        r: ScreenGeometry.roundedRadius
        rf: ScreenGeometry.roundedRadius
        surfaceColor: Theme.surface
    }
    Rectangle {
        id: bottomBar
        objectName: "wallpaperBottomBar"
        z: 10
        visible: root.workspace
        y: root.height - height + root.bottomSlide
        width: root.width
        height: root.bottomBarHeight
        color: Theme.surface
    }
    // Rounded shoulders and upward flares join the gallery to the screen rails.
    Shape {
        id: bottomPanel
        objectName: "wallpaperBottomPanel"
        visible: root.workspace
        x: ScreenGeometry.leftInset
        y: root.height - root.bottomBarHeight - height + root.bottomSlide
        width: root.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset
        // Keep the raised selection and its padding inside the chassis shoulders.
        height: Math.max(1, carousel.cardWidth * 9 / 16 * carousel.selectedScale + carousel.selectedLift
            + carousel.contentPadding - root.bottomBarHeight + root.panelTopPadding)
        readonly property real topWidth: Math.max(carousel.cardWidth * carousel.selectedScale, root.mediaTabWidth) + root.panelPadding * 4
        readonly property real upperLeft: (width - topWidth) / 2
        readonly property real upperRight: (width + topWidth) / 2
        readonly property real upperCornerRadius: Math.min(Math.max(Theme.giantRadius + root.panelTopPadding, ScreenGeometry.roundedRadius), topWidth / 4, height / 3)
        readonly property real flareRadius: Math.min(ScreenGeometry.edgeHugRadius, height / 3)
        readonly property real sideRun: (width - topWidth) / 2
        readonly property real sideRise: height
        readonly property real flareTop: height - flareRadius
        readonly property real sideLength: Math.max(1, Math.sqrt(sideRun * sideRun + sideRise * sideRise))
        readonly property real slopeX: sideRun / sideLength
        readonly property real slopeY: sideRise / sideLength
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.surface
            strokeColor: "transparent"
            startX: bottomPanel.upperLeft + bottomPanel.upperCornerRadius; startY: 0
            PathLine { x: bottomPanel.upperRight - bottomPanel.upperCornerRadius; y: 0 }
            PathQuad {
                controlX: bottomPanel.upperRight; controlY: 0
                x: bottomPanel.upperRight + bottomPanel.slopeX * bottomPanel.upperCornerRadius
                y: bottomPanel.slopeY * bottomPanel.upperCornerRadius
            }
            PathLine {
                x: bottomPanel.width - bottomPanel.slopeX * bottomPanel.flareRadius
                y: bottomPanel.sideRise - bottomPanel.slopeY * bottomPanel.flareRadius
            }
            PathQuad {
                controlX: bottomPanel.width; controlY: bottomPanel.height
                x: bottomPanel.width; y: bottomPanel.flareTop
            }
            PathLine { x: bottomPanel.width; y: bottomPanel.height }
            PathLine { x: 0; y: bottomPanel.height }
            PathLine { x: 0; y: bottomPanel.flareTop }
            PathQuad {
                controlX: 0; controlY: bottomPanel.height
                x: bottomPanel.slopeX * bottomPanel.flareRadius
                y: bottomPanel.sideRise - bottomPanel.slopeY * bottomPanel.flareRadius
            }
            PathLine {
                x: bottomPanel.upperLeft - bottomPanel.slopeX * bottomPanel.upperCornerRadius
                y: bottomPanel.slopeY * bottomPanel.upperCornerRadius
            }
            PathQuad {
                controlX: bottomPanel.upperLeft; controlY: 0
                x: bottomPanel.upperLeft + bottomPanel.upperCornerRadius; y: 0
            }
        }
    }
    // Balanced side groups leave the selected wallpaper name at the screen center.
    Item {
        id: workspaceControls
        objectName: "wallpaper-toolbar"
        y: root.topSlide
        visible: root.workspace
        width: root.width
        height: root.topPanelHeight
        Item {
            id: toolbar
            anchors.fill: parent
            readonly property bool compact: root.width < 1600 || Theme.fontSize > 16
            readonly property bool dense: root.width < 1200
            readonly property int libraryFontSize: dense ? Math.min(13, Theme.fontSize - 1) : Theme.fontSize - 1
            readonly property real edgePadding: compact ? 16 : 24
            Text {
                id: longestModeLabel
                visible: false
                text: "Lively Wallpaper"
                font.family: Theme.fontFamily; font.pixelSize: toolbar.libraryFontSize
            }
            Row {
                id: leftTools
                x: toolbar.edgePadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: toolbar.compact ? 8 : 12
                Row {
                    id: modeBadge
                    objectName: "wallpaper-mode-badge"
                    readonly property bool wallpaperTooltipTarget: true
                    spacing: 8
                    height: root.toolbarControlHeight
                    HoverHandler { id: modeHover }
                    Text {
                        objectName: "wallpaper-mode-icon"
                        text: "\uf03e"
                        height: root.toolbarControlHeight
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24
                        Accessible.name: "Wallpaper"
                    }
                    Text {
                        objectName: "wallpaper-mode-label"
                        // Reserve the longer caption for both media modes.
                        width: Math.ceil(Math.max(implicitWidth, longestModeLabel.implicitWidth))
                        height: root.toolbarControlHeight
                        text: root.filter === "video" ? "Lively Wallpaper" : "Image Wallpaper"
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignLeft
                        color: Theme.fg
                        font.family: Theme.fontFamily; font.pixelSize: toolbar.libraryFontSize
                    }
                }
                Item {
                    id: searchSlot
                    // Leave space for the centered name without hiding the library labels.
                    width: Math.max(80, Math.min(256, root.width / 2 - modeBadge.width - libraryGroup.width
                        - leftTools.spacing * 2 - toolbar.edgePadding - 76))
                    height: root.toolbarControlHeight
                }
                Rectangle {
                    id: libraryGroup
                    width: libraryButtons.implicitWidth + 4; height: root.toolbarControlHeight
                    radius: 8; color: Theme.hoverMuted
                    Row {
                        id: libraryButtons
                        anchors.centerIn: parent
                        spacing: 2
                        WallpaperToolbarButton {
                            objectName: "wallpaper-shuffle"
                            width: implicitWidth; height: root.toolbarControlHeight - 4
                            caption: "Shuffle"; icon: "\uf074"; description: "Shuffle selection"
                            fontSize: toolbar.libraryFontSize
                            iconSize: toolbar.dense ? 14 : 18
                            horizontalPadding: toolbar.dense ? 8 : 12
                            enabled: root.filteredItems.length > 1
                            onClicked: root.shuffle()
                        }
                        WallpaperToolbarButton {
                            objectName: "wallpaper-refresh"
                            width: implicitWidth; height: root.toolbarControlHeight - 4
                            caption: "Refresh"; icon: "\uf021"; description: "Refresh wallpaper library"
                            fontSize: toolbar.libraryFontSize
                            iconSize: toolbar.dense ? 14 : 18
                            horizontalPadding: toolbar.dense ? 8 : 12
                            enabled: !root.loading
                            onClicked: root.refresh()
                        }
                    }
                }
            }
            Base.HTooltip {
                objectName: "wallpaper-mode-tooltip"
                target: modeBadge
                text: root.filter === "video" ? "Lively wallpaper library" : "Image wallpaper library"
                active: modeHover.hovered && root.workspace
            }
            Rectangle {
                objectName: "wallpaper-title-left-separator"
                x: selectedTitle.x - 16 - width
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: root.toolbarControlHeight - 8
                color: Theme.fgMuted; opacity: 0.5
            }
            Rectangle {
                objectName: "wallpaper-title-right-separator"
                x: selectedTitle.x + selectedTitle.width + 16
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: root.toolbarControlHeight - 8
                color: Theme.fgMuted; opacity: 0.5
            }
            Text {
                id: selectedTitle
                objectName: "wallpaper-selected-title"
                anchors.centerIn: parent
                anchors.alignWhenCentered: false
                width: Math.max(0, Math.min(520, root.width - 2 * (Math.max(leftTools.width, rightTools.width) + toolbar.edgePadding + 16)))
                text: root.selectedTitle
                height: root.toolbarControlHeight
                textFormat: Text.PlainText
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold
                Accessible.name: root.selected ? root.selected.label : text
                readonly property bool wallpaperTooltipTarget: true
                // Flare must anchor to the bounded title box, not the text's natural width.
                Item {
                    id: titleTooltipAnchor
                    anchors.fill: parent
                    readonly property bool wallpaperTooltipTarget: true
                }
                Base.HTooltip {
                    id: titleTooltip
                    objectName: "wallpaper-title-tooltip"
                    target: titleTooltipAnchor
                    text: root.selectedTooltip
                    component: titleMetadataContent
                    active: titleHover.hovered && root.enabled && !!root.selected
                    onActiveChanged: if (active) root.requestMetadata()
                }
                HoverHandler { id: titleHover }
            }
            Component {
                id: titleMetadataContent
                Item {
                    id: metadataContent
                    property var payload: null
                    property real maxWidth: 0
                    // The flare's 22 px side padding completes the separator span.
                    implicitWidth: Math.max(1, Math.min(maxWidth, selectedTitle.width + 32 - 44))
                    implicitHeight: metadataText.implicitHeight
                    width: implicitWidth
                    Text {
                        id: metadataText
                        width: parent.width
                        text: metadataContent.payload && metadataContent.payload.text ? metadataContent.payload.text : ""
                        textFormat: Text.PlainText
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
            Row {
                id: rightTools
                x: parent.width - width - toolbar.edgePadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: toolbar.compact ? 8 : 12
                Rectangle {
                    id: quality
                    objectName: "wallpaper-video-quality"
                    // Compact layouts keep direct quality choices in the Playback menu.
                    visible: root.width >= 1440
                    enabled: root.filter === "video"
                    opacity: root.filter === "video" ? 1 : 0.45
                    Behavior on opacity { NumberAnimation { duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.effectsCurve } }
                    width: implicitWidth
                    height: root.toolbarControlHeight
                    readonly property var options: UiCatalog.wallpaperVideoProfiles
                    implicitWidth: qualityButtons.implicitWidth + 4
                    radius: 8
                    color: Theme.hoverMuted
                    Motion.SelectionPill {
                        objectName: "wallpaper-quality-indicator"
                        coordinateSpace: quality
                        color: Theme.accent
                        targetItem: quality.visible && qualityRepeater.count > 0 ? qualityRepeater.itemAt(quality.options.findIndex(option => option.value === WallpaperSettingsStore.values.playback.profile)) : null
                    }
                    Row {
                        id: qualityButtons
                        z: 1
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            id: qualityRepeater
                            model: quality.options
                            delegate: WallpaperToolbarButton {
                                required property var modelData
                                objectName: "wallpaper-quality-" + modelData.value
                                width: implicitWidth; height: root.toolbarControlHeight - 4
                                caption: toolbar.compact ? modelData.shortLabel : modelData.label
                                description: modelData.description
                                fontSize: Math.max(11, Theme.fontSize - 2)
                                disabledOpacity: root.filter === "video" ? 0.45 : 1
                                selectedColor: "transparent"
                                hoverColor: "transparent"
                                pressedColor: "transparent"
                                focusColor: "transparent"
                                hoverScaleDelta: 0.02
                                pressScaleDelta: 0.04
                                disabledColor: "transparent"
                                disabledForegroundColor: selected ? selectedForegroundColor : foregroundColor
                                selected: WallpaperSettingsStore.values.playback.profile === modelData.value
                                enabled: WallpaperSettingsStore.ready && !WallpaperSettingsStore.loading && !WallpaperSettingsStore.saving
                                onClicked: if (root.filter === "video") WallpaperSettingsStore.setValue("playback", "profile", modelData.value)
                            }
                        }
                    }
                }
                WallpaperToolbarButton {
                    objectName: "wallpaper-save-preferences"
                    visible: quality.visible
                    width: implicitWidth
                    caption: "Save"; description: "Save video quality preferences"
                    enabled: root.filter === "video" && WallpaperSettingsStore.ready && WallpaperSettingsStore.dirty && WallpaperSettingsStore.valid
                        && !WallpaperSettingsStore.loading && !WallpaperSettingsStore.saving
                    onClicked: if (root.filter === "video") WallpaperSettingsStore.apply()
                }
                Rectangle {
                    objectName: "wallpaper-lively-controls"
                    enabled: root.filter === "video"
                    opacity: root.filter === "video" ? 1 : 0.45
                    Behavior on opacity { NumberAnimation { duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.effectsCurve } }
                    width: preferenceButtons.implicitWidth + 4; height: root.toolbarControlHeight
                    radius: 8; color: Theme.hoverMuted
                    Row {
                        id: preferenceButtons
                        anchors.centerIn: parent
                        spacing: 2
                        WallpaperToolbarButton {
                            objectName: "wallpaper-playback"
                            width: implicitWidth; height: root.toolbarControlHeight - 4
                            caption: toolbar.compact ? "" : "Playback"
                            icon: toolbar.compact ? "\uf144" : ""
                            description: "Video playback settings"
                            disabledOpacity: 1
                            selected: root.settingsSection === "playback"
                            onClicked: if (root.filter === "video") root.settingsSection = root.settingsSection === "playback" ? "" : "playback"
                        }
                        WallpaperToolbarButton {
                            objectName: "wallpaper-cache"
                            width: implicitWidth; height: root.toolbarControlHeight - 4
                            caption: toolbar.compact ? "" : "Cache"
                            icon: toolbar.compact ? "\uf1c0" : ""
                            description: "Video cache settings"
                            disabledOpacity: 1
                            selected: root.settingsSection === "cache"
                            onClicked: if (root.filter === "video") root.settingsSection = root.settingsSection === "cache" ? "" : "cache"
                        }
                    }
                }
                WallpaperToolbarButton {
                    objectName: "wallpaper-settings"
                    width: implicitWidth
                    icon: "\uf013"; description: "All wallpaper settings"
                    fontSize: Theme.fontSize + 2
                    onClicked: root.settingsRequested()
                }
                WallpaperToolbarButton {
                    objectName: "wallpaper-close"
                    width: implicitWidth
                    icon: "\uf00d"; description: "Close wallpaper workspace"
                    fontSize: Theme.fontSize + 4
                    onClicked: root.dismiss()
                }

                WallpaperToolbarButton {
                    objectName: "wallpaper-apply"
                    width: Math.max(toolbar.dense ? 40 : 88, implicitWidth)
                    readonly property bool preparingSelection: WallpaperService.busy && !!root.selected && WallpaperService.requestedPath === root.selected.path
                    caption: toolbar.dense ? "" : preparingSelection ? "Preparing…" : WallpaperService.error ? "Retry apply" : "Apply"
                    icon: toolbar.dense ? (preparingSelection ? "\uf110" : WallpaperService.error ? "\uf071" : "\uf00c") : ""
                    description: WallpaperService.error || "Apply selected wallpaper"
                    selected: true
                    enabled: !!root.selected
                    onClicked: root.applySelected()
                }
            }
        }
    }
    // Media tabs belong to the trapezoid header and follow the entire bottom slide.
    Item {
        id: typeSlot
        objectName: "wallpaper-media-tabs"
        z: 30
        visible: root.workspace
        x: (root.width - width) / 2
        y: bottomPanel.y + root.panelPadding
        width: root.mediaTabWidth
        height: root.mediaTabHeight
    }
    Loader {
        active: root.workspace
        z: 3000
        y: root.topPanelHeight + root.topSlide
        width: root.width
        sourceComponent: Base.TooltipLayer {
            objectName: "wallpaper-tooltip-layer"
            tipAreaHeight: 180
            minimumTooltipWidth: selectedTitle.width + 32
        }
    }
    WallpaperSettingsPopover {
        id: details
        objectName: "wallpaper-settings-popover"
        z: 2000
        visible: root.workspace && displayedSection.length > 0
        section: root.settingsSection
        hostReveal: root.reveal
        x: root.width - width - ScreenGeometry.rightInset - 24
        y: root.topPanelHeight + root.topSlide
        width: Math.min(620, root.width - 64 - ScreenGeometry.leftInset - ScreenGeometry.rightInset)
        availableHeight: root.height - root.topPanelHeight - gap - root.bottomPanelHeight - 24
        onCloseRequested: { root.settingsSection = ""; root.forceActiveFocus() }
    }
    Item {
        id: quickBounds
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: Math.min(carousel.width, carousel.cardStep * 4 + carousel.cardWidth * carousel.farScale)
        height: Math.min(root.height, controls.height + root.panelPadding * 2 + carousel.height)
    }
    // The empty desktop between workspace panels remains pointer-transparent.
    Item {
        id: bottomBounds
        y: Math.min(bottomPanel.y, bottomBar.y)
        width: root.width
        height: root.height - y
    }
    // Search, media and category navigation reserve space above the quick carousel.
    Item {
        id: controls
        objectName: "wallpaper-quick-controls"
        property real navigationScale: 1
        visible: !root.workspace
        x: (parent.width - width) / 2
        y: quickBounds.y
        width: Math.min(460, parent.width - 48)
        height: searchControl.implicitHeight + 12 + typeLane.implicitHeight + Theme.gap + root.categoryTabHeight
        opacity: root.contentOpacity
        scale: (0.96 + 0.04 * root.reveal) * navigationScale
        Item {
            id: searchControl
            parent: root.workspace ? searchSlot : controls
            anchors.fill: root.workspace ? parent : undefined
            implicitHeight: 42
            width: controls.width; height: implicitHeight
            TextField {
                id: search
                objectName: "wallpaperSearch"
                anchors.fill: parent
                text: root.query
                placeholderText: "Search wallpapers…"
                color: Theme.fg
                placeholderTextColor: Theme.fgMuted
                font.family: Theme.fontFamily; font.pixelSize: root.workspace ? Theme.fontSize - 1 : Theme.fontSize
                leftPadding: 16
                rightPadding: 16
                selectByMouse: true
                hoverEnabled: true
                readonly property bool wallpaperTooltipTarget: true
                Base.HTooltip {
                    objectName: "wallpaper-search-tooltip"
                    target: search
                    text: "Search wallpapers (Ctrl+F)"
                    active: root.workspace && search.hovered
                }
                background: Rectangle { color: root.workspace ? Theme.hoverMuted : Theme.surface; radius: height / 2; border.width: root.workspace ? 1 : 0; border.color: search.activeFocus ? Theme.accent : Theme.hoverMuted }
                onTextEdited: root.query = text
                Accessible.name: "Search wallpapers"
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => root.handleShortcut(event)
            }
        }
        Rectangle {
            id: typeLane
            parent: root.workspace ? typeSlot : controls
            anchors.fill: root.workspace ? parent : undefined
            y: root.workspace ? 0 : searchControl.implicitHeight + 12
            width: root.workspace ? parent.width : Math.min(parent.width, 248)
            implicitHeight: root.workspace ? root.mediaTabHeight : 40
            height: implicitHeight
            radius: root.workspace ? 0 : height / 2
            color: root.workspace ? "transparent" : Theme.surface
            border.width: 0
            anchors.horizontalCenter: root.workspace ? undefined : parent.horizontalCenter
            readonly property real slotWidth: root.workspace ? width / 2 : (width - 12) / 2
            Rectangle {
                visible: root.workspace
                width: parent.width; height: 1
                color: Theme.hoverMuted
            }
            Rectangle {
                objectName: "wallpaper-type-top-border"
                visible: root.workspace
                x: root.kinds.findIndex(choice => choice.id === root.filter) * typeLane.slotWidth
                width: typeLane.slotWidth; height: 2
                color: Theme.accent
                Behavior on x {
                    NumberAnimation { duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                }
            }
            Item {
                visible: !root.workspace
                x: 4; y: 4; width: parent.width - 8; height: parent.height - 8
                Motion.SelectionPill {
                    objectName: "wallpaper-type-indicator"
                    targetIndex: root.kinds.findIndex(choice => choice.id === root.filter)
                    slotCount: root.kinds.length; slotSpacing: 4
                    radius: height / 2
                }
            }
            Repeater {
                model: root.kinds
                delegate: WallpaperActionButton {
                    required property var modelData
                    required property int index
                    objectName: "wallpaper-kind-" + modelData.id
                    x: root.workspace ? index * typeLane.slotWidth : 4 + index * (typeLane.slotWidth + 4)
                    y: root.workspace ? 0 : 4
                    width: typeLane.slotWidth; height: root.workspace ? typeLane.height : typeLane.height - 8
                    expandedVisual: !root.workspace
                    hoverXScaleDelta: root.workspace ? 0 : 0.08
                    hoverScaleDelta: root.workspace ? 0 : 0.012
                    fontSize: root.workspace ? Theme.fontSize + 1 : Theme.fontSize - 1
                    idleColor: "transparent"; selectedColor: "transparent"
                    foregroundColor: root.workspace ? Theme.fgMuted : Theme.fg
                    hoverForegroundColor: Theme.fg
                    selectedForegroundColor: root.workspace ? Theme.accent : Theme.onAccentColor
                    text: modelData.name
                    Accessible.name: modelData.id === "video" ? "Lively wallpapers" : modelData.name
                    selected: root.filter === modelData.id
                    onClicked: { root.filter = modelData.id; root.forceActiveFocus() }
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => root.handleShortcut(event)
                }
            }
        }
    }
    // One scrolling category lane follows the shared library across presentations.
    FocusScope {
        id: categoryLane
        objectName: "wallpaper-category-lane"
        parent: root.workspace ? root : controls
        z: 30
        x: root.workspace ? (root.width - width) / 2 : 0
        y: root.workspace ? typeSlot.y + typeSlot.height + Theme.gap : typeLane.y + typeLane.height + Theme.gap
        width: root.workspace ? root.mediaTabWidth : controls.width
        height: root.categoryTabHeight

        // Keep focused and selected chips within the horizontal viewport.
        function ensureVisible(item) {
            if (!item) return
            categoryScroll.contentX = Math.max(0, Math.min(categoryScroll.contentWidth - categoryScroll.width,
                Math.max(item.x + item.width - categoryScroll.width, Math.min(categoryScroll.contentX, item.x))))
        }
        WallpaperToolbarButton {
            id: categoryPrevious
            objectName: "wallpaper-prev-category"
            width: root.categoryTabHeight; height: root.categoryTabHeight
            horizontalPadding: 6
            icon: "\uf104"; description: "Previous category (Alt+Left)"
            showTooltip: root.workspace
            foregroundColor: Theme.fgMuted
            hoverForegroundColor: Theme.fgDescription
            enabled: WallpaperLibrary.categories.indexOf(WallpaperLibrary.activeCategory) > 0
            onClicked: root.moveCategory(-1)
        }
        Flickable {
            id: categoryScroll
            objectName: "wallpaper-category-scroll"
            anchors {
                left: categoryPrevious.right; right: categoryNext.left
                top: parent.top; bottom: parent.bottom
                leftMargin: Theme.gap; rightMargin: Theme.gap
            }
            contentWidth: Math.max(width, categoryButtons.width)
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            onContentWidthChanged: categoryPosition.restart()
            onWidthChanged: categoryPosition.restart()
            // One shared surface morphs between variable-width category buttons.
            Motion.SelectionPill {
                id: categoryPill
                objectName: "wallpaper-category-indicator"
                coordinateSpace: categoryScroll.contentItem
                color: Theme.accent
            }
            Row {
                id: categoryButtons
                z: 1
                // Center short category groups while allowing long groups to overflow.
                x: Math.max(0, (categoryScroll.width - width) / 2)
                spacing: Theme.gap
                onXChanged: categoryPill.syncTarget(true)
                onPositioningComplete: categoryPill.syncTarget(true)
                Repeater {
                    model: WallpaperLibrary.categories
                    delegate: WallpaperActionButton {
                        id: categoryButton
                        // Folder names are kept intact for selection and accessibility.
                        required property string modelData
                        objectName: "wallpaper-category-" + modelData
                        width: Math.min(220, Math.max(64, categoryLabel.implicitWidth + 24))
                        height: root.categoryTabHeight
                        radius: height / 2
                        // The moving pill owns selection; buttons retain text, focus and input.
                        idleColor: "transparent"
                        selectedColor: "transparent"
                        hoverColor: "transparent"
                        pressedColor: "transparent"
                        focusColor: "transparent"
                        // Unselected labels use neutral dim text; the pill keeps its current contrast.
                        foregroundColor: Theme.fgMuted
                        hoverForegroundColor: selected ? selectedForegroundColor : foregroundColor
                        pressedForegroundColor: hoverForegroundColor
                        focusForegroundColor: hoverForegroundColor
                        selected: WallpaperLibrary.activeCategory === modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData || "All"
                        Accessible.selected: selected
                        onClicked: WallpaperLibrary.setCategory(modelData)
                        Component.onCompleted: if (selected) categoryPill.targetItem = this
                        onSelectedChanged: if (selected) {
                            categoryPill.targetItem = this
                            categoryPosition.restart()
                        }
                        onActiveFocusChanged: if (activeFocus) categoryLane.ensureVisible(this)
                        Keys.onReturnPressed: event => event.modifiers === Qt.NoModifier ? clicked() : root.handleShortcut(event)
                        Keys.onEnterPressed: event => event.modifiers === Qt.NoModifier ? clicked() : root.handleShortcut(event)
                        Keys.onSpacePressed: event => event.modifiers === Qt.NoModifier ? clicked() : root.handleShortcut(event)
                        Text {
                            id: categoryLabel
                            objectName: "wallpaper-category-label"
                            anchors.centerIn: parent
                            width: parent.width - 24
                            text: categoryButton.modelData || "All"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: categoryButton.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                }
            }
        }
        WallpaperToolbarButton {
            id: categoryNext
            objectName: "wallpaper-next-category"
            anchors.right: parent.right
            width: root.categoryTabHeight; height: root.categoryTabHeight
            horizontalPadding: 6
            icon: "\uf105"; description: "Next category (Alt+Right)"
            showTooltip: root.workspace
            foregroundColor: Theme.fgMuted
            hoverForegroundColor: Theme.fgDescription
            enabled: WallpaperLibrary.categories.indexOf(WallpaperLibrary.activeCategory) < WallpaperLibrary.categories.length - 1
            onClicked: root.moveCategory(1)
        }
        // Run after the row lays out; destruction also cancels pending positioning.
        Timer {
            id: categoryPosition
            interval: 0
            onTriggered: categoryLane.ensureVisible(categoryButtons.children.find(item => item.selected))
        }
    }
    // Compress and rebound the quick controls without changing their layout bounds.
    SequentialAnimation {
        id: navigationBounce
        NumberAnimation {
            target: controls; property: "navigationScale"; to: 0.96
            duration: HAnimation.buttonPressDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.buttonPressCurve
        }
        NumberAnimation {
            target: controls; property: "navigationScale"; to: 1
            duration: HAnimation.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.sidebarOpenCurve
        }
    }
    WallpaperCarousel {
        id: carousel
        z: root.workspace ? 20 : 0
        x: (root.width - width) / 2
        y: root.workspace ? root.height - root.bottomBarHeight - root.bottomPanelHeight + root.bottomSlide : controls.y + controls.height + root.panelPadding
        width: root.workspace ? Math.min(root.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset - 24, 1900) : Math.min(root.width * 0.88, 1600)
        height: root.workspace ? root.bottomPanelHeight + root.bottomBarHeight : Math.min(root.height * 0.5, 560)
        presentation: root.presentation
        spread: root.spread
        selectedPulse: root.selectedPulse
        onApplyRequested: root.applySelected()
        opacity: root.workspace ? 1 : root.contentOpacity
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => root.handleShortcut(event)
    }
}
