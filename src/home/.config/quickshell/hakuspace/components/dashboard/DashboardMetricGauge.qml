import QtQuick
import "../../services"

Item {
    id: root

    property string title: ""
    property real value: 0
    property bool available: true
    property color accentColor: Theme.accent
    property real diameter: 68
    property real strokeWidth: Math.max(5, Math.round(diameter * 0.07))

    // Click toggle properties (% vs used value)
    property string usedText: ""
    property bool showUsed: false

    width: diameter
    height: diameter

    property real displayValue: available ? Math.max(0, Math.min(100, value)) : 0
    Behavior on displayValue {
        NumberAnimation {
            duration: HAnimation.normal
            easing.type: Easing.OutCubic
        }
    }

    onDisplayValueChanged: canvas.requestPaint()
    onAvailableChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onStrokeWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var r = (Math.min(width, height) - root.strokeWidth) / 2
            if (r <= 0) return

            // 1. Background ring
            ctx.lineWidth = root.strokeWidth
            ctx.strokeStyle = Theme.hoverMuted
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.stroke()

            // 2. Active metric arc
            if (root.available && root.displayValue > 0) {
                var startAngle = -Math.PI / 2
                var sweep = (root.displayValue / 100.0) * (2 * Math.PI)
                var endAngle = startAngle + sweep

                ctx.strokeStyle = root.accentColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, endAngle)
                ctx.stroke()
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            id: valueText
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                if (!root.available) return "N/A"
                if (root.showUsed && root.usedText.length > 0) return root.usedText
                return Math.round(root.displayValue) + "%"
            }
            font.family: Theme.fontFamily
            font.pixelSize: {
                var baseSize = Math.max(15, Math.round(root.diameter * 0.20))
                if (root.showUsed && root.usedText.length > 5) {
                    return Math.max(11, Math.round(baseSize * 0.72))
                } else if (root.showUsed && root.usedText.length > 3) {
                    return Math.max(12, Math.round(baseSize * 0.82))
                }
                return baseSize
            }
            font.weight: Font.Bold
            color: root.available ? Theme.fg : Theme.fgDim
        }

        Text {
            id: titleText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, Math.round(root.diameter * 0.12))
            font.weight: Font.Medium
            color: Theme.fgDim
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton

        function updateTooltip() {
            if (!root.available) {
                DashboardTooltip.show(root, root.title + ": Not available")
                return
            }
            var pctStr = Math.round(root.displayValue) + "%"
            var desc = root.title + ": " + (root.showUsed ? (root.usedText || pctStr) : pctStr)
            if (root.usedText.length > 0 && !root.showUsed) {
                desc += " (" + root.usedText + ")"
            } else if (root.usedText.length > 0 && root.showUsed) {
                desc += " (" + pctStr + ")"
            }
            desc += "\nClick to toggle % / used"
            DashboardTooltip.show(root, desc)
        }

        onEntered: updateTooltip()
        onExited: DashboardTooltip.hide(root)
        onClicked: {
            if (root.available) {
                root.showUsed = !root.showUsed
                updateTooltip()
            }
        }
    }
}
