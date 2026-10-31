// Filter and sort only when process data or explicit controls change.
function processRows(processes, query, sortKey, descending) {
    var needle = query.trim().toLowerCase()
    var rows = processes.filter(function(process) {
        return !needle || [process.pid, process.name, process.cmdline, process.user].join(" ").toLowerCase().includes(needle)
    })
    var field = {cpu: "cpuTotalPercent", memory: "rss", pid: "pid", name: "name"}[sortKey] || "cpuTotalPercent"
    rows.sort(function(a, b) {
        var first = a[field], second = b[field]
        var order = field === "name" ? first.localeCompare(second) : (first || 0) - (second || 0)
        return (descending ? -order : order) || a.pid - b.pid
    })
    return rows
}

// Format optional telemetry without displaying missing sensors as zero.
function metric(value, suffix, digits) {
    return value === null || value === undefined || !Number.isFinite(value) ? "Unavailable" : value.toFixed(digits === undefined ? 1 : digits) + suffix
}

// Keep byte units consistent across summary and process details.
function bytes(value) {
    if (value === null || value === undefined || !Number.isFinite(value)) return "Unavailable"
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var unit = 0
    while (Math.abs(value) >= 1024 && unit < units.length - 1) { value /= 1024; unit++ }
    return value.toFixed(unit ? 1 : 0) + " " + units[unit]
}

// Distinguish missing metrics, permissions and unsupported GPU drivers.
function gpuUsage(gpu) {
    if (Number.isFinite(gpu.usage)) return metric(gpu.usage, "%")
    return {permissionDenied: "Permission denied", unsupported: "Unsupported", warmingUp: "Warming up…"}[gpu.status] || "Unavailable"
}
