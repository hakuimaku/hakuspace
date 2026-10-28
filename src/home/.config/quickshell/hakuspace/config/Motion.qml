pragma Singleton
import QtQuick

QtObject {
    // Core timing tiers
    readonly property int fast: 160
    // Standard transition duration.
    readonly property int normal: 320
    // Slow transition and tooltip duration.
    readonly property int slow: 540

    // Module curve.
    readonly property list<real> moduleCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
    // Tooltip curve.
    readonly property list<real> tooltipCurve: [0.4, 0.0, 0.2, 1.0, 1, 1]
    // Shell curve.
    readonly property list<real> shellCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
    // Both wipe layers share easing while retaining independent durations.
    readonly property list<real> shellTransitionCurve: [0.65, 0.0, 0.35, 1.0, 1, 1]

    // Navigation Motion (slower, modern fluid expansion)
    readonly property int navigationOpenDuration: 600
    // Navigation close duration.
    readonly property int navigationCloseDuration: 420
    // Navigation collapse duration.
    readonly property int navigationCollapseDuration: 240
    // Navigation open curve.
    readonly property list<real> navigationOpenCurve: [0.16, 1.0, 0.25, 1.0, 1, 1]
    // Navigation close curve.
    readonly property list<real> navigationCloseCurve: [0.25, 1.0, 0.35, 1.0, 1, 1]

    // Dashboard Motion (gentle bouncing elastic expansion & graceful unhurried close)
    readonly property int dashboardOpenDuration: 640
    // Dashboard close duration.
    readonly property int dashboardCloseDuration: 500
    // Dashboard open curve.
    readonly property list<real> dashboardOpenCurve: [0.24, 1.30, 0.34, 1.0, 1, 1]
    // Dashboard close curve.
    readonly property list<real> dashboardCloseCurve: [0.32, 0.0, 0.22, 1.0, 1, 1]

    // Sidebar Motion (tactile, bouncy elastic expansion with visible rebound)
    readonly property int sidebarOpenDuration: 600
    // Sidebar close duration.
    readonly property int sidebarCloseDuration: 320
    // Sidebar open curve.
    readonly property list<real> sidebarOpenCurve: [0.30, 1.48, 0.38, 1.0, 1, 1]
    // Sidebar close curve.
    readonly property list<real> sidebarCloseCurve: [0.38, 0.0, 0.22, 1.0, 1, 1]

    // Sidebar Tool / Temp Note Panel Motion (calm flare expansion from rail)
    readonly property int sidebarToolOpenDuration: 560
    // Sidebar tool close duration.
    readonly property int sidebarToolCloseDuration: 400
    // Sidebar tool open curve.
    readonly property list<real> sidebarToolOpenCurve: [0.16, 1.08, 0.30, 1.0, 1, 1]
    // Sidebar tool close curve.
    readonly property list<real> sidebarToolCloseCurve: [0.32, 0.0, 0.22, 1.0, 1, 1]

    // Dashboard Dynamic Widget Switch Motion (subtle directional card slide-fade)
    readonly property int dashboardWidgetSwitchDuration: 260
    // Dashboard widget switch curve.
    readonly property list<real> dashboardWidgetSwitchCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]

    // Haku menu open duration.
    readonly property int hakuMenuOpenDuration: 360
    // Haku menu close duration.
    readonly property int hakuMenuCloseDuration: 308
    // Haku menu open curve.
    readonly property list<real> hakuMenuOpenCurve: [0.88, 1.31, 0.25, 0.98, 1, 1]
    // Haku menu close curve.
    readonly property list<real> hakuMenuCloseCurve: [1, 0.3, 0.25, 1, 1, 1]
    // Tab-to-tab width morph is intentionally calmer than the bouncy open curve.
    readonly property int hakuMenuResizeDuration: 280
    // Haku menu resize curve.
    readonly property list<real> hakuMenuResizeCurve: [0.7, 1.0, 0.6, 0.98, 1, 1]
    // Haku menu bounce headroom.
    readonly property real hakuMenuBounceHeadroom: 0.04
    // Settings resize duration.
    readonly property int settingsResizeDuration: 280
    // Settings resize curve.
    readonly property list<real> settingsResizeCurve: [0.7, 1.0, 0.6, 0.98, 1, 1]

    // Bottom Dock reveal, collapse and dynamic-width motion.
    readonly property int dockOpenDuration: 360
    // Dock close duration.
    readonly property int dockCloseDuration: 224
    // Dock resize duration.
    readonly property int dockResizeDuration: 280
    // Dock open curve.
    readonly property list<real> dockOpenCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
    // Dock close curve.
    readonly property list<real> dockCloseCurve: [0.4, 0.0, 0.2, 1.0, 1, 1]

    // Six control values drive the asymmetric workspace and flare motion.
    readonly property list<real> spatialCurve: [0.5, 1.21, 0.22, 1, 1, 1]
    // Effects curve.
    readonly property list<real> effectsCurve: [0.56, 0.8, 0.34, 1, 1, 1]
    // Selection and spatial transition duration.
    readonly property int spatial: 350
    // Decorative effect duration.
    readonly property int effects: 200
    // Selection trailing-edge duration multiplier.
    readonly property real trailFactor: 1.5

    // Shared Hikai interactive-state motion. Keep these calmer than shell-open motion.
    readonly property int buttonHoverDuration: 240
    // Button press duration.
    readonly property int buttonPressDuration: 120
    // Button release duration.
    readonly property int buttonReleaseDuration: 240
    // Button focus duration.
    readonly property int buttonFocusDuration: 240
    // Button hover curve.
    readonly property list<real> buttonHoverCurve: [0.20, 0.60, 0.20, 1.0, 1, 1]
    // Button press curve.
    readonly property list<real> buttonPressCurve: [0.40, 0.00, 0.20, 1.0, 1, 1]
    // Button release curve.
    readonly property list<real> buttonReleaseCurve: [0.16, 1.08, 0.30, 1.0, 1, 1]
    // Button focus curve.
    readonly property list<real> buttonFocusCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]

    // Shared Action Layer Motion (centered reveal, smooth morphing, fade-zoom close)
    readonly property int actionLayerOpenDuration: 560
    // Action layer close duration.
    readonly property int actionLayerCloseDuration: 460
    // Action layer morph duration.
    readonly property int actionLayerMorphDuration: 600
    // Action layer morph content duration.
    readonly property int actionLayerMorphContentDuration: 340
    // Action layer open curve.
    readonly property list<real> actionLayerOpenCurve: [0.16, 1.0, 0.25, 1.0, 1, 1]
    // Action layer close curve.
    readonly property list<real> actionLayerCloseCurve: [0.25, 1.0, 0.35, 1.0, 1, 1]
    // Action layer morph curve.
    readonly property list<real> actionLayerMorphCurve: [0.20, 0.90, 0.20, 1.0, 1, 1]
    // Action layer content curve.
    readonly property list<real> actionLayerContentCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]
    // Action layer data fade duration.
    readonly property int actionLayerDataFadeDuration: 260
    // Action layer data fade curve.
    readonly property list<real> actionLayerDataFadeCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]
    // Shell wipe timings remain available through Theme.
    readonly property int shellTransitionAccentDuration: 560
    // Shell transition black duration.
    readonly property int shellTransitionBlackDuration: 400
    // Shell transition black delay.
    readonly property int shellTransitionBlackDelay: 60
    // Shell transition hold duration.
    readonly property int shellTransitionHoldDuration: 240
    // Floating panels scale the sidebar tool timing.
    readonly property real floatingPanelOpenFactor: 0.9
    // Floating panel close factor.
    readonly property real floatingPanelCloseFactor: 0.7
}
