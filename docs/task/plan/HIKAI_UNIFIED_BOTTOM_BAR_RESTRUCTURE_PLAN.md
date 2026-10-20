# HIKAI UNIFIED BOTTOM BAR RESTRUCTURE PLAN

## 0. Mục tiêu

Cấu trúc lại chrome của Hikai để Taskbar và TopBar có hai topology rõ ràng.

### Dock mode

```text
TOP
┌──────────────────────── TopBar ────────────────────────┐
│ Logo | Workspaces | WindowTitle | Center | Right...   │
└────────────────────────────────────────────────────────┘

                         Desktop

                   ┌──── Dock ────┐
                   │ taskbar apps │
                   └──────────────┘
BOTTOM
```

HakuMenu:

```text
Dock App Menu
→ dockFloating
```

### Full bar mode

```text
                         Desktop

┌────────────────── Unified Bottom Bar ───────────────────┐
│ LEFT STATUS │       TASKBAR APPS       │ RIGHT STATUS │
└─────────────────────────────────────────────────────────┘
BOTTOM
```

Trong Full bar:

- TopBar không còn surface riêng ở phía trên.
- Các module trái/phải của TopBar được chuyển vào cùng bottom surface với Taskbar.
- Taskbar giữ vị trí center vật lý.
- `centerCluster` của TopBar bị loại khỏi presentation này.
- Không được tạo hai PanelWindow chồng nhau để giả lập merge.
- Bottom bar là owner duy nhất của background, input region và exclusive zone.
- HakuMenu dùng **bottom-attached Flare**, mở lên trên.
- Chỉ Dock mode mới dùng HakuMenu floating.

---

# 1. Contract bắt buộc

## 1.1 Mode matrix

Phải support đúng bốn trạng thái sau:

| Taskbar state | Dock style | Chrome |
|---|---|---|
| OFF | `dock` | TopBar trên cùng, không Dock |
| ON | `dock` | TopBar trên cùng + compact Dock |
| OFF | `bar` | TopBar trên cùng, không bottom bar |
| ON | `bar` | Unified Full Bottom Bar |

Điểm quan trọng:

```text
unifiedBottomBar =
    AppState.taskbarManualState
    && ShellSettingsStore.dockStyle === "bar"
```

Không dùng riêng `dockStyle === "bar"` để quyết định vị trí TopBar, vì nếu Taskbar bị OFF thì status chrome vẫn phải tồn tại ở phía trên.

---

## 1.2 Hikai TopBar luôn tồn tại về mặt chức năng

Trong Hikai:

```text
SUPER+CTRL+Z
```

không được bật/tắt status bar nữa.

Yêu cầu:

- Hikai không dùng `waybar_manual_state` để quyết định TopBar visibility.
- `waybar_manager.sh --toggle` ở Hikai trở thành no-op.
- Không thay đổi keybind chung của Hyprland/Niri/Mango chỉ vì Hikai.
- Khi quay về Classic, hành vi toggle Waybar cũ vẫn giữ nguyên.
- Không ghi đè preference Classic chỉ vì Hikai không dùng toggle này.

`waybar_manual_state` có thể giữ lại cho compatibility với Classic, nhưng Hikai chrome không được phụ thuộc vào nó.

---

## 1.3 Taskbar icon default

Default mới:

```text
36 px
```

áp dụng cho cả:

```text
dock
bar
```

Một setting duy nhất vẫn điều khiển hai presentation.

Không hardcode riêng 36 ở Full bar và 36 ở Dock.

Canonical source vẫn là:

```text
ShellSettingsStore.dockIconSize
```

Default backend + QML default đều đổi từ `48` → `36`.

Không force user đang có saved `iconSize: 48` về 36.

Semantics:

```text
fresh config        -> 36
Reset               -> 36
v1/v2 migration     -> 36
v3/v4/v5 explicit   -> preserve existing iconSize
```

Không bump schema version chỉ vì đổi default.

---

# 2. Không được bắt đầu bằng Navigation/Notification

Thứ tự refactor bắt buộc:

```text
layout state
    ↓
geometry abstraction
    ↓
shared status modules
    ↓
unified bottom owner
    ↓
Flare orientation
    ↓
HakuMenu
    ↓
tooltip / tray / notification
    ↓
navigation / dashboard / settings
    ↓
OSD
    ↓
runtime matrix
```

Không patch riêng từng:

```text
y:
anchors.top:
ScreenGeometry.flareTopY
```

để "trông có vẻ đúng".

Nếu làm như vậy geometry sẽ nhanh chóng diverge giữa Top và Bottom.

---

# 3. B0 — Freeze baseline hiện tại

Repository trong snapshot hiện tại đang có WIP Full Bar chưa clean.

Các file đang modified gồm ít nhất:

```text
docs/task/HIKAI_NATIVE_DOCK_REPORT.md
docs/task/QUICKSHELL_STYLE.md
docs/task/QUICKSHELL_TESTING.md
scripts/hikai_dock_harness.qml
scripts/hikai_settings_harness.qml
src/home/.config/quickshell/hakuspace/components/DockBar.qml
src/home/.config/quickshell/hakuspace/components/RoundedScreen.qml
src/home/.config/quickshell/hakuspace/components/settings/ShellSettingsPage.qml
src/home/.config/quickshell/hakuspace/services/ShellSettingsStore.qml
```

Current WIP đã có behavior quan trọng:

- Full bar dùng `Theme.surface`.
- Full bar square/borderless.
- Full bar luôn visible khi Taskbar ON.
- Full bar luôn reserve space.
- Compact Dock vẫn giữ preference autohide/exclusive riêng.
- RoundedScreen lower corners đã bắt đầu được đưa lên trên Full bar.

### Codex rule

Không `git reset`, không overwrite WIP này.

Trước khi restructure:

```bash
git status --short
git diff --check
git diff
```

Run baseline hiện tại:

```bash
bash scripts/test_hikai_shell.sh
bash scripts/test_hikai_shell.sh --headless
bash scripts/test_hikai_dock.sh
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
scripts/precommit_check.sh
```

Nếu baseline fail vì code đang WIP, ghi lại failure trước khi tiếp tục.

---

# 4. B1 — Tạo canonical Chrome layout state

## 4.1 Không để component tự suy ra mode

Hiện tại logic nằm rải ở:

```text
TopBar.qml
DockBar.qml
RoundedScreen.qml
HakuMenuDockFloating.qml
ScreenGeometry.qml
```

Cần một canonical derived-state layer.

Khuyến nghị tạo:

```text
services/ChromeLayout.qml
```

Singleton này **không chứa animation/UI**, chỉ chứa topology.

Ví dụ contract:

```qml
readonly property bool taskbarEnabled:
    AppState.taskbarManualState

readonly property bool fullBarRequested:
    ShellSettingsStore.dockStyle === "bar"

readonly property bool unifiedBottomBar:
    taskbarEnabled && fullBarRequested

readonly property bool topStatusBarVisible:
    !unifiedBottomBar

readonly property bool bottomStatusModulesVisible:
    unifiedBottomBar

readonly property bool centerModulesVisible:
    !unifiedBottomBar

readonly property string statusEdge:
    unifiedBottomBar ? "bottom" : "top"

readonly property string hakuMenuPresentation:
    unifiedBottomBar ? "bottomFlare" : "dockFloating"
```

Components không được tự viết lại expression:

```qml
AppState.taskbarManualState
    && ShellSettingsStore.dockStyle === "bar"
```

ở nhiều nơi.

Mọi topology decision phải đi qua canonical service.

---

# 5. B2 — Generalize ScreenGeometry khỏi TopBar-only geometry

Hiện tại:

```text
ScreenGeometry.flareTopY
ScreenGeometry.topBarAnchor()
```

đã encode assumption:

```text
chrome luôn nằm phía trên
surface luôn mở xuống
```

Đây là blocker lớn nhất.

## 5.1 Thêm generic edge geometry

`ScreenGeometry.qml` cần expose semantic geometry kiểu:

```text
chromeAttachmentY(screenHeight)
chromeBarHeight
statusContentAnchor(...)
attachedBodyY(screenHeight, contentHeight)
attachedBodyRect(...)
availableAttachedHeight(screenHeight)
fallbackModuleAnchor(...)
```

Semantics:

### Top

```text
attachmentY = Theme.topBarHeight

surface:
y = attachmentY
extends downward
```

### Bottom unified

```text
attachmentY = screenHeight - ScreenGeometry.dockHeight

surface:
bottom = attachmentY
extends upward
```

`attachmentY` trong Bottom mode là **top edge của bottom bar**, không phải physical screen bottom.

---

## 5.2 Fallback anchor

Thay:

```text
topBarAnchor(x, width)
```

bằng generic:

```text
barAnchor(screenHeight, x, width)
```

Top mode:

```text
inside Theme.topBarHeight
```

Bottom mode:

```text
inside ScreenGeometry.dockHeight
```

và vertical-center item thật sự.

Không sử dụng `Theme.topBarTopPadding / 2` cho Full Bottom mode.

---

## 5.3 Giữ compatibility tạm thời

Trong migration có thể giữ:

```text
flareTopY
topBarAnchor()
```

như deprecated aliases cho Top mode để giảm blast radius.

Nhưng trước final phải audit:

```bash
rg "flareTopY|topBarAnchor" src/home/.config/quickshell/hakuspace
```

Mọi surface có thể chạy trong Bottom mode phải dùng API generic.

---

# 6. B3 — Extract reusable status module lane

`TopBar.qml` hiện vừa làm:

- layer window;
- reservation;
- tray menu controller;
- status module layout;
- Tooltip host;
- OSD Flare;
- visibility/state cleanup.

Không thể reuse sạch trong Bottom Bar.

Tách phần module thành component mới, ví dụ:

```text
components/bar/StatusModules.qml
```

## 6.1 StatusModules ownership

Component này chỉ quản lý:

```text
Logo
Workspaces
WindowTitle

Cava
CenterModule

TrayGroup
SettingsGroup
RecorderGroup
ClockGroup
NotificationGroup
```

Nó không own PanelWindow/exclusive zone.

Props nên có concept:

```text
screenName
presentation
showCenterCluster
```

presentation:

```text
top
fullBottom
```

---

## 6.2 Top presentation

Phải pixel/behavior compatible với hiện tại:

```text
LEFT:
Logo
Workspaces
WindowTitle

CENTER:
Cava
CenterModule

RIGHT:
Tray
Settings
Recorder
Clock
Notification
```

Giữ navigation displacement hiện tại cho non-Logo left modules.

---

## 6.3 Full Bottom presentation

Layout:

```text
LEFT:
Logo
Workspaces
WindowTitle

CENTER:
<NO CenterModule>
<NO Cava>
TASKBAR APP VIEWPORT owns center

RIGHT:
Tray
Settings
Recorder
Clock
Notification
```

Không chỉ:

```qml
visible: false
```

rồi vẫn reserve width một cách vô tình.

Center cluster trong Full mode phải có:

```text
width = 0
implicitWidth = 0
no input
no spacing
```

hoặc không instantiate.

Preferences:

```text
topbar.center
topbar.cava
```

vẫn được giữ lại.

Chúng chỉ không được render trong Full mode.

Khi user quay về Dock mode, saved preferences hoạt động lại.

---

# 7. B4 — Tray controller phải reusable

Hiện tray request/resolution logic nằm trực tiếp trong `TopBar.qml`:

```text
QsMenuOpener
requestTrayMenu()
resolveTrayMenu()
platformMenu()
openTrayPanel()
```

Nếu copy-paste logic này sang DockBar sẽ tạo hai implementation.

Tách thành reusable controller/service/component.

Possible:

```text
components/bar/TrayMenuController.qml
```

Nó phải giữ:

- custom QML tray menu;
- timeout 1500ms;
- native platform fallback;
- secondary activation fallback;
- disappearing tray item cleanup;
- actual anchor rect;
- owning screen.

TopBar và Full Bottom host chỉ forward:

```text
item
anchor Item
owner Window
screenName
```

Native `item.display(...)` phải tiếp tục nhận đúng owning window và coordinates.

---

# 8. B5 — Unified Bottom Bar: một surface duy nhất

Đây là phase thay đổi topology chính.

## 8.1 TopBar

`TopBar.qml` trở thành host cho **Top presentation only**.

Visibility:

```text
ChromeLayout.topStatusBarVisible
```

Không còn:

```text
AppState.waybarManualState
```

quyết định Hikai bar visibility.

Reservation window cũng chỉ active khi:

```text
ChromeLayout.topStatusBarVisible
```

---

## 8.2 DockBar

Compact behavior giữ nguyên.

Khi:

```text
ChromeLayout.unifiedBottomBar
```

thì `DockBar` trở thành owner của toàn bộ Bottom Bar.

Cùng một `dockWindow` chứa:

```text
full width background
StatusModules(left/right)
taskbar viewport
tooltip attachment host
```

Không tạo thêm "BottomTopBar.qml" PanelWindow đè lên DockBar.

---

# 9. B5.1 — Full Bottom Bar layout

Target:

```text
┌──────────────────────────────────────────────────────────┐
│ Logo WS Title │       apps apps apps       │ Tray ... 🔔 │
└──────────────────────────────────────────────────────────┘
```

Tất cả module:

```text
anchors.verticalCenter: parent.verticalCenter
verticalCenterOffset: 0
```

Không dùng TopBar's:

```text
Theme.topBarTopPadding / 2
```

---

# 10. B5.2 — Taskbar phải center vật lý

Không center theo remaining free area một cách naïve.

Nếu left/right widths khác nhau thì:

```text
remaining area center != physical screen center
```

Requirement là taskbar center vật lý.

Tính symmetric safe span quanh:

```text
screenCenterX = width / 2
```

Ví dụ:

```text
leftLimit  = leftStatus.x + leftStatus.width + Theme.gap
rightLimit = rightStatus.x - Theme.gap

safeHalf = min(
    screenCenterX - leftLimit,
    rightLimit - screenCenterX
)

centerViewportWidth = max(0, 2 * safeHalf)
```

Taskbar viewport:

```text
anchors.horizontalCenter: parent.horizontalCenter
width <= centerViewportWidth
```

Nếu app list dài hơn:

```text
Flickable scroll
```

Không được overlap status modules.

### Acceptance

Ở màn hình rộng:

```text
taskbar physical center == screen physical center
```

Ở màn hình hẹp:

```text
taskbar viewport shrink
apps scroll
left/right modules remain usable
no overlap
```

---

# 11. B5.3 — Full bar height

Default icon:

```text
36px
```

Current height formula:

```text
dockHeight = iconSize + 17
```

→ default Full Bar/Dock target height:

```text
53px
```

Status modules phải vertical-center trong height này.

Không tăng bar height riêng chỉ để accommodate TopBar nếu current module height đã fit.

Nếu minimum module height thực tế vượt 53:

```text
barHeight = max(dockHeight, requiredStatusHeight)
```

nhưng `ScreenGeometry` phải là canonical source của final reserved height.

Không cho:

```text
DockBar thinks 53
RoundedScreen thinks 53
reservation thinks 57
```

---

# 12. B5.4 — Exclusive zone

Full Bar ON:

```text
exactly one bottom exclusive zone
```

Không còn TopBar top reservation.

Compact Dock mode:

```text
TopBar top reservation
+
Dock reservation according to existing Dock preference
```

Full bar style + Taskbar OFF:

```text
TopBar top reservation
no bottom reservation
```

Acceptance test phải detect double reservation bằng actual maximized client height.

---

# 13. B6 — Hikai Waybar toggle semantics

Files:

```text
src/core/backend/desktop/waybar_ctl.sh
src/core/facade/waybar_manager.sh
services/AppState.qml
TopBar.qml
docs/core/util.md
docs/task/QUICKSHELL_TESTING.md
```

## Hikai

```text
waybar_manager.sh --toggle
→ no visual change
→ no mutation required
→ exit 0
```

Có thể báo informational notification, nhưng không bắt buộc.

Không đổi:

```text
taskbar_manual_state
```

Taskbar toggle vẫn hoạt động bình thường.

---

## Classic

Không regression:

```text
SUPER+CTRL+Z
→ Waybar ON/OFF như cũ
```

### Important

Không xóa keybind khỏi:

```text
Hyprland
Niri
Mango
Labwc
```

vì cùng config còn được dùng cho Classic.

Chặn hành vi ở backend routing layer.

---

# 14. B7 — Make Flare orientation real

Hiện `FlareHost.qml` đã có:

```qml
enum AttachMode { Top, Left, Right, Bottom }
property int attach: FlareHost.Top
```

nhưng `attach` hiện chưa thực sự điều khiển rendering.

Không tạo thêm API trùng nghĩa.

Hãy hoàn thiện API này.

---

# 15. B7.1 — FlareSurface Top/Bottom

`FlareSurface.qml` hiện hardcode:

- ears ở top edge;
- body mở downward;
- bottom corner radii;
- foot ở bottom.

Thêm orientation.

Ví dụ:

```text
attachmentEdge = Top
attachmentEdge = Bottom
```

Top:

```text
ear
▼
body
rounded distal bottom
```

Bottom:

```text
rounded distal top
body
▲
ear attached to bottom bar
```

### Cấm

Không mirror toàn bộ component bằng:

```qml
scaleY: -1
```

nếu nó làm content/text/input bị upside-down.

Chỉ geometry/background được mirror hoặc tính edge-aware.

Hosted content phải giữ orientation bình thường.

---

# 16. B7.2 — FlareHost

`FlareHost.attach` phải điều khiển:

```text
FlareSurface orientation
content placement
body Y
interaction envelope
anchor relationship
```

`FlareMorph` horizontal span logic có thể giữ nguyên.

Height scalar vẫn là:

```text
0 → contentHeight
```

không cần negative height.

---

# 17. B7.3 — FlarePanelWindow

`base/FlarePanelWindow.qml` hiện hardcode:

```text
ScreenGeometry.flareTopY
body beneath anchor
max content from top seam to bottom
```

Thêm generic attachment.

Top:

```text
bodyRect.y = attachmentY
```

Bottom:

```text
bodyRect.y = attachmentY - bodyHeight
```

Safe zones phải derive từ actual body rect.

`SafeZoneGeometry.verticalBridge()` hiện direction-independent, có thể reuse nếu rect đầu/cuối đúng.

Không duplicate corridor logic.

---

# 18. B7.4 — TooltipLayer

Top status:

```text
tooltip opens downward
```

Full Bottom:

```text
tooltip opens upward
```

Full Bottom `dockWindow` cần một TooltipLayer cùng window ownership để `TooltipManager.activeBar` vẫn resolve đúng.

Audit đặc biệt:

```text
TooltipManager.activeBar
TooltipLayer.windowRoot
```

vì status module tree đã chuyển từ TopBar Window sang Dock Window.

Test:

- WindowTitle tooltip.
- Volume/Brightness tooltip.
- Clock/Calendar tooltip.
- Notification tooltip.
- rapid hover between modules.
- active transient panel dismisses tooltip.

Dock app tooltip hiện đã mở phía trên icon qua `SettingsTooltip`; giữ behavior đó.

---

# 19. B8 — HakuMenu topology mới

## 19.1 Chỉ còn hai presentation có ý nghĩa

Target:

```text
bottomFlare
dockFloating
```

`topFlare` không còn là active Hikai presentation.

Có thể giữ compatibility mapping:

```text
"topFlare" request
→ "bottomFlare"
```

trong một release nếu cần.

---

# 20. B8.1 — Full Bar HakuMenu

Full Bar:

```text
App Menu click
→ bottomFlare
```

Body mở **lên trên** từ bottom bar.

Không float.

Không phải detached card.

Không có old 20%-wide invisible trigger ở screen top.

Anchor là actual App Menu icon/button rect khi có.

Safe zone:

```text
App Menu anchor
↕ corridor
bottom flare body
```

Repeated App Menu click:

```text
open → close
```

Escape/outside exit giữ semantics hiện tại.

---

# 21. B8.2 — Dock HakuMenu

Compact Dock:

```text
App Menu click
→ dockFloating
```

Giữ current lifted-icon seed animation.

Chỉ presentation này:

```text
leases owning Dock
```

và giữ floating gap.

---

# 22. B8.3 — IPC/default callers

Current calls như:

```text
hakumenu.openDefault
launcher.open("drun")
UiState.openHakuMenu(...)
```

không được hardcode top presentation nữa.

Tạo resolver:

```text
UiState / ChromeLayout
→ preferred HakuMenu presentation
```

Rules:

```text
Unified Full Bottom
    → bottomFlare

Dock style
    → dockFloating
```

Nếu dockFloating được gọi từ keyboard/IPC mà không có actual item anchor:

- tạo synthetic anchor tại bottom-center Dock slot;
- không fallback lên top.

---

# 23. B8.4 — HakuMenu component structure

Khuyến nghị:

```text
HakuMenuPanel.qml
 ├─ HakuMenuBottomFlare.qml
 └─ HakuMenuDockFloating.qml
```

Rename/refactor:

```text
HakuMenuTopFlare.qml
→ HakuMenuBottomFlare.qml
```

hoặc tạo generic:

```text
HakuMenuEdgeFlare.qml
```

nhưng không giữ hai implementations Flare gần giống nhau.

Bottom Flare nên dùng:

```qml
HakuMenuContent {
    controlsAtBottom: true
}
```

để controls nằm gần owning bottom chrome.

---

# 24. B9 — Migrate attached surfaces theo thứ tự

Không migrate tất cả trong một commit.

Order:

```text
B9.1 Tooltip
B9.2 Tray Menu
B9.3 Notification Center
B9.4 Notification Popup
B9.5 Navigation
B9.6 Dashboard + Sidebar
B9.7 Settings handoff
B9.8 Level OSD
```

---

# 25. B9.1 — Tray Menu

Current:

```text
TrayGroup
→ actual itemRect
→ TrayMenuPanel / FlarePanelWindow
```

Compact Top mode:

```text
unchanged downward Flare
```

Full Bottom:

```text
opens upward from Tray icon
```

Native platform fallback coordinates phải vẫn đúng.

Test tray items:

```text
custom menu
native fallback
secondaryActivate
item removed while menu open
screen removed
```

---

# 26. B9.2 — Notification Center

Không thay notification data model.

Không biến Center thành modal fullscreen.

Compact:

```text
bell at top-right
→ panel downward
```

Full Bottom:

```text
bell at bottom-right
→ panel upward
```

Giữ:

```text
Top visual layer
Overlay interactive body
panel-sized mask
outside desktop click-through
OnDemand keyboard focus
```

Safe zones phải nằm từ actual bell → actual body.

Right edge vẫn flush theo current design.

Ở Bottom mode, body kết thúc ngay trên bottom bar.

Không overlap bar.

---

# 27. B9.3 — Notification Popup

Current Popup mặc định top-right.

Chuyển thành chrome-edge aware:

### Dock mode

```text
top-right
stack downward
```

### Full Bottom mode

```text
bottom-right
above bottom bar
stack upward
```

Không đặt popup phủ Notification button/bar.

Update:

```text
fitCount
available height
reveal clipping
Top-layer flare placement
Overlay body placement
stack direction
```

Notification model/lifecycle không đổi:

- replacement id;
- timeout;
- remote close;
- DND;
- history.

---

# 28. B9.4 — Navigation

Navigation là phần rủi ro lớn nhất.

Không rewrite visual design.

Chỉ đổi attachment coordinate system.

Current assumptions:

```text
attachmentY = flareTopY
Logo source = top-left
controller grows downward
```

New:

### Top

```text
same as current
```

### Full Bottom

```text
Logo source = bottom-left
Navigation grows upward
```

Logo vẫn morph thành hub.

Non-Logo left modules vẫn được shift để clear Navigation footprint.

---

# 29. B9.5 — Navigation vertical coordinate mapping

Thay vì rải:

```text
if bottom ...
```

khắp `NavigationPanel.qml`, dùng geometry mapping.

Concept:

```text
distanceFromAttachment = canonical logical coordinate
```

Top mapping:

```text
screenY = attachmentY + distance
```

Bottom mapping:

```text
screenY = attachmentY - distance - objectHeight
```

Point mapping:

```text
Top:
y = attachmentY + dy

Bottom:
y = attachmentY - dy
```

Các geometry sau phải derive từ mapping này:

```text
navigation flare
hub/controller
logo proxy
dashboard body
sidebar body
safe zones
animation envelopes
```

---

# 30. B9.6 — Dashboard / Sidebar

Files cần audit:

```text
NavigationPanel.qml
dashboard/DashboardSurface.qml
dashboard/DashboardFlareSurface.qml
sidebar/*
```

Full Bottom:

```text
Dashboard / Sidebar grow upward from Navigation
```

Không mirror text/content.

Sidebar ear joins phải vẫn nằm trong Navigation silhouette.

Existing radius/spike regression tests phải chạy cả Top và Bottom orientation.

---

# 31. B9.7 — Settings

`SettingsPanel.qml` hiện trực tiếp dùng:

```text
ScreenGeometry.flareTopY
```

cho seed/motion.

Khi Navigation source nằm bottom-left:

```text
Settings initial motion phải originate từ bottom-left chrome
```

sau đó mới expand toward center.

Không để Settings animation vẫn xuất phát từ top-left trong Full mode.

Keep:

- Keep/Discard logic.
- confirmation.
- fullscreen overlay semantics.
- editor/settings data logic.

---

# 32. B9.8 — Level OSD

Center module bị bỏ trong Full mode nhưng volume/brightness OSD vẫn phải tồn tại.

Compact:

```text
attached below TopBar center
```

Full Bottom:

```text
attached above Bottom Bar center
```

Files:

```text
TopBar.qml
LevelOsdOverlay.qml
CenterState.qml
```

Nếu current OSD visual bridge phụ thuộc TopBar window, extract ownership để Full Bottom host có thể render same bridge.

Không duplicate OSD state.

---

# 33. B10 — RoundedScreen / frame contract

Current WIP đã đưa lower corners lên trên visible Full bar.

Giữ hướng đó.

## Dock mode

```text
top status reservation
rounded side/bottom frame
optional Dock reservation
```

## Full bar

```text
no top status reservation
bottom Full Bar reservation
RoundedScreen lower corners end at top of Full Bar
```

## Full style + Taskbar OFF

```text
TopBar returns to top
RoundedScreen returns to normal physical bottom
```

No stale bottom inset.

Test style switch live:

```text
dock → bar
bar → dock
Taskbar ON → OFF
OFF → ON
```

không cần reload Quickshell.

---

# 34. B11 — Settings UI behavior

Shell Settings vẫn có:

```text
Dock / Full bar
Visibility
Reserve space
Icon size
...
```

Current WIP đã lock:

```text
Visibility
Reserve space
```

khi style Full bar.

Giữ.

Add UI hint:

```text
Full bar merges Hikai status modules into the bottom taskbar.
Center/Cava are only shown in top-bar layout.
```

Không tự mutate:

```text
topbar.center
topbar.cava
```

khi user chọn Full bar.

---

# 35. Automated test plan

## 35.1 Settings/default tests

Update:

```text
src/core/backend/user/hikai_settings_ctl.py
services/ShellSettingsStore.qml
scripts/hikai_settings_harness.qml
scripts/test_hikai_settings_ctl.py
scripts/test_hikai_shell.sh
```

Assertions:

```text
default iconSize == 36
Reset iconSize == 36
fresh pins sync to 36
v1/v2 migration receives 36
legacy explicit size preserved
```

Current assertions expecting:

```text
48
```

must be updated only where they represent defaults.

---

# 36. 35.2 Chrome topology harness

Extend existing harness or add:

```text
scripts/hikai_chrome_harness.qml
```

Matrix:

### A

```text
taskbar OFF
style dock
```

Expect:

```text
TopBar visible
Top reservation present
Dock absent
```

### B

```text
taskbar ON
style dock
```

Expect:

```text
TopBar visible
Compact Dock visible
```

### C

```text
taskbar OFF
style bar
```

Expect:

```text
TopBar visible
Full Bottom absent
```

### D

```text
taskbar ON
style bar
```

Expect:

```text
TopBar window not visible
Top reservation == 0
Full Bottom visible
Bottom reservation == bar height
Status left/right present
CenterModule absent
Cava absent
Taskbar viewport centered
```

---

# 37. 35.3 Crowded Full Bar test

Need test ở width nhỏ.

Ví dụ headless:

```text
1280
```

Populate:

- many workspaces;
- long WindowTitle;
- multiple tray icons;
- Clock;
- Notification;
- many pinned/running apps.

Assertions:

```text
left modules do not overlap taskbar
right modules do not overlap taskbar
taskbar center stays physical center
viewport becomes scrollable
no clipping outside screen
```

---

# 38. 35.4 Tooltip matrix

For both Top and Bottom:

```text
WindowTitle
Clock
Notification
Settings quick controls
```

Check:

```text
correct direction
correct anchor rect
no clipping
safe Flare ears
dismiss on activePanel
multi-monitor ownership
```

Bottom tooltip body must have:

```text
body.bottom <= bottomBar.top
```

within pixel tolerance.

---

# 39. 35.5 HakuMenu matrix

### Full Bottom

```text
App Menu click
→ bottomFlare

second click
→ close

Escape
→ close

outside exit
→ close

controlsAtBottom
→ true
```

No top-edge hover trigger.

### Dock

```text
App Menu click
→ dockFloating

Dock remains leased while menu open
second click closes
```

### IPC

```text
hakumenu.openDefault
launcher.open drun
```

must choose correct presentation without top fallback.

---

# 40. 35.6 Notification matrix

Both layouts:

```text
popup
replacement
timeout
remote close
DND
center
Clear All
```

Full Bottom:

```text
popup stacks upward
center opens upward
desktop outside Center remains directly clickable
bell second-click closes
```

Multi-monitor:

```text
source bell monitor owns Center
popup routing remains correct
```

---

# 41. 35.7 Navigation matrix

Both layouts:

```text
Logo click
hover
open
close
Dashboard
Sidebar
Settings
Escape
outside exit
```

Full Bottom screenshot checks:

```text
Logo morph starts from actual bottom-left Logo rect
Navigation sits above bar
Sidebar ear no spike
Dashboard does not cross bar
```

---

# 42. 35.8 OSD matrix

Test:

```text
volume up/down
mute
brightness
rapid 10–20 inputs
switch volume → brightness
fullscreen client
```

Top mode:

```text
below TopBar
```

Full mode:

```text
above Bottom Bar
```

No CenterModule dependency.

---

# 43. 35.9 Hikai TopBar toggle test

While Hikai active:

```bash
~/.local/bin/waybar_manager.sh --toggle
```

Expect:

```text
Top status/full bottom chrome unchanged
no shell surface disappears
```

Run twice.

Then switch Classic.

Run same command.

Expect:

```text
Classic Waybar toggles normally
```

This cross-backend test is mandatory.

---

# 44. Physical compositor matrix

After headless PASS:

```text
Hyprland
Niri
MangoWM
```

Minimum smoke:

```text
1 monitor
2 monitors
Taskbar Dock
Taskbar Full
Taskbar OFF
style switch live
HakuMenu
Tooltip
Tray
Notification popup
Notification Center
Navigation
Dashboard
Sidebar
Settings
OSD
fullscreen app
workspace switch
shell reload
```

Also test fractional scaling if available:

```text
1.25
1.5
```

Do not refactor WM workspace backends as part of this task.

Only fix WM-specific code if this chrome work exposes an actual regression.

---

# 45. Style switch with active transient UI

Explicitly test:

```text
Tooltip open → switch style
Tray open → switch style
Notification Center open → switch style
Navigation open → switch style
HakuMenu open → switch style
```

Policy:

Prefer:

```text
close transient cleanly before topology transfer
```

over trying to animate one active surface from top to bottom in-place.

No stale:

```text
anchorRect
safeZone
screenName
keyboard lease
UiState.activePanel
```

may survive incorrectly.

---

# 46. File audit list

Primary:

```text
services/ChromeLayout.qml                   NEW
services/ScreenGeometry.qml
services/ShellSettingsStore.qml
services/AppState.qml
services/UiState.qml

components/TopBar.qml
components/DockBar.qml
components/RoundedScreen.qml

components/bar/StatusModules.qml            NEW
components/bar/TrayMenuController.qml       likely NEW

components/base/FlarePanelWindow.qml
components/base/TooltipLayer.qml
components/base/SafeZoneDebugOverlay.qml

components/flare/FlareHost.qml
components/flare/FlareSurface.qml
components/flare/FlareMorph.qml

components/HakuMenuPanel.qml
components/hakumenu/HakuMenuTopFlare.qml    replace/rename
components/hakumenu/HakuMenuDockFloating.qml
components/hakumenu/HakuMenuContent.qml

components/TrayMenuPanel.qml
components/NotificationCenterPanel.qml
components/NotificationPopup.qml
components/NavigationPanel.qml
components/SettingsPanel.qml
components/LevelOsdOverlay.qml

components/dashboard/DashboardSurface.qml
components/dashboard/DashboardFlareSurface.qml

shell.qml

src/core/backend/user/hikai_settings_ctl.py
src/core/backend/desktop/waybar_ctl.sh
src/core/facade/waybar_manager.sh
```

Tests/docs:

```text
scripts/hikai_settings_harness.qml
scripts/hikai_dock_harness.qml
scripts/hikai_topbar_harness.qml
scripts/hikai_hakumenu_harness.qml

scripts/test_hikai_shell.sh
scripts/test_hikai_dock.sh
scripts/test_hikai_hakumenu.sh
scripts/test_hikai_settings_ctl.py
scripts/test_rounded_screen_pixels.py

docs/task/QUICKSHELL_STYLE.md
docs/task/QUICKSHELL_TESTING.md
docs/task/HIKAI_NATIVE_DOCK_REPORT.md
```

---

# 47. Search audits before final

Run:

```bash
rg -n "ScreenGeometry\.flareTopY" \
  src/home/.config/quickshell/hakuspace

rg -n "ScreenGeometry\.topBarAnchor" \
  src/home/.config/quickshell/hakuspace

rg -n "waybarManualState" \
  src/home/.config/quickshell/hakuspace

rg -n '"topFlare"|topFlare' \
  src/home/.config/quickshell/hakuspace

rg -n "anchors \{ top: true" \
  src/home/.config/quickshell/hakuspace/components
```

Review every hit.

Not every `anchors.top` is wrong.

Only reject hits that encode chrome attachment direction instead of internal component layout.

---

# 48. Important regression traps

## Trap 1 — Two Full Bar windows

Do not implement:

```text
DockBar bottom window
+
moved TopBar bottom window
```

This creates:

- duplicate input;
- duplicate background;
- conflicting exclusive zones;
- ordering problems;
- tooltip ownership bugs.

One unified owner only.

---

## Trap 2 — Mirroring content with Scale

Do not solve Bottom Flare by flipping a parent containing text.

Geometry can mirror.

Content cannot.

---

## Trap 3 — Center cluster hidden but still reserving width

Full Bar requires actual removal from layout.

Taskbar owns center.

---

## Trap 4 — `dockStyle === bar` alone

Taskbar can be manually OFF.

Bottom chrome only exists while Full bar is actually active.

---

## Trap 5 — Notification Center becomes modal

Do not replace its current panel-sized input topology with fullscreen capture just to simplify bottom safe-zones.

---

## Trap 6 — ActivePanel closed because TopBar host hides

Current `TopBar.onVisibleChanged` has cleanup tied to bar visibility.

After restructure:

```text
TopBar hidden
```

can simply mean:

```text
presentation moved to Full Bottom
```

It does NOT mean global Hikai chrome was turned off.

Remove/refactor any cleanup that assumes these are equivalent.

---

## Trap 7 — Tray fallback coordinates

Moving TrayGroup into DockBar changes its owning Window.

Verify native tray fallback uses correct window-local coordinates.

---

## Trap 8 — TooltipManager root ownership

`TooltipManager.activeBar` currently discovers host through the object tree.

Moving modules into DockBar may change its resolved root.

Test this explicitly instead of assuming it works.

---

# 49. Suggested commit sequence

Do not implement this as one giant commit.

Recommended:

```text
1. refactor(chrome): add canonical Hikai layout state
2. refactor(geometry): make chrome attachment edge-aware
3. refactor(bar): extract reusable status modules and tray controller
4. feat(taskbar): merge status modules into full bottom bar
5. fix(hikai): make topbar visibility fixed in Hikai
6. refactor(flare): support bottom attachment in shared primitives
7. feat(hakumenu): replace top flare with bottom flare in full bar
8. feat(chrome): make tooltip tray and notifications edge-aware
9. feat(navigation): support bottom-origin navigation and handoffs
10. feat(osd): attach level feedback to active chrome edge
11. test(hikai): expand chrome/full-bar runtime matrix
12. docs(hikai): document unified bottom chrome
```

Each commit must leave syntax/static checks passing.

Runtime-dependent commits must include evidence before moving on.

---

# 50. Phase gates

Codex must stop and fix regressions at each gate.

## Gate A

After layout/geometry refactor:

```text
Dock mode visually unchanged
```

## Gate B

After shared StatusModules:

```text
TopBar visually unchanged
```

## Gate C

After Full Bottom owner:

```text
one bottom window
one reservation
taskbar centered
left/right modules usable
no CenterModule
```

## Gate D

After Flare primitives:

```text
Top Flare baseline unchanged
Bottom Flare renders correctly
```

## Gate E

After HakuMenu:

```text
Full = bottomFlare
Dock = dockFloating
```

## Gate F

After attached surfaces:

```text
tooltip
tray
notifications
navigation
settings
OSD
```

all use correct edge.

---

# 51. Definition of DONE

This restructure is DONE only when all statements are true:

```text
[ ] Fresh Hikai Taskbar icon default is 36px
[ ] Dock and Full use the same icon-size setting
[ ] Existing explicit user icon sizes survive migration
[ ] Hikai SUPER+CTRL+Z cannot hide chrome
[ ] Classic SUPER+CTRL+Z still toggles Waybar

[ ] Dock style keeps current TopBar + floating Dock topology
[ ] Full style + Taskbar ON has no TopBar at screen top
[ ] Full style has one unified bottom chrome owner
[ ] Full bar reserves exactly one bottom exclusive zone
[ ] Taskbar apps remain physically centered
[ ] Left/right status modules are vertically centered
[ ] CenterModule is absent in Full mode
[ ] Cava center slot is absent in Full mode

[ ] Full HakuMenu is bottom-attached Flare
[ ] Dock HakuMenu remains floating
[ ] No top HakuMenu trigger remains active

[ ] Top tooltips open downward
[ ] Bottom tooltips open upward
[ ] Tray follows owning edge
[ ] Notification Center follows owning edge
[ ] Notification Popup follows owning edge
[ ] Navigation follows owning edge
[ ] Dashboard/Sidebar handoff works from bottom Navigation
[ ] Settings morph source follows owning edge
[ ] OSD follows owning edge

[ ] Notification Center remains non-modal outside its panel
[ ] Fullscreen behavior is preserved
[ ] multi-monitor ownership is correct
[ ] fractional scale has no obvious seam/offset regression
[ ] live Dock ↔ Full switching leaves no stale UiState
[ ] shell reload passes

[ ] git diff --check passes
[ ] QML syntax passes
[ ] precommit passes
[ ] headless Hikai tests pass
[ ] Hyprland physical smoke passes
[ ] Niri physical smoke passes
[ ] MangoWM physical smoke passes
```

---

# 52. Final architectural rule

Sau task này, component không được hỏi:

```text
"TopBar đang ở đâu?"
```

Nó phải hỏi:

```text
"active chrome edge là gì?"
"attachment seam nằm ở đâu?"
"surface mở theo hướng nào?"
```

Và component không được hỏi:

```text
"đây có phải TopBar không?"
```

nếu thứ nó thật sự cần là:

```text
status module lane
anchor rect
chrome edge
exclusive zone
```

Mục tiêu của refactor không chỉ là kéo UI xuống dưới.

Mục tiêu là loại bỏ assumption:

```text
Hikai chrome == top edge
```

khỏi geometry layer, để Dock mode và Full Bottom mode cùng chạy trên một kiến trúc.