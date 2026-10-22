// Normalize protocol objects by address without grouping application windows.
function normalize(toplevels, lookup) {
    var seen = Object.create(null)
    return toplevels.filter(function(window) {
        if (!window.address || !window.workspace || seen[window.address]) return false
        seen[window.address] = true
        return true
    }).map(function(window) {
        var wayland = window.wayland
        var ipc = window.lastIpcObject || {}
        var appId = wayland ? wayland.appId : ipc.class || ""
        var desktop = lookup(appId)
        return {key: "hypr:" + window.address, address: window.address,
            title: window.title || (desktop ? desktop.name : appId) || "Window",
            appId: appId, desktopId: desktop ? desktop.id : "",
            appName: desktop ? desktop.name : appId || "Application",
            icon: desktop && desktop.icon ? desktop.icon : "application-x-executable",
            active: window.activated, urgent: window.urgent,
            minimized: wayland ? wayland.minimized : false,
            fullscreen: wayland ? wayland.fullscreen : false,
            workspaceId: window.workspace.id, workspaceName: window.workspace.name,
            special: window.workspace.id < 0,
            monitorName: window.monitor ? window.monitor.name : "",
            waylandToplevel: wayland, hyprlandToplevel: window,
            parent: wayland ? wayland.parent : null}
    })
}

// Keep confirmed focus first, prune closed addresses and append unseen windows.
function mru(previous, windows, focused) {
    var addresses = windows.map(function(window) { return window.address })
    return [focused].concat(previous, addresses).filter(function(address, index, all) {
        return addresses.indexOf(address) >= 0 && all.indexOf(address) === index
    })
}

// Order the switch snapshot by MRU and the atlas by workspace proximity.
function ordered(windows, addresses, overview, workspaceId, monitorName) {
    function group(window) {
        if (window.workspaceId === workspaceId) return 0
        if (window.special) return 3
        return window.monitorName === monitorName ? 1 : 2
    }
    return windows.slice().sort(function(a, b) {
        return (overview ? group(a) - group(b) : 0)
            || addresses.indexOf(a.address) - addresses.indexOf(b.address)
    })
}

// Refresh metadata while freezing switch membership and preserving selection.
function reconcile(session, windows, overview, selectedAddress, selectedIndex) {
    var entries = overview ? windows.slice() : session.map(function(old) {
        return windows.find(function(window) { return window.address === old.address })
    }).filter(function(window) { return !!window })
    var index = entries.findIndex(function(window) { return window.address === selectedAddress })
    return {windows: entries, index: index >= 0 ? index : Math.min(Math.max(0, selectedIndex), entries.length - 1)}
}

// Wrap keyboard navigation without a special case at either end.
function cycle(index, delta, count) {
    return count ? ((index + delta) % count + count) % count : -1
}
