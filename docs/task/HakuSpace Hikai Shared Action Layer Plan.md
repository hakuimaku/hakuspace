# HakuSpace — Shared Hikai Action Layer / Morph Menu Plan

## 0. Mục tiêu

Tạo một hệ thống **shared Action/Menu Layer** cho các command tương tác vốn đang dùng Rofi trong Classic.

Nguyên tắc backend:

```text
Classic
    public facade
        → frontend/classic/*_rofi.sh
        → backend/*_ctl.sh

Hikai
    public facade
        → Quickshell IPC
        → native shared Action Layer
        → backend/*_ctl.sh
```

Classic phải giữ nguyên Rofi.

Hikai không được gọi Rofi cho các menu đã migrate.

Backend tiếp tục hoàn toàn headless.

Không duplicate mutation logic trong QML.

---

# 1. UX contract bắt buộc

## 1.1 Một shared centered layer

Các menu Hikai mới dùng chung một fullscreen `PanelWindow`/host trên `WlrLayer.Overlay`.

Bên trong là một surface hình chữ nhật đặt chính giữa màn hình.

Layer chịu trách nhiệm chung cho:

- fullscreen input capture;
- keyboard focus;
- Escape;
- outside-click;
- open/close lifecycle;
- surface geometry;
- morph giữa các page;
- page stack/back navigation;
- button motion;
- scrim;
- `UiState.activePanel`.

Không tạo một `PanelWindow` khác cho:

- record;
- power;
- exit;
- theme;
- submenu theme;
- microphone selection.

Tất cả phải dùng **cùng một host/surface**.

---

# 2. Motion language

Đây là yêu cầu UX, không được thay bằng fade đơn giản.

## 2.1 First open — circular center reveal

Khi menu được mở từ trạng thái đóng:

```text
closed
    ↓
center circular reveal
    ↓
full rectangular surface
```

Hiệu ứng lấy cảm hứng trực tiếp từ circular reveal đang có ở Wallpaper selector.

Không cần copy nguyên code WallpaperCarousel, nhưng nên reuse cùng nguyên lý:

```text
circular mask centered in surface
diameter: 0 → diagonal(surface)
```

Surface cuối đã biết geometry từ trước.

Trong lúc reveal:

- circle mở từ đúng center;
- opacity 0 → 1;
- surface có thể scale rất nhẹ khoảng `0.94 → 1.0`;
- radius cuối dùng HakuSpace radius;
- không bounce mạnh;
- không spring quá mức.

Animation phải chậm, mềm, hiện đại.

Initial tuning:

```text
open reveal:       ~560 ms
surface scale:     ~560 ms
content entrance:  ~320 ms
```

Dùng Bezier mềm tương tự HAnimation shell/navigation motion, không `OutBack` mạnh.

---

## 2.2 Close — fade + zoom out

Close KHÔNG reverse circular reveal.

Đúng yêu cầu:

```text
surface scale 1.0 → ~0.88–0.92
opacity 1 → 0
scrim opacity → 0
```

Initial tuning:

```text
close: 420–480 ms
```

Chuyển động chậm hơn button nhưng nhanh hơn open một chút.

`visible = false` và release input mask chỉ sau khi animation kết thúc.

Không được:

```text
activePanel = ""
→ surface biến mất ngay
```

Phải có `closeRequested / closing / finishClose` tương tự lifecycle của Wallpaper.

---

# 3. Yêu cầu quan trọng nhất: page/layer nối tiếp PHẢI morph

Không được làm:

```text
Theme menu
→ disappear
→ Font Size menu appears
```

Không được đóng `PanelWindow` hiện tại rồi mở một `PanelWindow` khác.

Không được chỉ crossfade hai Loader.

Thay vào đó:

```text
parent page
    → selected MorphButton becomes morph origin
    → surface/content morph continuously
    → child page
```

## 3.1 Button-to-layer morph

Khi user click một button dẫn sang submenu:

Ví dụ:

```text
Change Theme
┌───────────────────────┐
│ Change Font           │
│ Change Font Size  ← click
│ Change Accent Color   │
└───────────────────────┘
```

Button `Change Font Size` là **morph seed**.

Gemini phải lấy geometry của button trong coordinate space của shared surface:

```text
seedX
seedY
seedWidth
seedHeight
seedRadius
seedColor
```

Sau đó dùng một visual morph proxy.

Concept:

```text
selected button
     ↓
expand/morph
     ↓
child layer/page
```

Morph proxy:

```text
x/y          seed → child surface/body target
width/height seed → child target geometry
radius       button radius → layer radius
fill         selected/accent → surface
```

Outgoing content giảm opacity trong lúc button đang expand.

Incoming content chỉ bắt đầu hiện sau khi morph đã tiến đủ xa, ví dụ khoảng 55–70%.

Kết quả phải tạo cảm giác:

> submenu sinh ra trực tiếp từ button vừa chọn.

---

# 4. Reverse morph / Back

Nếu đang ở child page:

```text
Escape
Back
```

không đóng toàn bộ menu ngay.

Quy tắc:

```text
stack depth > 1
    → reverse morph về page trước

stack depth == 1
    → close layer bằng fade + zoom
```

Ví dụ:

```text
Theme root
  ↓ click Accent
Accent page

Escape
  ↓
Accent page morphs back into "Change Accent Color" button
  ↓
Theme root
```

Geometry và focus của button gốc phải được nhớ trong navigation stack.

Back phải là visual reverse hợp lý của forward morph.

---

# 5. Same-size pages vẫn phải morph

Một số Rofi menu hiện cùng dùng:

```text
option-menu.rasi
width: 40%
height: 40%
```

Ví dụ:

```text
change_theme root
→ font size

record mode
→ microphone source
```

Dù rectangle đầu/cuối có cùng kích thước, vẫn phải nhìn thấy morph.

Do đó page morph không được phụ thuộc hoàn toàn vào:

```text
width A != width B
```

Button seed vẫn expand thành content page mới.

Content, selected shell, radius và internal layout phải chuyển động.

---

# 6. Geometry profiles lấy từ Rofi hiện tại

Không chọn một size duy nhất cho mọi menu.

Tạo shared geometry profiles.

## `option`

Tương đương:

```text
option-menu.rasi
width: 40%
height: 40%
```

Dùng cho:

- record mode;
- record source;
- theme root;
- font;
- font size;
- accent;
- các generic option menus sau này.

Quickshell:

```text
width  ≈ screen.width  * 0.40
height ≈ screen.height * 0.40
```

Có min/max hợp lý để không quá nhỏ hoặc quá lớn trên ultrawide.

---

## `exitReport`

Rofi hiện tại:

```text
width: 50%
height: 60%
```

Hikai giữ footprint tương đương:

```text
width  ≈ 50vw
height ≈ 60vh
```

---

## `powerHorizontal`

Rofi `shutdown.rasi`:

```text
width: 70%
height: 140px
```

Power Hikai phải giữ silhouette rộng/thấp tương tự.

---

## `powerVertical`

Compatibility cho:

```text
shutdown.sh -v
```

Rofi:

```text
120px × 400px
```

Nếu vẫn hỗ trợ `-v` ở Hikai, dùng profile vertical tương ứng và vẫn center.

Classic-only placement arguments `--extend` không được làm phức tạp Hikai surface.

Hikai luôn centered trừ khi sau này có specification khác.

---

# 7. Shared components đề xuất

Không over-generalize thành UI framework lớn.

Tạo abstraction vừa đủ.

Ví dụ:

```text
components/actionmenu/
    ActionMenuPanel.qml
    ActionMenuSurface.qml
    ActionMenuPage.qml
    ActionMenuButton.qml
    ActionMenuMorphProxy.qml

    pages/
        RecordPage.qml
        RecordSourcePage.qml
        PowerPage.qml
        ExitPage.qml
        ThemePage.qml
        ThemeFontPage.qml
        ThemeFontSizePage.qml
        ThemeAccentPage.qml
        ThemeRofiPage.qml
        ThemeWaybarPage.qml
```

Tên cụ thể Gemini có thể điều chỉnh, nhưng topology phải tương đương.

---

# 8. Reuse shared button motion

Repo đã có:

```text
components/motion/MorphButton.qml
components/motion/ButtonMotion.qml
services/HAnimation.qml
```

Action Menu không được tạo hệ thống hover/press animation riêng.

`ActionMenuButton.qml` nên wrap/reuse `MorphButton`.

Button phải có:

```text
idle
hover
press
selected/focus
```

và chuyển động theo shared HAnimation.

Không được thay đổi implicit layout khi hover.

Morph proxy mới là thứ được phép thay đổi geometry lớn.

---

# 9. HAnimation additions

Thêm token riêng thay vì hardcode duration khắp QML.

Ví dụ:

```text
actionLayerOpenDuration
actionLayerCloseDuration

actionLayerMorphDuration
actionLayerMorphContentDuration

actionLayerOpenCurve
actionLayerCloseCurve
actionLayerMorphCurve
actionLayerContentCurve
```

Initial target:

```text
open        560 ms
close       460 ms
page morph  480 ms
content     260–300 ms
```

Animation phải calm / fluid.

Không dùng HakuMenu bounce curve nếu nó làm surface giật mạnh.

---

# 10. Shared state machine

Mở rộng `UiState.qml` hoặc tạo state service chuyên biệt nhưng `UiState.activePanel` vẫn là global owner.

Suggested logical state:

```text
activePanel = "actionMenu"

actionMenuScreenName
actionMenuFlow
actionMenuPage
actionMenuClosing
actionMenuPhase
```

Phase:

```text
closed
opening
ready
morphing-forward
morphing-back
closing
```

Navigation stack tối thiểu chứa:

```text
flow
page
geometryProfile
selectedIndex/focus
morphSeedGeometry
```

Không cho double-click hay IPC mới phá animation đang chạy.

Trong `morphing-*`:

- block activation;
- block outside-click;
- giữ keyboard focus;
- tránh start hai Process mutation cùng lúc.

---

# 11. IPC

Thêm IPC riêng, ví dụ:

```text
target: "actionMenu"
```

API tối thiểu:

```text
openDefault(flow)
close()
status()
```

Ví dụ:

```text
qs -c hakuspace ipc call actionMenu openDefault record
qs -c hakuspace ipc call actionMenu openDefault power
qs -c hakuspace ipc call actionMenu openDefault exit
qs -c hakuspace ipc call actionMenu openDefault theme
```

Không truyền arbitrary shell command từ facade vào QML.

Chỉ truyền stable flow ID.

Allowed:

```text
record
power
exit
theme
```

QML tự biết flow đó được phép gọi backend nào.

---

# 12. Facade routing

Theo pattern đã dùng thành công ở `wallpaper_select.sh`.

## `record.sh`

No args:

```text
Classic:
    nếu recording → record_ctl stop
    nếu idle → record_rofi.sh

Hikai:
    nếu recording → record_ctl stop
    nếu idle → actionMenu openDefault record
```

Explicit API:

```text
--status
--list-modes
--list-sources
--start
--stop
```

giữ nguyên headless behavior.

---

## `shutdown.sh`

No args:

```text
Classic
    → power_rofi.sh

Hikai
    → actionMenu power
```

Explicit backend flags giữ nguyên.

---

## `exit.sh`

No args:

```text
Classic
    → exit_rofi.sh

Hikai
    → actionMenu exit
```

`--process-report` và `--execute` giữ nguyên.

---

## `change_theme.sh`

No args:

```text
Classic
    → theme_rofi.sh menu

Hikai
    → actionMenu theme
```

Explicit:

```text
--accent
--font
--size
--status
```

giữ headless và không phụ thuộc UI.

---

# 13. Record flow — reference multi-layer implementation

Đây là flow đầu tiên để chứng minh generic morph.

## Root

Load:

```text
record_ctl.sh list-modes --json
```

Map stable IDs → presentation:

```text
system-audio → Only Sound
mic-system   → Micro and Sound
no-audio     → No Sound
```

Label/icon thuộc QML frontend.

Backend chỉ sử dụng stable ID.

### system-audio

Click:

```text
button press
→ selection morph acknowledgement
→ record_ctl.sh start system-audio
→ close layer
```

### no-audio

Tương tự.

### mic-system

KHÔNG đóng menu.

```text
Record Mode
   ↓ click "Micro and Sound"
selected button morphs
   ↓
Microphone Source page
```

Load:

```text
record_ctl.sh list-sources --json
```

Chọn source:

```text
record_ctl.sh start mic-system --source <stable-id>
```

Sau success:

```text
close layer with fade + zoom
```

Escape tại microphone page:

```text
reverse morph
→ Record Mode
```

Đây là acceptance case bắt buộc cho nested morph.

---

# 14. `change_theme.sh` — canonical morph stress test

Đây phải là test chính của architecture.

Root page:

```text
Change Theme

Change Waybar Theme
Change Rofi Theme
Change Font
Change Font Size
Change Accent Color
```

Các row là `ActionMenuButton`.

## 14.1 Font

```text
Theme root
→ click Change Font
→ button-to-layer morph
→ Font page
```

Load:

```text
theme_ctl.sh list-fonts
```

Apply:

```text
theme_ctl.sh set-font <font>
```

Sau successful apply có thể:

- giữ child page mở và update current state; hoặc
- morph back về Theme root.

Preferred:

```text
apply
→ short selected confirmation
→ reverse morph về Theme root
```

để user thấy state mới.

---

## 14.2 Font Size

Flow:

```text
Theme root
→ Change Font Size
→ morph
→ 10 / 12 / 14 / 16 / 18
```

Current value:

```text
theme_ctl.sh get size
```

Apply:

```text
theme_ctl.sh set-size <value>
```

Sau apply:

```text
reverse morph → Theme root
```

Theme hot reload có thể làm font thay đổi trong chính animation.

Không được để reload reset ActionMenu state.

Test đặc biệt case này.

---

## 14.3 Accent Color

Root:

```text
Theme
→ Change Accent Color
→ morph
→ Accent page
```

Presets giữ parity với Classic:

```text
Slate Blue
Green
Peach
Yellow
Pink
White
Grey
```

QML giữ display labels.

Backend chỉ nhận:

```text
#RRGGBB
```

Apply:

```text
theme_ctl.sh set-accent "#xxxxxx"
```

Hikai có thể bổ sung native custom hex input.

Không parse màu từ label như Classic hiện tại.

---

# 15. Waybar/Rofi theme submenu trong Hikai

Không được gọi `theme_rofi.sh`, `waybar_rofi.sh` hay `rofi_theme_rofi.sh` từ Hikai.

Dữ liệu phải lấy từ headless controllers.

Rofi theme:

```text
rofi_theme_ctl.sh list
rofi_theme_ctl.sh current
rofi_theme_ctl.sh set <id>
```

Waybar:

```text
waybar_ctl.sh list
waybar_ctl.sh current
waybar_ctl.sh set <id>
```

Tuy nhiên backend hiện có policy giới hạn Waybar mode khi Hikai active.

Gemini không được silently bypass policy đó.

Nếu muốn Hikai dùng menu này để cấu hình Classic Waybar cho lần switch sau thì phải tạo một explicit backend operation riêng và test rõ ràng.

Không nhét workaround trực tiếp vào QML.

---

# 16. Power flow

Power layer dùng `powerHorizontal` profile.

Six actions:

```text
Suspend
Reboot
Poweroff
Hibernate
Lock
Logout
```

Visual tương tự shutdown Rofi hiện tại:

```text
wide horizontal row
large icon buttons
```

Buttons phải reuse morph motion.

Các action:

```text
suspend
reboot
poweroff
hibernate
lock
```

gọi explicit:

```text
power_ctl.sh <action>
```

---

# 17. Power → Logout phải morph sang Exit page

Đây là một case nested khác rất quan trọng.

Hiện tại:

```text
power_ctl.sh logout
→ exit.sh
```

Trong Hikai không nên để process này mở một layer mới trên layer Power.

Thay vào đó Power UI xử lý navigation:

```text
Power
→ click Logout
→ Logout button morphs
→ Exit confirmation/report page
```

Không gọi:

```text
power_ctl.sh logout
```

từ Hikai Power UI.

Exit child page gọi trực tiếp headless backend:

```text
session_exit_ctl.sh process-report
session_exit_ctl.sh execute
```

Classic vẫn giữ nguyên:

```text
power_ctl logout
→ exit.sh
→ exit_rofi.sh
```

Không phá compatibility Classic.

---

# 18. Exit page

Geometry:

```text
50vw × 60vh
```

Không render toàn bộ process report thành hàng loạt action button như Rofi.

Native layout tốt hơn:

```text
┌──────────────────────────────────┐
│ Exit Session                     │
│                                  │
│ Active Processes                 │
│ ┌──────────────────────────────┐ │
│ │ scrollable process report    │ │
│ │ ...                          │ │
│ └──────────────────────────────┘ │
│                                  │
│ [ Cancel ]      [ Exit Anyway ] │
└──────────────────────────────────┘
```

Data:

```text
session_exit_ctl.sh process-report
```

Actions:

```text
Cancel
→ if child of Power: reverse morph → Power
→ if root exit.sh: close layer

Exit Anyway
→ session_exit_ctl.sh execute
```

Destructive action must require explicit click/Enter on confirmation button.

No auto-execute from opening the layer.

---

# 19. Morph source lifecycle

Do not animate actual Layout-controlled item dimensions directly if it causes relayout.

Use proxy pattern:

```text
actual button
↓ clicked
hide/freeze visual
↓
ActionMenuMorphProxy copies geometry
↓
proxy animation
↓
incoming layer owns final rendering
```

This prevents neighboring buttons moving during morph.

This follows HakuSpace rule:

> ordinary interactive motion must not change layout.

---

# 20. Content transition during morph

Avoid cheap:

```text
opacity A 1→0
opacity B 0→1
```

without spatial relation.

Recommended timeline:

```text
0.00
button press finishes

0.00–0.55
proxy expands from selected button
outgoing non-selected controls fade slightly

0.40–1.00
incoming header/content appears

1.00
proxy hands final surface to incoming page
phase = ready
```

For reverse:

```text
incoming child content fade
surface contracts toward parent seed button
parent page appears underneath
proxy lands exactly at button geometry
button becomes visible
```

No visible geometry pop at handoff.

---

# 21. Keyboard contract

At root:

```text
Up/Down or Left/Right depending layout
Enter/Space activate
Escape close layer
```

At child:

```text
navigation keys
Enter activate
Escape reverse morph / Back
```

Power horizontal:

```text
Left/Right
```

List menus:

```text
Up/Down
```

After Back, restore focus to the exact button that opened child.

---

# 22. Mouse contract

- hover uses shared button morph;
- click selected item activates;
- outside click closes whole Action Layer;
- outside click disabled during page morph;
- no click-through while modal layer is logically open;
- release input mask only after close animation finishes.

---

# 23. Do NOT merge with existing Picker

`modules/picker/Picker.qml` serves a different purpose:

```text
stdin items
→ generic selector
→ FIFO response
```

Keep it for `haku_pick.sh` workflows.

Action Layer is for rich application flows:

```text
record
power
exit
theme
...
```

Do not turn Picker into one giant conditional component.

Do not migrate Wallpaper/HakuMenu/Notifications into Action Layer.

They already have specialized native surfaces.

---

# 24. Scope after first four flows

Once shared layer is stable, audit remaining Classic interactive facades:

```text
clipboard_menu.sh
shell_switcher.sh
gen_shortcut.sh
niri_animation_switcher.sh
taskbar_manager.sh
waybar_manager.sh
rofi_theme_switcher.sh
```

Classify each:

```text
native Action Layer
keep specialized native UI
Classic-only
generic Picker
```

Do not mass-convert everything before the shared architecture proves itself with:

```text
record
change_theme
shutdown
exit
```

---

# 25. Implementation sequence / atomic batches

## A0 — Baseline audit

No functional change.

Document current:

```text
option-menu.rasi = 40% × 40%
exit = 50% × 60%
shutdown horizontal = 70% × 140px
shutdown vertical = 120 × 400px
```

Confirm Classic behavior.

Run baseline checks.

---

## A1 — Shared state + empty Action Layer

Add:

```text
UiState actionMenu ownership
ActionMenuPanel
ActionMenuSurface
IPC actionMenu
```

Temporary debug page only.

Acceptance:

```text
IPC open
→ centered layer

Escape/outside
→ animated close

other UiState panels
→ mutually exclusive
```

No real feature migration yet.

---

## A2 — Opening/closing motion

Implement:

```text
circular center reveal
fade + zoom close
scrim
input lifecycle
```

Acceptance:

- no pop;
- no visible resize jump;
- no input leak;
- opening resembles Wallpaper center circular reveal;
- closing is visibly slower/smoother than ordinary button motion.

---

## A3 — Shared buttons

Wrap existing:

```text
MorphButton
ButtonMotion
HAnimation
```

Create standard:

```text
icon
label
secondary label
danger state if needed
focus
keyboard activation
```

No feature logic.

---

## A4 — Page morph engine

Implement:

```text
page stack
forward morph
reverse morph
morph proxy
focus restore
different geometry profiles
same-geometry morph
```

Use dummy pages first.

Critical acceptance:

```text
Page A 40×40
→ Page B 40×40

must visibly morph
```

and:

```text
Power 70%×140
→ Exit 50%×60%

must smoothly morph geometry
```

No destroy/recreate flash.

---

## A5 — Record migration

Route Hikai `record.sh` into Action Layer.

Implement:

```text
mode page
mic source child
backend Process
error state
success close
```

Acceptance:

```text
Only Sound → start
No Sound → start
Mic+Sound → child morph → source → start
Escape source → reverse morph
Classic unchanged
```

---

## A6 — Theme migration

Route Hikai `change_theme.sh`.

Implement root +:

```text
Font
Font Size
Accent
Rofi Theme
Waybar Theme where backend policy allows
```

This is the main multi-page stress test.

Acceptance:

```text
root → child → root
```

must morph every time.

Theme reload must not destroy current layer/morph state.

---

## A7 — Exit migration

Hikai `exit.sh`:

```text
process-report
scrollable content
cancel
execute
```

Classic unchanged.

---

## A8 — Power migration + Power→Exit morph

Hikai `shutdown.sh` → Power page.

Logout:

```text
Power
→ Exit page
```

inside same Action Layer.

This is a required cross-flow morph test.

---

## A9 — Runtime hardening

Test:

```text
rapid open/close
rapid Escape
open while closing
same facade invoked twice
different facade invoked while open
backend Process failure
Quickshell reload
theme hot reload
screen removal if possible
fractional scale
fullscreen application
```

No stuck fullscreen input mask.

No orphan morph proxy.

No stale `activePanel`.

---

## A10 — Docs + follow-up audit

Update:

```text
QUICKSHELL_STYLE.md
QUICKSHELL_TESTING.md
HAKUSPACE_QUICKSHELL_PLAN.md
src/core/README.md if routing contract changes
```

Create migration table for remaining Rofi surfaces.

---

# 26. Required regression matrix

## Classic

Must remain equivalent:

```text
record.sh
shutdown.sh
shutdown.sh -v
exit.sh
change_theme.sh
```

all still use their existing Rofi presentation.

No Classic QML dependency.

---

## Hikai

### Record

```text
idle → record menu
recording → stop
mode → mic child morph
Back
start
```

### Theme

```text
Theme root
→ Font
→ Back

Theme root
→ Font Size
→ apply
→ reverse morph

Theme root
→ Accent
→ apply
→ reverse morph
```

### Power

```text
open
keyboard navigation
outside click
Escape
action
Logout → Exit morph
```

### Exit

```text
standalone exit.sh
Power → Exit
process report
cancel
execute
```

---

# 27. Quality gates

Every batch:

```bash
git diff --check

python3 scripts/qml_syntax_check.py \
    $(find src/home/.config/quickshell -name '*.qml')

scripts/precommit_check.sh
```

Also inspect:

```text
git status --short
git diff
```

No debug logging left behind unless gated.

No Rofi dependency introduced into backend.

No duplicate basename under `src/core`.

---

# 28. Architectural non-negotiables

Gemini must not:

1. Rewrite Classic Rofi UI unnecessarily.
2. Put UI/picker logic in `backend/`.
3. Call Rofi from Hikai migrated flows.
4. Duplicate power/theme/record mutations in QML.
5. Spawn a new PanelWindow for each submenu.
6. Implement child navigation as instant Loader swap.
7. Implement child navigation as pure crossfade.
8. Close parent layer before opening child layer.
9. Use a second fullscreen overlay for the child.
10. Repurpose generic Picker into the Action Menu framework.
11. Let button hover change Layout geometry.
12. Release fullscreen input before close animation finishes.
13. Hardcode shell commands supplied by arbitrary IPC input.
14. Parse human labels as backend action IDs.

---

# 29. Definition of DONE

Shared Action Layer is DONE only when this sequence works visibly as one continuous object:

```text
change_theme.sh
    ↓
circular center reveal
    ↓
Theme root
    ↓ click Change Font Size
button expands/morphs
    ↓
Font Size page
    ↓ apply / Back
reverse morph
    ↓
Theme root
    ↓ Escape
fade + zoom out
    ↓
desktop
```

And:

```text
shutdown.sh
    ↓
Power layer
    ↓ Logout
Logout button morphs
    ↓
Exit report layer
    ↓ Cancel
reverse morph
    ↓
Power layer
```

And:

```text
record.sh
    ↓
Record Mode
    ↓ Micro + Sound
button morphs
    ↓
Mic Source
```

Nếu ba flow này không có continuity rõ ràng thì shared layer chưa đạt, kể cả functional backend đã hoạt động.