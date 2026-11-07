import QtQuick
import "../../services"
import "../../config/UiCatalog.js" as UiCatalog
import "../base" as Base
import "../motion" as Motion

Item {
    id: toolbar
    required property var browser
    readonly property var root: browser
    readonly property Item searchSlotItem: searchSlot
    readonly property real titleWidth: selectedTitle.width
    readonly property bool metadataActive: titleTooltip.active
    readonly property bool stacked: root.workspaceVertical
    implicitWidth: stacked ? Theme.fontSize * 26 + edgePadding * 2 : Math.max(modeBadge.width, libraryGroup.width) + 180 + edgePadding * 2 + leftTools.spacing
    implicitHeight: stacked ? rightTools.y + rightTools.height + edgePadding : root.topPanelHeight
    readonly property bool compact: toolbar.width < 1600 || Theme.fontSize > 16
    readonly property bool dense: toolbar.width < 1200
    readonly property real controlRadius: Math.min(Theme.radius, controlHeight / 3)
    readonly property real controlHeight: stacked ? Math.max(Theme.controlHeight, root.toolbarControlHeight) : root.toolbarControlHeight
    readonly property int libraryFontSize: dense && !stacked ? Math.min(13, Theme.fontSize - 1) : Theme.fontSize - 1
    readonly property real edgePadding: compact ? 16 : 24
    Text {
        id: longestModeLabel
        visible: false
        text: "Lively Wallpaper"
        font.family: Theme.fontFamily; font.pixelSize: toolbar.stacked ? Theme.fontSize : toolbar.libraryFontSize
    }
    Grid {
        id: leftTools
        columns: toolbar.stacked ? 1 : 3
        x: toolbar.edgePadding
        y: toolbar.stacked ? toolbar.edgePadding : 0
        anchors.verticalCenter: toolbar.stacked ? undefined : parent.verticalCenter
        spacing: toolbar.compact ? 8 : 12
        Row {
            id: modeBadge
            objectName: "wallpaper-mode-badge"
            readonly property bool wallpaperTooltipTarget: true
            spacing: 8
            height: toolbar.controlHeight
            HoverHandler { id: modeHover }
            Text {
                objectName: "wallpaper-mode-icon"
                text: "\uf03e"
                height: toolbar.controlHeight
                verticalAlignment: Text.AlignVCenter
                color: Theme.fg
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24
                Accessible.name: "Wallpaper"
            }
            Text {
                objectName: "wallpaper-mode-label"
                // Reserve the longer caption for both media modes.
                width: Math.ceil(Math.max(implicitWidth, longestModeLabel.implicitWidth))
                height: toolbar.controlHeight
                text: root.filter === "video" ? "Lively Wallpaper" : "Image Wallpaper"
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                color: Theme.fg
                font.family: Theme.fontFamily; font.pixelSize: toolbar.stacked ? Theme.fontSize : toolbar.libraryFontSize
            }
        }
        Item {
            id: searchSlot
            // Leave space for the centered name without hiding the library labels.
            width: toolbar.stacked ? toolbar.width - toolbar.edgePadding * 2 : Math.max(80, Math.min(256, toolbar.width / 2 - modeBadge.width - libraryGroup.width
                - leftTools.spacing * 2 - toolbar.edgePadding - 76))
            height: toolbar.controlHeight
        }
        Rectangle {
            id: libraryGroup
            width: toolbar.stacked ? toolbar.width - toolbar.edgePadding * 2 : libraryButtons.implicitWidth + 4; height: toolbar.controlHeight
            radius: toolbar.stacked ? toolbar.controlRadius : 8
            color: toolbar.stacked ? "transparent" : Theme.hoverMuted
            Row {
                id: libraryButtons
                anchors.centerIn: parent
                spacing: toolbar.stacked ? Theme.gap : 2
                WallpaperToolbarButton {
                    objectName: "wallpaper-shuffle"
                    width: toolbar.stacked ? (libraryGroup.width - Theme.gap) / 2 : implicitWidth
                    height: toolbar.stacked ? toolbar.controlHeight : toolbar.controlHeight - 4
                    radius: toolbar.stacked ? toolbar.controlRadius : Math.min(8, height / 2)
                    idleColor: toolbar.stacked ? Theme.hoverMuted : "transparent"
                    caption: "Shuffle"; icon: "\uf074"; description: "Shuffle selection"
                    fontSize: toolbar.libraryFontSize
                    iconSize: toolbar.stacked ? Theme.fontSize + 2 : toolbar.dense ? 14 : 18
                    horizontalPadding: toolbar.dense ? 8 : 12
                    enabled: root.filteredItems.length > 1
                    onClicked: root.shuffle()
                }
                WallpaperToolbarButton {
                    objectName: "wallpaper-refresh"
                    width: toolbar.stacked ? (libraryGroup.width - Theme.gap) / 2 : implicitWidth
                    height: toolbar.stacked ? toolbar.controlHeight : toolbar.controlHeight - 4
                    radius: toolbar.stacked ? toolbar.controlRadius : Math.min(8, height / 2)
                    idleColor: toolbar.stacked ? Theme.hoverMuted : "transparent"
                    caption: "Refresh"; icon: "\uf021"; description: "Refresh wallpaper library"
                    fontSize: toolbar.libraryFontSize
                    iconSize: toolbar.stacked ? Theme.fontSize + 2 : toolbar.dense ? 14 : 18
                    horizontalPadding: toolbar.dense ? 8 : 12
                    enabled: !root.loading
                    onClicked: root.refresh()
                }
            }
        }
    }
    // Header actions share the title row while the remaining controls fill the panel grid.
    Row {
        id: headerTools
        layoutDirection: Qt.RightToLeft
        x: toolbar.width - width - toolbar.edgePadding
        y: toolbar.edgePadding
        spacing: Theme.gap
    }
    Base.HTooltip {
        objectName: "wallpaper-mode-tooltip"
        target: modeBadge
        text: root.filter === "video" ? "Lively wallpaper library" : "Image wallpaper library"
        active: modeHover.hovered && root.workspace
    }
    Rectangle {
        objectName: "wallpaper-title-left-separator"
        visible: !toolbar.stacked
        x: selectedTitle.x - 16 - width
        anchors.verticalCenter: parent.verticalCenter
        width: 1; height: toolbar.controlHeight - 8
        color: Theme.fgMuted; opacity: 0.5
    }
    Rectangle {
        objectName: "wallpaper-title-right-separator"
        visible: !toolbar.stacked
        x: selectedTitle.x + selectedTitle.width + 16
        anchors.verticalCenter: parent.verticalCenter
        width: 1; height: toolbar.controlHeight - 8
        color: Theme.fgMuted; opacity: 0.5
    }
    Text {
        id: selectedTitle
        objectName: "wallpaper-selected-title"
        anchors.centerIn: toolbar.stacked ? undefined : parent
        x: toolbar.stacked ? toolbar.edgePadding : 0
        y: toolbar.stacked ? leftTools.y + leftTools.height + Theme.gap : 0
        anchors.alignWhenCentered: false
        width: toolbar.stacked ? toolbar.width - toolbar.edgePadding * 2 : Math.max(0, Math.min(520, toolbar.width - 2 * (Math.max(leftTools.width, rightTools.width) + toolbar.edgePadding + 16)))
        text: root.selectedTitle
        height: toolbar.controlHeight
        leftPadding: 0
        rightPadding: leftPadding
        wrapMode: Text.NoWrap
        textFormat: Text.PlainText
        maximumLineCount: 1
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: toolbar.stacked ? Text.AlignLeft : Text.AlignHCenter
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
    Flow {
        id: rightTools
        readonly property real naturalWidth: visibleChildren.reduce((total, child) => total + child.width, 0)
            + Math.max(0, visibleChildren.length - 1) * spacing
        width: toolbar.stacked ? toolbar.width - toolbar.edgePadding * 2 : naturalWidth
        x: toolbar.stacked ? toolbar.edgePadding : parent.width - width - toolbar.edgePadding
        y: toolbar.stacked ? selectedTitle.y + selectedTitle.height + Theme.gap : 0
        anchors.verticalCenter: toolbar.stacked ? undefined : parent.verticalCenter
        spacing: toolbar.compact ? 8 : 12
        Rectangle {
            id: quality
            objectName: "wallpaper-video-quality"
            // Compact layouts keep direct quality choices in the Playback menu.
            visible: toolbar.width >= 1440
            enabled: root.filter === "video"
            opacity: root.filter === "video" ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.effectsCurve } }
            width: implicitWidth
            height: toolbar.controlHeight
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
                        width: implicitWidth; height: toolbar.controlHeight - 4
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
            id: livelyControls
            objectName: "wallpaper-lively-controls"
            enabled: root.filter === "video"
            opacity: root.filter === "video" ? 1 : toolbar.stacked ? 0.3 : 0.45
            Behavior on opacity { NumberAnimation { duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.effectsCurve } }
            width: toolbar.stacked ? rightTools.width : preferenceButtons.implicitWidth + 4; height: toolbar.controlHeight
            radius: toolbar.stacked ? toolbar.controlRadius : 8
            color: toolbar.stacked ? "transparent" : Theme.hoverMuted
            Row {
                id: preferenceButtons
                anchors.centerIn: parent
                spacing: toolbar.stacked ? Theme.gap : 2
                WallpaperToolbarButton {
                    objectName: "wallpaper-playback"
                    width: toolbar.stacked ? (livelyControls.width - Theme.gap) / 2 : implicitWidth
                    height: toolbar.stacked ? toolbar.controlHeight : toolbar.controlHeight - 4
                    radius: toolbar.stacked ? toolbar.controlRadius : Math.min(8, height / 2)
                    iconSize: toolbar.stacked ? Theme.fontSize + 2 : 20
                    idleColor: toolbar.stacked ? Theme.hoverMuted : "transparent"
                    caption: toolbar.compact && !toolbar.stacked ? "" : "Playback"
                    icon: toolbar.compact ? "\uf144" : ""
                    description: "Video playback settings"
                    disabledOpacity: 1
                    selected: root.settingsSection === "playback"
                    onClicked: if (root.filter === "video") root.settingsSection = root.settingsSection === "playback" ? "" : "playback"
                }
                WallpaperToolbarButton {
                    objectName: "wallpaper-cache"
                    width: toolbar.stacked ? (livelyControls.width - Theme.gap) / 2 : implicitWidth
                    height: toolbar.stacked ? toolbar.controlHeight : toolbar.controlHeight - 4
                    radius: toolbar.stacked ? toolbar.controlRadius : Math.min(8, height / 2)
                    iconSize: toolbar.stacked ? Theme.fontSize + 2 : 20
                    idleColor: toolbar.stacked ? Theme.hoverMuted : "transparent"
                    caption: toolbar.compact && !toolbar.stacked ? "" : "Cache"
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
            radius: toolbar.stacked ? toolbar.controlRadius : Math.min(8, height / 2)
            iconSize: toolbar.stacked ? Theme.fontSize + 2 : 20
            parent: toolbar.stacked ? headerTools : rightTools
            height: toolbar.controlHeight
            width: toolbar.stacked ? toolbar.controlHeight : implicitWidth
            icon: "\uf013"; description: "All wallpaper settings"
            fontSize: Theme.fontSize + 2
            onClicked: root.settingsRequested()
        }
        WallpaperToolbarButton {
            objectName: "wallpaper-close"
            radius: toolbar.stacked ? toolbar.controlRadius : Math.min(8, height / 2)
            iconSize: toolbar.stacked ? Theme.fontSize + 2 : 20
            parent: toolbar.stacked ? headerTools : rightTools
            height: toolbar.controlHeight
            width: toolbar.stacked ? toolbar.controlHeight : implicitWidth
            icon: "\uf00d"; description: "Close wallpaper workspace"
            fontSize: Theme.fontSize + 4
            onClicked: root.dismiss()
        }

        WallpaperToolbarButton {
            objectName: "wallpaper-apply"
            radius: toolbar.stacked ? toolbar.controlRadius : Math.min(8, height / 2)
            iconSize: toolbar.stacked ? Theme.fontSize + 2 : 20
            width: toolbar.stacked ? rightTools.width : Math.max(toolbar.dense ? 40 : 88, implicitWidth)
            height: toolbar.controlHeight
            readonly property bool preparingSelection: WallpaperService.busy && !!root.selected && WallpaperService.requestedPath === root.selected.path
            caption: toolbar.dense && !toolbar.stacked ? "" : preparingSelection ? "Preparing…" : WallpaperService.error ? "Retry apply" : "Apply"
            icon: toolbar.dense ? (preparingSelection ? "\uf110" : WallpaperService.error ? "\uf071" : "\uf00c") : ""
            description: WallpaperService.error || "Apply selected wallpaper"
            selected: true
            enabled: !!root.selected
            onClicked: root.applySelected()
        }
    }
}
