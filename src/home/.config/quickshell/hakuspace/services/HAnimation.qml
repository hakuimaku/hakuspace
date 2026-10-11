pragma Singleton
import QtQuick

QtObject {
    id: root
    
    // Core timing tiers
    property int fast: 160
    property int normal: 320
    property int slow: 540
    
    property list<real> moduleCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
    property list<real> tooltipCurve: [0.4, 0.0, 0.2, 1.0, 1, 1]
    property list<real> shellCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]

    // Navigation Motion (slower, buttery-smooth expansion)
    property int navigationOpenDuration: 480
    property int navigationCloseDuration: 360
    property int navigationCollapseDuration: 220
    property list<real> navigationOpenCurve: [0.16, 1.0, 0.28, 1.0, 1, 1]
    property list<real> navigationCloseCurve: [0.25, 1.0, 0.35, 1.0, 1, 1]

    // Dashboard Motion (bouncing elastic expansion & graceful unhurried close)
    property int dashboardOpenDuration: 680
    property int dashboardCloseDuration: 540
    property list<real> dashboardOpenCurve: [0.30, 1.42, 0.38, 1.0, 1, 1]
    property list<real> dashboardCloseCurve: [0.32, 0.0, 0.22, 1.0, 1, 1]

    // Sidebar Motion (tactile, bouncy elastic expansion with visible rebound)
    property int sidebarOpenDuration: 600
    property int sidebarCloseDuration: 320
    property list<real> sidebarOpenCurve: [0.30, 1.48, 0.38, 1.0, 1, 1]
    property list<real> sidebarCloseCurve: [0.38, 0.0, 0.22, 1.0, 1, 1]

    property int hakuMenuOpenDuration: 400
    property int hakuMenuCloseDuration: 440
    property list<real> hakuMenuOpenCurve: [0.88, 1.31, 0.25, 0.98, 1, 1]
    property list<real> hakuMenuCloseCurve: [1, 0.3, 0.25, 1, 1, 1]
    // Tab-to-tab width morph is intentionally calmer than the bouncy open curve.
    property int hakuMenuResizeDuration: 280
    property list<real> hakuMenuResizeCurve: [0.7, 1.0, 0.6, 0.98, 1, 1]
    property real hakuMenuBounceHeadroom: 0.04

    // Shared Hikai interactive-state motion. Keep these calmer than shell-open motion.
    property int buttonHoverDuration: 240
    property int buttonPressDuration: 120
    property int buttonReleaseDuration: 240
    property int buttonSelectDuration: 300
    property int buttonFocusDuration: 240
    property list<real> buttonHoverCurve: [0.20, 0.60, 0.20, 1.0, 1, 1]
    property list<real> buttonPressCurve: [0.40, 0.00, 0.20, 1.0, 1, 1]
    property list<real> buttonReleaseCurve: [0.16, 1.08, 0.30, 1.0, 1, 1]
    property list<real> buttonSelectCurve: [0.16, 1.20, 0.30, 0.98, 1, 1]
    property list<real> buttonFocusCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]
    
    // Six control values drive the asymmetric workspace and flare motion.
    property list<real> spatialCurve: [0.5, 1.21, 0.22, 1, 1, 1]
    property list<real> effectsCurve: [0.56, 0.8, 0.34, 1, 1, 1]
    property int spatial: 350
    property int effects: 200
    property real trailFactor: 1.5
}
