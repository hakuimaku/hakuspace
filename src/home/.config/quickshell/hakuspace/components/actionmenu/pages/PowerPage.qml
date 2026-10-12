import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../services"
import ".." as ActionMenu
import "../../motion" as Motion

ActionMenu.ActionMenuPage {
    id: root

    title: "Power Menu"
    subtitle: ""
    geometryProfile: "powerHorizontal"
    showHeader: false

    signal pushSubmenu(string pageUrl, var props, var seedGeom, string profile)

    property int selectedIndex: 0

    readonly property var actions: [
        { id: "suspend", icon: "󰒲", label: "Suspend", danger: false },
        { id: "reboot", icon: "󰑐", label: "Reboot", danger: true },
        { id: "poweroff", icon: "󰐥", label: "Poweroff", danger: true },
        { id: "hibernate", icon: "󰒲", label: "Hibernate", danger: false },
        { id: "lock", icon: "󰌾", label: "Lock", danger: false },
        { id: "logout", icon: "󰍃", label: "Logout", danger: false }
    ]

    Process {
        id: powerProc
        onExited: {
            root.requestClose();
        }
    }

    function activateAction(idx) {
        if (idx < 0 || idx >= actions.length) return;
        var act = actions[idx];
        var btn = buttonsRow.children[idx];

        if (act.id === "logout") {
            // Power -> Logout morphs into ExitPage in the same layer!
            var geom = btn && btn.getSurfaceGeometry ? btn.getSurfaceGeometry() : null;
            root.pushSubmenu("pages/ExitPage.qml", { fromPower: true }, geom, "exitReport");
        } else {
            powerProc.command = [Env.binDir + "/power_ctl.sh", act.id];
            powerProc.running = true;
            root.requestClose();
        }
    }

    onScrollPrevious: {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
    }

    onScrollNext: {
        root.selectedIndex = Math.min(actions.length - 1, root.selectedIndex + 1);
    }

    onSelectedIndexChanged: {
        var it = (buttonsRepeater.count > root.selectedIndex && root.selectedIndex >= 0)
            ? buttonsRepeater.itemAt(root.selectedIndex)
            : null;
        if (it) selectionPill.targetItem = it;
    }

    Keys.onLeftPressed: event => {
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        event.accepted = true;
    }

    Keys.onRightPressed: event => {
        root.selectedIndex = Math.min(actions.length - 1, root.selectedIndex + 1);
        event.accepted = true;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.selectedIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectedIndex = actions.length - 1;
            event.accepted = true;
        }
    }

    function activateCurrent() {
        activateAction(root.selectedIndex);
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

    RowLayout {
        id: buttonsRow
        z: 1
        anchors.fill: parent
        spacing: Theme.pad

        Repeater {
            id: buttonsRepeater
            model: root.actions
            delegate: Motion.MorphButton {
                id: pBtn
                property bool danger: modelData.danger
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius > 0 ? Theme.radius : 12

                text: ""
                selected: root.selectedIndex === index
                focused: selected
                selectedOverridesHover: true

                idleColor: modelData.danger ? Qt.rgba(1.0, 0.3, 0.3, 0.10) : "transparent"
                hoverColor: (selected || focused) ? "transparent"
                                                  : (modelData.danger ? Qt.rgba(1.0, 0.3, 0.3, 0.28)
                                                                      : Qt.darker(Theme.hoverMuted, 1.18))
                pressedColor: (selected || focused) ? "transparent"
                                                    : (modelData.danger ? Qt.rgba(1.0, 0.3, 0.3, 0.42)
                                                                        : Qt.darker(Theme.hoverMuted, 1.35))
                selectedColor: "transparent"
                focusColor: "transparent"

                foregroundColor: (selected || focused) ? (modelData.danger ? "#ffffff" : "#000000")
                                                       : (modelData.danger ? "#ff6b6b" : Theme.fg)
                hoverForegroundColor: (selected || focused) ? foregroundColor
                                                            : (modelData.danger ? "#ffffff" : Theme.fg)
                selectedForegroundColor: modelData.danger ? "#ffffff" : "#000000"

                Component.onCompleted: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                onSelectedChanged: {
                    if (selected) {
                        selectionPill.targetItem = this;
                    }
                }

                onHoveredChanged: {
                    if (hovered) {
                        root.selectedIndex = index;
                    }
                }

                function getSurfaceGeometry(surfaceItem) {
                    var screenPt = mapToItem(null, 0, 0);
                    return {
                        screenX: screenPt.x,
                        screenY: screenPt.y,
                        x: screenPt.x,
                        y: screenPt.y,
                        width: pBtn.width,
                        height: pBtn.height,
                        radius: pBtn.radius,
                        color: modelData.danger ? "#e05555" : Theme.accent,
                        icon: modelData.icon,
                        label: modelData.label
                    };
                }

                onClicked: {
                    root.selectedIndex = index;
                    activateAction(index);
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: modelData.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 2.2
                        color: pBtn.foreground
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        font.weight: pBtn.selected ? Font.DemiBold : Font.Normal
                        color: pBtn.foreground
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
