import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../config" as Config
import "../../../services"
import "../../../config/UiCatalog.js" as UiCatalog
import "../../motion" as Motion
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Shell Backend"
    subtitle: "Current: " + (currentBackend === "hikai" ? "Hikai" : "Classic")
    icon: "󰆧"
    geometryProfile: degraded ? "exitReport" : "option"

    readonly property var backends: UiCatalog.actionMenuShellBackends
    readonly property string currentBackend: AppState.shellBackend
    readonly property bool degraded: ShellHealth.degraded
    readonly property var issues: ShellHealth.issues
    property int selectedIndex: 0

    function syncSelectedIndex() {
        var preferredId = degraded ? "classic" : currentBackend;
        for (var i = 0; i < backends.length; i++) {
            if (backends[i].id === preferredId) {
                selectedIndex = i;
                break;
            }
        }
    }

    Component.onCompleted: syncSelectedIndex()
    onDegradedChanged: syncSelectedIndex()

    // Launches the headless backend transition without binding it to this ephemeral page.
    function activateBackend(backendId) {
        if (!backendId) return;
        if (backendId === root.currentBackend) {
            root.requestClose();
            return;
        }
        Quickshell.execDetached([Env.binDir + "/haku_backend.sh", "set", backendId]);
        root.requestClose();
    }

    function activateIndex(idx) {
        if (idx < 0 || idx >= backends.length) return;
        activateBackend(backends[idx].id);
    }

    function activateCurrent() {
        activateIndex(root.selectedIndex);
    }

    onScrollPrevious: {
        if (backends.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        }
    }

    onScrollNext: {
        if (backends.length > 0) {
            root.selectedIndex = Math.min(backends.length - 1, root.selectedIndex + 1);
        }
    }

    onSelectedIndexChanged: {
        var it = (backendsRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? backendsRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onUpPressed: event => {
        if (backends.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (backends.length > 0) {
            root.selectedIndex = Math.min(backends.length - 1, root.selectedIndex + 1);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home && backends.length > 0) {
            root.selectedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End && backends.length > 0) {
            root.selectedIndex = backends.length - 1;
            event.accepted = true;
        }
    }

    Keys.onReturnPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    ActionMenu.ActionMenuSelectionPill {
        id: selectionPill
        z: 0
    }

    ColumnLayout {
        id: listCol
        z: 1
        anchors.fill: parent
        spacing: Theme.actionLayerListSpacing

        Rectangle {
            id: healthBanner
            objectName: "backendHealthBanner"
            visible: root.degraded
            Layout.fillWidth: true
            implicitHeight: bannerCol.implicitHeight + Theme.cardPadding * 2
            radius: Theme.radius
            color: bannerHit.containsMouse ? Theme.danger : Theme.dangerFill
            border.width: 0

            property bool copied: false
            readonly property color inkColor: Config.Design.onAccentDark
            readonly property color mutedInkColor: Qt.rgba(0, 0, 0, 0.82)

            Timer {
                id: copiedTimer
                interval: 1800
                onTriggered: healthBanner.copied = false
            }

            MouseArea {
                id: bannerHit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["wl-copy", "--", ShellHealth.logPath]);
                    healthBanner.copied = true;
                    copiedTimer.restart();
                }
            }

            ColumnLayout {
                id: bannerCol
                z: 1
                anchors.fill: parent
                anchors.margins: Theme.cardPadding
                spacing: Theme.spaceSm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceSm

                    Text {
                        text: ""
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize + 4
                        font.weight: Font.Bold
                        color: healthBanner.inkColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Hikai degraded mode (" + root.issues.length + " issue" + (root.issues.length === 1 ? "" : "s") + ")"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 2
                        font.weight: Font.Bold
                        color: healthBanner.inkColor
                        elide: Text.ElideRight
                    }

                    Motion.MorphButton {
                        Layout.preferredHeight: Theme.fontSize * 2.0
                        Layout.preferredWidth: retryLabel.implicitWidth + Theme.pad * 1.8
                        radius: Theme.radius
                        text: ""
                        idleColor: Qt.rgba(0, 0, 0, 0.16)
                        hoverColor: Qt.rgba(0, 0, 0, 0.28)
                        pressedColor: Qt.rgba(0, 0, 0, 0.38)
                        foregroundColor: healthBanner.inkColor
                        hoverForegroundColor: healthBanner.inkColor
                        onClicked: ShellHealth.retryNow()

                        Text {
                            id: retryLabel
                            anchors.centerIn: parent
                            text: "Retry"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.weight: Font.Bold
                            color: healthBanner.inkColor
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Recommended: switch back to Classic mode until these errors are resolved.\n"
                        + (healthBanner.copied ? "Copied log path: " : "Click box to copy log path: ")
                        + ShellHealth.logPath
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                    color: healthBanner.inkColor
                    wrapMode: Text.Wrap
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 136)
                    contentWidth: width
                    contentHeight: issueList.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: issueList
                        width: parent.width
                        spacing: Theme.spaceXs

                        Repeater {
                            model: root.issues
                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: "• " + modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: Font.Bold
                                    color: healthBanner.inkColor
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Theme.spaceMd
                                    text: modelData.detail
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.max(11, Theme.fontSize - 1)
                                    color: healthBanner.mutedInkColor
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            id: backendsRepeater
            model: root.backends
            delegate: ActionMenu.ActionMenuButton {
                id: btn
                readonly property bool isRecommendedFallback: root.degraded && modelData.id === "classic" && root.currentBackend !== "classic"
                Layout.fillWidth: true
                icon: modelData.icon
                label: modelData.label
                secondaryText: isRecommendedFallback
                    ? "Recommended fallback"
                    : modelData.secondary
                badge: modelData.id === root.currentBackend ? "Active" : (isRecommendedFallback ? "Recommended" : "")
                badgeColor: isRecommendedFallback ? Theme.warning : Theme.accent
                selected: root.selectedIndex === index
                focused: selected

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this;
                }

                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this;
                }

                onPointerSelected: {
                    if (hovered) root.selectedIndex = index;
                }

                onClicked: {
                    root.selectedIndex = index;
                    root.activateBackend(modelData.id);
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
