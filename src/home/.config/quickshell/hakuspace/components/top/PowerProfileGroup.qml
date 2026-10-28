import QtQuick
import "../../services"
import ".."

TopModule {
    id: root
    // The shared bar owns preference gating; this module owns daemon availability.
    property bool requested: true
    property bool subscribed: false
    readonly property var icons: ({performance: "", balanced: "", "power-saver": ""})
    visible: requested && PpdProfile.profile !== ""
    icon: icons[PpdProfile.profile] || ""
    tooltip: "Power profile: " + PpdProfile.profile
    isAccent: false
    // Query while requested so an initially unavailable daemon can appear.
    function syncSubscription() {
        var active = !!parent && parent.visible && requested
        if (active === subscribed) return
        subscribed = active
        if (subscribed) PpdProfile.acquire()
        else PpdProfile.release()
    }
    onRequestedChanged: syncSubscription()
    Connections {
        target: root.parent
        function onVisibleChanged() { root.syncSubscription() }
    }
    Component.onCompleted: syncSubscription()
    Component.onDestruction: if (subscribed) PpdProfile.release()
    onClicked: PpdProfile.cycle()
}
