pragma Singleton
import QtQuick
import "."

Item {
    id: root
    
    property real thickness: AppState.roundedScreenThickness > 0 ? AppState.roundedScreenThickness : 0
    // Snap toward the frame so fractional TopBar height cannot leave a hairline seam.
    readonly property real topOriginY: Math.floor(Theme.topBarHeight + thickness)
    
    // Reserve the rounded-screen border when placing flare surfaces.
    function getBounds(windowWidth) {
        return {
            start: thickness,
            end: Math.max(0, windowWidth - thickness)
        };
    }
}
