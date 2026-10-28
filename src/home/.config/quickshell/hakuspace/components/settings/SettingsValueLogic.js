// Format durations without requiring users to convert minutes to seconds.
function duration(seconds) { return seconds % 60 === 0 ? seconds / 60 + " min" : seconds + " sec" }
// Accept one explicit time unit and enforce the provider's interval bounds.
function parseDuration(text, descriptor) {
    var match = String(text).trim().match(/^(\d+(?:\.\d+)?)\s*(s|sec|seconds?|m|min|minutes?|h|hours?)?$/i)
    if (!match) return null
    var seconds = Number(match[1]) * (/^h/i.test(match[2] || "") ? 3600 : /^m/i.test(match[2] || "") ? 60 : 1)
    return Number.isInteger(seconds) && seconds >= descriptor.min && seconds <= descriptor.max && seconds % (descriptor.step || 1) === 0 ? seconds : null
}
// Disabled stages retain their intervals but leave the cumulative chain.
function timeline(policy) {
    var total = 0
    return [{key: "dim", label: "Dim"}, {key: "lock", label: "Lock"}, {key: "displayOff", label: "Screen off"}, {key: "suspend", label: "Suspend"}].map(function(stage) {
        var enabled = policy[stage.key + "Enabled"]
        if (enabled) total += policy[stage.key + "Timeout"]
        return {key: stage.key, label: stage.label, enabled: enabled, absolute: total, interval: policy[stage.key + "Timeout"]}
    })
}
// Convert an absolute milestone back to the existing relative interval schema.
function intervalAt(policy, key, absolute) {
    var stages = timeline(policy), index = stages.findIndex(function(stage) { return stage.key === key })
    var previous = index > 0 ? stages[index - 1].absolute : 0
    return Math.max(10, Math.min(86400, Math.round((absolute - previous) / 10) * 10))
}
