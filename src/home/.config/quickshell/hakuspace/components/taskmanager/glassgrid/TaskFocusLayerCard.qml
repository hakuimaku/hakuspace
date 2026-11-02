import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../services"
import "TaskManagerMotion.js" as Motion

Rectangle {
    id: root

    readonly property string cardRole: "focusCard"
    property int instanceId: 0
    property string metricId: "memory"
    readonly property alias displayMetric: root.metricId
    property rect startRect: Qt.rect(0, 0, 100, 100)
    property rect targetRect: Qt.rect(0, 0, 100, 100)
    property rect idleRect: Qt.rect(0, 0, 100, 100)
    property real progress: 1.0
    property real roleProgress: 1.0
    property bool isFront: false
    property bool isAnimating: false
    property bool interactive: true
    property bool compact: false
    property bool ultraCompact: false
    property bool reducedMotion: false
    property real waterWavePhase: 0.0

    property var memory: ({})
    property var gpus: []
    property var disks: ({})
    property var network: ({})
    property var history: []
    property bool serviceReady: false
    property string interfaceName: ""
    property var visuals
    signal interfaceSelected(string name)

    objectName: isAnimating ? "incomingMorphCard" : (isFront ? "taskFocusCard" : "taskFocusBackCard")
    radius: Theme.radius
    border.width: 0

    readonly property real clampedRole: Motion.clamp01(root.roleProgress)
    readonly property real clampedProgress: Motion.clamp01(root.progress)

    readonly property color compactBaseColor: visuals
        ? (root.metricId === "memory" ? visuals.activeCardSurface : visuals.cardSurface)
        : Theme.surface
    readonly property color focusBaseColor: visuals ? visuals.focusSurface : Theme.surface
    readonly property color blendedTint: Qt.rgba(
        Motion.lerp(compactBaseColor.r, focusBaseColor.r, clampedRole),
        Motion.lerp(compactBaseColor.g, focusBaseColor.g, clampedRole),
        Motion.lerp(compactBaseColor.b, focusBaseColor.b, clampedRole),
        Motion.lerp(compactBaseColor.a, focusBaseColor.a, clampedRole)
    )

    color: isAnimating ? Qt.tint(Theme.surface, blendedTint) : (visuals ? visuals.focusSurface : Theme.surface)
    clip: true

    x: isAnimating ? Math.round(Motion.lerp(startRect.x, targetRect.x, clampedProgress)) : Math.round(idleRect.x)
    y: isAnimating ? Math.round(Motion.lerp(startRect.y, targetRect.y, clampedProgress)) : Math.round(idleRect.y)
    width: isAnimating ? Math.max(1, Math.round(Motion.lerp(startRect.width, targetRect.width, clampedProgress))) : Math.max(1, Math.round(idleRect.width))
    height: isAnimating ? Math.max(1, Math.round(Motion.lerp(startRect.height, targetRect.height, clampedProgress))) : Math.max(1, Math.round(idleRect.height))

    readonly property real headerProgress: Motion.segment(root.clampedRole, 0.0, 0.36)
    readonly property real detailProgress: Motion.segment(root.clampedRole, 0.28, 0.88)

    Accessible.role: Accessible.Grouping
    Accessible.name: "Focused metric " + metricId

    function resetState(metric) {
        if (presentation) presentation.showNumeric = false
    }

    TaskMetricPresentation {
        id: presentation
        objectName: "focusCardVisualLayer"
        anchors.fill: parent
        metricId: root.metricId
        expansionProgress: root.clampedRole
        interactive: root.interactive && root.clampedRole > 0.8
        waterWavePhase: root.waterWavePhase
        visuals: root.visuals
        compact: root.compact
        ultraCompact: root.ultraCompact
        reducedMotion: root.reducedMotion
        memory: root.memory
        gpus: root.gpus
        disks: root.disks
        network: root.network
        history: root.history
        serviceReady: root.serviceReady
        interfaceName: root.interfaceName
        onInterfaceSelected: name => root.interfaceSelected(name)
    }
}
