pragma Singleton
import QtQuick

QtObject {
    id: root
    
    // Core timing tiers
    property int fast: 160
    property int normal: 320
    property int slow: 540
    
    property list<real> moduleCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
    property int tooltipDuration: slow
    property list<real> tooltipCurve: [0.4, 0.0, 0.2, 1.0, 1, 1]
    property list<real> shellCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]

    // Navigation Motion (slower, modern fluid expansion)
    property int navigationOpenDuration: 600
    property int navigationCloseDuration: 420
    property int navigationCollapseDuration: 240
    property list<real> navigationOpenCurve: [0.16, 1.0, 0.25, 1.0, 1, 1]
    property list<real> navigationCloseCurve: [0.25, 1.0, 0.35, 1.0, 1, 1]

    // Dashboard Motion (gentle bouncing elastic expansion & graceful unhurried close)
    property int dashboardOpenDuration: 640
    property int dashboardCloseDuration: 500
    property list<real> dashboardOpenCurve: [0.24, 1.30, 0.34, 1.0, 1, 1]
    property list<real> dashboardCloseCurve: [0.32, 0.0, 0.22, 1.0, 1, 1]

    // Sidebar Motion (tactile, bouncy elastic expansion with visible rebound)
    property int sidebarOpenDuration: 600
    property int sidebarCloseDuration: 320
    property list<real> sidebarOpenCurve: [0.30, 1.48, 0.38, 1.0, 1, 1]
    property list<real> sidebarCloseCurve: [0.38, 0.0, 0.22, 1.0, 1, 1]

    // Sidebar Tool / Temp Note Panel Motion (calm flare expansion from rail)
    property int sidebarToolOpenDuration: 560
    property int sidebarToolCloseDuration: 400
    property list<real> sidebarToolOpenCurve: [0.16, 1.08, 0.30, 1.0, 1, 1]
    property list<real> sidebarToolCloseCurve: [0.32, 0.0, 0.22, 1.0, 1, 1]
    // Floating panels retain the Temp Note curves with shorter reveal and collapse times.
    readonly property int floatingPanelOpenDuration: Math.round(sidebarToolOpenDuration * 0.9)
    readonly property int floatingPanelCloseDuration: Math.round(sidebarToolCloseDuration * 0.7)
    readonly property list<real> floatingPanelOpenCurve: sidebarToolOpenCurve
    readonly property list<real> floatingPanelCloseCurve: sidebarToolCloseCurve

    // Dashboard Dynamic Widget Switch Motion (subtle directional card slide-fade)
    property int dashboardWidgetSwitchDuration: 260
    property list<real> dashboardWidgetSwitchCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]

    property int hakuMenuOpenDuration: 360
    property int hakuMenuCloseDuration: 308
    property list<real> hakuMenuOpenCurve: [0.88, 1.31, 0.25, 0.98, 1, 1]
    property list<real> hakuMenuCloseCurve: [1, 0.3, 0.25, 1, 1, 1]
    // Tab-to-tab width morph is intentionally calmer than the bouncy open curve.
    property int hakuMenuResizeDuration: 280
    property list<real> hakuMenuResizeCurve: [0.7, 1.0, 0.6, 0.98, 1, 1]
    property real hakuMenuBounceHeadroom: 0.04
    property int settingsResizeDuration: 280
    property list<real> settingsResizeCurve: [0.7, 1.0, 0.6, 0.98, 1, 1]

    // Bottom Dock reveal, collapse and dynamic-width motion.
    property int dockOpenDuration: 360
    property int dockCloseDuration: 224
    property int dockResizeDuration: 280
    property list<real> dockOpenCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
    property list<real> dockCloseCurve: [0.4, 0.0, 0.2, 1.0, 1, 1]

    // Six control values drive the asymmetric workspace and flare motion.
    property list<real> spatialCurve: [0.5, 1.21, 0.22, 1, 1, 1]
    property list<real> effectsCurve: [0.56, 0.8, 0.34, 1, 1, 1]
    property int spatial: 350
    property int effects: 200
    property real trailFactor: 1.5

    // Selection Morph & Synchronized Text Fade Timing
    // The selection pill asymmetric morph completes when its trailing edge reaches target (spatial * trailFactor = 525ms).
    // Text color fade MUST take this exact duration and easing curve so both finish simultaneously.
    readonly property int selectionMorphDuration: Math.round(spatial * trailFactor)
    readonly property list<real> selectionMorphCurve: spatialCurve

    // Shared Hikai interactive-state motion. Keep these calmer than shell-open motion.
    property int buttonHoverDuration: 240
    property int buttonPressDuration: 120
    property int buttonReleaseDuration: 240
    property int buttonSelectDuration: selectionMorphDuration
    property int buttonFocusDuration: 240
    property list<real> buttonHoverCurve: [0.20, 0.60, 0.20, 1.0, 1, 1]
    property list<real> buttonPressCurve: [0.40, 0.00, 0.20, 1.0, 1, 1]
    property list<real> buttonReleaseCurve: [0.16, 1.08, 0.30, 1.0, 1, 1]
    property list<real> buttonSelectCurve: selectionMorphCurve
    property list<real> buttonFocusCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]

    // Shared Action Layer Motion (centered reveal, smooth morphing, fade-zoom close)
    property int actionLayerOpenDuration: 560
    property int actionLayerCloseDuration: 460
    property int actionLayerMorphDuration: 600
    property int actionLayerMorphContentDuration: 340
    property list<real> actionLayerOpenCurve: [0.16, 1.0, 0.25, 1.0, 1, 1]
    property list<real> actionLayerCloseCurve: [0.25, 1.0, 0.35, 1.0, 1, 1]
    property list<real> actionLayerMorphCurve: [0.20, 0.90, 0.20, 1.0, 1, 1]
    property list<real> actionLayerContentCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]
    property int actionLayerDataFadeDuration: 260
    property list<real> actionLayerDataFadeCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]
}
