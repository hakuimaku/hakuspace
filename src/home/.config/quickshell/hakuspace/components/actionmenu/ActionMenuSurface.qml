import QtQuick
import QtQuick.Effects
import "../../services"

Item {
    id: root

    property real screenWidth: 1920
    property real screenHeight: 1080
    property string flow: "record"

    // Lifecycle phase: closed | opening | ready | morphing-forward | morphing-back | closing
    property string phase: "closed"

    // Motion parameters for open / close
    property real openProgress: 0.0
    property real openOpacity: 0.0
    property real openScale: 0.94
    property real closeProgress: 0.0
    property real closeOpacity: 1.0
    property real closeScale: 1.0
    property real contentEntranceOpacity: 1.0

    // Geometry profiles
    property string currentProfile: "option"
    property real surfaceWidth: 540
    property real surfaceHeight: 420

    // Navigation Stack
    // Array of objects: { pageUrl: string, pageItem: Item, seedGeom: var, profile: string }
    property var navStack: []
    readonly property bool canGoBack: navStack.length > 1

    signal requestClose()
    signal closeAnimationFinished()

    readonly property bool revealActive: phase === "opening" && openProgress < 0.999
    readonly property real revealDiameter: Math.sqrt(surfaceWidth * surfaceWidth + surfaceHeight * surfaceHeight) * openProgress

    // Stable screen-centered coordinate anchor
    readonly property real centerX: screenWidth / 2
    readonly property real centerY: screenHeight / 2
    readonly property real surfaceScreenX: centerX - surfaceWidth / 2
    readonly property real surfaceScreenY: centerY - surfaceHeight / 2

    // Morph interpolation variables
    property real morphProgress: 0.0
    property real morphBackProgress: 0.0

    onMorphProgressChanged: {
        if (root.phase === "morphing-forward") {
            root.updateForwardMorphFrame(root.morphProgress);
        }
    }

    onMorphBackProgressChanged: {
        if (root.phase === "morphing-back") {
            root.updateBackMorphFrame(root.morphBackProgress);
        }
    }

    property real morphStartW: 540
    property real morphStartH: 420
    property real morphTargetW: 540
    property real morphTargetH: 420
    property real morphStartScreenX: 0
    property real morphStartScreenY: 0
    property real morphTargetScreenX: 0
    property real morphTargetScreenY: 0

    property real morphSeedScreenX: 0
    property real morphSeedScreenY: 0
    property real morphSeedWidth: 200
    property real morphSeedHeight: 40
    property real morphSeedRadius: Theme.radius
    property color morphSeedColor: Theme.accent
    property string morphSeedIcon: ""
    property string morphSeedLabel: ""

    property real maskScreenX: 0
    property real maskScreenY: 0
    property real maskWidth: 0
    property real maskHeight: 0
    property real maskRadius: 0

    readonly property real maskLocalX: maskScreenX - surfaceScreenX
    readonly property real maskLocalY: maskScreenY - surfaceScreenY

    readonly property real childLocalX: (phase === "morphing-forward" ? morphTargetScreenX : morphStartScreenX) - surfaceScreenX
    readonly property real childLocalY: (phase === "morphing-forward" ? morphTargetScreenY : morphStartScreenY) - surfaceScreenY

    readonly property real parentLocalX: (phase === "morphing-forward" ? morphStartScreenX : morphTargetScreenX) - surfaceScreenX
    readonly property real parentLocalY: (phase === "morphing-forward" ? morphStartScreenY : morphTargetScreenY) - surfaceScreenY

    property color morphCarrierColor: Theme.surface
    property real morphGhostOpacity: 0.0
    property int morphBorderWidth: 0
    property real morphParentOpacity: 1.0

    // Temporary references during morph
    property var activeMorphChild: null
    property var activeMorphParent: null

    // Linearly interpolates RGBA color channels by progress t [0.0..1.0].
    function interpolateColor(c1, c2, t) {
        var col1 = Qt.color(c1);
        var col2 = Qt.color(c2);
        var clampedT = Math.max(0.0, Math.min(1.0, t));
        var r = col1.r + (col2.r - col1.r) * clampedT;
        var g = col1.g + (col2.g - col1.g) * clampedT;
        var b = col1.b + (col2.b - col1.b) * clampedT;
        var a = col1.a + (col2.a - col1.a) * clampedT;
        return Qt.rgba(r, g, b, a);
    }

    // Resolves width and height boundaries for a geometry profile name.
    function getProfileSize(profile) {
        var w = 540;
        var h = 420;
        switch (profile) {
        case "option":
            w = Math.min(Math.max(screenWidth * 0.40, 440), 720);
            h = Math.min(Math.max(screenHeight * 0.40, 360), 540);
            break;
        case "exitReport":
            w = Math.min(Math.max(screenWidth * 0.50, 540), 880);
            h = Math.min(Math.max(screenHeight * 0.60, 440), 760);
            break;
        case "powerHorizontal":
            w = Math.min(Math.max(screenWidth * 0.70, 680), 1040);
            h = 148;
            break;
        case "powerVertical":
            w = 140;
            h = 440;
            break;
        default:
            w = Math.min(Math.max(screenWidth * 0.40, 440), 720);
            h = Math.min(Math.max(screenHeight * 0.40, 360), 540);
            break;
        }
        return { width: Math.round(w), height: Math.round(h) };
    }

    // Maps flow ID string to QML component page path.
    function pageUrlForFlow(flowId) {
        switch (flowId) {
        case "record": return "pages/RecordPage.qml";
        case "power": return "pages/PowerPage.qml";
        case "exit": return "pages/ExitPage.qml";
        case "theme": return "pages/ThemePage.qml";
        case "clipboard": return "pages/ClipboardPage.qml";
        case "shortcut": return "pages/ShortcutPage.qml";
        case "sidebarPin": return "pages/ShortcutPage.qml";
        case "niriAnimation":
        case "niri_animation": return "pages/NiriAnimationPage.qml";
        default: return "pages/RecordPage.qml";
        }
    }

    // Returns default geometry profile for a given flow ID.
    function defaultProfileForFlow(flowId) {
        switch (flowId) {
        case "power": return "powerHorizontal";
        case "exit": return "exitReport";
        case "theme": return "option";
        case "record": return "option";
        case "clipboard": return "option";
        case "niriAnimation":
        case "niri_animation": return "option";
        default: return "option";
        }
    }

    // Cleans up all pushed navigation stack pages.
    function clearStack() {
        for (var i = 0; i < root.navStack.length; i++) {
            if (root.navStack[i].pageItem) {
                root.navStack[i].pageItem.destroy();
            }
        }
        root.navStack = [];
        root.activeMorphChild = null;
        root.activeMorphParent = null;
    }

    // Connects back, close, and pushSubmenu signals on dynamic page instances.
    function connectPageSignals(item) {
        if (!item) return;
        if (item.requestBack !== undefined) {
            item.requestBack.connect(root.popPage);
        }
        if (item.requestClose !== undefined) {
            item.requestClose.connect(root.requestClose);
        }
        if (item.pushSubmenu !== undefined) {
            item.pushSubmenu.connect(root.pushPage);
        }
    }

    // Triggers default action on active top-of-stack page.
    function activateCurrent() {
        if (root.phase !== "ready" || root.navStack.length === 0) return;
        var topEntry = root.navStack[root.navStack.length - 1];
        if (topEntry && topEntry.pageItem && topEntry.pageItem.activateCurrent) {
            topEntry.pageItem.activateCurrent();
        }
    }

    // Forwards scroll-previous event to active page.
    function scrollPrevious() {
        if (root.phase !== "ready" || root.navStack.length === 0) return;
        var topEntry = root.navStack[root.navStack.length - 1];
        if (topEntry && topEntry.pageItem && topEntry.pageItem.scrollPrevious) {
            topEntry.pageItem.scrollPrevious();
        }
    }

    // Forwards scroll-next event to active page.
    function scrollNext() {
        if (root.phase !== "ready" || root.navStack.length === 0) return;
        var topEntry = root.navStack[root.navStack.length - 1];
        if (topEntry && topEntry.pageItem && topEntry.pageItem.scrollNext) {
            topEntry.pageItem.scrollNext();
        }
    }

    // Initializes initial flow page and starts circular reveal opening animation.
    function beginOpenAnimation() {
        if (closeAnim.running) closeAnim.stop();

        clearStack();

        var initialUrl = pageUrlForFlow(root.flow);
        var initialProf = defaultProfileForFlow(root.flow);
        var size = getProfileSize(initialProf);

        root.currentProfile = initialProf;
        root.surfaceWidth = size.width;
        root.surfaceHeight = size.height;

        var comp = Qt.createComponent(initialUrl);
        if (comp.status === Component.Ready) {
            var page = comp.createObject(pageStackHost, {
                canGoBack: false
            });
            if (page) {
                page.anchors.fill = pageStackHost;
                connectPageSignals(page);
                page.visible = true;
                page.opacity = 1.0;
                root.navStack = [{
                    pageUrl: initialUrl,
                    pageItem: page,
                    profile: initialProf,
                    seedGeom: null
                }];
            }
        } else if (comp.status === Component.Error) {
            console.error("ActionMenuSurface: failed to load " + initialUrl + ": " + comp.errorString());
        }

        morphCarrier.active = false;
        childRevealEffect.visible = false;

        root.phase = "opening";
        root.openProgress = 0.0;
        root.openOpacity = 0.0;
        root.openScale = 0.94;
        root.closeProgress = 0.0;
        root.closeOpacity = 1.0;
        root.closeScale = 1.0;
        root.contentEntranceOpacity = 0.0;

        openAnim.restart();
    }

    // Starts action layer closing animation and resets morph states.
    function beginCloseAnimation() {
        if (root.phase === "closed" || root.phase === "closing") return;
        if (openAnim.running) openAnim.stop();
        if (morphForwardAnim.running) morphForwardAnim.stop();
        if (morphBackAnim.running) morphBackAnim.stop();

        morphCarrier.active = false;
        childRevealEffect.visible = false;
        root.phase = "closing";
        closeAnim.restart();
    }

    // Cancels active closing animation and restores ready phase.
    function cancelCloseAnimation() {
        if (root.phase !== "closing") return;
        closeAnim.stop();
        root.closeProgress = 0.0;
        root.closeOpacity = 1.0;
        root.closeScale = 1.0;
        root.phase = "ready";
    }

    // Pushes submenu page onto stack and initiates button-to-surface forward morph.
    function pushPage(pageUrl, pageProps, seedGeom, profile) {
        if (root.phase !== "ready" || root.navStack.length === 0) return;

        var currentTop = root.navStack[root.navStack.length - 1];
        var parentItem = currentTop.pageItem;
        currentTop.seedGeom = seedGeom;

        var nextProf = profile || "option";
        var parentSize = getProfileSize(currentTop.profile);
        var nextSize = getProfileSize(nextProf);

        var comp = Qt.createComponent(pageUrl);
        if (comp.status !== Component.Ready) {
            console.error("ActionMenuSurface: cannot load " + pageUrl + ": " + comp.errorString());
            return;
        }

        var childProps = Object.assign({}, pageProps || {}, {
            canGoBack: true
        });
        var childItem = comp.createObject(morphChildHost, childProps);
        if (!childItem) {
            console.error("ActionMenuSurface: failed to create child page object for " + pageUrl);
            return;
        }
        connectPageSignals(childItem);

        var newEntry = {
            pageUrl: pageUrl,
            pageItem: childItem,
            seedGeom: seedGeom,
            profile: nextProf
        };
        root.navStack = root.navStack.concat([newEntry]);

        root.activeMorphChild = childItem;
        root.activeMorphParent = parentItem;

        // Configure stable geometry coordinates
        root.morphStartW = parentSize.width;
        root.morphStartH = parentSize.height;
        root.morphTargetW = nextSize.width;
        root.morphTargetH = nextSize.height;
        root.morphStartScreenX = root.centerX - parentSize.width / 2;
        root.morphStartScreenY = root.centerY - parentSize.height / 2;
        root.morphTargetScreenX = root.centerX - nextSize.width / 2;
        root.morphTargetScreenY = root.centerY - nextSize.height / 2;

        var seed = seedGeom || {
            screenX: root.centerX - 100,
            screenY: root.centerY - 20,
            x: Math.round(parentSize.width / 2 - 100),
            y: Math.round(parentSize.height / 2 - 20),
            width: 200,
            height: 40,
            radius: Theme.radius,
            color: Theme.accent,
            icon: "",
            label: ""
        };

        root.morphSeedScreenX = (seed.screenX !== undefined) ? seed.screenX : (root.morphStartScreenX + (seed.x || 0));
        root.morphSeedScreenY = (seed.screenY !== undefined) ? seed.screenY : (root.morphStartScreenY + (seed.y || 0));
        root.morphSeedWidth = seed.width || 200;
        root.morphSeedHeight = seed.height || 40;
        root.morphSeedRadius = seed.radius || Theme.radius;
        root.morphSeedColor = seed.color || Theme.accent;
        root.morphSeedIcon = seed.icon || "";
        root.morphSeedLabel = seed.label || "";

        // Position child inside morphChildHost at native target geometry
        childItem.anchors.fill = undefined;
        childItem.x = Qt.binding(function() { return root.childLocalX; });
        childItem.y = Qt.binding(function() { return root.childLocalY; });
        childItem.width = nextSize.width;
        childItem.height = nextSize.height;
        childItem.visible = true;
        childItem.opacity = 1.0;

        morphChildHost.visible = true;

        // Position parent inside pageStackHost
        parentItem.anchors.fill = undefined;
        parentItem.x = Qt.binding(function() { return root.parentLocalX; });
        parentItem.y = Qt.binding(function() { return root.parentLocalY; });
        parentItem.width = parentSize.width;
        parentItem.height = parentSize.height;
        parentItem.visible = true;
        parentItem.opacity = Qt.binding(function() { return root.morphParentOpacity; });

        // Enable morph layers
        morphCarrier.active = true;
        childRevealEffect.visible = true;

        root.phase = "morphing-forward";
        root.morphProgress = 0.0;
        root.updateForwardMorphFrame(0.0);
        morphForwardAnim.restart();
    }

    // Updates geometry, mask bounds, colors, and opacity on each forward morph frame.
    function updateForwardMorphFrame(progress) {
        root.morphProgress = progress;

        // Synchronous surface size update
        root.surfaceWidth = Math.round(root.morphStartW + (root.morphTargetW - root.morphStartW) * progress);
        root.surfaceHeight = Math.round(root.morphStartH + (root.morphTargetH - root.morphStartH) * progress);

        // Screen mask geometry interpolation
        root.maskScreenX = root.morphSeedScreenX + (root.morphTargetScreenX - root.morphSeedScreenX) * progress;
        root.maskScreenY = root.morphSeedScreenY + (root.morphTargetScreenY - root.morphSeedScreenY) * progress;
        root.maskWidth = Math.max(1, root.morphSeedWidth + (root.morphTargetW - root.morphSeedWidth) * progress);
        root.maskHeight = Math.max(1, root.morphSeedHeight + (root.morphTargetH - root.morphSeedHeight) * progress);
        root.maskRadius = Math.max(0, root.morphSeedRadius + (Theme.largeRadius - root.morphSeedRadius) * progress);

        // Visual effects
        if (progress <= 0.7) {
            root.morphCarrierColor = interpolateColor(root.morphSeedColor, Theme.surface, progress / 0.7);
        } else {
            root.morphCarrierColor = Theme.surface;
        }

        root.morphGhostOpacity = Math.max(0.0, 1.0 - progress * 2.8);
        root.morphBorderWidth = Math.max(0, Math.round((1.0 - progress) * Theme.borderWidth));
        root.morphParentOpacity = Math.max(0.0, 1.0 - progress * 2.2);
    }

    // Finalizes forward morph transition, settling active focus on child page.
    function finishForwardMorph() {
        var childItem = root.activeMorphChild;
        var parentItem = root.activeMorphParent;

        childRevealEffect.visible = false;
        morphCarrier.active = false;

        if (childItem) {
            childItem.anchors.fill = undefined;
            childItem.parent = pageStackHost;
            childItem.x = 0;
            childItem.y = 0;
            childItem.anchors.fill = pageStackHost;
            childItem.visible = true;
            childItem.opacity = 1.0;
        }

        if (parentItem) {
            parentItem.anchors.fill = undefined;
            parentItem.visible = false;
            parentItem.opacity = 1.0;
            parentItem.x = 0;
            parentItem.y = 0;
            parentItem.anchors.fill = pageStackHost;
        }

        var topEntry = root.navStack[root.navStack.length - 1];
        if (topEntry) {
            root.currentProfile = topEntry.profile;
            var finalSize = getProfileSize(topEntry.profile);
            root.surfaceWidth = finalSize.width;
            root.surfaceHeight = finalSize.height;
        }

        root.activeMorphChild = null;
        root.activeMorphParent = null;
        root.phase = "ready";

        if (childItem && childItem.forceActiveFocus) {
            childItem.forceActiveFocus();
        }
    }

    // Pops top page from navigation stack and initiates reverse morph back to originating button.
    function popPage() {
        if (root.phase !== "ready" || root.navStack.length <= 1) {
            root.requestClose();
            return;
        }

        var childEntry = root.navStack[root.navStack.length - 1];
        var parentEntry = root.navStack[root.navStack.length - 2];
        var childItem = childEntry.pageItem;
        var parentItem = parentEntry.pageItem;

        var childSize = getProfileSize(childEntry.profile);
        var parentSize = getProfileSize(parentEntry.profile);

        root.activeMorphChild = childItem;
        root.activeMorphParent = parentItem;

        root.morphStartW = childSize.width;
        root.morphStartH = childSize.height;
        root.morphTargetW = parentSize.width;
        root.morphTargetH = parentSize.height;
        root.morphStartScreenX = root.centerX - childSize.width / 2;
        root.morphStartScreenY = root.centerY - childSize.height / 2;
        root.morphTargetScreenX = root.centerX - parentSize.width / 2;
        root.morphTargetScreenY = root.centerY - parentSize.height / 2;

        var seed = childEntry.seedGeom || {
            screenX: root.centerX - 100,
            screenY: root.centerY - 20,
            x: Math.round(parentSize.width / 2 - 100),
            y: Math.round(parentSize.height / 2 - 20),
            width: 200,
            height: 40,
            radius: Theme.radius,
            color: Theme.accent,
            icon: "",
            label: ""
        };

        root.morphSeedScreenX = (seed.screenX !== undefined) ? seed.screenX : (root.morphTargetScreenX + (seed.x || 0));
        root.morphSeedScreenY = (seed.screenY !== undefined) ? seed.screenY : (root.morphTargetScreenY + (seed.y || 0));
        root.morphSeedWidth = seed.width || 200;
        root.morphSeedHeight = seed.height || 40;
        root.morphSeedRadius = seed.radius || Theme.radius;
        root.morphSeedColor = seed.color || Theme.accent;
        root.morphSeedIcon = seed.icon || "";
        root.morphSeedLabel = seed.label || "";

        // Move child to morphChildHost at its native geometry
        childItem.anchors.fill = undefined;
        childItem.parent = morphChildHost;
        childItem.x = Qt.binding(function() { return root.childLocalX; });
        childItem.y = Qt.binding(function() { return root.childLocalY; });
        childItem.width = childSize.width;
        childItem.height = childSize.height;
        childItem.visible = true;
        childItem.opacity = 1.0;

        morphChildHost.visible = true;

        // Position parent in pageStackHost, initially faded
        parentItem.anchors.fill = undefined;
        parentItem.x = Qt.binding(function() { return root.parentLocalX; });
        parentItem.y = Qt.binding(function() { return root.parentLocalY; });
        parentItem.width = parentSize.width;
        parentItem.height = parentSize.height;
        parentItem.visible = true;
        parentItem.opacity = Qt.binding(function() { return root.morphParentOpacity; });

        morphCarrier.active = true;
        childRevealEffect.visible = true;

        root.phase = "morphing-back";
        root.morphBackProgress = 0.0;
        root.updateBackMorphFrame(0.0);
        morphBackAnim.restart();
    }

    // Updates geometry, mask bounds, colors, and opacity on each reverse morph frame.
    function updateBackMorphFrame(progress) {
        root.morphBackProgress = progress;

        // Synchronous surface size update from child size to parent size
        root.surfaceWidth = Math.round(root.morphStartW + (root.morphTargetW - root.morphStartW) * progress);
        root.surfaceHeight = Math.round(root.morphStartH + (root.morphTargetH - root.morphStartH) * progress);

        // Screen mask shrinks from full child surface back to seed button
        root.maskScreenX = root.morphStartScreenX + (root.morphSeedScreenX - root.morphStartScreenX) * progress;
        root.maskScreenY = root.morphStartScreenY + (root.morphSeedScreenY - root.morphStartScreenY) * progress;
        root.maskWidth = Math.max(1, root.morphStartW + (root.morphSeedWidth - root.morphStartW) * progress);
        root.maskHeight = Math.max(1, root.morphStartH + (root.morphSeedHeight - root.morphStartH) * progress);
        root.maskRadius = Math.max(0, Theme.largeRadius + (root.morphSeedRadius - Theme.largeRadius) * progress);

        // Visual effects
        if (progress <= 0.3) {
            root.morphCarrierColor = Theme.surface;
        } else {
            root.morphCarrierColor = interpolateColor(Theme.surface, root.morphSeedColor, (progress - 0.3) / 0.7);
        }

        root.morphGhostOpacity = (progress >= 0.65) ? Math.min(1.0, (progress - 0.65) / 0.35) : 0.0;
        root.morphBorderWidth = Math.max(0, Math.round(progress * Theme.borderWidth));
        root.morphParentOpacity = Math.min(1.0, progress * 2.0);
    }

    // Finalizes reverse morph transition, cleaning up child page and restoring parent active focus.
    function finishBackMorph() {
        var childItem = root.activeMorphChild;
        var parentItem = root.activeMorphParent;

        childRevealEffect.visible = false;
        morphCarrier.active = false;

        // Child object is destroyed ONLY after reverse morph finishes
        if (childItem) {
            childItem.destroy();
        }

        root.navStack = root.navStack.slice(0, root.navStack.length - 1);

        if (parentItem) {
            parentItem.anchors.fill = undefined;
            parentItem.x = 0;
            parentItem.y = 0;
            parentItem.anchors.fill = pageStackHost;
            parentItem.visible = true;
            parentItem.opacity = 1.0;
        }

        var topEntry = root.navStack[root.navStack.length - 1];
        if (topEntry) {
            root.currentProfile = topEntry.profile;
            var finalSize = getProfileSize(topEntry.profile);
            root.surfaceWidth = finalSize.width;
            root.surfaceHeight = finalSize.height;
        }

        root.activeMorphChild = null;
        root.activeMorphParent = null;
        root.phase = "ready";

        if (parentItem && parentItem.forceActiveFocus) {
            parentItem.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible && (phase === "closed" || phase === "closing")) {
            beginOpenAnimation();
        } else if (!visible && phase !== "closed") {
            phase = "closed";
        }
    }

    onFlowChanged: {
        if (visible && phase === "ready") {
            beginOpenAnimation();
        }
    }

    width: surfaceWidth
    height: surfaceHeight
    scale: openScale * closeScale
    opacity: openOpacity * closeOpacity

    // Universal Escape key routing across all pages
    Keys.onEscapePressed: event => {
        if (root.phase !== "ready") {
            event.accepted = true;
            return;
        }
        if (root.canGoBack) {
            root.popPage();
        } else {
            root.requestClose();
        }
        event.accepted = true;
    }

    // Main surface background & container
    Rectangle {
        id: surfaceRect
        anchors.fill: parent
        visible: true
        radius: Theme.largeRadius
        color: Theme.surface
        border.color: Theme.border !== "transparent" ? Theme.border : Qt.rgba(1, 1, 1, 0.12)
        border.width: Theme.borderWidth
        clip: true

        // Permanent Page Stack Host (Layer 1, parent lives here underneath)
        Item {
            id: pageStackHost
            anchors.fill: parent
            z: 1
            clip: true
        }

        // Morph Carrier (Layer 2, expanding/shrinking button shell)
        ActionMenuMorphProxy {
            id: morphCarrier
            z: 2
            active: false
            morphX: root.maskLocalX
            morphY: root.maskLocalY
            morphWidth: root.maskWidth
            morphHeight: root.maskHeight
            morphRadius: root.maskRadius
            morphColor: root.morphCarrierColor
            morphBorderWidth: root.morphBorderWidth
            seedIcon: root.morphSeedIcon
            seedLabel: root.morphSeedLabel
            ghostOpacity: root.morphGhostOpacity
        }

        // Offscreen host for child page during morph
        Item {
            id: morphChildHost
            anchors.fill: parent
            visible: true
            clip: true
        }

        // Texture capture source with hideSource: true to prevent raw-painting on surface
        ShaderEffectSource {
            id: childCaptureSource
            anchors.fill: parent
            sourceItem: morphChildHost
            hideSource: true
            live: true
            visible: false
        }

        // Hardware-accelerated Child Content Reveal (Layer 3)
        MultiEffect {
            id: childRevealEffect
            anchors.fill: parent
            source: childCaptureSource
            visible: false
            z: 3
            maskEnabled: true
            maskSource: childRevealMaskItem
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.025
            maskThresholdMax: 1.0
            maskSpreadAtMax: 0.0
        }

        // Guard to block navigation/activation during transitions
        Item {
            id: transitionGuard
            anchors.fill: parent
            z: 999
            visible: root.phase !== "ready"
            focus: root.phase !== "ready"

            Keys.onPressed: event => {
                event.accepted = true;
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.phase !== "ready"
                acceptedButtons: Qt.AllButtons
                hoverEnabled: false
                onPressed: mouse => mouse.accepted = true
                onClicked: mouse => mouse.accepted = true
            }

            WheelHandler {
                enabled: root.phase !== "ready"
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => event.accepted = true
            }
        }

        // Offscreen mask for child reveal MultiEffect
        Item {
            id: childRevealMaskItem
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                x: root.maskLocalX
                y: root.maskLocalY
                width: Math.max(1, root.maskWidth)
                height: Math.max(1, root.maskHeight)
                radius: Math.max(0, root.maskRadius)
                color: "white"
            }
        }
    }

    // Offscreen texture capture source for initial open reveal with hideSource semantics.
    // Keeps surfaceRect visible: true so all layouts (ColumnLayout, RowLayout)
    // polish immediately on creation rather than freezing for the 560ms duration of openAnim.
    ShaderEffectSource {
        id: openCaptureSource
        anchors.fill: surfaceRect
        sourceItem: surfaceRect
        hideSource: root.revealActive
        live: root.revealActive
        visible: false
    }

    // Mask for circular initial open reveal
    Item {
        id: circleMask
        anchors.fill: surfaceRect
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(1, root.revealDiameter)
            height: width
            radius: width / 2
            color: "white"
        }
    }

    // Hardware-accelerated MultiEffect reveal applied only during initial opening phase
    MultiEffect {
        id: openRevealEffect
        anchors.fill: surfaceRect
        source: openCaptureSource
        visible: root.revealActive
        z: 100
        maskEnabled: true
        maskSource: circleMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.025
        maskThresholdMax: 1.0
        maskSpreadAtMax: 0.0
    }

    // Opening animation
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: root
            property: "openProgress"
            from: 0.0
            to: 1.0
            duration: HAnimation.actionLayerOpenDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerOpenCurve
        }
        NumberAnimation {
            target: root
            property: "openOpacity"
            from: 0.0
            to: 1.0
            duration: HAnimation.actionLayerOpenDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerOpenCurve
        }
        NumberAnimation {
            target: root
            property: "openScale"
            from: 0.94
            to: 1.0
            duration: HAnimation.actionLayerOpenDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerOpenCurve
        }
        NumberAnimation {
            target: root
            property: "contentEntranceOpacity"
            from: 0.0
            to: 1.0
            duration: HAnimation.actionLayerMorphContentDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerContentCurve
        }
        onFinished: {
            root.openProgress = 1.0;
            root.openOpacity = 1.0;
            root.openScale = 1.0;
            root.contentEntranceOpacity = 1.0;
            root.phase = "ready";
            var topEntry = root.navStack[root.navStack.length - 1];
            if (topEntry && topEntry.pageItem && topEntry.pageItem.forceActiveFocus) {
                topEntry.pageItem.forceActiveFocus();
            }
        }
    }

    // Closing animation
    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: root
            property: "closeProgress"
            from: 0.0
            to: 1.0
            duration: HAnimation.actionLayerCloseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerCloseCurve
        }
        NumberAnimation {
            target: root
            property: "closeOpacity"
            from: 1.0
            to: 0.0
            duration: HAnimation.actionLayerCloseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerCloseCurve
        }
        NumberAnimation {
            target: root
            property: "closeScale"
            from: 1.0
            to: 0.90
            duration: HAnimation.actionLayerCloseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: HAnimation.actionLayerCloseCurve
        }
        onFinished: {
            root.phase = "closed";
            clearStack();
            root.closeAnimationFinished();
        }
    }

    // Forward morph animation: drives single progress value with synchronized frame updates
    NumberAnimation {
        id: morphForwardAnim
        target: root
        property: "morphProgress"
        from: 0.0
        to: 1.0
        duration: HAnimation.actionLayerMorphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.actionLayerMorphCurve
        onFinished: {
            root.finishForwardMorph();
        }
    }

    // Reverse morph animation: drives single back progress value with synchronized frame updates
    NumberAnimation {
        id: morphBackAnim
        target: root
        property: "morphBackProgress"
        from: 0.0
        to: 1.0
        duration: HAnimation.actionLayerMorphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: HAnimation.actionLayerMorphCurve
        onFinished: {
            root.finishBackMorph();
        }
    }
}
