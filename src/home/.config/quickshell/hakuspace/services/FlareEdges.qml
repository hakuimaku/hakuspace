pragma Singleton
import QtQuick
import "."

Item {
    id: root
    
    property bool rsOn: AppState.roundedScreenState && AppState.roundedScreenThickness > 0
    property real thickness: rsOn ? AppState.roundedScreenThickness : 0
    
    // Reserve the rounded-screen border when placing flare surfaces.
    function getBounds(windowWidth) {
        return {
            start: thickness,
            end: Math.max(0, windowWidth - thickness)
        };
    }
}
