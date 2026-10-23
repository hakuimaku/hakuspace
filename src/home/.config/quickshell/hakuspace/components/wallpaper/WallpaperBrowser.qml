import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"
import "../motion" as Motion

FocusScope {
    id: root
    // A bounded still-image reel keeps the selected wallpaper at the center.
    property var items: []
    property string query: ""
    property string filter: WallpaperSettingsStore.savedValues.browser.filter
    property string profile: WallpaperSettingsStore.savedValues.playback.profile
    property string loadError: ""
    property bool refreshPending: false
    property bool initialized: false
    property real reveal: 1
    // Reveal the quality section inside the fixed drawing window.
    property real qualityReveal: filter === "video" ? 1 : 0
    Behavior on qualityReveal {
        NumberAnimation { duration: HAnimation.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: HAnimation.spatialCurve }
    }
    // Shared choices keep keyboard cycling and the visible selection strips aligned.
    readonly property var kinds: [{id: "static", name: "Images"}, {id: "video", name: "Videos"}]
    readonly property var profiles: [{id: "low-memory", name: "Low Memory"}, {id: "screen", name: "Screen"}, {id: "original", name: "Original"}]
    readonly property bool loading: listing.running
    readonly property bool interactionReady: visible && !loading
    readonly property var filteredItems: items.filter(item => item.kind === filter
        && item.label.toLowerCase().includes(query.trim().toLowerCase()))
    readonly property var selected: filteredItems[list.currentIndex] || null
    signal closeRequested()
    signal settingsRequested()

    // Refresh requests coalesce when an earlier scan is still running.
    function refresh() {
        if (listing.running) { refreshPending = true; return }
        loadError = ""
        listing.command = WallpaperService.command(["list", "--json"])
        listing.running = true
    }
    // Focus only selects a row; applying is always explicit.
    function applySelected(build) {
        if (!selected || WallpaperService.busy) return false
        return WallpaperService.select(selected.path, profile, build)
    }
    // Preserve the active selection when filters narrow the list.
    function resetIndex() {
        var index = filteredItems.findIndex(item => item.path === WallpaperService.current.path)
        list.currentIndex = index >= 0 ? index : filteredItems.length ? 0 : -1
    }
    // Keyboard traversal scrolls into view without starting a decoder or proxy job.
    function move(step) {
        if (!filteredItems.length) return
        list.currentIndex = (list.currentIndex + step + filteredItems.length) % filteredItems.length
    }
    // Describe preparation and the active proxy without probing media in delegates.
    function detail(item) {
        if (item.path === WallpaperService.requestedPath && WallpaperService.busy) return "Preparing · " + WallpaperService.requestedProfile
        if (item.path === WallpaperService.current.path) {
            var render = WallpaperService.current.render
            return render && render.needed ? render.width + " × " + render.height + " · " + Math.round(render.fps) + " fps · proxy ready" : "Original source"
        }
        if (item.error) return "Preview unavailable"
        if (item.metadata && WallpaperSettingsStore.savedValues.browser.showMetadata)
            return item.metadata.width + " × " + item.metadata.height + " · " + Math.round(item.metadata.fps) + " fps"
        return item.kind === "video" ? "Video wallpaper" : "Image wallpaper"
    }
    // Layer shortcuts stay available while the search field or an action has focus.
    function handleShortcut(event) {
        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_F) {
            search.forceActiveFocus()
        } else {
            var step = [Qt.Key_Left, Qt.Key_Up].includes(event.key) ? -1 : [Qt.Key_Right, Qt.Key_Down].includes(event.key) ? 1 : 0
            if (!step) return false
            if (event.modifiers === Qt.ControlModifier)
                filter = kinds[(kinds.findIndex(choice => choice.id === filter) + step + kinds.length) % kinds.length].id
            else if (event.modifiers === Qt.AltModifier && filter === "video")
                profile = profiles[(profiles.findIndex(choice => choice.id === profile) + step + profiles.length) % profiles.length].id
            else return false
        }
        event.accepted = true
        return true
    }
    onFilteredItemsChanged: resetIndex()
    onVisibleChanged: if (initialized && visible) refresh()
    Component.onCompleted: { initialized = true; if (visible) refresh() }
    Keys.onEscapePressed: closeRequested()
    Keys.onReturnPressed: applySelected(false)
    Keys.onEnterPressed: applySelected(false)
    Keys.onPressed: event => {
        if (root.handleShortcut(event)) return
        if (event.modifiers === Qt.NoModifier && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            root.move(event.key === Qt.Key_Left || event.key === Qt.Key_Up ? -1 : 1)
            event.accepted = true
        }
    }

    // Wheel browsing stays available over cards, controls and empty carousel space.
    MouseArea {
        objectName: "wallpaperWheel"
        anchors.fill: parent
        z: 1000
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            root.move(event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1)
            event.accepted = true
        }
    }

    Item {
        id: header
        x: 24; y: 10
        width: parent.width - 48
        height: 146 + 98 * root.qualityReveal
        Text { objectName: "wallpaperTitle"; text: "Wallpaper"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 26; font.weight: Font.DemiBold }
        WallpaperActionButton { x: parent.width - 36; width: 36; height: 36; text: "×"; Accessible.name: "Close wallpaper browser"; onClicked: root.closeRequested() }
        TextField {
            id: search
            objectName: "wallpaperSearch"
            y: 44
            width: parent.width; height: 38
            placeholderText: "Search wallpapers…"
            color: Theme.fg
            placeholderTextColor: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            leftPadding: 12
            selectByMouse: true
            background: Rectangle { color: Theme.hoverMuted; radius: Theme.radius; border.color: search.activeFocus ? Theme.accent : "transparent" }
            onTextChanged: root.query = text
            Accessible.name: "Search wallpapers"
            Keys.onPressed: event => root.handleShortcut(event)
            Keys.onDownPressed: event => {
                if (!root.handleShortcut(event)) { list.forceActiveFocus(); root.move(1) }
            }
            Keys.onEscapePressed: root.closeRequested()
            Keys.onReturnPressed: root.applySelected(false)
        }
        Text { y: 94; text: "LIBRARY"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.2 }
        Item {
            id: typeLane
            y: 112; width: parent.width; height: 34
            readonly property real slotWidth: (width - 8) / 2
            // A moving underline distinguishes library tabs from quality cards.
            Item {
                width: parent.width; height: 3; anchors.bottom: parent.bottom
                Motion.SelectionPill {
                    objectName: "wallpaper-type-indicator"
                    targetIndex: root.kinds.findIndex(choice => choice.id === root.filter)
                    slotCount: root.kinds.length; slotSpacing: 8
                }
            }
            Repeater {
                model: root.kinds
                delegate: WallpaperActionButton {
                    required property var modelData
                    required property int index
                    objectName: "wallpaper-kind-" + modelData.id
                    x: index * (typeLane.slotWidth + 8)
                    width: typeLane.slotWidth; height: 30
                    idleColor: "transparent"
                    selectedColor: "transparent"
                    foregroundColor: Theme.fgMuted
                    selectedForegroundColor: Theme.accent
                    text: modelData.name
                    selected: root.filter === modelData.id
                    onClicked: root.filter = modelData.id
                }
            }
        }
        Item {
            objectName: "wallpaper-quality-reveal"
            y: 146; width: parent.width; height: 98 * root.qualityReveal
            visible: root.qualityReveal > 0
            enabled: root.filter === "video"
            opacity: root.qualityReveal
            clip: true
            Text { y: 18; text: "VIDEO QUALITY"; color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.2 }
            Rectangle {
                id: qualityLane
                objectName: "wallpaper-quality"
                y: 36; width: parent.width; height: 62
                color: Theme.hoverMuted; radius: 12
                readonly property int selectedIndex: root.profiles.findIndex(choice => choice.id === root.profile)
                readonly property Item currentButton: qualityChoices.itemAt(selectedIndex) || null
                // The shared HakuMenu pill stretches between quality choices and follows presses.
                Motion.SelectionPill {
                    id: qualityIndicator
                    objectName: "wallpaper-quality-indicator"
                    targetIndex: qualityLane.selectedIndex
                    slotCount: 3; slotSpacing: 8
                    radius: qualityLane.currentButton ? qualityLane.currentButton.radius : 10
                    scale: qualityLane.currentButton ? qualityLane.currentButton.scale : 1
                    transform: Scale {
                        origin.x: qualityIndicator.width / 2; origin.y: qualityIndicator.height / 2
                        xScale: qualityLane.currentButton ? qualityLane.currentButton.horizontalScale : 1
                    }
                }
                Repeater {
                    id: qualityChoices
                    model: root.profiles
                    delegate: WallpaperActionButton {
                        id: qualityButton
                        required property var modelData
                        required property int index
                        objectName: "wallpaper-quality-" + modelData.id
                        x: index * (width + 8)
                        width: (qualityLane.width - 16) / 3; height: qualityLane.height
                        idleColor: "transparent"
                        selectedColor: "transparent"
                        selected: root.profile === modelData.id
                        Accessible.name: modelData.name + " video quality"
                        onClicked: root.profile = modelData.id
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Text { text: qualityButton.modelData.name; color: qualityButton.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; font.weight: Font.Medium }
                            Text {
                                text: qualityButton.index === 0 ? "720p · 24 fps" : qualityButton.index === 1 ? "Display · 60 fps" : "Source quality"
                                color: qualityButton.foreground; opacity: 0.7
                                font.family: Theme.fontFamily; font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
        Rectangle { y: parent.height + 12; width: parent.width; height: 1; color: Theme.hoverMuted }
    }
    PathView {
        id: list
        objectName: "wallpaperReel"
        x: 24; y: header.y + header.height + 28
        width: parent.width - 48
        height: Math.max(0, footer.y - y - 16)
        readonly property real cardWidth: Math.max(100, Math.min(420, width - 32, (height - 48) * 16 / 9 * 0.8))
        clip: true
        model: root.filteredItems
        currentIndex: -1
        pathItemCount: 3
        cacheItemCount: 0
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: 180
        dragMargin: width / 2
        snapMode: PathView.SnapToItem
        path: Path {
            startX: list.width / 2; startY: 0
            PathAttribute { name: "cardScale"; value: 0.55 }
            PathAttribute { name: "cardOpacity"; value: 0.25 }
            PathAttribute { name: "cardDepth"; value: 0 }
            PathLine { x: list.width / 2; y: list.height / 2 }
            PathAttribute { name: "cardScale"; value: 1 }
            PathAttribute { name: "cardOpacity"; value: 1 }
            PathAttribute { name: "cardDepth"; value: 10 }
            PathLine { x: list.width / 2; y: list.height }
            PathAttribute { name: "cardScale"; value: 0.55 }
            PathAttribute { name: "cardOpacity"; value: 0.25 }
            PathAttribute { name: "cardDepth"; value: 0 }
        }
        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property bool chosen: PathView.isCurrentItem
            readonly property bool activeWallpaper: WallpaperService.current.path === modelData.path
            width: list.cardWidth
            height: width * 9 / 16 + 64
            // Path attributes are unset while delegates enter or leave the reel.
            visible: PathView.onPath
            scale: PathView.cardScale ?? 1
            opacity: (PathView.cardOpacity ?? 0) * root.reveal
            z: PathView.cardDepth ?? 0
            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.label + ", " + modelData.kind
            Accessible.selected: chosen
            Accessible.onPressAction: list.currentIndex = index
            // An opaque caption plate keeps adjacent previews behind the selected card.
            Rectangle { anchors.fill: parent; radius: Theme.radius + 6; color: Theme.surface }
            Rectangle {
                width: parent.width; height: width * 9 / 16
                radius: Theme.radius + 6
                color: Theme.hoverMuted
                clip: true
                Text { anchors.centerIn: parent; visible: preview.status !== Image.Ready; text: card.modelData.kind === "video" ? "▶" : "◇"; color: Theme.fgMuted; font.pixelSize: 32 }
                Image {
                    id: preview
                    anchors.fill: parent
                    source: WallpaperService.fileUrl(card.modelData.thumbnail)
                    sourceSize.width: 420; sourceSize.height: 236
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                }
                Rectangle {
                    x: parent.width - width - 12; y: 12
                    width: kindLabel.width + 16; height: 24; radius: 6
                    color: "#cc111111"
                    Text { id: kindLabel; anchors.centerIn: parent; text: card.modelData.kind === "video" ? "VIDEO" : "IMAGE"; color: "white"; font.pixelSize: 10; font.letterSpacing: 1 }
                }
                Rectangle {
                    visible: card.activeWallpaper
                    x: 12; y: parent.height - height - 12
                    width: activeLabel.width + 18; height: 26; radius: 7
                    color: Theme.accent
                    Text { id: activeLabel; anchors.centerIn: parent; text: "✓  Active"; color: Theme.onAccentColor; font.pixelSize: 11 }
                }
            }
            Text {
                y: parent.height - 50; width: parent.width
                text: card.modelData.label; elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 3; font.weight: Font.Medium
            }
            Text {
                y: parent.height - 25; width: parent.width
                text: root.detail(card.modelData)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight; color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { list.currentIndex = card.index; list.forceActiveFocus() }
                onDoubleClicked: { list.currentIndex = card.index; root.applySelected(false) }
            }
        }
        Text {
            anchors.centerIn: parent
            width: parent.width - 32
            visible: !root.filteredItems.length
            text: root.loading ? "Loading your collection…" : root.loadError || "No wallpapers found"
            wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
            color: Theme.fgDescription; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
        }
    }
    Column {
        id: footer
        x: 24; width: parent.width - 48
        anchors.bottom: parent.bottom; anchors.bottomMargin: 20
        spacing: 10
        Text {
            width: parent.width
            text: WallpaperService.error || (WallpaperService.busy ? "Preparing wallpaper…" : WallpaperService.cacheMessage || (root.filter === "static" ? "Image wallpaper" : root.profile === "low-memory" ? "Low Memory · up to 720p / 24 fps" : root.profile === "screen" ? "Screen · up to 60 fps" : "Original resolution and frame rate"))
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: WallpaperService.error ? Theme.accent : Theme.fgDescription
            font.family: Theme.fontFamily; font.pixelSize: 11
        }
        Row {
            width: parent.width; spacing: 8
            WallpaperActionButton { width: 36; height: 40; text: "↑"; Accessible.name: "Previous wallpaper"; enabled: root.filteredItems.length > 1; onClicked: root.move(-1) }
            WallpaperActionButton {
                width: (footer.width - 96) * 0.52; height: 40
                text: WallpaperService.busy ? "Preparing…" : "Apply  ↵"
                selected: true
                enabled: !!root.selected && !WallpaperService.busy
                onClicked: root.applySelected(false)
            }
            WallpaperActionButton {
                width: (footer.width - 96) * 0.48; height: 40
                text: "Build & apply"
                enabled: !!root.selected && root.selected.kind === "video" && root.profile !== "original" && !WallpaperService.busy
                onClicked: root.applySelected(true)
            }
            WallpaperActionButton { width: 36; height: 40; text: "↓"; Accessible.name: "Next wallpaper"; enabled: root.filteredItems.length > 1; onClicked: root.move(1) }
        }
        Row {
            width: parent.width; spacing: 8
            WallpaperActionButton {
                objectName: "wallpaper-build-all"
                width: (footer.width - 8) / 2; height: 36
                text: WallpaperService.buildingVideos ? "Building videos…" : "Build all videos"
                enabled: !WallpaperService.busy && !WallpaperService.cacheBusy && root.profile !== "original" && root.items.some(item => item.kind === "video")
                onClicked: WallpaperService.buildAll(root.items, root.profile)
            }
            WallpaperActionButton {
                objectName: "wallpaper-clear-cache"
                width: (footer.width - 8) / 2; height: 36
                text: "Clear cache"
                enabled: !WallpaperService.busy && !WallpaperService.cacheBusy
                onClicked: WallpaperService.clearUnused()
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.hoverMuted }
        Row {
            width: parent.width; spacing: 8
            WallpaperActionButton { width: 104; height: 32; text: "⚙  Settings"; onClicked: root.settingsRequested() }
            WallpaperActionButton { width: 72; height: 32; text: "Refresh"; enabled: !root.loading; onClicked: root.refresh() }
            Text {
                width: Math.max(0, footer.width - 192); height: 32
                text: root.filteredItems.length + " wallpapers · " + Math.round(WallpaperService.cacheMiB) + " MB"
                horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: Theme.fgMuted; font.family: Theme.fontFamily; font.pixelSize: 10
            }
        }
    }
    Process {
        id: listing
        stdout: StdioCollector { id: listOut }
        stderr: StdioCollector { id: listErr }
        onExited: code => {
            if (code !== 0) root.loadError = listErr.text.trim() || "Could not load wallpapers"
            else {
                try { root.items = JSON.parse(listOut.text); WallpaperService.warm(root.items) }
                catch (e) { root.loadError = "Invalid wallpaper list" }
            }
            if (root.refreshPending) { root.refreshPending = false; root.refresh() }
        }
    }
}
