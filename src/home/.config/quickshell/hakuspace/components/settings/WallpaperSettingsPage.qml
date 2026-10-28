import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../../services"
import "../motion" as Motion

Item {
    id: root
    property Item shortcutTarget: null
    property string highlightedId: ""
    // Workspace popovers retain their focused Playback / Cache entrypoints.
    property string sectionFilter: ""
    readonly property var actionLabels: []
    readonly property string footerStatus: ""
    readonly property bool footerDirty: false
    readonly property bool footerError: false
    readonly property var sidebarSections: page.sidebarSections
    readonly property string activeSection: page.activeSection
    function canActivate(label) { return false }
    function activateAction(label) { }
    function reveal(id, section) { if (id === "wallpaper.proxy.maxCacheMiB") cacheDialog.open(); else page.reveal(id, section) }
    function scrollToSection(name) { page.scrollToSection(name) }
    Component.onCompleted: WallpaperService.refreshCache()
    SettingsCategoryPage {
        id: page
        anchors.fill: parent
        visible: root.sectionFilter !== "cache"
        category: "Wallpaper"; shortcutTarget: root.shortcutTarget; highlightedId: root.highlightedId
        excludedGroups: root.sectionFilter === "playback" ? ["Folders & rotation", "Browser"] : []
        excludedIds: ["wallpaper.proxy.maxCacheMiB"]
        localContents: !root.sectionFilter
        extraSections: root.sectionFilter ? [] : ["Video cache"]
        leadingContent: root.sectionFilter ? null : thumbnail
        trailingContent: root.sectionFilter ? null : cacheSummary
    }
    Component {
        id: thumbnail
        Column {
            spacing: Theme.spaceSm
            Image { width: parent.width; height: 140; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: Math.ceil(width * Screen.devicePixelRatio); sourceSize.height: Math.ceil(height * Screen.devicePixelRatio); source: WallpaperService.fileUrl(WallpaperService.current.thumbnail || (WallpaperService.current.kind === "static" ? WallpaperService.current.path : "")) }
            Text { width: parent.width; text: WallpaperService.current.path || "No current wallpaper"; elide: Text.ElideMiddle; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
        }
    }
    Component {
        id: cacheSummary
        SettingsSectionCard {
            width: parent.width; title: "Video cache"
            Text { width: parent.width; text: (WallpaperService.cacheBytes / 1048576).toFixed(1) + " / " + WallpaperSettingsStore.values.proxy.maxCacheMiB + " MiB · " + WallpaperService.cacheEntries.length + " prepared copies"; color: Theme.fg; font.family: Theme.fontFamily; wrapMode: Text.Wrap }
            Text { width: parent.width; text: WallpaperService.cacheMessage || (WallpaperService.cacheBusy ? "Maintenance active" : "Cache ready"); color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2; wrapMode: Text.Wrap }
            SettingsActionButton { width: 190; height: 36; text: "Manage cache…"; activeFocusOnTab: true; focused: activeFocus; onClicked: cacheDialog.open(); Keys.onReturnPressed: clicked(); Keys.onSpacePressed: clicked() }
        }
    }
    // Both cache entrypoints use the same bounded, padded inventory viewport.
    Component {
        id: cacheContent
        Flickable {
            id: cacheScroll
            objectName: "wallpaper-settings-scroll"
            contentWidth: width
            contentHeight: cacheBody.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Motion.HScrollBar { id: cacheBar }
            WallpaperCachePanel {
                id: cacheBody
                width: Math.max(0, cacheScroll.width - cacheBar.reservedGutter)
                shortcutTarget: root.shortcutTarget
            }
        }
    }
    Loader { anchors.fill: parent; active: root.sectionFilter === "cache"; sourceComponent: cacheContent }
    Dialog {
        id: cacheDialog
        objectName: "settings-wallpaper-cache-dialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(820, root.width); height: Math.min(720, root.height)
        padding: Theme.spaceXl
        spacing: Theme.spaceSm
        modal: true; dim: true; focus: true
        title: "Manage wallpaper cache"
        closePolicy: Popup.CloseOnEscape
        property real revealProgress: 0
        property Item previousFocus: null
        opacity: revealProgress
        scale: 0.96 + revealProgress * 0.04
        onAboutToShow: previousFocus = root.Window.window ? root.Window.window.activeFocusItem : null
        onOpened: cacheClose.forceActiveFocus()
        onClosed: if (previousFocus && previousFocus.visible && previousFocus.enabled) previousFocus.forceActiveFocus()
        // Keep the current frame when a closing popup is reopened.
        enter: Transition {
            NumberAnimation { target: cacheDialog; property: "revealProgress"; to: 1; duration: HAnimation.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.actionLayerOpenCurve }
        }
        exit: Transition {
            NumberAnimation { target: cacheDialog; property: "revealProgress"; to: 0; duration: HAnimation.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.actionLayerCloseCurve }
        }
        Overlay.modal: Rectangle { color: "#80000000"; opacity: cacheDialog.revealProgress }
        background: Rectangle { color: Theme.surface; radius: Theme.largeRadius; border.width: 1; border.color: Theme.hoverMuted }
        header: Column {
            leftPadding: cacheDialog.padding
            rightPadding: cacheDialog.padding
            topPadding: cacheDialog.padding
            spacing: Theme.spaceSm
            Text { width: parent.width - parent.leftPadding - parent.rightPadding; text: cacheDialog.title; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 4; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
            Text { width: parent.width - parent.leftPadding - parent.rightPadding; text: "Prepared video copies. Your original wallpapers are kept."; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.Wrap }
        }
        contentItem: Loader {
            // Popup.visible stays true until its exit transition has finished.
            active: cacheDialog.visible
            sourceComponent: cacheContent
        }
        footer: Item {
            implicitHeight: Theme.comfortableControlHeight + Theme.spaceXl
            Rectangle { x: cacheDialog.padding; width: parent.width - x * 2; height: 1; color: Theme.hoverMuted }
            Text { x: cacheDialog.padding; y: Theme.spaceMd; width: parent.width - x * 2 - cacheClose.width - Theme.spaceMd; text: SettingsCoordinator.error || (SettingsCoordinator.busy ? "Saving…" : "Changes save automatically"); color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2; wrapMode: Text.Wrap }
            SettingsActionButton {
                id: cacheClose
                x: parent.width - width - cacheDialog.padding; y: Theme.spaceMd
                width: 104; height: Theme.comfortableControlHeight; text: "Close"
                activeFocusOnTab: true; focused: activeFocus
                onClicked: cacheDialog.close()
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }
        }
    }
}
