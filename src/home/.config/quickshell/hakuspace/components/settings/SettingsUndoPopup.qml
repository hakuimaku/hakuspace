import QtQuick
import "../../services"
import "../flare" as Flare

Item {
    id: root
    // Keep animation and input inside the existing Settings drawing window.
    required property rect panelRect
    property bool requested: false
    property Item shortcutTarget: null
    property string displayedMessage: ""
    readonly property real bottomSpace: height - panelRect.y - panelRect.height - Theme.spaceLg
    readonly property real cardHeight: Theme.comfortableControlHeight + Theme.spaceMd * 2
    readonly property real cardWidth: Math.max(0, Math.min(440, panelRect.width - 32))
    readonly property bool outside: bottomSpace >= cardHeight
    readonly property real extent: outside ? cardHeight : Math.max(0, Math.min(cardHeight, panelRect.height - 32))
    readonly property rect popupRect: Qt.rect(panelRect.x + (panelRect.width - cardWidth) / 2,
        outside ? panelRect.y + panelRect.height - 1 : panelRect.y + panelRect.height - extent - 16, cardWidth, extent)
    readonly property real revealedHeight: Math.max(0, Math.min(extent, morph.mHeight))
    readonly property bool releaseReady: !requested && revealedHeight <= 0.01
    visible: requested || revealedHeight > 0.01
    z: 40
    // Preserve the last label while the closing surface slides back into Settings.
    Component.onCompleted: if (SettingsCoordinator.message) displayedMessage = SettingsCoordinator.message
    Connections {
        target: SettingsCoordinator
        function onMessageChanged() { if (SettingsCoordinator.message) root.displayedMessage = SettingsCoordinator.message }
    }
    Flare.FlareMorph {
        id: morph
        shown: root.requested && root.extent > 0
        anchorRect: Qt.rect(0, 0, root.cardWidth, 1)
        contentW: root.cardWidth
        contentH: root.extent
        minW: root.cardWidth; maxW: root.cardWidth
        padX: 0; padY: 0; snap: 1
        bounds: ({start: -Theme.hugRadius, end: root.cardWidth + Theme.hugRadius})
    }
    Flare.FlareSurface {
        x: root.popupRect.x; y: root.popupRect.y
        start: 0; end: root.cardWidth
        currentHeight: root.revealedHeight
        bounds: ({start: -Theme.hugRadius, end: root.cardWidth + Theme.hugRadius})
        r: Theme.largeRadius
        rf: Theme.hugRadius
        surfaceColor: Theme.surface
    }
    Item {
        x: root.popupRect.x; y: root.popupRect.y
        width: root.cardWidth; height: root.revealedHeight
        clip: true
        enabled: root.requested
        MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }
        Item {
            y: root.revealedHeight - root.extent
            width: root.cardWidth; height: root.extent
            opacity: Math.min(1, root.revealedHeight / Math.max(1, root.extent) * 1.4)
            Text {
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom; right: undo.left; margins: Theme.spaceMd; rightMargin: Theme.spaceSm }
                text: root.displayedMessage
                color: Theme.fg
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            SettingsActionButton {
                id: undo
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Theme.spaceMd }
                width: 88; height: Theme.comfortableControlHeight
                text: "Undo"
                enabled: !!SettingsCoordinator.transaction && !SettingsCoordinator.busy
                activeFocusOnTab: true; focused: activeFocus
                Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
                onClicked: SettingsCoordinator.undo()
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
            }
        }
    }
}
