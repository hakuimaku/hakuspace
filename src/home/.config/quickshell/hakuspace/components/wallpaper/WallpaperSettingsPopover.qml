import QtQuick
import QtQuick.Layouts
import "../../services"
import "../base" as Base
import "../settings" as Settings

// The clipped viewport retains its editor until the slide finishes or reverses.
Item {
    id: root
    property string section: ""
    property string displayedSection: ""
    property real hostReveal: 1
    property real availableHeight: 680
    property real progress: 0
    property real sectionOpacity: 1
    readonly property real gap: 12
    property real panelHeight: Math.max(0, Math.min(displayedSection === "cache" ? 480 : 680, availableHeight))
    readonly property real travelHeight: displayedSection ? panelHeight + gap : 0
    readonly property bool editorLoaded: editor.active
    readonly property bool animating: slide.running || resize.running || contentSwitch.running
    signal closeRequested()
    height: (panelHeight + gap) * progress
    visible: displayedSection.length > 0
    clip: true

    // Keep the travel extent stable if the entire workspace is closing too.
    function releaseSection() {
        if (!section && progress === 0 && !slide.running && !editor.active && hostReveal === 1)
            displayedSection = ""
    }
    onSectionChanged: {
        slide.stop()
        contentSwitch.stop()
        if (section && displayedSection && displayedSection !== section && progress > 0) contentSwitch.start()
        else {
            if (section) displayedSection = section
            sectionOpacity = 1
        }
        slide.to = section ? 1 : 0
        if (progress !== slide.to) slide.start()
        else releaseSection()
    }
    onHostRevealChanged: if (hostReveal === 1) releaseSection()
    onEditorLoadedChanged: if (!editorLoaded) releaseSection()
    // Resize the same card while its retained editor changes section behind a fade.
    Behavior on panelHeight {
        enabled: root.progress > 0
        NumberAnimation {
            id: resize
            duration: HAnimation.settingsResizeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.settingsResizeCurve
        }
    }
    SequentialAnimation {
        id: contentSwitch
        NumberAnimation { target: root; property: "sectionOpacity"; to: 0; duration: HAnimation.fast / 2 }
        ScriptAction { script: { if (root.section) root.displayedSection = root.section } }
        NumberAnimation { target: root; property: "sectionOpacity"; to: 1; duration: HAnimation.fast }
    }
    NumberAnimation {
        id: slide
        target: root; property: "progress"
        duration: root.section ? HAnimation.normal : HAnimation.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.tooltipCurve
        onFinished: root.releaseSection()
    }
    Rectangle {
        id: panel
        objectName: "wallpaper-settings-card"
        y: root.gap - (height + root.gap) * (1 - root.progress)
        width: root.width
        height: root.panelHeight
        radius: Theme.largeRadius
        color: Theme.surface
        border.width: 1; border.color: Theme.hoverMuted
        RowLayout {
            opacity: root.sectionOpacity
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 24 }
            height: 32
            Text {
                Layout.fillWidth: true
                text: root.displayedSection === "playback" ? "Playback settings" : "Cache settings"
                color: Theme.fg
                elide: Text.ElideRight
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 4; font.weight: Font.DemiBold
            }
            WallpaperToolbarButton {
                objectName: "wallpaper-section-close"
                width: 32; height: 32
                icon: "\uf00d"; description: "Close wallpaper settings section"
                useSettingsTooltip: true
                onClicked: root.closeRequested()
            }
        }
        Item {
            id: editorHost
            anchors { fill: parent; leftMargin: 24; rightMargin: 24; topMargin: 76; bottomMargin: 88 }
            enabled: root.section.length > 0
            opacity: root.sectionOpacity
            Base.LifecycleLoader {
                id: editor
                requested: root.section.length > 0
                Settings.WallpaperSettingsPage {
                    parent: editorHost
                    anchors.fill: parent
                    sectionFilter: root.displayedSection
                    readonly property bool releaseReady: root.progress === 0 && !slide.running
                }
            }
        }
        Rectangle {
            x: 24; y: parent.height - 72
            width: parent.width - 48; height: 1
            color: Theme.hoverMuted
        }
        RowLayout {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 24 }
            height: 32
            spacing: 16
            Text {
                Layout.fillWidth: true
                text: SettingsCoordinator.error || WallpaperService.error || (SettingsCoordinator.busy ? "Saving…" : "")
                elide: Text.ElideRight
                color: Theme.fgDescription
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2
            }
            WallpaperToolbarButton {
                caption: "Retry save"; height: 32; visible: !!SettingsCoordinator.error
                enabled: !SettingsCoordinator.busy
                onClicked: SettingsCoordinator.activateAction("Retry")
            }
        }
    }
}
