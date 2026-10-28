pragma Singleton
import QtQuick
import "../config"

QtObject {
    id: root
    
    // Core timing tiers
    property int fast: Motion.fast
    property int normal: Motion.normal
    property int slow: Motion.slow
    
    property list<real> moduleCurve: Motion.moduleCurve
    property int tooltipDuration: slow
    property list<real> tooltipCurve: Motion.tooltipCurve
    property list<real> shellCurve: Motion.shellCurve
    // Both wipe layers share easing while retaining independent durations.
    property list<real> shellTransitionCurve: Motion.shellTransitionCurve

    // Navigation Motion (slower, modern fluid expansion)
    property int navigationOpenDuration: Motion.navigationOpenDuration
    property int navigationCloseDuration: Motion.navigationCloseDuration
    property int navigationCollapseDuration: Motion.navigationCollapseDuration
    property list<real> navigationOpenCurve: Motion.navigationOpenCurve
    property list<real> navigationCloseCurve: Motion.navigationCloseCurve

    // Dashboard Motion (gentle bouncing elastic expansion & graceful unhurried close)
    property int dashboardOpenDuration: Motion.dashboardOpenDuration
    property int dashboardCloseDuration: Motion.dashboardCloseDuration
    property list<real> dashboardOpenCurve: Motion.dashboardOpenCurve
    property list<real> dashboardCloseCurve: Motion.dashboardCloseCurve

    // Sidebar Motion (tactile, bouncy elastic expansion with visible rebound)
    property int sidebarOpenDuration: Motion.sidebarOpenDuration
    property int sidebarCloseDuration: Motion.sidebarCloseDuration
    property list<real> sidebarOpenCurve: Motion.sidebarOpenCurve
    property list<real> sidebarCloseCurve: Motion.sidebarCloseCurve

    // Sidebar Tool / Temp Note Panel Motion (calm flare expansion from rail)
    property int sidebarToolOpenDuration: Motion.sidebarToolOpenDuration
    property int sidebarToolCloseDuration: Motion.sidebarToolCloseDuration
    property list<real> sidebarToolOpenCurve: Motion.sidebarToolOpenCurve
    property list<real> sidebarToolCloseCurve: Motion.sidebarToolCloseCurve
    // Floating panels retain the Temp Note curves with shorter reveal and collapse times.
    readonly property int floatingPanelOpenDuration: Math.round(sidebarToolOpenDuration * Motion.floatingPanelOpenFactor)
    readonly property int floatingPanelCloseDuration: Math.round(sidebarToolCloseDuration * Motion.floatingPanelCloseFactor)
    readonly property list<real> floatingPanelOpenCurve: sidebarToolOpenCurve
    readonly property list<real> floatingPanelCloseCurve: sidebarToolCloseCurve

    // Dashboard Dynamic Widget Switch Motion (subtle directional card slide-fade)
    property int dashboardWidgetSwitchDuration: Motion.dashboardWidgetSwitchDuration
    property list<real> dashboardWidgetSwitchCurve: Motion.dashboardWidgetSwitchCurve

    property int hakuMenuOpenDuration: Motion.hakuMenuOpenDuration
    property int hakuMenuCloseDuration: Motion.hakuMenuCloseDuration
    property list<real> hakuMenuOpenCurve: Motion.hakuMenuOpenCurve
    property list<real> hakuMenuCloseCurve: Motion.hakuMenuCloseCurve
    // Tab-to-tab width morph is intentionally calmer than the bouncy open curve.
    property int hakuMenuResizeDuration: Motion.hakuMenuResizeDuration
    property list<real> hakuMenuResizeCurve: Motion.hakuMenuResizeCurve
    property real hakuMenuBounceHeadroom: Motion.hakuMenuBounceHeadroom
    property int settingsResizeDuration: Motion.settingsResizeDuration
    property list<real> settingsResizeCurve: Motion.settingsResizeCurve

    // Bottom Dock reveal, collapse and dynamic-width motion.
    property int dockOpenDuration: Motion.dockOpenDuration
    property int dockCloseDuration: Motion.dockCloseDuration
    property int dockResizeDuration: Motion.dockResizeDuration
    property list<real> dockOpenCurve: Motion.dockOpenCurve
    property list<real> dockCloseCurve: Motion.dockCloseCurve

    // Six control values drive the asymmetric workspace and flare motion.
    property list<real> spatialCurve: Motion.spatialCurve
    property list<real> effectsCurve: Motion.effectsCurve
    property int spatial: Motion.spatial
    property int effects: Motion.effects
    property real trailFactor: Motion.trailFactor

    // Selection Morph & Synchronized Text Fade Timing
    // The selection pill asymmetric morph completes when its trailing edge reaches target (spatial * trailFactor = 525ms).
    // Text color fade MUST take this exact duration and easing curve so both finish simultaneously.
    readonly property int selectionMorphDuration: Math.round(spatial * trailFactor)
    readonly property list<real> selectionMorphCurve: spatialCurve

    // Shared Hikai interactive-state motion. Keep these calmer than shell-open motion.
    property int buttonHoverDuration: Motion.buttonHoverDuration
    property int buttonPressDuration: Motion.buttonPressDuration
    property int buttonReleaseDuration: Motion.buttonReleaseDuration
    property int buttonSelectDuration: selectionMorphDuration
    property int buttonFocusDuration: Motion.buttonFocusDuration
    property list<real> buttonHoverCurve: Motion.buttonHoverCurve
    property list<real> buttonPressCurve: Motion.buttonPressCurve
    property list<real> buttonReleaseCurve: Motion.buttonReleaseCurve
    property list<real> buttonSelectCurve: selectionMorphCurve
    property list<real> buttonFocusCurve: Motion.buttonFocusCurve

    // Shared Action Layer Motion (centered reveal, smooth morphing, fade-zoom close)
    property int actionLayerOpenDuration: Motion.actionLayerOpenDuration
    property int actionLayerCloseDuration: Motion.actionLayerCloseDuration
    property int actionLayerMorphDuration: Motion.actionLayerMorphDuration
    property int actionLayerMorphContentDuration: Motion.actionLayerMorphContentDuration
    property list<real> actionLayerOpenCurve: Motion.actionLayerOpenCurve
    property list<real> actionLayerCloseCurve: Motion.actionLayerCloseCurve
    property list<real> actionLayerMorphCurve: Motion.actionLayerMorphCurve
    property list<real> actionLayerContentCurve: Motion.actionLayerContentCurve
    property int actionLayerDataFadeDuration: Motion.actionLayerDataFadeDuration
    property list<real> actionLayerDataFadeCurve: Motion.actionLayerDataFadeCurve
}
