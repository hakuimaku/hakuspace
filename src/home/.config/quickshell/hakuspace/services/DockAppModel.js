// Compare desktop entry and Wayland IDs without requiring the optional desktop suffix.
function identity(id) {
    return String(id || "").replace(/\.desktop$/, "").toLowerCase()
}

// Resolve metadata through Quickshell before falling back to StartupWMClass.
function resolve(id, entries, byId, heuristic) {
    var exact = byId(id) || byId(id + ".desktop")
    if (exact) return exact
    var guessed = heuristic(id)
    if (guessed) return guessed
    return entries.find(function(entry) { return identity(entry.startupClass) === identity(id) && !!id }) || null
}

// Group live protocol objects once per logical application, preserving encounter order.
function group(windows, lookup) {
    var groups = []
    var indexed = Object.create(null)
    for (var window of windows) {
        var entry = lookup(window.appId)
        var key = identity(entry ? entry.id : window.appId)
        // Separate unidentified windows instead of collapsing unrelated applications.
        if (!key) key = "unknown:" + groups.length
        var app = indexed[key]
        if (!app) {
            app = {key: key, desktopId: entry ? entry.id : "", appId: window.appId,
                name: entry ? entry.name : window.appId || window.title || "Application",
                icon: entry && entry.icon ? entry.icon : "application-x-executable",
                entry: entry, windows: [], runningCount: 0, active: false, pinned: false, type: "app"}
            indexed[key] = app
            groups.push(app)
        }
        app.windows.push(window)
        app.runningCount++
        app.active = app.active || window.activated
    }
    return groups
}

// Preserve canonical pin ordering and append only applications not already represented.
function merge(pins, groups, lookup) {
    var result = []
    var represented = Object.create(null)
    for (var pin of pins) {
        if (pin.type === "system") {
            result.push({key: "system:menu", type: "system", name: "Applications", icon: "view-app-grid",
                windows: [], runningCount: 0, active: false, pinned: false, pinId: "menu"})
            continue
        }
        var entry = lookup(pin.id)
        var key = identity(entry ? entry.id : pin.id)
        if (represented[key]) continue
        var running = groups.find(function(app) { return app.key === key || identity(app.appId) === identity(pin.id) })
        if (running) key = running.key
        if (represented[key]) continue
        represented[key] = true
        result.push(Object.assign({}, running || {key: key, desktopId: entry ? entry.id : "", appId: pin.id,
            name: entry ? entry.name : pin.id, icon: entry && entry.icon ? entry.icon : "application-x-executable",
            entry: entry, windows: [], runningCount: 0, active: false, type: "app"},
            {pinned: true, pinId: pin.id, command: pin.command}))
    }
    return result.concat(groups.filter(function(app) { return !represented[app.key] }))
}

// Advance relative to the active window; an inactive group starts with its first window.
function nextWindow(windows, previous) {
    if (!windows.length) return null
    var active = windows.findIndex(function(window) { return window.activated })
    if (active < 0) active = windows.indexOf(previous)
    return windows[(active + 1) % windows.length]
}
