import QtQuick
import Quickshell
import "../../services"
import "../../services/WM"
import "../base"
import "TitleFormatting.js" as TitleFormatting

Item {
    id: root
    
    // Only the typographic label turns; the host and input stay upright.
    property bool vertical: false
    property real maximumLength: 240
    Accessible.name: activeClass + ": " + activeTitle
    property string nextClass: WM.activeWindowClass
    property string nextTitle: WM.activeWindowTitle
    
    property string activeClass: "Desktop"
    property string activeTitle: ""
    readonly property int maxTitleCharacters: vertical ? 42 : 32
    readonly property string displayTitle: TitleFormatting.shorten(TitleFormatting.title(activeTitle, activeClass), maxTitleCharacters)

    property bool hovered: false
    readonly property Item visualItem: titleChassis
    // The budget elides text; only the measured ink determines the vertical cluster height.
    readonly property real verticalPadding: ScreenGeometry.leftModuleInset
    readonly property real verticalGap: 14
    // Reserve the full text advance so fitting labels retain their final glyphs.
    readonly property real preferredVerticalHeight: verticalPadding * 2 + iconMetrics.tightBoundingRect.height
        + verticalGap + Math.max(naturalTitleMetrics.advanceWidth, naturalTitleMetrics.tightBoundingRect.width) + 2
    readonly property real verticalTextBudget: Math.max(0, maximumLength - verticalPadding * 2
        - iconMetrics.tightBoundingRect.height - verticalGap - 2)
    // Read positions explicitly so mapped ink bounds follow layout changes.
    readonly property var iconPaintedBounds: {
        var x = verticalTitleIcon.x, y = verticalTitleIcon.y
        return verticalTitleIcon.mapToItem(root, iconMetrics.tightBoundingRect.x,
            verticalTitleIcon.baselineOffset + iconMetrics.tightBoundingRect.y, iconMetrics.tightBoundingRect.width, iconMetrics.tightBoundingRect.height)
    }
    readonly property var textPaintedBounds: {
        var x = verticalTitleText.x, y = verticalTitleText.y
        return verticalTitleText.mapToItem(root, inkMetrics.tightBoundingRect.x,
            verticalTitleText.baselineOffset + inkMetrics.tightBoundingRect.y, inkMetrics.tightBoundingRect.width, inkMetrics.tightBoundingRect.height)
    }
    TextMetrics {
        id: naturalTitleMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Bold
        text: TitleFormatting.shorten(TitleFormatting.title(root.activeTitle, root.activeClass).replace(/[\r\n]+/g, " "), root.maxTitleCharacters)
    }
    TextMetrics {
        id: elidedTitleMetrics
        font: naturalTitleMetrics.font
        text: naturalTitleMetrics.text
        elide: Text.ElideRight
        elideWidth: root.verticalTextBudget
    }
    TextMetrics { id: inkMetrics; font: naturalTitleMetrics.font; text: elidedTitleMetrics.elidedText }
    TextMetrics { id: iconMetrics; font: verticalTitleIcon.font; text: verticalTitleIcon.text }
    
    implicitHeight: vertical ? Math.min(maximumLength, verticalPadding * 2 + iconMetrics.tightBoundingRect.height
        + (inkMetrics.text.length ? verticalGap + inkMetrics.tightBoundingRect.width : 0)) : Math.max(Theme.fontSize * 1.8, contentWrapper.implicitHeight + Math.round(Theme.fontSize * 0.4))
    implicitWidth: vertical ? ScreenGeometry.leftModuleTouchSize : contentWrapper.implicitWidth + Theme.pad * 2
    
    // Animates window title pill width and height when title text changes.
    Behavior on implicitWidth {
        enabled: !root.vertical
        NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve }
    }
    Behavior on implicitHeight {
        enabled: !root.vertical
        NumberAnimation { duration: HAnimation.normal; easing.bezierCurve: HAnimation.moduleCurve }
    }
    
    onNextClassChanged: {
        if (activeClass !== nextClass) morphAnim.restart();
    }
    onNextTitleChanged: {
        if (activeTitle !== nextTitle) morphAnim.restart();
    }
    
    // Fades window title out and in when active window class or title updates.
    SequentialAnimation {
        id: morphAnim
        NumberAnimation { target: contentWrapper; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
        ScriptAction {
            script: {
                root.activeClass = root.nextClass;
                root.activeTitle = root.nextTitle;
            }
        }
        NumberAnimation { target: contentWrapper; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InQuad }
    }
    
    Component.onCompleted: {
        activeClass = nextClass;
        activeTitle = nextTitle;
        contentWrapper.opacity = 1;
    }

    // Background chassis of the window title module pill.
    Rectangle {
        id: titleChassis
        anchors.centerIn: parent
        width: root.vertical ? ScreenGeometry.leftVisualSize : root.width
        height: root.height
        color: root.hovered ? Theme.hoverMuted : Theme.surface
        radius: Theme.radius
        // Animates background surface color on hover enter and exit.
        Behavior on color { ColorAnimation { duration: HAnimation.normal } }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: { root.hovered = true; tooltipObj.active = true; }
        onExited: { root.hovered = false; tooltipObj.active = false; }
    }
    
    HTooltip {
        id: tooltipObj
        target: root
        text: {
            var c = root.activeClass !== "" ? root.activeClass : "Desktop";
            var t = root.activeTitle !== "" ? root.activeTitle : "None";
            return "App ID: " + c + "\nTitle: " + t;
        }
    }
    
    Item {
        id: contentWrapper
        anchors.centerIn: parent
        implicitWidth: root.vertical ? root.width : row.implicitWidth
        implicitHeight: root.vertical ? root.height : row.implicitHeight
        width: implicitWidth
        height: implicitHeight
        
        Item {
            id: verticalLine
            objectName: "vertical-window-title-line"
            anchors.fill: parent
            visible: root.vertical && root.maximumLength >= root.verticalPadding * 2 + iconMetrics.tightBoundingRect.height
            Text {
                id: verticalTitleIcon
                objectName: "vertical-window-title-icon"
                x: parent.width / 2 - iconMetrics.tightBoundingRect.x - iconMetrics.tightBoundingRect.width / 2
                y: root.verticalPadding - baselineOffset - iconMetrics.tightBoundingRect.y
                text: TitleFormatting.icon(root.activeClass)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 4
                font.weight: Font.Bold
                color: root.hovered ? Theme.accent : Theme.fg
            }
            Text {
                id: verticalTitleText
                objectName: "vertical-window-title-text"
                // Position the rotated ink, including bearings, directly below the upright icon.
                x: parent.width / 2 + baselineOffset + inkMetrics.tightBoundingRect.y + inkMetrics.tightBoundingRect.height / 2
                y: root.verticalPadding + iconMetrics.tightBoundingRect.height + root.verticalGap - inkMetrics.tightBoundingRect.x
                rotation: 90
                transformOrigin: Item.TopLeft
                text: inkMetrics.text
                font: naturalTitleMetrics.font
                wrapMode: Text.NoWrap
                color: root.hovered ? Theme.accent : Theme.fg
            }
        }
        Row {
            id: row
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: Theme.gap + 10
            
            Text {
                id: iconText
                text: TitleFormatting.icon(root.activeClass)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                font.weight: Font.Bold
                color: root.hovered ? Theme.accent : Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                
                Text {
                    id: classText
                    text: root.activeClass !== "" ? root.activeClass : "...hakushell..."
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(Theme.fontSize * 0.75)
                    font.weight: Font.Bold
                    color: root.hovered ? Theme.accent : Theme.fgMuted
                    width: implicitWidth
                }
                
                Text {
                    id: titleText
                    text: root.displayTitle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Bold
                    color: root.hovered ? Theme.accent : Theme.fg
                    width: implicitWidth
                    visible: root.activeTitle !== ""
                }
            }
        }
    }
}
