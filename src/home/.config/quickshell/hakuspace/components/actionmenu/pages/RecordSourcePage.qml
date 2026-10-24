import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu

ActionMenu.ActionMenuPage {
    id: root

    title: "Select Microphone"
    subtitle: "Input audio device"
    icon: "󰍬"
    geometryProfile: "option"
    canGoBack: true

    property var sources: []
    property int selectedIndex: 0
    property string rawOutput: ""

    // Formats raw ALSA audio device identifiers into clean human-readable labels.
    function formatSourceLabel(id) {
        if (!id) return "Unknown";
        // Convert long alsa device strings into human readable names
        var clean = id;
        if (clean.indexOf("HiFi__") !== -1) {
            var parts = clean.split("HiFi__");
            if (parts.length > 1) {
                return parts[1].replace("__source", "").replace(/_/g, " ");
            }
        }
        var tokens = clean.split(".");
        return tokens[tokens.length - 1].replace(/_/g, " ");
    }

    property bool loading: true
    property bool showLoadingIndicator: false

    Timer {
        id: loadingDelayTimer
        interval: 120
        running: root.loading
        onTriggered: {
            if (root.loading) root.showLoadingIndicator = true;
        }
    }

    Process {
        id: listSourcesProc
        command: [Env.binDir + "/record_ctl.sh", "list-sources", "--json"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.rawOutput += data;
            }
        }
        onExited: {
            try {
                var parsed = JSON.parse(root.rawOutput.trim());
                if (Array.isArray(parsed)) {
                    root.sources = parsed;
                }
            } catch (e) {
                root.sources = [];
            }
            root.selectedIndex = 0;
            root.loading = false;
        }
    }

    // Starts recording with selected microphone audio source device.
    function activateSource(idx) {
        if (idx < 0 || idx >= sources.length) return;
        var sourceId = sources[idx].id;
        Quickshell.execDetached([Env.binDir + "/record_ctl.sh", "start", "mic-system", "--source", sourceId]);
        root.requestClose();
    }

    onScrollPrevious: {
        if (sources.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            sourcesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    onScrollNext: {
        if (sources.length > 0) {
            root.selectedIndex = Math.min(sources.length - 1, root.selectedIndex + 1);
            sourcesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    Keys.onUpPressed: event => {
        if (sources.length > 0) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            sourcesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onDownPressed: event => {
        if (sources.length > 0) {
            root.selectedIndex = Math.min(sources.length - 1, root.selectedIndex + 1);
            sourcesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            if (sources.length > 0) {
                root.selectedIndex = 0;
                sourcesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_End) {
            if (sources.length > 0) {
                root.selectedIndex = sources.length - 1;
                sourcesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                event.accepted = true;
            }
        }
    }

    // Executes recording launch with currently selected audio source.
    function activateCurrent() {
        activateSource(root.selectedIndex);
    }

    Keys.onReturnPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        activateCurrent();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.pad

        Text {
            visible: root.loading && root.showLoadingIndicator
            text: "Detecting input devices..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        Text {
            visible: !root.loading && root.sources.length === 0
            text: "No microphone devices found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgMuted
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.pad * 2
        }

        ListView {
            id: sourcesList
            visible: root.sources.length > 0
            opacity: root.loading ? 0.0 : 1.0
            Behavior on opacity {
                NumberAnimation {
                    duration: HAnimation.actionLayerDataFadeDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: HAnimation.actionLayerDataFadeCurve
                }
            }
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.gap * 2
            clip: true
            model: root.sources

            ActionMenu.ActionMenuSelectionPill {
                id: selectionPill
                parent: sourcesList.contentItem
                z: 0
            }

            ScrollBar.vertical: ActionMenu.ActionMenuScrollBar {
                id: vbar
            }

            delegate: ActionMenu.ActionMenuButton {
                id: delegateBtn
                z: 1
                width: sourcesList.width - vbar.reservedGutter
                icon: "󰍬"
                label: root.formatSourceLabel(modelData.id)
                secondaryText: modelData.id
                selected: root.selectedIndex === index
                focused: selected

                Component.onCompleted: {
                    if (selected) selectionPill.targetItem = this;
                }
                onSelectedChanged: {
                    if (selected) selectionPill.targetItem = this;
                }
                onPointerSelected: {
                    if (hovered) {
                        root.selectedIndex = index;
                    }
                }

                onClicked: {
                    root.selectedIndex = index;
                    activateSource(index);
                }
            }
        }
    }
}
