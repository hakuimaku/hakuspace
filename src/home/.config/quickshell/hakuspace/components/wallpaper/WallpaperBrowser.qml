import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell.Io
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog
import "../base" as Base
import "../motion" as Motion
import "../settings" as Settings
import "../flare" as Flare
import "WorkspaceGeometry.js" as WorkspaceGeometry

FocusScope {
    id: root
    // Keep the existing browser API backed by the shared lightweight session.
    property string presentation: "quick"
    readonly property bool workspace: presentation === "workspace"
    property bool workspaceVertical: false
    property string screenName: UiState.wallpaperScreenName
    FontMetrics { id: categoryFontMetrics; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
    FontMetrics { id: mediaFontMetrics; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1 }
    // Width measurement stays independent of the toolbar's wrapped height.
    readonly property var leftMetrics: ({width: width, height: height, left: ScreenGeometry.contentLeftEdge,
        right: ScreenGeometry.rightInset, top: ScreenGeometry.topBorderThickness,
        bottom: ScreenGeometry.bottomReservation(screenName), padding: Theme.pad, gap: Theme.gap, radius: Theme.giantRadius,
        toolbarWidth: toolbar.implicitWidth, toolbarHeight: toolbar.implicitHeight,
        mediaHeight: mediaTabHeight, categoryHeight: categoryTabHeight, categoryCount: WallpaperLibrary.categories.length,
        labelWidth: WallpaperLibrary.categories.reduce((value, name) => Math.max(value,
            categoryFontMetrics.advanceWidth(name || "All")), mediaFontMetrics.advanceWidth("Images") * 2 + Theme.gap)})
    readonly property real leftInfoWidth: WorkspaceGeometry.infoWidth({width: width, left: ScreenGeometry.contentLeftEdge,
        right: ScreenGeometry.rightInset, gap: Theme.gap, radius: Theme.giantRadius, toolbarWidth: toolbar.implicitWidth})
    readonly property var sideGeometry: WorkspaceGeometry.leftLayout(leftMetrics)
    readonly property real rightRailWidth: sideGeometry.railRect.width
    readonly property real infoSlide: -(sideGeometry.infoSurfaceRect.width + ScreenGeometry.roundedRadius) * (1 - reveal)
    readonly property real gallerySlide: (sideGeometry.galleryRect.width + ScreenGeometry.rightInset) * (1 - reveal)
    readonly property var cardInputItems: {
        var offset = carousel.offset
        return workspaceVertical && carousel.currentItem ? carousel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible && !item.chosen) : []
    }
    property real reveal: 1
    // Resolve tooltip ownership against this native workspace host.
    readonly property var tooltipHost: {
        var host = root
        while (host.parent) host = host.parent
        return host
    }
    // Closing opacity can lag behind the geometric zoom progress.
    property real contentOpacity: reveal
    property real spread: 1
    property real selectedPulse: 1
    property real workspaceMorph: 0
    property real workspaceButtonReveal: 1
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
    readonly property var selectedMetadata: metadata.selectedMetadata
    readonly property string selectedTooltip: metadata.tooltip
    WallpaperMetadata {
        id: metadata
        selected: root.selected
        profile: root.profile
        active: root.workspace && toolbar.metadataActive
    }
    readonly property var kinds: UiCatalog.wallpaperKinds
    // The quick input region surrounds controls without painting a container.
    readonly property Item quickInputItem: quickBounds
    readonly property Item topInputItem: workspaceControls
    readonly property Item bottomInputItem: workspaceVertical ? emptyInput : bottomBounds
    readonly property Item mediaInputItem: typeSlot
    readonly property Item categoryInputItem: categoryLane
    readonly property Item settingsInputItem: details
    readonly property Item selectedInputItem: workspace ? carousel.currentItem : null
    Item { id: emptyInput; width: 0; height: 0 }
    // Morph target matches Mode 2's selected card position and scale so switching modes glides continuously.
    readonly property real morphTargetX: ChromeLayout.leftBarMode
        ? sideGeometry.cardViewport.x + sideGeometry.anchors.selected.x
        : width / 2
    readonly property real morphTargetY: {
        if (ChromeLayout.leftBarMode)
            return sideGeometry.cardViewport.y + sideGeometry.anchors.selected.y
        var wsW = Math.min(width - ScreenGeometry.leftInset - ScreenGeometry.rightInset - 24, 1900)
        var wsH = bottomPanelHeight + bottomBarHeight
        var wsCard = Math.max(80, Math.min(wsW / 5.2, wsH * 16 / 9 * 0.95, 360))
        return height - wsH + (wsH - 16 - wsCard * 9 / 32 * 1.32)
    }
    readonly property real morphTargetScale: ChromeLayout.leftBarMode
        ? (sideGeometry.cardWidth * sideGeometry.selectedScale) / Math.max(1, carousel.cardWidth)
        : Math.max(80, Math.min(Math.min(width - ScreenGeometry.leftInset - ScreenGeometry.rightInset - 24, 1900) / 5.2, (bottomPanelHeight + bottomBarHeight) * 16 / 9 * 0.95, 360)) * 1.32 / Math.max(1, carousel.cardWidth)
    readonly property real topPanelHeight: Theme.topBarHeight
    readonly property real toolbarControlHeight: Math.max(24, Math.floor(topPanelHeight - 12))
    readonly property real bottomPanelHeight: height * 0.15
    readonly property real panelPadding: 16
    readonly property real mediaTabHeight: Math.max(44, toolbarControlHeight + 12)
    readonly property real mediaTabWidth: Math.min(Math.max(320, Theme.fontSize * 20), width - panelPadding * 4)
    // Reserve category navigation above the gallery in both presentations.
    readonly property real categoryTabHeight: Math.max(32, toolbarControlHeight)
    readonly property real quickCategoryHeight: categoryTabHeight + 8
    readonly property real quickControlGap: Theme.spaceMd
    readonly property real panelTopPadding: mediaTabHeight + Theme.gap + categoryTabHeight + panelPadding * 2
    // Overlay surfaces match the bars without changing their state or reservations.
    readonly property real bottomBarHeight: ScreenGeometry.taskbarHeight
    // Every visual in a panel shares one translation, including open settings.
    readonly property real topSlide: -(topPanelHeight + Math.max(ScreenGeometry.roundedRadius + topPanel.seamOverlap, details.travelHeight)) * (1 - reveal)
    readonly property real bottomSlide: (bottomPanel.height + bottomBarHeight) * (1 - reveal)
    readonly property var cardInputRects: {
        var offset = carousel.offset
        var viewport = {x: carousel.x, y: carousel.y, width: carousel.width, height: carousel.height}
        if (!workspaceVertical || !carousel.currentItem) return []
        return carousel.currentItem.parent.children.filter(item => item.wallpaper !== undefined && item.visible).map(function(item) {
            var scale = item.scale, x = item.x, y = item.y
            var start = item.mapToItem(root, 0, 0), end = item.mapToItem(root, item.width, item.height)
            return WorkspaceGeometry.intersection(WorkspaceGeometry.intersection(
                {x: start.x, y: start.y, width: end.x - start.x, height: end.y - start.y}, viewport), root.sideGeometry.safeRect)
        })
    }
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
        else if (workspace && plain && event.key === Qt.Key_Tab) {
            if (search.activeFocus) carousel.forceActiveFocus()
            else search.forceActiveFocus()
        }
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
        } else if (plain && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)
                && (workspace || !search.activeFocus || [Qt.Key_Up, Qt.Key_Down].includes(event.key))) {
            // Workspace arrows browse without changing the focus toggled by Tab.
            if (!workspace) {
                search.focus = false
                carousel.forceActiveFocus()
            }
            move([Qt.Key_Left, Qt.Key_Up].includes(event.key) ? -1 : 1)
        } else return false
        event.accepted = true
        return true
    }
    // Capture Tab before a focused toolbar button starts its default focus traversal.
    Shortcut {
        sequence: "Tab"
        enabled: root.workspace && root.enabled && root.visible && !root.settingsSection
        onActivated: root.handleShortcut({key: Qt.Key_Tab, modifiers: Qt.NoModifier, accepted: false})
    }
    Keys.onPressed: event => handleShortcut(event)
    onVisibleChanged: if (visible && refreshOnShow) refresh()
    Component.onCompleted: if (visible && refreshOnShow) refresh()

    // Panel surfaces and their content slide together without resizing the host.
    Flare.FlareSurface {
        id: topPanel
        objectName: "wallpaperTopPanel"
        x: root.workspaceVertical ? root.sideGeometry.infoRect.x + root.infoSlide : 0
        y: root.workspaceVertical ? 0 : root.topSlide
        visible: root.workspace && !root.workspaceVertical
        width: root.width
        attach: Flare.FlareHost.Top
        start: root.workspaceVertical ? ScreenGeometry.topBorderThickness : ScreenGeometry.leftInset
        end: root.workspaceVertical ? root.height - ScreenGeometry.bottomReservation(root.screenName) : root.width - ScreenGeometry.rightInset
        currentHeight: root.workspaceVertical ? root.sideGeometry.infoRect.width : root.topPanelHeight
        bounds: root.workspaceVertical ? ({start: 0, end: root.height}) : ScreenGeometry.horizontalBounds(root.width)
        transform: Matrix4x4 { matrix: root.workspaceVertical
            ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            : Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        r: ScreenGeometry.roundedRadius
        rf: ScreenGeometry.roundedRadius
        surfaceColor: Theme.surface
    }
    // Short corner ears join the toolbar to the top and Leftbar without a long diagonal edge.
    Shape {
        id: informationSurface
        objectName: "wallpaper-information-surface"
        visible: root.workspace && root.workspaceVertical
        x: root.sideGeometry.infoSurfaceRect.x + root.infoSlide
        y: root.sideGeometry.infoSurfaceRect.y
        width: root.sideGeometry.infoSurfaceRect.width
        height: root.sideGeometry.infoSurfaceRect.height
        readonly property real corner: root.sideGeometry.infoRadius
        readonly property real bodyWidth: width - corner
        readonly property real bodyHeight: height - corner
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.surface
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: informationSurface.width; y: 0 }
            PathQuad {
                controlX: informationSurface.bodyWidth; controlY: 0
                x: informationSurface.bodyWidth; y: informationSurface.corner
            }
            PathLine { x: informationSurface.bodyWidth; y: informationSurface.bodyHeight - informationSurface.corner }
            PathQuad {
                controlX: informationSurface.bodyWidth; controlY: informationSurface.bodyHeight
                x: informationSurface.bodyWidth - informationSurface.corner; y: informationSurface.bodyHeight
            }
            PathLine { x: informationSurface.corner; y: informationSurface.bodyHeight }
            PathQuad {
                controlX: 0; controlY: informationSurface.bodyHeight
                x: 0; y: informationSurface.height
            }
            PathLine { x: 0; y: 0 }
        }
    }
    Rectangle {
        id: bottomBar
        objectName: "wallpaperBottomBar"
        z: 10
        visible: root.workspace
        x: root.workspaceVertical ? root.width - ScreenGeometry.rightInset + root.gallerySlide : 0
        y: root.workspaceVertical ? root.sideGeometry.galleryRect.y : root.height - height + root.bottomSlide
        width: root.workspaceVertical ? ScreenGeometry.rightInset : root.width
        height: root.workspaceVertical ? root.sideGeometry.galleryRect.height : root.bottomBarHeight
        color: Theme.surface
    }
    // The gallery cradle and its upright cards consume the same bounded layout.
    WorkspaceGallerySurface {
        id: bottomPanel
        objectName: "wallpaperBottomPanel"
        visible: root.workspace
        vertical: root.workspaceVertical
        backingCurve: root.sideGeometry.backingCurve
        x: root.workspaceVertical ? root.sideGeometry.rightSurfaceRect.x + root.gallerySlide : ScreenGeometry.leftInset
        y: root.workspaceVertical ? root.sideGeometry.rightSurfaceRect.y : root.height - root.bottomBarHeight - height + root.bottomSlide
        width: root.workspaceVertical ? root.sideGeometry.rightSurfaceRect.width : root.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset
        height: root.workspaceVertical ? root.sideGeometry.rightSurfaceRect.height : Math.max(1, carousel.cardWidth * 9 / 16 * carousel.selectedScale + carousel.selectedLift
            + carousel.contentPadding - root.bottomBarHeight + root.panelTopPadding)
        topWidth: root.workspaceVertical ? carousel.cardWidth * 9 / 16 * carousel.selectedScale + root.panelPadding * 4
            : Math.max(carousel.cardWidth * carousel.selectedScale, root.mediaTabWidth) + root.panelPadding * 4
        headerPadding: root.workspaceVertical ? root.panelPadding : root.panelTopPadding
    }
    // Both workspace axes reuse the same toolbar and its original controls.
    Item {
        id: workspaceControls
        objectName: "wallpaper-toolbar"
        x: root.workspaceVertical ? root.sideGeometry.infoRect.x + root.infoSlide : 0
        y: root.workspaceVertical ? root.sideGeometry.infoRect.y : root.topSlide
        visible: root.workspace
        width: root.workspaceVertical ? root.leftInfoWidth : root.width
        height: root.workspaceVertical ? root.sideGeometry.infoRect.height : root.topPanelHeight
        clip: root.workspaceVertical
        Flickable {
            id: informationScroll
            anchors.fill: parent
            contentWidth: width
            contentHeight: root.workspaceVertical ? informationComposition.height : height
            interactive: root.workspaceVertical && contentHeight > height
            clip: root.workspaceVertical
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar { visible: root.workspaceVertical && informationScroll.contentHeight > informationScroll.height }
            Item {
                id: informationComposition
                objectName: "wallpaper-information-composition"
                // The corner toolbar wraps in physical screen coordinates.
                width: informationScroll.width
                height: root.workspaceVertical ? toolbar.implicitHeight : informationScroll.height
                WorkspaceToolbar {
                    id: toolbar
                    browser: root
                    width: parent.width
                    height: root.workspaceVertical ? implicitHeight : root.topPanelHeight
                }
            }
        }
    }

    // Media choices follow the right rail or the horizontal gallery header.
    Item {
        id: typeSlot
        objectName: "wallpaper-media-tabs"
        z: 30
        visible: root.workspace
        parent: root
        x: root.workspaceVertical ? root.sideGeometry.mediaRect.x + root.gallerySlide : (root.width - width) / 2
        y: root.workspaceVertical ? root.sideGeometry.mediaRect.y : bottomPanel.y + root.panelPadding
        width: root.workspaceVertical ? root.sideGeometry.mediaRect.width : root.mediaTabWidth
        height: root.workspaceVertical ? root.sideGeometry.mediaRect.height : root.mediaTabHeight
    }
    Loader {
        active: root.workspace && !root.workspaceVertical
        z: 3000
        y: root.workspaceVertical ? workspaceControls.y + workspaceControls.height : root.topPanelHeight + root.topSlide
        width: root.width
        height: root.workspaceVertical ? root.height : 180
        sourceComponent: Base.TooltipLayer {
            objectName: "wallpaper-tooltip-layer"
            tipAreaHeight: 180
            minimumTooltipWidth: toolbar.titleWidth + 32
            screenName: root.screenName
            leftAttached: false
            sideAttachmentX: root.sideGeometry.infoRect.x + root.sideGeometry.infoRect.width
            height: root.workspaceVertical ? root.height : tipAreaHeight
        }
    }
    // Leftbar workspace tooltips float beside their targets without flare geometry or morphs.
    Settings.SettingsTooltip {
        id: floatingTooltip
        objectName: "wallpaper-floating-tooltip"
        target: root.workspaceVertical && TooltipManager.current ? TooltipManager.current.target : null
        text: TooltipManager.current ? TooltipManager.current.text : ""
        active: root.workspace && root.workspaceVertical && root.visible && root.enabled
            && TooltipManager.shown && TooltipManager.activeBar === root.tooltipHost && !!target
        immediate: true
        fadeDuration: HAnimation.effects
        popupType: Popup.Item
        // Display filesystem category names literally in the shared floating bubble.
        Component.onCompleted: contentItem.textFormat = Text.PlainText
        x: {
            if (!target) return 0
            var point = target.mapToItem(root, 0, 0)
            return Math.max(ScreenGeometry.contentLeftEdge + 8,
                Math.min(root.width - ScreenGeometry.rightInset - width - 8, point.x + (target.width - width) / 2)) - point.x
        }
        y: {
            if (!target) return 0
            var point = target.mapToItem(root, 0, 0)
            var bottom = root.height - ScreenGeometry.bottomReservation(root.screenName) - 8
            return point.y + target.height + height + 6 <= bottom ? target.height + 6
                : Math.max(ScreenGeometry.topBorderThickness + 8 - point.y, -height - 6)
        }
    }
    WallpaperSettingsPopover {
        id: details
        objectName: "wallpaper-settings-popover"
        z: 2000
        visible: root.workspace && displayedSection.length > 0
        section: root.settingsSection
        hostReveal: root.reveal
        x: root.workspaceVertical ? root.sideGeometry.infoRect.x + root.infoSlide : root.width - width - ScreenGeometry.rightInset - 24
        y: root.workspaceVertical ? workspaceControls.y + workspaceControls.height + root.panelPadding : root.topPanelHeight + root.topSlide
        width: root.workspaceVertical ? Math.min(root.sideGeometry.infoRect.width,
            root.sideGeometry.galleryRect.x - x - Theme.gap) : Math.min(620, root.width - 64 - ScreenGeometry.leftInset - ScreenGeometry.rightInset)
        availableHeight: root.workspaceVertical ? root.height - y - ScreenGeometry.bottomReservation(root.screenName) - root.panelPadding : root.height - root.topPanelHeight - gap - root.bottomPanelHeight - 24
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
        height: searchControl.implicitHeight + root.quickControlGap + typeLane.implicitHeight + root.quickControlGap + categoryLane.height
        opacity: root.contentOpacity
        scale: (0.96 + 0.04 * root.reveal) * navigationScale
        Item {
            id: searchControl
            parent: root.workspace ? toolbar.searchSlotItem : controls
            anchors.fill: root.workspace ? parent : undefined
            y: root.workspace ? 0 : -root.workspaceMorph * 28
            implicitHeight: 42
            width: root.workspace ? parent.width : controls.width
            height: root.workspace ? parent.height : implicitHeight
            opacity: root.workspace ? 1 : Math.max(0, 1 - root.workspaceMorph * 2.1)
            scale: root.workspace ? 1 : 1 - root.workspaceMorph * 0.08
            TextField {
                id: search
                ContextMenu.menu: null
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
                    text: root.workspace ? "Search wallpapers (Tab)" : "Search wallpapers (Ctrl+F)"
                    active: root.workspace && search.hovered
                }
                background: Rectangle { color: root.workspace ? Theme.hoverMuted : Theme.surface; radius: root.workspaceVertical ? toolbar.controlRadius : height / 2; border.width: root.workspace ? 1 : 0; border.color: search.activeFocus ? Theme.accent : Theme.hoverMuted }
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
            y: root.workspace ? 0 : searchControl.implicitHeight + root.quickControlGap - root.workspaceMorph * 16
            opacity: root.workspace ? 1 : Math.max(0, 1 - Math.max(0, root.workspaceMorph - 0.12) * 1.9)
            scale: root.workspace ? 1 : 1 - root.workspaceMorph * 0.1
            width: root.workspace ? parent.width : Math.min(parent.width, 248)
            implicitHeight: root.workspaceVertical ? typeSlot.height : root.workspace ? root.mediaTabHeight : 40
            height: implicitHeight
            radius: root.workspaceVertical ? Math.min(Theme.largeRadius, root.mediaTabHeight / 2) : root.workspace ? 0 : height / 2
            color: root.workspaceVertical ? Theme.hoverMuted : root.workspace ? "transparent" : Theme.surface
            border.width: 0
            anchors.horizontalCenter: root.workspace ? undefined : parent.horizontalCenter
            readonly property real slotWidth: root.workspaceVertical && root.sideGeometry.mediaStacked ? mediaChoices.width : root.workspace && !root.workspaceVertical ? width / 2 : (mediaChoices.width - 4) / 2
            Rectangle {
                visible: root.workspace && !root.workspaceVertical
                width: parent.width; height: 1
                color: Theme.hoverMuted
            }
            Rectangle {
                objectName: "wallpaper-type-top-border"
                visible: root.workspace && !root.workspaceVertical
                x: root.kinds.findIndex(choice => choice.id === root.filter) * typeLane.slotWidth
                y: 0
                width: typeLane.slotWidth
                height: 2
                color: Theme.accent
                Behavior on x {
                    NumberAnimation { duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.moduleCurve }
                }
            }
            Item {
                id: mediaChoices
                // Selection and labels share one inset origin, including their first layout.
                x: root.workspace && !root.workspaceVertical ? 0 : 4
                y: x
                width: parent.width - x * 2
                height: parent.height - y * 2
                Motion.SelectionPill {
                    objectName: "wallpaper-type-indicator"
                    visible: !root.workspace || root.workspaceVertical
                    targetIndex: root.workspaceVertical ? -1 : root.kinds.findIndex(choice => choice.id === root.filter)
                    slotCount: root.workspaceVertical ? 0 : root.kinds.length
                    slotSpacing: 4
                    targetItem: root.workspaceVertical && mediaRepeater.count > 0 ? mediaRepeater.itemAt(root.kinds.findIndex(choice => choice.id === root.filter)) : null
                    radius: root.workspaceVertical ? Math.max(0, typeLane.radius - mediaChoices.x) : height / 2
                }
            }
            Repeater {
                id: mediaRepeater
                parent: root.workspaceVertical ? mediaChoices : typeLane
                model: root.kinds
                delegate: WallpaperActionButton {
                    id: mediaButton
                    required property var modelData
                    required property int index
                    objectName: "wallpaper-kind-" + modelData.id
                    x: root.workspaceVertical ? (root.sideGeometry.mediaStacked ? 0 : index * (typeLane.slotWidth + 4)) : root.workspace ? index * typeLane.slotWidth : 4 + index * (typeLane.slotWidth + 4)
                    y: root.workspaceVertical ? (root.sideGeometry.mediaStacked ? index * (height + 4) : 0) : root.workspace ? 0 : 4
                    width: typeLane.slotWidth
                    height: root.workspaceVertical && root.sideGeometry.mediaStacked ? (mediaChoices.height - 4) / 2 : mediaChoices.height
                    radius: root.workspaceVertical ? Math.max(0, typeLane.radius - mediaChoices.x) : 0
                    expandedVisual: !root.workspace
                    hoverXScaleDelta: root.workspace ? 0 : 0.08
                    hoverScaleDelta: root.workspace ? 0 : 0.012
                    pressXScaleDelta: root.workspaceVertical ? 0 : 0.13
                    pressScaleDelta: root.workspaceVertical ? 0 : 0.045
                    fontSize: root.workspaceVertical ? Theme.fontSize : root.workspace ? Theme.fontSize + 1 : Theme.fontSize - 1
                    idleColor: "transparent"; selectedColor: "transparent"
                    foregroundColor: root.workspace ? Theme.fgMuted : Theme.fg
                    hoverForegroundColor: Theme.fg
                    selectedForegroundColor: root.workspace && !root.workspaceVertical ? Theme.accent : Theme.onAccentColor
                    disabledForegroundColor: selected ? selectedForegroundColor : foregroundColor
                    disabledOpacity: 1
                    text: root.workspaceVertical ? "" : modelData.name
                    Text {
                        id: mediaLabel
                        anchors.centerIn: parent
                        width: parent.width
                        visible: root.workspaceVertical
                        text: mediaButton.modelData.name
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: mediaButton.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: mediaButton.fontSize
                    }
                    Base.HTooltip {
                        target: mediaButton
                        text: mediaButton.modelData.name
                        active: root.workspaceVertical && mediaButton.hovered && mediaLabel.truncated
                    }
                    Accessible.name: modelData.id === "video" ? "Lively wallpapers" : modelData.name
                    selected: root.filter === modelData.id
                    onClicked: { root.filter = modelData.id; root.forceActiveFocus() }
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => root.handleShortcut(event)
                }
            }
        }
    }
    // Isolate reveal slide/fade from MorphButton's hover scale and opacity Behavior.
    Item {
        id: openWorkspaceHost
        visible: !root.workspace
        z: 40
        width: 52
        height: 52
        x: root.width - width - ScreenGeometry.rightInset - Theme.panelPadding
        y: ScreenGeometry.topChromeHeight + Theme.panelPadding
        opacity: Math.max(0, Math.min(1, root.workspaceButtonReveal))
        transform: [
            Scale {
                origin.x: openWorkspaceHost.width / 2
                origin.y: openWorkspaceHost.height / 2
                xScale: 0.78 + 0.22 * root.workspaceButtonReveal
                yScale: 0.78 + 0.22 * root.workspaceButtonReveal
            },
            Translate {
                x: (1 - root.workspaceButtonReveal) * (openWorkspaceHost.width + ScreenGeometry.rightInset + Theme.panelPadding + 36)
                y: -(1 - root.workspaceButtonReveal) * (openWorkspaceHost.height + ScreenGeometry.topChromeHeight + Theme.panelPadding + 36)
            }
        ]
        WallpaperToolbarButton {
            id: openWorkspaceButton
            objectName: "wallpaper-open-workspace"
            anchors.fill: parent
            radius: width / 2
            icon: "\uf03e"
            iconSize: 22
            horizontalPadding: 0
            description: "Open wallpaper workspace (Ctrl+Enter)"
            showTooltip: false
            idleColor: Theme.surface
            hoverColor: Theme.surface
            pressedColor: Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.18))
            foregroundColor: Theme.fg
            hoverForegroundColor: Theme.fg
            disabledForegroundColor: Theme.fg
            disabledOpacity: 1
            hoverScaleDelta: 0.1
            pressScaleDelta: 0.04
            onClicked: UiState.enterWallpaperWorkspace()
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => root.handleShortcut(event)
            Settings.SettingsTooltip {
                objectName: "wallpaper-open-workspace-tooltip"
                target: openWorkspaceButton
                text: openWorkspaceButton.description
                x: target ? Math.min((target.width - width) / 2, target.width - width) : 0
                active: openWorkspaceButton.hovered && openWorkspaceButton.enabled && openWorkspaceButton.visible
            }
        }
    }
    // One scrolling category lane follows the shared library across presentations.
    FocusScope {
        id: categoryLane
        objectName: "wallpaper-category-lane"
        readonly property real contentInset: root.workspaceVertical ? root.sideGeometry.categoryInset : 0
        readonly property real lanePad: !root.workspace ? 4 : 0
        parent: root.workspace ? root : controls
        z: 30
        x: root.workspaceVertical ? root.sideGeometry.categoryRect.x + root.gallerySlide : root.workspace ? (root.width - width) / 2 : 0
        y: root.workspaceVertical ? root.sideGeometry.categoryRect.y : root.workspace ? typeSlot.y + typeSlot.height + Theme.gap : searchControl.implicitHeight + typeLane.implicitHeight + root.quickControlGap * 2 + root.workspaceMorph * 12
        width: root.workspaceVertical ? root.sideGeometry.categoryRect.width : root.workspace ? root.mediaTabWidth : controls.width
        height: root.workspaceVertical ? root.sideGeometry.categoryRect.height : root.workspace ? root.categoryTabHeight : root.quickCategoryHeight
        opacity: root.workspace ? 1 : Math.max(0, 1 - Math.max(0, root.workspaceMorph - 0.2) * 1.9)
        scale: root.workspace ? 1 : 1 - root.workspaceMorph * 0.08

        Rectangle {
            id: categoryBackdrop
            objectName: "wallpaper-category-backdrop"
            visible: !root.workspace
            anchors.fill: parent
            radius: height / 2
            color: Theme.surface
        }

        // Keep focused and selected categories inside the padded viewport.
        function ensureVisible(item) {
            if (!item) return
            var point = item.mapToItem(categoryScroll.contentItem, 0, 0)
            if (root.workspaceVertical) categoryScroll.contentY = Math.max(0, Math.min(categoryScroll.contentHeight - categoryScroll.height,
                Math.max(point.y + item.height + contentInset - categoryScroll.height, Math.min(categoryScroll.contentY, point.y - contentInset))))
            else categoryScroll.contentX = Math.max(0, Math.min(categoryScroll.contentWidth - categoryScroll.width,
                Math.max(point.x + item.width - categoryScroll.width, Math.min(categoryScroll.contentX, point.x))))
        }
        WallpaperToolbarButton {
            id: categoryPrevious
            objectName: "wallpaper-prev-category"
            visible: !root.workspaceVertical || root.sideGeometry.categoryArrows
            x: root.workspaceVertical ? 0 : categoryLane.lanePad
            y: root.workspaceVertical ? 0 : categoryLane.lanePad
            width: root.workspaceVertical ? parent.width : root.categoryTabHeight
            height: visible ? root.categoryTabHeight : 0
            radius: !root.workspace ? height / 2 : Math.min(8, height / 2)
            horizontalPadding: 6
            icon: root.workspaceVertical ? "\uf106" : "\uf104"; description: "Previous category (Alt+Left)"
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
                left: root.workspaceVertical ? parent.left : categoryPrevious.right
                right: root.workspaceVertical ? parent.right : categoryNext.left
                top: root.workspaceVertical ? categoryPrevious.bottom : parent.top
                bottom: root.workspaceVertical ? categoryNext.top : parent.bottom
                leftMargin: root.workspaceVertical ? 0 : Theme.gap
                rightMargin: root.workspaceVertical ? 0 : Theme.gap
                topMargin: root.workspaceVertical && categoryPrevious.visible ? Theme.gap : categoryLane.lanePad
                bottomMargin: root.workspaceVertical && categoryNext.visible ? Theme.gap : categoryLane.lanePad
            }
            contentWidth: root.workspaceVertical ? width : Math.max(width, categoryButtons.width)
            contentHeight: root.workspaceVertical ? Math.max(height, categoryButtons.y + categoryButtons.height + categoryLane.contentInset) : height
            flickableDirection: root.workspaceVertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            onContentWidthChanged: categoryPosition.restart()
            onWidthChanged: categoryPosition.restart()
            onContentHeightChanged: categoryPosition.restart()
            onHeightChanged: categoryPosition.restart()
            // One shared surface morphs between variable-width category buttons.
            Motion.SelectionPill {
                id: categoryPill
                objectName: "wallpaper-category-indicator"
                coordinateSpace: categoryScroll.contentItem
                color: Theme.accent
            }
            Grid {
                id: categoryButtons
                columns: root.workspaceVertical ? 1 : Math.max(1, categoryRepeater.count)
                z: 1
                // Center short lists between the arrows; long lists retain padded scroll edges.
                x: root.workspaceVertical ? 0 : Math.max(0, (categoryScroll.width - width) / 2)
                y: root.workspaceVertical ? Math.max(categoryLane.contentInset, (categoryScroll.height - height) / 2) : 0
                spacing: root.workspaceVertical ? root.sideGeometry.categorySpacing : Theme.gap
                onXChanged: categoryPill.syncTarget(true)
                onYChanged: categoryPill.syncTarget(true)
                onPositioningComplete: categoryPill.syncTarget(true)
                Repeater {
                    id: categoryRepeater
                    model: WallpaperLibrary.categories
                    delegate: WallpaperActionButton {
                        id: categoryButton
                        readonly property bool wallpaperTooltipTarget: root.workspaceVertical
                        // Folder names are kept intact for selection and accessibility.
                        required property string modelData
                        objectName: "wallpaper-category-" + modelData
                        width: root.workspaceVertical ? categoryScroll.width : Math.min(220, Math.max(64, categoryLabel.implicitWidth + 24))
                        height: root.workspaceVertical ? root.sideGeometry.categoryRowHeight : root.categoryTabHeight
                        radius: Math.min(height, root.categoryTabHeight) / 2
                        border.width: root.workspaceVertical && activeFocus ? 1 : 0
                        border.color: Theme.accent
                        selectedForegroundColor: Theme.onAccentColor
                        // The moving pill owns selection; buttons retain text, focus and input.
                        hoverScaleDelta: 0.05
                        hoverXScaleDelta: 0
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
                        disabledForegroundColor: selected ? selectedForegroundColor : foregroundColor
                        disabledOpacity: 1
                        selected: WallpaperLibrary.activeCategory === modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData || "All"
                        Accessible.selected: selected
                        onClicked: WallpaperLibrary.setCategory(modelData)
                        Component.onCompleted: if (selected) categoryPill.targetItem = root.workspaceVertical ? categoryTarget : this
                        onSelectedChanged: if (selected) {
                            categoryPill.targetItem = root.workspaceVertical ? categoryTarget : this
                            categoryPosition.restart()
                        }
                        onActiveFocusChanged: if (activeFocus) categoryLane.ensureVisible(this)
                        Keys.onReturnPressed: event => event.modifiers === Qt.NoModifier ? clicked() : root.handleShortcut(event)
                        Keys.onEnterPressed: event => event.modifiers === Qt.NoModifier ? clicked() : root.handleShortcut(event)
                        Keys.onSpacePressed: event => event.modifiers === Qt.NoModifier ? clicked() : root.handleShortcut(event)
                        Base.HTooltip {
                            target: categoryButton
                            text: categoryButton.modelData || "All"
                            active: root.workspace && root.workspaceVertical && categoryButton.hovered && categoryLabel.truncated
                        }
                        // Stretch the hit area while keeping the selection surface a compact pill.
                        Item {
                            id: categoryTarget
                            anchors.centerIn: parent
                            width: parent.width
                            height: Math.min(parent.height, root.categoryTabHeight)
                            readonly property real radius: height / 2
                        }
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
            visible: !root.workspaceVertical || root.sideGeometry.categoryArrows
            anchors.right: root.workspaceVertical ? undefined : parent.right
            anchors.rightMargin: root.workspaceVertical ? 0 : categoryLane.lanePad
            y: root.workspaceVertical ? 0 : categoryLane.lanePad
            anchors.bottom: root.workspaceVertical ? parent.bottom : undefined
            width: root.workspaceVertical ? parent.width : root.categoryTabHeight
            height: visible ? root.categoryTabHeight : 0
            radius: !root.workspace ? height / 2 : Math.min(8, height / 2)
            horizontalPadding: 6
            icon: root.workspaceVertical ? "\uf107" : "\uf105"; description: "Next category (Alt+Right)"
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
        x: root.workspaceVertical ? root.sideGeometry.cardViewport.x + root.gallerySlide : (root.width - width) / 2
        y: root.workspaceVertical ? root.sideGeometry.cardViewport.y : root.workspace ? root.height - root.bottomBarHeight - root.bottomPanelHeight + root.bottomSlide : controls.y + controls.height + root.panelPadding
        width: root.workspaceVertical ? root.sideGeometry.cardViewport.width : root.workspace ? Math.min(root.width - ScreenGeometry.leftInset - ScreenGeometry.rightInset - 24, 1900) : Math.min(root.width * 0.88, 1600)
        height: root.workspaceVertical ? root.sideGeometry.cardViewport.height : root.workspace ? root.bottomPanelHeight + root.bottomBarHeight : Math.min(root.height * 0.5, 560)
        presentation: root.presentation
        vertical: root.workspaceVertical
        leftLayout: root.sideGeometry
        spread: root.spread
        selectedPulse: root.selectedPulse
        onApplyRequested: root.applySelected()
        opacity: root.workspace ? 1 : root.contentOpacity * (root.workspaceMorph > 0 ? Math.max(0, 1 - Math.max(0, root.workspaceMorph - 0.25) / 0.75) : 1)
        transform: [
            Scale {
                origin.x: carousel.width / 2
                origin.y: carousel.height / 2
                xScale: !root.workspace ? 1 + (root.morphTargetScale - 1) * root.workspaceMorph : 1
                yScale: !root.workspace ? 1 + (root.morphTargetScale - 1) * root.workspaceMorph : 1
            },
            Translate {
                x: !root.workspace ? (root.morphTargetX - (carousel.x + carousel.width / 2)) * root.workspaceMorph : 0
                y: !root.workspace ? (root.morphTargetY - (carousel.y + carousel.height / 2)) * root.workspaceMorph : 0
            }
        ]
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => root.handleShortcut(event)
    }
}
