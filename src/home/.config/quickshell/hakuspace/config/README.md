# Developer configuration

| Need to change | Edit |
| --- | --- |
| Spacing, radius offsets, palette, sizing, typography fallbacks | `Design.qml` |
| Animation durations, factors and easing curves | `Motion.qml` |
| HakuMenu tabs and fixed General/Theme items | `UiCatalog.js` → HakuMenu |
| Theme options, accent/font-size presets, Power actions, Record modes | `UiCatalog.js` → Action Menu |
| Sidebar tools and quick actions | `UiCatalog.js` → Sidebar |
| Dashboard widget identity, titles and ordering | `UiCatalog.js` → Dashboard |
| Wallpaper kinds and video quality profiles | `UiCatalog.js` → Wallpaper |
| Settings rows, search metadata and reset descriptors | `SettingsCatalog.js` |
| Shell preference defaults and schema version | `Defaults.js` |
| Internal Hikai memory thresholds, warmup, sampling and cooldowns | `Memory.js` |
| Runtime state, IO, validation and persistence | `../services/` |

`Theme` and `HAnimation` remain the public runtime facades. Components keep
using them; presentation components may import the JavaScript catalogs directly.
Derived motion bindings remain in `HAnimation` so runtime overrides retain their
existing behavior. Shell wipe timings remain available through `Theme`.
Keep this directory static: no service imports, processes, file watchers or
runtime state. Generated theme overrides and settings drafts stay in services.
Data discovered or changed at runtime does not belong in `config/`: keep clipboard
records, notifications, process/device/font lists, wallpaper files, window models
and temporary UI state with their existing owners.

Dashboard widget implementations are mapped by stable `key` in
`components/dashboard/DashboardWidgetHost.qml`. Add a local Component mapping when
adding a new widget descriptor. Power/Record/Sidebar action execution and visibility
rules stay in their existing QML handlers and services.

`Defaults.shellDefaults()` returns a fresh nested snapshot on every call.
Python retains its standalone defaults; `tests/hikai/config/test_contract.js`
checks exact parity with the backend and Settings reset metadata.
It also checks migrated catalog ownership and pre-refactor presentation fixtures.
When intentionally changing labels, order or presets, update the corresponding
expectations in `tests/hikai/config/fixtures/ui_catalog.json`.
