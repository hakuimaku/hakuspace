import QtQuick
import "../../services"

SettingsCategoryPage {
    id: root
    category: "Power & Session"
    excludedGroups: ["Keep Awake", "Idle timeline"]
    leadingContent: Component {
        Column {
            // Search reaches specialized milestones through their catalog IDs.
            function reveal(id) {
                if (id === "idle-keep-awake") return awake.reveal(id)
                return timeline.reveal(id)
            }
            spacing: Theme.sectionGap
            GeneralSettingsForm { id: awake; width: parent.width; category: root.category; group: "Keep Awake"; shortcutTarget: root.shortcutTarget }
            SettingsSectionCard { width: parent.width; title: "Idle timeline"; IdleTimeline { id: timeline; width: parent.width; shortcutTarget: root.shortcutTarget } }
        }
    }
}
