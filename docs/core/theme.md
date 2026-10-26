# The Theming Engine in HakuSpace

HakuSpace's theming engine turns wallpaper or manual color choices into shared theme state, generated application styles and consumer updates.

In this document, we'll take a deep dive into how the theming engine and the smart Accent Color extraction mechanism actually work under the hood. Theme controllers live under `src/core/backend/theme/`, rendering/apply helpers under `src/core/theme/`, and shared state libraries under `src/core/lib/`.

## The Complete Workflow

Whenever you change your wallpaper (whether you trigger it manually via `wallpaper_select.sh` or automatically through `random_wallpaper.sh`), the system kicks off a sequence of scripts to update your entire desktop's look. Here is the step-by-step breakdown:

### 1. Setting the Wallpaper (`wallpaper_set.sh`)

Images use awww in both modes. Hikai coordinates selection through wallpaper IPC and replaces video playback with Quickshell; see [Native Hikai wallpaper](#native-hikai-wallpaper).
Everything starts when you pick a new image. The system calls `wallpaper_set.sh`, which is responsible for physically displaying the wallpaper on your screen. 
- If you select a static image (`.png`, `.jpg`, `.gif`), it uses `awww` to render it. 
- If you pick a video wallpaper (`.mp4`), Classic uses `mpvpaper` and Hikai uses native Quickshell playback.
- This script creates blurred cache versions of the wallpaper, which are used later for elements like the Niri overview backdrop or Rofi backgrounds.
- **State Caching:** The script also saves the current wallpaper path to `~/.cache/current_wallpaper`. This allows our autostart script, `wallpaper_resume.sh`, to know what was previously set. On Classic startup or mode entry, `wallpaper_resume.sh` starts awww and reapplies the saved image or video through `wallpaper_set.sh`.

### 2. Extracting the Colors (`get_accent_color.py`)
If you have the automatic color extraction enabled (which is controlled by the `ACCENT_COLOR_BASED_ON_WALLPAPER=true` flag inside your `~/hakucfg/setting.sh` file), the system calls our Python script: `get_accent_color.py`.
- This script leverages the `colorthief` library to analyze the wallpaper image and generate a palette of colors.
- It doesn't just pick a random color! It uses a specific algorithm based on your chosen `ACCENT_COLOR_MODE`. By default, it uses the **`vivid`** mode, which calculates the mathematical brightness and saturation of the extracted colors to find the most visually striking and readable option.
- Other available modes include **`dominant`** (the most common color in the image), **`brightest`** (the lightest color), and **`saturated`** (the most colorful option).

### 3. Safety Checks and Validation (`accent_color.sh`)
Not every color pulled from an image is suitable for a user interface. For example, if your wallpaper is very dark, the Python script might extract a deep gray or black. If we applied that to your fonts or UI outlines, you wouldn't be able to read anything!
- To prevent this, the extracted color is passed through a validation function called `accent_color_or_fallback`.
- This function double-checks the brightness of the color. If the selected color is deemed too dark or invalid, it rejects it and safely falls back to a predefined default color (`THEME_DEFAULT_ACCENT`). This ensures your UI is always readable and aesthetically pleasing.

### 4. Generating the Theme (`gen_style.sh`)
Once we have the perfect, validated Hex color code (e.g., `#ff6699`), it is handed to `theme_ctl.sh set-accent`, which saves canonical state and calls `gen_style.sh`. This is the workhorse of the theming engine.
- The script takes the Hex code and translates it into various color formats (RGB, RGBA) so different applications can understand it.
- It renders application-specific outputs from the same canonical state. Generated styles are output only; consumers must not use them to overwrite user preferences. Read the renderer source for its current output formats and targets.

### 5. Applying the Changes Live (`apply_style.sh`)
Generating the config files isn't enough; the applications need to know that their configs have changed. That's where `apply_style.sh` comes in.
- This script wakes up all the relevant applications and tells them to reload their configurations on the fly.
- Consumers either watch generated styles or receive a reload request through the apply helpers. `reload_config.sh` handles Window Manager reloads; each application adapter owns its update mechanism.

### 6. Automated Wallpaper Transitions (`random_wallpaper.sh`)
For those who want a dynamic desktop, `random_wallpaper.sh` automatically cycles through your wallpapers at a defined interval (`WALL_INTERVAL` in `setting.sh`).
- **Context-Aware Selection:** The script is smart enough to detect your current wallpaper mode. In Classic, if it detects that `mpvpaper` is actively running, it assumes you are in "lively mode" and will exclusively pick random video wallpapers (`.mp4`) from your `$WALL_MPV_DIR`. If `mpvpaper` is not running, Classic falls back to static images in `$WALL_DIR`. Hikai derives the video/image choice from native current state instead of process existence.
- **Accent Color Synchronization:** Just like manual selection, it triggers the entire color extraction pipeline. When transitioning between video wallpapers, it cleverly extracts the new accent color from pre-generated thumbnail previews (located in the `.thumbnails/` directory) to ensure your desktop UI changes color synchronously with the video, without any stutter.

## Customizing the Theming Engine

We've designed this system to be highly customizable. If you want to tweak how it behaves, you have several options:

1. **Disable Auto-Theming:** If you prefer a static color scheme that doesn't change with your wallpaper, simply open `~/hakucfg/setting.sh` and set `ACCENT_COLOR_BASED_ON_WALLPAPER=false`.
2. **Change the Extraction Mode:** Don't like the vivid colors? Open `~/hakucfg/setting.sh` and change `ACCENT_COLOR_MODE` to `dominant`, `brightest`, or `saturated` to suit your taste.
3. **Pick a Color Manually:** Sometimes you just want to choose the color yourself. You can run the `accent_color_picker.sh` script to open a graphical color picker. Whatever color you select there will immediately be sent through `theme_ctl.sh set-accent`, applied to your desktop, and synchronized through the HakuSpace internal icon accent engine according to `HAKU_ICON_THEME` and `HAKU_ICON_ACCENT_MODE`!
4. **Opaque Theme Mode:** Want your panels and UI elements to be solid black rather than transparent/translucent? `opaque_theme.sh` provides this functionality. When enabled (via the Haku Menu's Setting tab), it dynamically writes solid `#000000` background rules into `THEME_RENDER_DIR/opaque/`. These rules are safely included at the bottom of Waybar, SwayNC, Rofi, GTK, and Kitty configs, allowing instant toggleable opaqueness without manual config editing.

## Visual Ecosystem (Icons, GTK & Cursor Sync)

Beyond just changing your terminal and status bar colors, HakuSpace comes with its own matching visual suite - **[Haku Cursor](https://github.com/hakuimaku/haku-cursor)**, **[Hikaide GTK](https://github.com/hakuimaku/hikade-gtk-theme)**, and **[Hikaide-Symbols](https://github.com/hakuimaku/hikaide-symbols)** - managed by HakuSpace as independent repositories at their own absolute paths; see [visual setup and multi-root development](../visual-setup.md). `./scripts/setup.sh setup` builds and installs them; `hakuspace-archive` supplies wallpapers only through `./scripts/assets.sh`.

Use `./scripts/setup.sh status` to inspect source locations and dirty state,
`./scripts/setup.sh update` to fast-forward clean sources and install changed
revisions, or `./scripts/setup.sh apply symbols` to build local edits without
pulling. Dirty repositories, detached/no-upstream branches and explicit source
overrides are preserved during automatic update. Existing source trees elsewhere
are never moved; the `HAKU_*_SOURCE` overrides remain available for explicit setup/apply.

HakuSpace derives repository revisions, dirty state and installed assets live.
Only explicit source locations are remembered through registered centralized state;
no separate installation manifest is read or written. Pending appearance activation
is retained in `[system].visual-reconcile.pending` and retried by setup/update/verify
without rebuilding unchanged repositories just to reactivate appearance. Reconciliation
uses current source core once per batch and preserves Light/Dark/Classic mapping,
XDG discovery and stateless accent sync. Installed assets remain usable independently
of the wallpaper archive or source checkouts.

Even better: your folder and system icons in `Hikaide-Symbols` automatically change color to match your active accent color! Here is how that pipeline works behind the scenes:

```text
Theme UI / wallpaper / CLI → theme_ctl
                                  → save canonical state ([theme].appearance.env)
                                  → gen_style
                                  → appearance_ctl sync-accent → haku_icon_accent.py
                                  → apply_style / reload consumers (desktop icons, WM, etc.)
```

### 1. The Theme & Appearance Controllers (`theme_ctl.sh` & `appearance_ctl.sh`)
Instead of having random scripts edit theme files directly, everything goes through two central controllers:
- **`theme_ctl.sh`**: The main entry point whenever you change your accent color, font, or font size.
  - Running `theme_ctl.sh set-accent '#AC7994'` saves the new color to `~/.local/state/hakuspace/state/[theme].appearance.env`, renders the new styles via `gen_style.sh`, asks `appearance_ctl.sh sync-accent` to recolor your icons first (via `haku_icon_accent.py`), and *then* reloads all desktop consumers via `apply_style.sh` so your apps immediately see the newly recolored icons.
  - Running `theme_ctl.sh apply` reconciles everything in the same safe order: renders style, synchronizes icons, and reloads consumers.
  - Changing only your font (`set-font`) or size (`set-size`) skips icon recoloring so it stays fast.
- **`appearance_ctl.sh`**: Manages your GTK theme, icon theme, and mouse cursor settings.

```bash
~/.local/bin/appearance_ctl.sh status
~/.local/bin/appearance_ctl.sh verify
~/.local/bin/appearance_ctl.sh apply
~/.local/bin/theme_ctl.sh set-accent '#AC7994'
~/.local/bin/theme_ctl.sh apply
```

### Native application mode selection

`appearance_ctl.sh apply-mode light|dark` selects the existing asset pair without rebuilding, extracting wallpaper colors, recoloring SVGs, changing cursors, or saving Hikai preferences:

| Effective mode | GTK | Icons |
| --- | --- | --- |
| Dark | `Hikaide` | `Hikaide-Symbols` |
| Light | `Hikaide-Light` | `Hikaide-Symbols-Light` |

`apply` resolves Classic to dark and Hikai to its validated saved `appearance.colorMode`. The existing `DesktopColorScheme` writer also applies these names during live preview, Apply and Discard. Classic cutovers reassert dark names after the outgoing shell exits. Custom theme names are preserved, and `HAKU_ICON_THEME=system` skips icon selection.

GTK3/GTK4 native settings are synchronized without changing fonts or user CSS. Existing managed Hikaide GTK4 links follow the selected theme. Both Hikaide names keep `gtk-application-prefer-dark-theme=0`: the theme name carries the appearance, so a persistent dark preference cannot accidentally select the Light theme's dark fallback. An already-running portal backend that cached old GTK settings may need one reload after upgrading; do not interrupt an open chooser.

### 2. Appearance selection and policy

The controller reads the active desktop GTK and icon theme names, with native GTK settings as a fallback. The shared defaults and family mapping live in `src/core/lib/haku_appearance.sh`; no separate appearance override file is loaded.

- Mode changes affect GTK only while `Hikaide` or `Hikaide-Light` is active, and icons only while `Hikaide-Symbols` or `Hikaide-Symbols-Light` is active. A custom selection in either component is preserved independently.
- Icon accent sync requires an active, recognized managed Hikaide-Symbols family. Third-party icon themes are never recolored, including when a legacy command environment sets `HAKU_ICON_ACCENT_MODE=on`. Both `auto` and `on` retain this managed-family restriction; `off` disables recoloring.
- `HAKU_ICON_THEME=system` remains an explicit script-level opt-out from icon changes.
- Icon discovery searches `${XDG_DATA_HOME:-$HOME/.local/share}/icons`, `~/.icons`, `/usr/local/share/icons`, then `/usr/share/icons`. Empty/unset `HAKU_ICON_DIR` uses this order; a nonempty value selects that root exclusively. Activation, metadata checks, status and accent targets share this resolver.
- Only writable, user-owned managed installations with the expected theme name and Hikaide metadata are recolored. System installations are activation-only; escaped symlinks and invalid/missing pair metadata cannot authorize writes. Multiple valid user installations produce a warning and all receive the canonical Dark/Light accents.
- Cursor defaults are `Haku-Dark`, size 24. Mode-only operations leave the current cursor unchanged. Full appearance apply writes cursor settings to `~/.config/environment.d/90-hakuspace-cursor.conf`.

### 3. The Built-in Icon Recoloring Engine (`haku_icon_accent.py`)
Located at `src/core/app/icon-accent/haku_icon_accent.py` (and linked to `~/.local/bin/haku_icon_accent.py`), this pure-Python script safely updates SVG accent colors in your icon theme without needing any external dependencies.
Managed Hikaide-Symbols uses stateless accent reconciliation: Dark receives `ACCENT_DARK`, Light receives `ACCENT_LIGHT`, and `[theme].appearance.env` remains the source of truth. Sync uses `apply --no-backup`; it validates patched SVGs before atomic replacement, leaves matching files untouched, and creates no backup, receipt or current-accent state. Interrupted multi-file writes may leave mixed accents; rerun `appearance_ctl.sh sync-accent` to converge. Mode changes only select the installed variants.

Locks live under `${XDG_RUNTIME_DIR}/hakuspace/appearance/`, falling back to `${TMPDIR:-/tmp}/hakuspace-$UID/appearance/`. Successful managed reconciliation removes only legacy Hikaide backup entries identified by their theme, installation path, backend and hashed directory key; unrelated or unverified entries remain.

Generic usage retains checksum-verified backup/restore by default. Backups live under `${XDG_STATE_HOME:-$HOME/.local/state}/icon-accent`; `--state-dir PATH` selects a different backup root. Combining `--state-dir` with `--no-backup` is rejected. Stateless mode never constructs a backup manager and cannot restore previous artwork.

```bash
# Inspect managed artwork or reconcile both variants from canonical state:
python3 ~/.local/bin/haku_icon_accent.py --icons-dir ~/.icons status Hikaide-Symbols
~/.local/bin/appearance_ctl.sh sync-accent
# Generic, explicitly requested recoloring retains backups:
python3 ~/.local/bin/haku_icon_accent.py --icons-dir ~/.icons set '#89B4FA' --theme Example
python3 ~/.local/bin/haku_icon_accent.py --icons-dir ~/.icons restore Example
# Direct stateless use with a resolved path:
python3 ~/.local/bin/haku_icon_accent.py apply --theme-dir ~/.icons/Hikaide-Symbols --accent '#89B4FA' --no-backup
```

> [!NOTE]
> After icons are recolored, simply reopen your file manager or apps to see the fresh icons (HakuSpace won't forcefully kill your open Thunar windows).

---

## Headless Backend Split (Wallpaper & Niri Animations)

Wallpaper and animation operations use public facades, frontend adapters and headless controllers. This keeps the domain logic available independently of presentation. See [Hikai](../hikai.md) for shell architecture.

### Wallpaper Control (`wallpaper_select.sh` / `wallpaper_ctl.sh`)
- **`wallpaper_select.sh` (Facade):** The command bound to `SUPER + Y` and `SUPER + SHIFT + Y`. It opens the right wallpaper picker for your current shell mode, while keeping flags like `--static`, `--lively`, and `--exit` working as usual.
- **`wallpaper_rofi.sh` (Classic UI):** Builds the Rofi grid menu with thumbnails when you're in Classic mode.
- **`wallpaper_ctl.sh` (Headless Backend):** Discovers static/video wallpapers, generates missing video previews, applies the chosen wallpaper, and triggers accent extraction. It exposes explicit commands and JSON output for structured queries:

```bash
wallpaper_ctl.sh list-static --json
wallpaper_ctl.sh list-lively --json
wallpaper_ctl.sh apply-static <id-or-path>
wallpaper_ctl.sh apply-lively <id-or-path>
wallpaper_ctl.sh stop-lively
wallpaper_ctl.sh current --json
wallpaper_ctl.sh status --json
wallpaper_ctl.sh ensure-thumbnails
```

### Native Hikai Wallpaper

Hikai coordinates awww image application and per-output Qt Multimedia video surfaces through `WallpaperService.qml`. One managed Quickshell child owns all native video windows and decoders while video is active, independently of menu visibility. After awww commits an image, that child exits and releases its Qt/FFmpeg heap, image cache and graphics resources. Images allocate no native wallpaper renderer. The main shell keeps only output registration and small diagnostic records; it does not load Qt Multimedia. A private runtime socket carries selection/policy snapshots and readiness acknowledgements, preserving the per-output commit barrier. Closing the parent connection also closes the child. Both media kinds still run `wallpaper_set.sh` to generate the usual `walpaper_wide_gen.jpg`, `walpaper_box_gen.jpg` and Niri backdrop. Its right-edge wallpaper sidebar is independent of playback and uses cached still previews in a vertical carousel. Top-left and bottom-left flares join the Rounded Screen ceiling and floor. Only the TopBar’s right module lane hides on the requested output until closing finishes; left/center modules, OSD and tooltips retain their usual behavior. Theme → Change Wallpaper closes HakuMenu normally and opens the wallpaper sidebar independently from the right edge. The sidebar retains its opening/closing Bezier motion and the controls retain their own morph effects.

Use Up/Down or the wheel to browse, Ctrl + arrow keys to switch Images / Videos, Alt + arrows in Videos to cycle Low Memory / Screen / Original, and Enter to apply. The Images tab hides video quality controls; existing All filter preferences open Images. Buttons morph without brightening their background on hover. Wallpaper Settings uses the same morph controls with a moving selection surface. Selection outlines are omitted from the preview and type/quality strips. Build all videos prepares the whole collection using the selected profile, including videos hidden by search or filters, without applying a wallpaper. Clear cache removes unused video proxies while protecting active/prepared selections.

The quality section expands when Videos is selected and collapses when returning to Images, animating only inside the stable drawing window. Wallpaper Settings lets every sidebar section scroll to the viewport top so its selection pill follows Playback, Proxy cache and Browser. The wider Settings domain tabs end with Info: General / Shell / Config / Wallpaper / Info (Alt+4 for Wallpaper, Alt+5 for Info).

The compact heading sits above search. Library choices are tabs with a moving underline; video quality uses separate cards with frame-rate/resolution details and a moving HakuMenu selection surface. Button backgrounds expand and round on hover, contract on press, then recover on release. The footer omits the shortcut guide.

An existing shell that already loaded the old in-process decoder needs one full Quickshell restart to discard that heap. `tools/profiling/hikai_wallpaper_soak.py --source <video> --profile screen --seconds 3 --cycles 3 --output /tmp/wallpaper-cycles.json` checks image/video recovery, rapid reopening, reload and renderer failure in a private software-rendered session. Measurements report shell memory separately from `totalRssKiB` / `totalPssKiB`, which include the renderer. Process isolation adds an engine/startup cost while video is active; combined PSS is more useful than summed RSS because shared library pages can appear in both processes.

Wallpaper preferences live in `~/hakucfg/hikai/hikai-wallpaper.json` under Settings → Wallpaper. Screen is the default for new/reset preferences and targets the largest output at up to 60 fps, preserving lower source frame rates; existing saved profile choices are retained. Low Memory builds bounded 720p/24 fps proxies; Original uses the source. Proxies and still thumbnails live under `~/.cache/hakuspace/wallpaper/`, leaving original media unchanged. Missing proxy tools do not prevent explicit Original playback through Qt.

The Python controller prepares a candidate with `select`. Video commits after native surfaces report a valid frame; image commits after awww applies it successfully, then releases any native video. Failed preparation or application retains the preceding wallpaper. Fullscreen pause and decoder unload affect native video per output. Current and diagnostic records use `[desktop].wallpaper.current.json` and `[desktop].wallpaper.runtime.json`; random rotation uses managed current state in Hikai.

Classic keeps its existing awww/mpvpaper flow. Native handoff stops the legacy video process once when Hikai takes background ownership; returning to Classic restores the compatibility selection.

### Niri Animation Switcher (`niri_animation_switcher.sh` / `niri_animation_ctl.sh`)
- **`niri_animation_switcher.sh` (Facade):** Opens the animation picker for the selected shell mode.
- **`niri_animation_rofi.sh` (Classic UI):** Displays the Rofi menu for Niri animation presets.
- **`niri_animation_ctl.sh` (Headless Backend):** Reads and updates `niri-animation.kdl` (`list [--json]`, `get <mode>`, `set <mode> <option-id>`) and validates the KDL config safely.

---
**Previous:** [Core Libraries](lib.md) | **Next:** [System Management](sys.md)

## Hikai Light Mode and dual accents

Appearance → Theme Mode previews Dark or Light in Hikai. Apply persists
`appearance.colorMode` in `~/hakucfg/hikai/hikai-shell.json` (schema v7);
Discard restores the saved mode. The main shell synchronizes
`org.gnome.desktop.interface color-scheme` with the live preview (`prefer-light` or
`prefer-dark`). Hiding Hikai during a Classic cutover restores `prefer-dark`;
returning to Hikai restores its selected scheme. Renderer children do not write
this desktop preference. Schema v6 migrates to Dark without changing other preferences.
The existing surface keys remain `ink`, `dark`, and `soft`. In Light they display
Pure White (`#FFFFFF`), White (`#EEEEEE`), and Gray White (`#D6D6D6`).
Classic always uses its dark palette. Switching to Classic preserves Hikai's Light
preference; returning to Hikai restores it without reanalyzing the wallpaper.

`theme_ctl.sh set-accent HEX` accepts a seed. Manual selection and wallpaper extraction
share `accent_palette.py`, which preserves hue/saturation while adjusting lightness
for at least 4.5:1 contrast on dark surfaces and 7:1 on light surfaces.
Grayscale seeds stay grayscale. `theme_ctl.sh apply` refreshes the saved variants
from their existing seed, so contrast adjustments do not require wallpaper analysis.
Canonical `[theme].appearance.env` uses `THEME_STATE_VERSION=2`, `ACCENT_SEED`,
`ACCENT_DARK`, `ACCENT_LIGHT`, `FONT_FAMILY`, and `FONT_SIZE`. Existing single-accent
state migrates atomically on load, retaining typography. Generated files are never
read to recover canonical state.

Legacy `ACCENT_COLOR` is a runtime alias for `ACCENT_DARK`; `theme_ctl.sh get accent`
continues to return that dark-compatible color. Classic/global renderers and icon
accent synchronization use it. `quickshell.json` contains `accentDark` and `accentLight`;
`Theme.qml` chooses between them reactively, so mode changes do not rewrite generated
files or invoke ColorThief.

## Classic Opaque context

`[theme].opaque.enabled` stores the requested preference. Overrides are effective only
in Classic. `opaque_theme.sh sync classic|hikai` reconciles Waybar, Rofi, SwayNC,
Kitty, and compositor overrides without changing the request. Backend transitions
synchronize under their cover barrier and restore the original context on rollback;
early session startup reconciles the saved context.

Kitty loads its managed opaque override after `~/hakucfg/config/kitty.conf`. When
effective, it sets `background_opacity 1.0`. Generated Hyprland and Niri overrides
also force Kitty window opacity to 1.0, including inactive windows. Their includes
follow user configuration. When ineffective these overrides are empty, restoring
user/default transparency. Mango and Labwc have no Kitty transparency rule to override.
Context synchronization reloads the compositor and existing Kitty sockets without
restarting shell services. Existing Opaque on/off/toggle commands retain their API.
Kitty enables `dynamic_background_opacity` for subsequent live toggles. Windows
launched before that option was enabled may need to be reopened once after updating.

Compositor behavior follows the [Hyprland opacity override contract](https://wiki.hypr.land/Configuring/Basics/Window-Rules/)
and [Niri window rule contract](https://niri-wm.github.io/niri/Configuration:-Window-Rules.html).

## Kitty in Hikai Light

The main shell synchronizes Kitty with the live Light mode, surface and accent draft.
The managed `theme/kitty-mode.conf` supplies light background, contrast-correct ANSI
colors, cursor, selection and tab colors. Dark and Classic clear this override so
Kitty resumes its base and custom colors. The include follows `~/hakucfg/config/kitty.conf`
and precedes Classic Opaque; fonts, key bindings and user opacity remain under their
existing owners. Open Kitty instances reload through their existing remote-control
sockets; new terminals read the same override. Changing only a surface or mode does
not extract wallpaper colors or rewrite the custom Kitty configuration.

Cava Underbar uses opaque wave/capsule colors, matching its attachment surface.
The crest shares the body's color, and the wave spans the full output width across
the Rounded Screen side rails while keeping its existing stable, click-through window.
