pragma Singleton
import QtQuick

QtObject {
    id: root
    
    property int fast: 100
    property int normal: 220
    property int slow: 400
    
    property list<real> moduleCurve: [0.16, 1.0, 0.3, 1.0]
    
    property list<real> tooltipCurve: [0.4, 0.0, 0.2, 1.0]
    
    property list<real> shellCurve: [0.16, 1.0, 0.3, 1.0]

    property int hakuMenuOpenDuration: 320
    property int hakuMenuCloseDuration: 400
    property list<real> hakuMenuOpenCurve: [0.88, 1.31, 0.25, 0.98, 1, 1]
    property list<real> hakuMenuCloseCurve: [1, 0.3, 0.25, 1]
    // Tab-to-tab width morph is intentionally calmer than the bouncy open curve.
    property int hakuMenuResizeDuration: 240
    property list<real> hakuMenuResizeCurve: [0.7, 1.0, 0.6, 0.98]
    property real hakuMenuBounceHeadroom: 0.04
    
    // Six control values drive the asymmetric workspace and flare motion.
    property list<real> spatialCurve: [0.5, 1.21, 0.22, 1, 1, 1]
    property list<real> effectsCurve: [0.56, 0.8, 0.34, 1, 1, 1]
    property int spatial: 350
    property int effects: 200
    property real trailFactor: 1.5
}
