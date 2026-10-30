pragma Singleton
import QtQuick

QtObject {
    id: root
    // Keep only the currently owned native lock surfaces in this private fixture.
    property var surfaces: []
    // Mirror confirmed display-off in the isolated profiling environment.
    property bool displayOff: false

    // Register a native surface until its normal compositor teardown.
    function add(surface) { surfaces = surfaces.concat([surface]) }
    function remove(surface) { surfaces = surfaces.filter(function(item) { return item !== surface }) }

    // Return primitive counters without exposing passwords or retaining snapshot QObjects.
    function snapshot() {
        return surfaces.map(function(surface) {
            var motion = surface.motionController
            return {output: surface.profileOutputName, phase: motion.visualPhase,
                idleAnimationRunning: motion.profileIdleRunning, idlePhase: motion.idlePhase,
                idleSteps: motion.profileIdleSteps, motionUpdates: motion.profileMotionUpdates,
                orbitUpdates: surface.profileOrbitUpdates, dropletsUpdates: surface.profileDropletUpdates,
                pillUpdates: surface.profilePillUpdates, renderedOrbitUpdates: surface.profileRenderedOrbitUpdates,
                frames: surface.profileFrames,
                displayActive: motion.displayActive === undefined ? true : motion.displayActive,
                quiescent: motion.quiescent === undefined ? false : motion.quiescent,
                inputReady: surface.inputReady}
        })
    }
}
