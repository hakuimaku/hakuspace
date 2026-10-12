pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

QtObject {
    id: root

    // Records contain presentation data only. Protocol objects live in _handles
    // while active and are removed synchronously when closed() is delivered.
    property var records: []
    readonly property int count: records.filter(function(record) {
        return !record.transient && !record.dismissed
    }).length
    property var _handles: ({})
    property var _deadlines: ({})
    property int _nextKey: 1
    property var _memory: null
    property bool _started: false
    property bool dnd: false

    onDndChanged: {
        if (dnd) hidePopups()
    }

    // Toggles do-not-disturb mode and hides active popups if enabled.
    function toggleDnd() { dnd = !dnd }

    // Marks all active popup notifications as ineligible for popup display.
    function hidePopups() {
        records = records.map(function(record) {
            return record.popupEligible ? Object.assign({}, record, { popupEligible: false }) : record
        })
    }

    // Resolves primary screen name used as the popup destination fallback.
    function popupScreen() {
        return Quickshell.screens.length ? Quickshell.screens[0].name : ""
    }

    // Filters and returns the latest visible popup records for a screen.
    function popupForScreen(screenName) {
        var target = popupScreen()
        return records.filter(function(record) {
            var originAvailable = false
            for (var i = 0; i < Quickshell.screens.length; ++i)
                if (Quickshell.screens[i].name === record.popupScreenName) originAvailable = true
            return record.live && record.popupEligible && !record.dismissed && !dnd
                && UiState.activePanel !== "notifications"
                && (record.popupScreenName === screenName
                    || (!originAvailable && screenName === target))
        }).slice(-3).reverse()
    }

    onRecordsChanged: {
        if (_memory) _memory.recordsJson = JSON.stringify(records)
    }

    // Initializes notification store with persisted records from memory.
    function start(memory) {
        // The reloadable holder belongs to ShellRoot, where Quickshell can
        // match it to the preceding configuration generation.
        _memory = memory
        records = JSON.parse(memory.recordsJson || "[]").map(function(record) {
            return Object.assign({}, record, { popupEligible: false })
        })
        _nextKey = memory.nextKey || 1
        _started = true
        return server
    }

    // Finds array index of a notification by its tracking key.
    function indexOfKey(key) {
        for (var i = 0; i < records.length; ++i) {
            if (records[i].key === key) return i
        }
        return -1
    }

    // Finds active notification key corresponding to a notification ID.
    function activeKeyForId(id, allowUnbound) {
        for (var i = 0; i < records.length; ++i) {
            var record = records[i]
            if (record.id === id && record.live && (_handles[record.key] || allowUnbound))
                return record.key
        }
        return null
    }

    // Creates an immutable record snapshot from an incoming notification object.
    function snapshot(notification, previous, key) {
        var actions = []
        for (var i = 0; i < notification.actions.length; ++i) {
            var action = notification.actions[i]
            actions.push({ identifier: action.identifier, text: action.text })
        }
        return {
            key: key,
            id: notification.id,
            appName: notification.appName,
            desktopEntry: notification.desktopEntry,
            appIcon: notification.appIcon,
            summary: notification.summary,
            body: notification.body,
            image: notification.image,
            urgency: notification.urgency,
            timestamp: previous ? previous.timestamp : Date.now(),
            expireTimeout: notification.expireTimeout,
            resident: notification.resident,
            transient: notification.transient,
            actions: actions,
            live: true,
            popupEligible: !notification.lastGeneration && !dnd
                           && UiState.activePanel !== "notifications"
                           && (previous ? previous.popupEligible : true),
            popupScreenName: previous ? previous.popupScreenName : popupScreen(),
            read: previous ? previous.read : false,
            dismissed: previous ? previous.dismissed : false,
            expired: false,
            closeReason: ""
        }
    }

    // Refreshes the snapshot for an already tracked notification.
    function refresh(key, notification) {
        if (_handles[key] !== notification) return
        var index = indexOfKey(key)
        if (index < 0) return
        var updated = records.slice()
        updated[index] = snapshot(notification, updated[index], key)
        records = updated
    }

    // Computes and registers the timeout deadline for notification expiry.
    function scheduleExpiry(key, notification) {
        // This installed Quickshell 0.3.1 exposes the D-Bus timeout in ms.
        var timeoutMs = notification.expireTimeout
        if (timeoutMs < 0)
            timeoutMs = notification.urgency === NotificationUrgency.Critical ? 10000 : 5000
        if (timeoutMs === 0) delete _deadlines[key]
        else _deadlines[key] = Date.now() + timeoutMs
        expiryTimer.running = Object.keys(_deadlines).length > 0
    }

    // Closes a notification, cleans up handles/deadlines, and updates status.
    function close(key, notification, reason) {
        if (_handles[key] !== notification) return
        delete _handles[key]
        delete _deadlines[key]
        expiryTimer.running = Object.keys(_deadlines).length > 0
        var index = indexOfKey(key)
        if (index < 0) return
        var updated = records.slice()
        var record = updated[index]
        if (record.transient) {
            updated.splice(index, 1)
        } else {
            // No reference to notification or its actions survives closed().
            updated[index] = Object.assign({}, record, {
                live: false,
                popupEligible: false,
                expired: reason === NotificationCloseReason.Expired,
                closeReason: NotificationCloseReason.toString(reason)
            })
        }
        records = updated
    }

    // Ingests incoming notification, tracks handle, and sets up signal listeners.
    function accept(notification) {
        if (!_started) throw new Error("Notification arrived before history restore")
        // Quickshell drops an untracked notification after the signal handler.
        notification.tracked = true
        var key = activeKeyForId(notification.id, notification.lastGeneration)
        if (key === null) {
            key = _nextKey++
            if (_memory) _memory.nextKey = _nextKey
            var updated = records.slice()
            updated.push(snapshot(notification, null, key))
            records = updated
        } else if (_handles[key] !== notification) {
            // Replacement may supply another protocol object with the same id.
            _handles[key] = notification
            refresh(key, notification)
        } else {
            refresh(key, notification)
            scheduleExpiry(key, notification)
            return
        }

        _handles[key] = notification
        scheduleExpiry(key, notification)
        notification.closed.connect(function(reason) { root.close(key, notification, reason) })
        notification.appNameChanged.connect(function() { root.refresh(key, notification) })
        notification.appIconChanged.connect(function() { root.refresh(key, notification) })
        notification.desktopEntryChanged.connect(function() { root.refresh(key, notification) })
        notification.summaryChanged.connect(function() { root.refresh(key, notification) })
        notification.bodyChanged.connect(function() { root.refresh(key, notification) })
        notification.imageChanged.connect(function() { root.refresh(key, notification) })
        notification.urgencyChanged.connect(function() {
            root.refresh(key, notification)
            if (root._handles[key] === notification) root.scheduleExpiry(key, notification)
        })
        notification.expireTimeoutChanged.connect(function() {
            root.refresh(key, notification)
            if (root._handles[key] === notification) root.scheduleExpiry(key, notification)
        })
        notification.residentChanged.connect(function() { root.refresh(key, notification) })
        notification.transientChanged.connect(function() { root.refresh(key, notification) })
        notification.actionsChanged.connect(function() { root.refresh(key, notification) })
    }

    // Dismisses notification by key, hiding it from popups and signaling client.
    function dismiss(key) {
        var index = indexOfKey(key)
        if (index < 0) return
        var updated = records.slice()
        updated[index] = Object.assign({}, updated[index], { dismissed: true, popupEligible: false })
        records = updated
        var notification = _handles[key]
        if (notification) notification.dismiss()
    }

    // Tells the notification handle to trigger expiration.
    function expire(key) {
        var notification = _handles[key]
        if (notification) notification.expire()
    }

    // Clears all stored records and dismisses active handles.
    function clearAll() {
        if (records.length === 0) return
        records = []
        var keys = Object.keys(_handles)
        for (var i = 0; i < keys.length; ++i) _handles[keys[i]].dismiss()
    }

    // Periodic timer that expires notifications past their deadline.
    // Hover does not pause the notification expiry deadline.
    property Timer expiryTimer: Timer {
        interval: 250
        repeat: true
        running: false
        onTriggered: {
            var keys = Object.keys(root._deadlines)
            var now = Date.now()
            for (var i = 0; i < keys.length; ++i) {
                var key = keys[i]
                if (root._deadlines[key] > now) continue
                delete root._deadlines[key]
                root.expire(Number(key))
            }
            running = Object.keys(root._deadlines).length > 0
        }
    }

    property Instantiator server: Instantiator {
        active: root._started
        model: 1
        delegate: NotificationServer {
            keepOnReload: true
            persistenceSupported: false
            bodySupported: true
            bodyMarkupSupported: false
            bodyHyperlinksSupported: false
            bodyImagesSupported: false
            actionsSupported: false
            actionIconsSupported: false
            imageSupported: false
            inlineReplySupported: false
            onNotification: notification => root.accept(notification)
        }
    }
}
