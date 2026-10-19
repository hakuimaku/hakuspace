# HAKUMENU Dual-Presentation Standardization Plan

## 0. Mục tiêu

Chuẩn hoá HakuMenu theo hướng **một logic chung, hai presentation/style khác nhau**.

Không redesign hoặc thay thế HakuMenu hiện tại.

Giữ nguyên style cũ:

```text
topFlare
```

và bổ sung style mới:

```text
dockFloating
```

Kiến trúc mục tiêu:

```text
                    HakuMenu
                       │
               shared behavior
                       │
        ┌──────────────┴──────────────┐
        │                             │
     topFlare                    dockFloating
        │                             │
 existing HakuMenu               Dock App Menu
 top-edge trigger                bottom-center
 existing FlareMorph             floating surface
 existing layout                 Temp Note-style morph
 existing SafeZone               bottom controls
```

Nguyên tắc quan trọng nhất:

```text
topFlare before refactor
==
topFlare after refactor
```

Nếu refactor để thêm `dockFloating` gây regression `topFlare`, chưa được coi là đạt.

---

# 1. Scope

## 1.1 Giữ nguyên `topFlare`

Không thay đổi:

- top-center 20% trigger hiện tại;
- `FlareMorph` hiện tại;
- geometry hiện tại;
- open/close animation hiện tại;
- SafeZone hiện tại;
- keyboard behavior hiện tại;
- search behavior hiện tại;
- General / Drun / Theme logic hiện tại;
- tabs/search placement hiện tại;
- IPC hiện tại;
- launcher shortcut hiện tại;
- fullscreen behavior hiện tại;
- multi-monitor semantics hiện tại.

Không remove:

```text
FlareMorph
top trigger
top safe-zone
existing bounce/morph tokens
```

## 1.2 Chỉ thêm `dockFloating`

`dockFloating` là presentation mới chỉ dùng khi HakuMenu được gọi từ:

```text
DockBar → App Menu
```

Style này:

- floating ở bottom-center;
- không dính cạnh màn hình;
- mở từ vị trí App Menu item;
- open/close motion giống Temp Note ở Sidebar;
- tabs + search nằm phía dưới;
- Dock giữ visible trong thời gian menu mở;
- dùng SafeZone riêng cho Dock → HakuMenu handoff.

---

# 2. Kiến trúc tổng thể

HakuMenu không nên bị duplicate toàn bộ logic.

Mục tiêu:

```text
HakuMenu state / content / navigation
               │
        shared logic layer
               │
     ┌─────────┴─────────┐
     │                   │
 topFlare             dockFloating
```

Ưu tiên tách theo composition thay vì rải:

```text
if (style === "dockFloating")
```

khắp component.

Recommended structure:

```text
HakuMenuPanel.qml
├── HakuMenuContent.qml
├── HakuMenuTopFlare.qml
└── HakuMenuDockFloating.qml
```

hoặc equivalent nếu tree thực tế phù hợp hơn.

---

# 3. Shared HakuMenu content

Tách phần logic/content có thể chia sẻ vào:

```text
components/hakumenu/HakuMenuContent.qml
```

Nó chịu trách nhiệm:

```text
mode
query
prefix parsing
selected index
keyboard navigation
search state
GeneralList
DrunList
ThemeList
activation
```

Giữ nguyên semantics hiện tại:

```text
General
Drun
Theme
```

Search prefixes:

```text
>  → General
~  → Theme
normal text → Drun
```

Keyboard:

```text
Left / Right
→ switch tab

Up / Down
→ selection

Enter
→ activate

Escape
→ close
```

Không rewrite list models trong task này.

---

# 4. Presentation contract trong UiState

Mở rộng:

```text
services/UiState.qml
```

Thêm:

```qml
property string hakuMenuStyle: "topFlare"
property var hakuMenuAnchorRect: null
```

Recommended API:

```qml
openHakuMenu(screenName, mode, style, anchorRect)
toggleHakuMenu(screenName, mode, style, anchorRect)
closeHakuMenu()
closeHakuMenuIfScreen(screenName)
```

Backward compatibility:

```text
style omitted
→ "topFlare"

anchor omitted
→ null
```

Tức là caller cũ:

```qml
UiState.openHakuMenu(screenName, mode)
```

vẫn hoạt động như trước.

Không ép toàn bộ caller cũ phải truyền style mới.

---

# 5. `topFlare` presentation

Tách hoặc giữ nguyên implementation hiện tại trong:

```text
HakuMenuTopFlare.qml
```

Nó tiếp tục dùng:

```text
existing top trigger
existing FlareMorph
existing SafeZone
existing geometry
existing controls placement
```

Không đổi tabs/search xuống dưới cho style này.

Layout cũ vẫn giữ:

```text
[ tabs ][ search ]
[                ]
[     content    ]
```

`topFlare` là compatibility presentation.

---

# 6. `dockFloating` presentation

Style mới:

```text
HakuMenuDockFloating.qml
```

Final layout:

```text
╭──────────────────────────────╮
│                              │
│        menu content          │
│                              │
│                              │
├──────────────────────────────┤
│ General   Drun   Theme       │
│ Search...                    │
╰──────────────────────────────╯

             gap

        ┌───────────┐
        │  DockBar  │
        └───────────┘
```

Final state:

```text
floating
bottom-center
detached from screen edge
detached from DockBar
```

Không dùng top-edge `FlareMorph`.

Không dùng top trigger.

Không dùng top SafeZone corridor.

---

# 7. Dock App Menu integration

Current Dock App Menu phải trở thành launcher cho:

```text
style = "dockFloating"
mode = "drun"
```

Flow:

```text
click App Menu
→ capture anchor rect
→ UiState.toggleHakuMenu(
      screenName,
      "drun",
      "dockFloating",
      anchorRect
  )
```

Nếu click lần hai khi cùng HakuMenu đang mở:

```text
→ close
```

Không mở duplicate HakuMenu.

---

# 8. Anchor contract

Dock phải truyền vị trí thật của App Menu item.

Normalized shape:

```js
{
    x: ...,
    y: ...,
    width: ...,
    height: ...
}
```

Coordinate space:

```text
screen-local coordinates
```

Không hard-code:

```text
App Menu X
Dock left
screen center
```

Phải derive từ item thực tế.

Codex phải verify trên:

```text
single monitor
multi-monitor
different icon sizes
different Dock width
bottom inset
scrollable/crowded Dock nếu có
```

---

# 9. Dock visibility lease

Chỉ `dockFloating` mới giữ Dock visible.

Concept trong `DockBar.qml`:

```text
hakuMenuDockLease =
    UiState.activePanel === "hakumenu"
    && UiState.hakuMenuStyle === "dockFloating"
    && UiState.hakuMenuScreenName === modelData.name
```

Dock shown logic:

```text
enabled
&& (
    always
    || revealed
    || hakuMenuDockLease
)
```

Flow:

```text
open dockFloating HakuMenu
→ Dock remains visible

use HakuMenu
→ Dock remains visible

close HakuMenu
→ Dock returns to normal visibility policy
```

`topFlare` không tạo lease.

---

# 10. `dockFloating` motion language

Open/close animation phải mirror Temp Note ở Sidebar.

Không reuse ceiling Flare motion của `topFlare`.

Core state:

```qml
property real morphProgress: 0
```

Animation:

```text
0 → 1 open
1 → 0 close
```

Phải reversible.

Nếu:

```text
open
→ progress 0.6
→ close
```

thì close phải bắt đầu từ:

```text
0.6
```

không reset.

Nếu:

```text
closing
→ click App Menu lại
```

thì animation reverse từ current progress.

---

# 11. Remaining-distance duration

Giống Temp Note:

```text
duration =
    baseDuration
    * abs(targetProgress - currentProgress)
```

Mục đích:

```text
partial open/close
```

không bị animation quá chậm hoặc quá nhanh.

Không tạo một animation instance mới cho từng direction nếu không cần.

---

# 12. Morph geometry

## Seed

Seed lấy từ:

```text
App Menu anchorRect
```

Seed center:

```text
anchorRect center
```

Seed size:

```text
gần visual size của App Menu item
```

## Final

Final HakuMenu:

```text
horizontal center of screen
bottom above Dock + floating gap
stable target width
stable target height
```

## Interpolation

Concept:

```text
x =
    seedX
    + (finalX - seedX) * morphProgress

y =
    seedY
    + (finalY - seedY) * morphProgress

width =
    seedWidth
    + (finalWidth - seedWidth) * morphProgress

height =
    seedHeight
    + (finalHeight - seedHeight) * morphProgress
```

Radius cũng morph:

```text
seed capsule
→ final floating card radius
```

---

# 13. Temp Note-style content reveal

Không show full content ngay từ first frame.

Dùng derived progress:

```text
revealProgress
contentProgress
interactionReady
```

Concept:

```text
0.0 ───────── 1.0 morph

chassis:
████████████████

content:
      ██████████
```

Content chỉ bắt đầu fade/reveal khi chassis đủ lớn.

Keyboard interaction chỉ enable khi:

```text
interactionReady === true
```

---

# 14. Optional temporary Flare neck

Có thể thêm transition decoration:

```text
App Menu
   │
   │ temporary neck
   ▼
floating card
```

Nhưng đây chỉ là transition visual.

Final state:

```text
NO neck
NO attachment
NO bottom flare connection
```

Nếu cần component riêng:

```text
components/hakumenu/HakuMenuDockMorphNeck.qml
```

Không sửa shared Flare library nếu làm tăng regression risk.

Priority:

```text
correct morph
> correct lifecycle
> optional neck polish
```

---

# 15. Bottom controls — chỉ cho `dockFloating`

`topFlare` giữ layout cũ.

`dockFloating` dùng:

```text
[ content ]
[         ]
[ tabs    ]
[ search  ]
```

hoặc nếu width đủ:

```text
[ content                  ]
[ General Drun Theme | Search ]
```

Ưu tiên giữ visual semantics hiện tại trước:

```text
tabs
search
```

chỉ chuyển xuống footer.

Không redesign tabs/search trong cùng task nếu chưa cần.

---

# 16. Recommended footer layout

Stable:

```text
footerHeight
footerTop
```

Content region:

```text
top = innerPad
bottom = footerTop - gap
```

Footer:

```text
modeSwitcher
searchBox
```

Theme state region cũng phải dừng trước footer.

Không để:

```text
ThemeList
state controls
search
```

overlap.

---

# 17. Stable `dockFloating` chassis

Style mới nên có stable width giữa tabs.

Không để:

```text
General
→ width A

Drun
→ width B

Theme
→ width C
```

làm card nhảy trái/phải.

Dùng một width đủ chứa mode lớn nhất.

Có thể derive từ current HakuMenu maximum width contract.

Height cũng nên stable hoặc chỉ đổi khi thực sự cần.

---

# 18. Search/focus lifecycle

`topFlare` giữ nguyên focus lifecycle hiện tại.

`dockFloating`:

```text
open
→ chassis morph
→ interactionReady
→ searchInput.forceActiveFocus()
```

Close:

```text
searchInput.focus = false
→ reverse morph
```

Reopen mid-close:

```text
reverse
→ focus lại khi interactionReady
```

Không force focus ngay frame đầu nếu surface chưa sẵn sàng.

---

# 19. SafeZone cho `dockFloating`

Dùng shared:

```text
SafeZoneController
SafeZoneGeometry
```

Không tạo timer riêng.

Zones:

```text
1. Dock App Menu anchor
2. corridor anchor → floating card
3. current animated card bounds
4. target card bounds
5. temporary neck envelope
```

Không dùng top-edge trigger zone.

Dock lease giữ Dock visible.

SafeZone chịu trách nhiệm HakuMenu pointer lifecycle.

---

# 20. `topFlare` SafeZone

Không thay đổi.

Current:

```text
top trigger
top corridor
Flare/menu geometry
```

giữ nguyên.

Không cố unify hai SafeZone geometry nếu abstraction làm topFlare regression.

Hai presentation có thể share controller nhưng khác zone inputs.

---

# 21. Outside-click behavior

Không thêm fullscreen modal blocker chỉ vì có `dockFloating`.

Giữ HakuSpace non-modal model.

Close mechanisms:

```text
App Menu toggle
Escape
SafeZone exit
activation action
another transient panel taking ownership
```

Transparent outside area phải click-through.

---

# 22. Multi-monitor semantics

Dock App Menu trên output A:

```text
→ dockFloating HakuMenu on A
→ anchor from A
→ final card centered on A
→ Dock A gets lease
```

Output B:

```text
unchanged
```

Nếu click App Menu trên B khi A đang mở:

```text
transfer ownership A → B
```

Không để ghost HakuMenu trên A.

---

# 23. IPC compatibility

Caller cũ:

```text
hakumenu
launcher.open("drun")
```

vẫn mặc định:

```text
style = "topFlare"
```

Không thay đổi UX IPC cũ.

Có thể thêm sau:

```text
hakumenu.openDock
```

nhưng không cần cho milestone này.

---

# 24. Presentation ownership

`UiState` phải lưu:

```text
activePanel
hakuMenuScreenName
hakuMenuMode
hakuMenuStyle
hakuMenuAnchorRect
```

Khi mở:

```text
topFlare
```

thì:

```text
hakuMenuAnchorRect = null
```

Khi mở:

```text
dockFloating
```

thì:

```text
hakuMenuAnchorRect = Dock App Menu rect
```

Close phải clear transient anchor state.

---

# 25. Proposed files

Recommended:

```text
src/home/.config/quickshell/hakuspace/
├── components/
│   ├── HakuMenuPanel.qml
│   ├── DockBar.qml
│   └── hakumenu/
│       ├── HakuMenuContent.qml
│       ├── HakuMenuTopFlare.qml
│       ├── HakuMenuDockFloating.qml
│       └── HakuMenuDockMorphNeck.qml   # optional
│
├── services/
│   ├── UiState.qml
│   └── HAnimation.qml
│
└── shell.qml
```

Không bắt buộc đúng naming nếu codebase hiện tại yêu cầu khác.

Architecture mới là requirement; filename không phải contract cứng.

---

# 26. Animation tokens

Không thay token cũ của `topFlare`.

Bổ sung riêng cho dock floating hoặc dùng generic floating tokens.

Recommended:

```text
floatingPanelOpenDuration
floatingPanelCloseDuration
floatingPanelOpenCurve
floatingPanelCloseCurve
```

Initial values có thể alias Temp Note tokens:

```text
sidebarToolOpenDuration
sidebarToolCloseDuration
sidebarToolOpenCurve
sidebarToolCloseCurve
```

Mục tiêu:

```text
Temp Note
dockFloating HakuMenu
```

cùng motion family.

Không bắt topFlare dùng các token này.

---

# 27. Execution plan

## H0 — Baseline current HakuMenu

Record current:

```text
top trigger
FlareMorph
General
Drun
Theme
search
prefixes
keyboard
SafeZone
IPC
multi-monitor
fullscreen
```

Deliverable:

```text
docs/task/HAKUMENU_DUAL_STYLE_BASELINE.md
```

Gate:

```text
phải biết topFlare hiện tại pass gì
trước khi refactor
```

---

## H1 — Add presentation contract

Implement:

```text
UiState.hakuMenuStyle
UiState.hakuMenuAnchorRect
new optional API args
```

Default:

```text
topFlare
```

Không thay visual.

Acceptance:

```text
all old callers still open topFlare
old IPC unchanged
old trigger unchanged
```

---

## H2 — Extract shared content

Tách:

```text
search
tabs/mode state
list content
keyboard logic
```

khỏi chassis nếu cần.

Goal:

```text
topFlare presentation
→ same behavior before/after extraction
```

Không build dockFloating hoàn chỉnh ở batch này.

Acceptance blocker:

```text
topFlare regression
→ stop
```

---

## H3 — Stabilize `topFlare`

Physical/runtime test:

```text
top trigger
open
close
search
prefix
tabs
General
Drun
Theme
Escape
SafeZone
fullscreen
multi-monitor
IPC
```

Required:

```text
before == after
```

Chỉ khi pass mới tiếp tục.

---

## H4 — Dock anchor + lease

Implement:

```text
Dock App Menu anchor capture
dockFloating call
Dock visibility lease
```

Temporary dockFloating placeholder card đủ để verify geometry.

Acceptance:

```text
correct screen-local anchor
correct output
Dock stays shown
second App Menu click toggles close
topFlare does not affect Dock lease
```

---

## H5 — DockFloating chassis

Implement:

```text
bottom-center floating surface
stable width
stable height
no exclusive space
click-through outside
```

No final motion polish yet.

Acceptance:

```text
final position correct
not attached to screen edge
not attached to Dock
works with Dock autohide
works with Dock always
```

---

## H6 — Temp Note-style morph

Implement:

```text
morphProgress
seed geometry
final geometry
remaining-distance duration
reverse close
reverse reopen
delayed content reveal
```

Acceptance:

```text
App Menu → floating card
floating card → App Menu
no pop
no reset mid-animation
```

---

## H7 — Bottom tabs + search

Only `dockFloating`.

Move:

```text
tabs
search
```

to footer.

Keep `topFlare` controls unchanged.

Acceptance:

```text
General correct
Drun correct
Theme correct
no overlap
stable card geometry
```

---

## H8 — SafeZone / focus hardening

Implement dock-specific zones:

```text
anchor
corridor
card
temporary neck
```

Acceptance:

```text
Dock → menu pointer travel
typing
Escape
pointer exit
re-enter grace
launch action
```

No accidental close.

---

## H9 — Optional morph neck / visual polish

Add temporary connector only if H5–H8 are stable.

Acceptance:

```text
appears during transition
disappears before final state
no clipping
no giant flare artifacts
```

Do not block milestone if neck proves brittle.

---

## H10 — Multi-monitor / fullscreen / regression

Test:

```text
Hyprland
Niri
MangoWM
```

where practical.

Matrix:

```text
topFlare
dockFloating
single monitor
multi-monitor
fullscreen
Dock autohide
Dock always
Dock disabled
IPC topFlare
```

Verify no cross-style state leak.

---

## H11 — Cleanup + report

Remove:

```text
debug anchor rectangles
temporary placeholder card
console logs
dead branches
duplicate content
```

Run:

```text
git diff --check
QML syntax checks
scripts/precommit_check.sh
Dock regression tests
HakuMenu tests
```

Final:

```text
docs/task/HAKUMENU_DUAL_PRESENTATION_REPORT.md
```

---

# 28. Runtime acceptance matrix

## topFlare regression

```text
[ ] top-center trigger unchanged
[ ] existing FlareMorph unchanged
[ ] existing open animation unchanged
[ ] existing close animation unchanged
[ ] tabs/search remain in original location
[ ] General works
[ ] Drun works
[ ] Theme works
[ ] search prefixes work
[ ] keyboard navigation works
[ ] Escape works
[ ] SafeZone works
[ ] IPC still opens topFlare
[ ] fullscreen works
[ ] multi-monitor works
```

## dockFloating

```text
[ ] Dock App Menu opens dockFloating
[ ] App Menu second click closes it
[ ] default mode is Drun

[ ] correct App Menu anchor
[ ] correct monitor
[ ] final position bottom-center
[ ] final surface is floating
[ ] no screen-edge attachment
[ ] no exclusive zone

[ ] Dock stays visible while open
[ ] Dock returns to normal policy after close

[ ] open morph starts from App Menu
[ ] close morph returns to App Menu
[ ] reopen mid-close reverses smoothly
[ ] remaining-distance timing correct
[ ] content reveal delayed correctly

[ ] tabs are at bottom
[ ] search is at bottom
[ ] General content correct
[ ] Drun content correct
[ ] Theme content correct
[ ] no footer overlap

[ ] search autofocus works
[ ] keyboard works
[ ] Escape works

[ ] Dock → HakuMenu SafeZone works
[ ] pointer exit works
[ ] outside remains click-through

[ ] output A anchor/output correct
[ ] output B anchor/output correct
[ ] ownership transfer leaves no ghost panel

[ ] fullscreen works
[ ] Dock autohide works
[ ] Dock always works
```

## Cross-style

```text
[ ] opening topFlare after dockFloating works
[ ] opening dockFloating after topFlare works
[ ] no stale anchorRect
[ ] no stale Dock lease
[ ] no duplicate HakuMenu
[ ] no style-specific state leakage
```

---

# 29. Explicitly out of scope

Do not mix into this task:

```text
remove topFlare
replace top trigger
rewrite Drun
rewrite General
rewrite Theme
new search backend
new launcher model
new Dock pin logic
Dock hover redesign
Notification Center redesign
global Flare framework rewrite
new panel framework
```

This task adds **one new HakuMenu presentation**, not a new launcher architecture.

---

# 30. Definition of Done

Task DONE when:

```text
topFlare remains fully compatible

dockFloating exists as a second presentation

Dock App Menu opens dockFloating
Dock visibility lease works

dockFloating is bottom-center + floating

Temp Note-style reversible morph works
tabs + search are bottom-only in dockFloating

shared HakuMenu logic is reused
no duplicated launcher behavior

SafeZone/focus stable
multi-monitor stable
fullscreen stable

old IPC/callers remain topFlare by default

Dock regression suite passes
HakuMenu regression suite passes
precommit passes
```

Priority:

```text
preserve topFlare
> shared logic correctness
> style ownership
> Dock anchor correctness
> reversible motion
> SafeZone/focus
> bottom layout
> visual polish
```
