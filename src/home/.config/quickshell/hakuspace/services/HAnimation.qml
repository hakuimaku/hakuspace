pragma Singleton
import QtQuick

QtObject {
    id: root
    
    property int fast: 100
    property int normal: 220
    property int slow: 400
    
    // Default bezier for modules (TopBar items, expanding, coloring, morphing)
    property list<real> moduleCurve: [0.16, 1.0, 0.3, 1.0]
    
    // Default bezier for tooltips
    property list<real> tooltipCurve: [0.4, 0.0, 0.2, 1.0]
    
    // Default bezier for shell components (HDrawer, layers)
    property list<real> shellCurve: [0.16, 1.0, 0.3, 1.0]
    
    // Workspace morphing tokens
    property list<real> spatialCurve: [0.5, 1.21, 0.22, 1, 1, 1]
    property list<real> effectsCurve: [0.56, 0.8, 0.34, 1, 1, 1]
    property int spatial: 350
    property int effects: 200
    property real trailFactor: 1.5
}
