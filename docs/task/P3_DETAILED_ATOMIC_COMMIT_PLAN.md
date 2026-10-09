# HakuSpace P3 — Detailed Atomic Commit Execution Plan V2
## Based on the 2026-10-08 Dashboard / Navigation / Sidebar / Settings / HakuMenu / Wallpaper mockups

> Rule: **one accepted part = one commit**.
>
> This file is intentionally execution-oriented. Product/style semantics live in:
>
> - `QUICKSHELL_STYLE_P3_MOCKUP_LOCKED.md`
> - `HAKUSPACE_QUICKSHELL_PLAN_P3_MOCKUP_LOCKED.md`

---

# 0. Mandatory loop

For every numbered task:

```text
1. reset/confirm last accepted commit
2. implement only the named task
3. run static checks
4. run the focused runtime probe
5. capture one useful screenshot where visual
6. review
7. commit
8. confirm working tree state
9. continue
```

Never carry an unaccepted visual experiment into the next task.

Recommended report:

```text
Task:
Base commit:
Files changed:
Diff stat:
Static:
Runtime:
Screenshot:
Known limitations:
Ready to commit:
```

After approval:

```text
Committed:
Working tree:
Next task:
```

---

# 1. Static gate

Before every product commit:

```bash
git diff --check
python3 scripts/qml_syntax_check.py $(find src/home/.config/quickshell -name '*.qml')
scripts/precommit_check.sh
```

Run `qmllint` where supported.

---

# 2. Ordered commit list

## Foundation

### A1
Remove abandoned center-collar and old Wallpaper dual-front remnants.

Commit:

```text
p3(baseline): remove superseded visual experiments
```

### A2
Lock continuous RoundedScreen.

Commit:

```text
p3(frame): lock RoundedScreen chassis
```

### A3
Expose shared per-output frame bounds.

Commit:

```text
p3(geometry): expose shared frame bounds
```

### A4
Add/reuse bounded frame attachment helper.

Commit:

```text
p3(geometry): standardize frame attachment
```

---

## Navigation

### N1
Navigation lifecycle/state only. No final radial styling yet.

Commit:

```text
p3(navigation): add explicit navigation state model
```

### N2
Three-region radial visual from `navigation.png`.

Commit:

```text
p3(navigation): implement three-region radial visual
```

Gate:
- one screenshot;
- verify Dashboard/Sidebar/Settings labels/regions;
- no HakuMenu state mixed in.

---

## Dashboard

### D1
Dashboard shell + reserved blank area only.

Commit:

```text
p3(dashboard): add mockup-locked dashboard shell
```

### D2
Avatar visual + persistent selection.

Commit:

```text
p3(dashboard): add persistent dashboard avatar
```

### D3
Clock card.

Commit:

```text
p3(dashboard): add clock card
```

### D4
MPRIS controls + thumbnail card.

Commit:

```text
p3(dashboard): add mpris control card
```

### D5
Calendar + month controls.

Commit:

```text
p3(dashboard): add calendar card
```

### D6
ROM/RAM/CPU/GPU monitor card.

Commit:

```text
p3(dashboard): add monitor information card
```

### D7
Dashboard layout/radius/spacing integration.

Commit:

```text
p3(dashboard): finalize mockup layout
```

Gate:
- compare only against `dashboard.png`;
- do not add extra widgets.

---

## Sidebar

### S1
Pointer-state union / anti-flicker hover handoff.

Commit:

```text
p3(sidebar): add stable hover handoff
```

### S2
Rounded left Sidebar + circular dots + plus.

Commit:

```text
p3(sidebar): implement mockup visual
```

### S3
Only if specified actions exist: wire them.

Commit:

```text
p3(sidebar): wire specified sidebar actions
```

Unknown actions are not blockers; leave them explicit stubs.

---

## Settings

### T1
Settings stub surface exactly as current P3 scope.

Commit:

```text
p3(settings): add hikai settings stub
```

Gate:
- centered;
- radius consistency;
- `still working rn...`;
- no real settings implementation.

---

## HakuMenu shell

### H1
Center-triggered lifecycle + focus/input cleanup.

Commit:

```text
p3(hakumenu): add center-triggered lifecycle
```

### H2
Physical centering + equal-radius geometry.

Commit:

```text
p3(hakumenu): lock centered equal-radius geometry
```

Gate:
- physical center X and height remain stable;
- General may use the approved 95%-of-standard width while Drun/Theme use standard width;
- tab-to-tab width changes morph with the dedicated resize curve, not the shell-open bounce.
- HakuMenu uses synchronized split layers: Top = visual-only Flare/background, Overlay = rounded body/content/input/focus.
- Fullscreen clients may cover the Top visual shell, but Overlay content remains visible and usable without geometry drift.

### H3
General/Drun/Theme tab shell.

Commit:

```text
p3(hakumenu): add general drun theme tabs
```

Gate:
- state area hidden except Theme;
- no TopBar-center silhouette redesign.

### H4
Shared Hikai interactive-motion foundation and first migration.

Commits:

```text
p3(motion): add shared button morph primitives
p3(motion): migrate hakumenu tray and notifications
```

Gate:
- `ButtonMotion`, `MorphButton`, `MorphIconButton`, `SelectionPill` exist as reusable primitives;
- HakuMenu tabs use one moving selection pill;
- HakuMenu General/Drun rows and search focus have no instant interactive colour jumps;
- Tray rows/Back and Notification action buttons use the same motion profile;
- hover/press motion does not alter layout size;
- ordinary buttons do not reuse HakuMenu's bouncy open curve.

---

## HakuMenu General

### G1
Audit `hm_general.sh` output.

If no code change: report only.

If contract hardening is needed:

```text
p3(hakumenu): stabilize hm_general data contract
```

### G2
General parser/model.

Commit:

```text
p3(hakumenu): add general data model
```

### G3
General list rendering.

Commit:

```text
p3(hakumenu): render general list
```

---

## HakuMenu Drun

### R1
Application model/search source.

Commit:

```text
p3(hakumenu): add drun application model
```

### R2
Keyboard/pointer launch interaction.

Commit:

```text
p3(hakumenu): add drun interaction
```

### R3
Route Hikai launcher facade/IPC to Drun tab.

Commit:

```text
p3(launcher): route hikai launcher to hakumenu drun
```

Classic must remain unchanged.

---

## HakuMenu Theme

### M1
Theme-only right state region.

Commit:

```text
p3(hakumenu): add theme state-region layout
```

### M2
Theme stub content/status.

Commit:

```text
p3(hakumenu): mark theme tab as stub
```

No theme engine implementation.

---

## Wallpaper carousel

### W1
Audit existing wallpaper model/action path.

No commit unless real code needs normalization.

### W2
Fixed physical center selection slot.

Commit:

```text
p3(wallpaper): add fixed center selection slot
```

### W3
Stacked/overlapping left-right items. No big panel background.

Commit:

```text
p3(wallpaper): add stacked side carousel
```

### W4
Arrow + wheel navigation, one `selectedIndex`.

Commit:

```text
p3(wallpaper): add carousel navigation
```

### W5
Enter applies selected item.

Commit:

```text
p3(wallpaper): apply selected item on enter
```

### W6
Thumbnail/performance hardening.

Commit:

```text
p3(wallpaper): harden carousel thumbnail loading
```

Gate:
- compare against `wallpaper-change.png`;
- old dual-front Flare design must not return.

---

## Existing shell polish

### P1
Tooltip → RoundedScreen attachment.

```text
p3(anchor): attach tooltips to rounded frame
```

### P2
Tray → RoundedScreen attachment.

```text
p3(anchor): attach tray menu to rounded frame
```

### P3
Notification popup → RoundedScreen attachment.

```text
p3(anchor): attach notification popup to rounded frame
```

### P4
Notification Center attachment.

```text
p3(anchor): attach notification center to rounded frame
```

### P5
Notification Center spacing / taller body / Clear accent treatment.

```text
p3(notifications): polish center spacing and clear action
```

### P6
OSD attachment.

```text
p3(anchor): attach level osd to rounded frame
```

### P7
Compact OSD + stable percentage slot + physical centering. Icon, track and percentage must be optically centered as one group inside the capsule.

```text
p3(osd): stabilize compact centered layout
```

---

## Remaining migration

### X1+
Power / Clipboard / other remaining Hikai direct rofi paths.

One feature/caller family per commit.

Never bundle all migration into one commit.

---

# 3. Visual review gates

Use only one of:

```text
PASS
METRIC_TUNE_ONLY
TOPOLOGY_WRONG
FUNCTIONAL_FAIL
```

Rules:

### PASS
Commit immediately.

### METRIC_TUNE_ONLY
- freeze topology;
- tune at most 3 metrics in the next pass;
- no unrelated files.

### TOPOLOGY_WRONG
- stop;
- compare to the specific mockup;
- revise the local component plan before editing again.

### FUNCTIONAL_FAIL
- reproduce;
- fix behaviour before visual polish.

If two consecutive `METRIC_TUNE_ONLY` rounds fail to converge, stop tuning and revise the geometry model. Do not burn tokens indefinitely.

---

# 4. Mockup-specific gates

## Navigation
Source:

```text
navigation.png
```

Pass if:
- reads as one radial controller;
- three regions are legible;
- not a rectangular menu.

## Dashboard
Source:

```text
dashboard.png
```

Pass if:
- avatar occupies Navigation origin while Dashboard active;
- Clock / MPRIS / Calendar / ROM-RAM-CPU-GPU cluster exists;
- unused Dashboard area remains intentionally empty.

## Sidebar
Source:

```text
sidebar.png
```

Pass if:
- Sidebar appears immediately from Sidebar hover;
- pointer can reach the Sidebar without flicker-collapse;
- controls are circles;
- body is left-attached, not a generic drawer.

## Settings
Source:

```text
setting.png
```

Pass if:
- centered inner panel;
- equal radius feel;
- only stub content.

## HakuMenu
Source:

```text
hakumenu.png
```

Pass if:
- physically centered;
- three tabs;
- equal radius family;
- main list region;
- state region only in Theme;
- no horizontal jump when changing tab.

## Wallpaper
Source:

```text
wallpaper-change.png
```

Pass if:
- no large panel background;
- selected item stays at fixed center;
- side list reads as stacked/overlapping;
- arrows/wheel move selection;
- Enter applies.

---

# 5. Full runtime gates after major checkpoints

After Navigation + Dashboard + Sidebar + Settings:

```text
tag p3-v2-navigation-pass
```

After HakuMenu:

```text
tag p3-v2-hakumenu-pass
```

After Wallpaper:

```text
tag p3-v2-wallpaper-pass
```

After shell polish:

```text
tag p3-v2-shell-polish-pass
```

Before final:

```text
Hyprland
Niri
MangoWM
Classic regression
1.0x
fractional scale
reload/restart
```

Then:

```text
tag p3-v2-final
```

---

# 6. Stop conditions

Stop and report before more experimentation if:

- a component starts diverging from its assigned mockup;
- more than 3 visual metrics are repeatedly tuned;
- accepted foundation code must be rewritten;
- a diff touches unrelated surface families;
- a new abstraction affects multiple accepted components;
- user-visible behaviour must be invented because the mockup is silent;
- Classic semantics would change;
- a WM-specific workaround is about to enter shared UI code.

Fallback to the last accepted commit is preferred over accumulating speculative fixes.
