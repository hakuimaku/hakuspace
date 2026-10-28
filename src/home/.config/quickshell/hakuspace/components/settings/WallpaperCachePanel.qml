import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../services"
import "../motion" as Motion
import "../wallpaper" as Wallpaper

Column {
    id: root
    property Item shortcutTarget: null
    property bool sourceAvailable: false
    property string checkedPath: ""
    property string checkingPath: ""
    readonly property bool originalQuality: WallpaperSettingsStore.savedValues.playback.profile === "original"
    spacing: Theme.spaceLg
    // Check the current source only while the cache manager is in use.
    function checkSource() {
        var path = WallpaperService.current.path || ""
        if (sourceCheck.running || path === checkedPath) return
        sourceAvailable = false
        checkingPath = path
        if (!path || WallpaperService.current.kind !== "video") { checkedPath = path; return }
        sourceCheck.command = ["sh", "-c", '[ -f "$1" ] && [ -r "$1" ]', "--", path]
        sourceCheck.running = true
    }
    Connections { target: WallpaperService; function onCurrentChanged() { root.checkSource() } }
    Process { id: sourceCheck; onExited: code => { root.checkedPath = root.checkingPath; root.sourceAvailable = code === 0; root.checkSource() } }
    function cacheSize(bytes) { return Number((Number(bytes || 0) / 1048576).toFixed(1)) + " MiB" }
    Component.onCompleted: { WallpaperService.refreshCache(); checkSource() }
    Text {
        objectName: "wallpaper-cache-usage"
        width: parent.width
        text: root.cacheSize(WallpaperService.cacheBytes) + " used · " + WallpaperService.cacheEntries.length + " prepared copies"
        color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold; wrapMode: Text.Wrap
    }
    Text { width: parent.width; text: "Limit: " + WallpaperSettingsStore.values.proxy.maxCacheMiB + " MiB · Thumbnails: " + root.cacheSize(WallpaperService.cachePreviewBytes); color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
    Text { width: parent.width; text: WallpaperService.error || WallpaperService.cacheMessage || (WallpaperService.cacheBusy ? "Cache maintenance active" : "Cache is up to date"); color: WallpaperService.error ? Theme.danger : Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
    Flow {
        width: parent.width; spacing: Theme.spaceSm
        Item {
            id: prepareAllTarget
            width: prepareAll.implicitWidth; height: 36
            readonly property string reason: root.originalQuality ? "Original quality uses source files. Choose Save memory or Match screen to prepare copies." : library.running ? "Reading video library…" : WallpaperService.busy || WallpaperService.cacheBusy ? "Wait for the current wallpaper operation to finish" : "Prepare all video wallpapers"
            Wallpaper.WallpaperToolbarButton {
                id: prepareAll
                objectName: "wallpaper-prepare-library"
                anchors.fill: parent; caption: "Prepare all videos"; description: prepareAllTarget.reason
                useSettingsTooltip: true; showTooltip: false
                enabled: !root.originalQuality && !library.running && !WallpaperService.busy && !WallpaperService.cacheBusy
                onClicked: library.running = true
            }
            HoverHandler { id: prepareAllHover }
            SettingsTooltip { target: prepareAllTarget; active: prepareAllHover.hovered || prepareAll.activeFocus; text: prepareAllTarget.reason }
        }
        Item {
            id: prepareTarget
            width: prepareCurrent.implicitWidth; height: 36
            readonly property string reason: WallpaperService.current.kind !== "video" ? "Current wallpaper is not a video" : root.originalQuality || WallpaperService.current.profile === "original" ? "Original quality uses the source video without a prepared copy" : !root.sourceAvailable ? "Source unavailable" : WallpaperService.busy || WallpaperService.cacheBusy ? "Renderer or video preparation is busy" : "Prepare the current video"
            Wallpaper.WallpaperToolbarButton {
                id: prepareCurrent
                anchors.fill: parent; caption: "Prepare current"; description: prepareTarget.reason
                useSettingsTooltip: true; showTooltip: false
                enabled: WallpaperService.current.kind === "video" && !root.originalQuality && WallpaperService.current.profile !== "original" && root.sourceAvailable && !WallpaperService.busy && !WallpaperService.cacheBusy
                onClicked: WallpaperService.rebuild()
            }
            HoverHandler { id: prepareHover }
            SettingsTooltip { target: prepareTarget; active: prepareHover.hovered || prepareCurrent.activeFocus; text: prepareTarget.reason }
        }
        Wallpaper.WallpaperToolbarButton { height: 36; caption: "Open cache"; useSettingsTooltip: true; onClicked: WallpaperService.openCache() }
        Wallpaper.WallpaperToolbarButton { height: 36; caption: "Refresh"; useSettingsTooltip: true; onClicked: { root.checkedPath = ""; root.checkSource(); WallpaperService.refreshCache() } }
    }
    Rectangle {
        visible: !cacheList.count
        width: parent.width; height: 96; radius: Theme.radius
        color: Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.5))
        Text {
            anchors.fill: parent; anchors.margins: Theme.spaceLg
            verticalAlignment: Text.AlignVCenter; wrapMode: Text.Wrap
            text: WallpaperService.cacheBusy ? "Reading prepared video copies…" : "No prepared videos yet. Choose Save memory or Match screen, then prepare your videos."
            color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
        }
    }
    ListView {
        id: cacheList
        objectName: "wallpaper-cache-list"
        width: parent.width
        readonly property real rowHeight: Math.max(84, Theme.fontSize * 2 + 40)
        height: Math.min(count, 4) * rowHeight + Math.max(0, Math.min(count, 4) - 1) * spacing
        model: root.visible ? WallpaperService.cacheEntries : []
        spacing: Theme.spaceSm; clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Motion.HScrollBar { id: cacheBar }
        delegate: Rectangle {
            id: cacheRow
            required property var modelData
            width: cacheList.width - cacheBar.reservedGutter; height: cacheList.rowHeight
            radius: Theme.radius; color: cacheHover.hovered ? Theme.surfaceHighlight(1.12) : Qt.tint(Theme.surface, Qt.alpha(Theme.hoverMuted, 0.5))
            Column {
                anchors { fill: parent; margins: Theme.spaceLg }
                spacing: Theme.spaceSm
                RowLayout {
                    width: parent.width
                    Text { objectName: "wallpaper-cache-entry-title"; Layout.fillWidth: true; text: cacheRow.modelData.label; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.weight: Font.Medium }
                    Text { objectName: "wallpaper-cache-entry-state"; text: cacheRow.modelData.active ? "In use" : cacheRow.modelData.pending ? "Applying" : cacheRow.modelData.sourceChanged ? "Source changed" : cacheRow.modelData.path ? "Built" : "Unidentified"; color: cacheRow.modelData.active ? Theme.accent : Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                }
                Text {
                    objectName: "wallpaper-cache-entry-details"
                    width: parent.width
                    text: (cacheRow.modelData.profile === "low-memory" ? "720p" : cacheRow.modelData.profile === "screen" ? "Screen" : "Unknown quality")
                        + ((cacheRow.modelData.render || {}).width ? " · " + cacheRow.modelData.render.width + " × " + cacheRow.modelData.render.height : "")
                        + ((cacheRow.modelData.render || {}).fps > 0 ? " · " + Number(Number(cacheRow.modelData.render.fps).toFixed(2)) + " FPS" : "")
                        + " · " + root.cacheSize(cacheRow.modelData.bytes)
                    elide: Text.ElideRight; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
                }
            }
            HoverHandler { id: cacheHover }
            SettingsTooltip { target: cacheRow; text: cacheRow.modelData.path || cacheRow.modelData.proxyPath; active: cacheHover.hovered }
        }
    }
    GeneralSettingsForm { width: parent.width; category: "Wallpaper"; onlyIds: ["wallpaper.proxy.maxCacheMiB"]; shortcutTarget: root.shortcutTarget }
    Wallpaper.WallpaperToolbarButton {
        objectName: "wallpaper-clear-unused"
        height: 36; caption: "Clear unused cache…"; description: "Remove unused prepared copies while keeping active wallpapers and original files"
        useSettingsTooltip: true
        enabled: !WallpaperService.busy && !WallpaperService.cacheBusy && cacheList.count > 0
        onClicked: clearDialog.open()
    }
    Dialog {
        id: clearDialog
        objectName: "wallpaper-clear-cache-dialog"
        parent: Overlay.overlay; anchors.centerIn: parent
        width: Math.min(480, parent ? parent.width - Theme.spaceXl * 2 : 480)
        padding: Theme.spaceXl; spacing: Theme.spaceSm
        title: "Clear unused cache?"
        modal: true; focus: true; closePolicy: Popup.CloseOnEscape
        property real revealProgress: 0
        opacity: revealProgress; scale: 0.96 + revealProgress * 0.04
        enter: Transition { NumberAnimation { target: clearDialog; property: "revealProgress"; to: 1; duration: HAnimation.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.actionLayerOpenCurve } }
        exit: Transition { NumberAnimation { target: clearDialog; property: "revealProgress"; to: 0; duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.actionLayerCloseCurve } }
        header: Label { text: clearDialog.title; padding: Theme.spaceXl; bottomPadding: Theme.spaceSm; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
        contentItem: Text { text: "Delete unused prepared copies. The current wallpaper and original videos are kept."; wrapMode: Text.Wrap; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        background: Rectangle { radius: Theme.largeRadius; color: Theme.surface; border.width: 1; border.color: Theme.hoverMuted }
        footer: Item {
            implicitHeight: 64
            Row {
                anchors.right: parent.right; anchors.rightMargin: clearDialog.padding
                y: Theme.spaceSm; spacing: Theme.spaceSm
                SettingsActionButton { width: 100; height: 36; text: "Cancel"; activeFocusOnTab: true; focused: activeFocus; onClicked: clearDialog.reject(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
                SettingsActionButton { width: 140; height: 36; text: "Clear unused"; enabled: !WallpaperService.busy && !WallpaperService.cacheBusy; activeFocusOnTab: true; focused: activeFocus; onClicked: clearDialog.accept(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
            }
        }
        onAccepted: WallpaperService.clearUnused()
    }
    Process {
        id: library
        command: WallpaperService.command(["list", "--json"])
        stdout: StdioCollector { id: output }
        onExited: code => {
            if (code !== 0) { WallpaperService.error = "Could not read video collection"; return }
            try {
                var records = JSON.parse(output.text)
                if (!Array.isArray(records)) throw new Error("Expected a video collection")
                if (!records.some(item => item.kind === "video")) WallpaperService.cacheMessage = "No videos found in your wallpaper folders"
                else WallpaperService.buildAll(records, WallpaperSettingsStore.savedValues.playback.profile)
            } catch (error) { WallpaperService.error = "Could not read video collection" }
        }
    }
}
