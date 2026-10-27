// Derive stage transitions without clocks, processes, or compositor state.
function transition(enabled, idle, applied, allowed) {
    if (!enabled || !idle) return {pending: false, applied: false, action: applied ? "resume" : ""}
    if (applied) return {pending: false, applied: true, action: ""}
    if (!allowed) return {pending: true, applied: false, action: "retry"}
    return {pending: false, applied: true, action: "apply"}
}

// Enable monitors only after the selected native owner has loaded saved policy.
function active(backend, ready, enabled) {
    return backend === "hikai" && ready && enabled
}
