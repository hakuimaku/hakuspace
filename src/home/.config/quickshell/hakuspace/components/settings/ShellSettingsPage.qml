import QtQuick
import "../../services"
import "SettingsCatalog.js" as Catalog

SettingsCategoryPage {
    id: root
    category: "Shell"
    excludedGroups: ["Layout", "Top Bar"]
    // Keep the layout selector visible while the larger preview scrolls out of the way.
    headerContent: Component {
        SettingsSegmentedControl {
            width: parent.width
            options: Catalog.descriptor("layout").options
            value: SettingsCoordinator.read("layout")
            shortcutTarget: root.shortcutTarget
            enabled: !SettingsCoordinator.busy
            onChosen: value => SettingsCoordinator.set("layout", value)
        }
    }
    leadingContent: Component { ShellBarPreview { shortcutTarget: root.shortcutTarget; showLayoutControl: false } }
}
