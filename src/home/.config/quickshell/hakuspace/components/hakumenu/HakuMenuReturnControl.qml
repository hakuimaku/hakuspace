import QtQuick
import QtQuick.Shapes
import "../../services"
import "../base" as Base

Base.HButton {
    id: returnButton
    objectName: "hakumenu-return-button"
    // Animate only while the owning presentation accepts interaction.
    required property bool panelOpen
    required property bool reducedMotion
    enabled: panelOpen
    disabledOpacity: 1
    idleColor: "transparent"
    hoverColor: "transparent"
    pressedColor: "transparent"
    hoverForegroundColor: Theme.fg
    pressedForegroundColor: Theme.fg
    hoverScaleDelta: 0
    pressScaleDelta: 0
    clip: true
    // Share the cadence while easing each column along its own path.
    property real arrowPhase: 1 / 6
    // Expand the hover glow without changing the button's input geometry.
    property real hoverReveal: hovered && enabled && returnButton.panelOpen ? 1 : 0
    Behavior on hoverReveal {
        NumberAnimation {
            duration: returnButton.reducedMotion ? 0 : 650
            easing.type: Easing.OutCubic
        }
    }
    NumberAnimation on arrowPhase {
        from: 1 / 6
        to: 7 / 6
        duration: 2200
        loops: Animation.Infinite
        running: (returnButton.hovered || returnButton.hoverReveal > 0)
            && returnButton.enabled && returnButton.panelOpen && !returnButton.reducedMotion
        onRunningChanged: if (!running) returnButton.arrowPhase = 1 / 6
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Close HakuMenu"
    Accessible.onPressAction: UiState.returnFromHakuMenu()
    onClicked: UiState.returnFromHakuMenu()
    // Scale a fixed radial path into a soft elliptical glow behind the arrows.
    Shape {
        objectName: "hakumenu-return-glow"
        width: 100
        height: 100
        anchors.centerIn: parent
        opacity: returnButton.hoverReveal
        visible: opacity > 0
        transform: Scale {
            origin.x: 50; origin.y: 50
            xScale: returnButton.width / 100 * returnButton.hoverReveal
            yScale: returnButton.height / 100 * returnButton.hoverReveal
        }
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: 50; centerY: 50
                focalX: 50; focalY: 50
                centerRadius: 50
                GradientStop { position: 0; color: "#b3242424" }
                GradientStop { position: 0.5; color: "#66141414" }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: 100; y: 0 }
            PathLine { x: 100; y: 100 }
            PathLine { x: 0; y: 100 }
            PathLine { x: 0; y: 0 }
        }
    }
    Repeater {
        model: 3
        delegate: Shape {
            required property int index
            // A sine ease slows the entry and exit of each column independently.
            readonly property real cycle: (returnButton.arrowPhase + index / 3) % 1
            readonly property real progress: (1 - Math.cos(cycle * Math.PI)) / 2
            width: 28
            height: 14
            x: returnButton.width * (index + 0.5) / 3 - width / 2
            y: (returnButton.height - height) / 2
                + (returnButton.reducedMotion ? 0 : (progress - 0.5) * returnButton.height * returnButton.hoverReveal)
            // Blend back to the resting center arrow while the moving hint fades out.
            opacity: (index === 1 ? 1 - returnButton.hoverReveal : 0)
                + returnButton.hoverReveal * (returnButton.reducedMotion ? (index === 1 ? 1 : 0.55)
                    : Math.sin(progress * Math.PI))
            Accessible.ignored: true
            ShapePath {
                strokeColor: returnButton.foreground
                strokeWidth: 2.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 1.5; startY: 1.5
                PathLine { x: 14; y: 12.5 }
                PathLine { x: 26.5; y: 1.5 }
            }
        }
    }
}
