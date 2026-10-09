pragma Singleton
import QtQuick
import "."

Item {
    id: root
    
    // rsOn phụ thuộc trạng thái của AppState
    property bool rsOn: AppState.roundedScreenState && AppState.roundedScreenThickness > 0
    property real thickness: rsOn ? AppState.roundedScreenThickness : 0
    
    function getBounds(windowWidth) {
        return {
            start: thickness,
            end: Math.max(0, windowWidth - thickness)
        };
    }
}
