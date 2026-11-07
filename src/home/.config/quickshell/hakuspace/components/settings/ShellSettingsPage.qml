import QtQuick
import "../../services"
import "../../config/SettingsCatalog.js" as Catalog

SettingsCategoryPage {
    id: root
    category: "Shell"
    excludedGroups: ["Layout", "Top Bar"]
    // Keep the layout selector visible while the larger preview scrolls out of the way.
    headerContent: Component {
        ShellLayoutControl {
            width: parent.width
            shortcutTarget: root.shortcutTarget
        }
    }
    leadingContent: Component { ShellBarPreview { shortcutTarget: root.shortcutTarget; showLayoutControl: false } }
}
