import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "services"
import "components/base" as Base
import "components/dashboard" as Dashboard

ShellRoot {
    id: root
    // Count object construction and destruction independently from window visibility.
    property int births: 0
    property int deaths: 0
    property int widgetCount: 0
    property int phase: 0
    property int ticks: 0
    property int pollRuns: 0
    property var liveNotifications: []
    property QtObject memory: QtObject {
        property string recordsJson: "[]"
        property int nextKey: 1000
    }

    function check(condition, message) {
        if (condition) return
        console.error("Memory lifecycle failed: " + message)
        Qt.exit(1)
        throw new Error(message)
    }

    Base.LifecycleLoader {
        id: lifetime
        QtObject {
            property bool releaseReady: false
            Component.onCompleted: ++root.births
            Component.onDestruction: ++root.deaths
        }
    }
    Dashboard.DashboardWidgetHost {
        id: widgets
        width: 400; height: 300
        widgets: [{key: "one", title: "One", component: fakeWidget},
                  {key: "two", title: "Two", component: fakeWidget},
                  {key: "three", title: "Three", component: fakeWidget}]
    }
    Component {
        id: fakeWidget
        Item {
            Component.onCompleted: ++root.widgetCount
            Component.onDestruction: --root.widgetCount
        }
    }
    // Model protocol callbacks without creating a second notification server.
    function makeNotification(id, isTransient) {
        var closed = null
        var value = {id: id, tracked: false, lastGeneration: false, appName: "memory-test",
            desktopEntry: "", appIcon: "", summary: "bounded history", body: "", image: "",
            urgency: 1, expireTimeout: 0, resident: false, transient: isTransient, actions: [],
            closed: {connect: function(handler) { closed = handler }},
            dismiss: function() { closed(NotificationCloseReason.Dismissed) },
            expire: function() { closed(NotificationCloseReason.Expired) }}
        for (var field of ["appName", "appIcon", "desktopEntry", "summary", "body", "image",
                           "urgency", "expireTimeout", "resident", "transient", "actions"])
            value[field + "Changed"] = {connect: function(handler) {}}
        return value
    }

    // Validate history restore, burst ingestion and synchronous protocol cleanup.
    function checkHistory() {
        var legacy = []
        for (var i = 0; i < 500; ++i) legacy.push({key: i, id: i, live: false})
        memory.recordsJson = JSON.stringify(legacy)
        NotificationStore.start(memory)
        check(NotificationStore.records.length === 100 && NotificationStore.records[0].key === 400, "legacy trim keeps newest records")
        for (var j = 0; j < 500; ++j) {
            var notification = makeNotification(j + 1000, false)
            NotificationStore.accept(notification)
            liveNotifications.push(notification)
        }
        check(NotificationStore.records.length === 500 && Object.keys(NotificationStore._handles).length === 500, "never evict live notifications")
        for (var item of liveNotifications) {
            item.expire()
        }
        liveNotifications = []
        check(NotificationStore.records.length === 100, "closed burst returns to cap")
        check(Object.keys(NotificationStore._handles).length === 0 && Object.keys(NotificationStore._deadlines).length === 0, "protocol cleanup")
        check(!NotificationStore.expiryTimer.running, "expiry timer stops")
        var temporary = makeNotification(2000, true)
        temporary.expireTimeout = 5000
        NotificationStore.accept(temporary)
        temporary.dismiss()
        check(Object.keys(NotificationStore._deadlines).length === 0, "transient deadline cleanup")
        NotificationStore.clearAll()
        check(NotificationStore.records.length === 0, "clear bounded history")
    }

    Connections { target: Audio.poll; function onExited() { ++root.pollRuns } }
    Timer {
        interval: 40
        repeat: true
        running: true
        onTriggered: {
            root.check(++root.ticks < 250, "timeout in phase " + root.phase)
            if (root.phase === 0) {
                root.check(!lifetime.active && root.births === 0, "closed loader starts empty")
                root.check(root.widgetCount === 1, "one dashboard widget at rest")
                root.check(Audio.subscribers === 0 && !Audio.pollTimer.running && !Brightness.pollTimer.running && !PpdProfile.pollTimer.running, "no unsolicited polling")
                root.checkHistory()
                Audio.poll.command = ["sh", "-c", "sleep 0.2; printf 'Volume: 0.5\\n'"]
                Audio.refresh()
                Audio.refresh()
                Audio.refresh()
                lifetime.requested = true
                root.phase = 1
            } else if (root.phase === 1) {
                root.check(root.births === 1, "one loaded object")
                lifetime.requested = false
                root.phase = 2
            } else if (root.phase === 2) {
                root.check(lifetime.active && root.deaths === 0, "close animation retains object")
                lifetime.requested = true
                root.phase = 3
            } else if (root.phase === 3) {
                root.check(root.births === 1, "reopen reuses closing object")
                lifetime.requested = false
                lifetime.item.releaseReady = true
                widgets.nextWidget()
                root.phase = 4
            } else if (root.phase === 4) {
                root.check(!lifetime.active && root.deaths === 1, "settled object destroyed")
                if (widgets.transitioning) {
                    root.check(root.widgetCount === 2, "only incoming and outgoing widgets")
                    return
                }
                root.check(root.widgetCount === 1, "outgoing widget unloaded")
                if (Audio.poll.running || root.pollRuns < 2) return
                root.check(root.pollRuns === 2 && !Audio.refreshPending, "overlapping refreshes coalesce")
                Audio.acquire(); Brightness.acquire(); PpdProfile.acquire()
                root.check(Audio.pollTimer.running && Brightness.pollTimer.running && PpdProfile.pollTimer.running, "visible controls poll")
                Audio.release(); Brightness.release(); PpdProfile.release()
                root.check(!Audio.pollTimer.running && !Brightness.pollTimer.running && !PpdProfile.pollTimer.running, "hidden controls stop polling")
                console.log("Hikai memory lifecycle checks passed")
                Qt.quit()
            }
        }
    }
}
