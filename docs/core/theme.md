# The Theming Engine in HakuSpace

HakuSpace's theming engine turns wallpaper or manual color choices into shared theme state, generated application styles and consumer updates.

In this document, we'll take a deep dive into how the theming engine and the smart Accent Color extraction mechanism actually work under the hood. Theme controllers live under `src/core/backend/theme/`, rendering/apply helpers under `src/core/theme/`, and shared state libraries under `src/core/lib/`.

## The Complete Workflow

Whenever you change your wallpaper (whether you trigger it manually via `wallpaper_select.sh` or automatically through `random_wallpaper.sh`), the system kicks off a sequence of scripts to update your entire desktop's look. Here is the step-by-step breakdown:

### 1. Setting the Wallpaper (`wallpaper_set.sh`)
Everything starts when you pick a new image. The system calls `wallpaper_set.sh`, which is responsible for physically displaying the wallpaper on your screen. 
- If you select a static image (`.png`, `.jpg`, `.gif`), it uses `awww` to render it. 
- If you pick a video wallpaper (`.mp4`), it seamlessly switches to using `mpvpaper`.
- This script creates blurred cache versions of the wallpaper, which are used later for elements like the Niri overview backdrop or Rofi backgrounds.
- **State Caching:** The script also saves the current wallpaper path to `~/.cache/current_wallpaper`. This allows our autostart script, `wallpaper_resume.sh`, to know what was previously set. On startup, if `wallpaper_resume.sh` detects that the last wallpaper was a video, it will automatically relaunch `wallpaper_set.sh` to resume your lively wallpaper (since static images are natively restored by the `awww-daemon`).

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
- **Context-Aware Selection:** The script is smart enough to detect your current wallpaper mode. If it detects that `mpvpaper` is actively running, it assumes you are in "lively mode" and will exclusively pick random video wallpapers (`.mp4`) from your `$WALL_MPV_DIR`. If `mpvpaper` is not running, it falls back to cycling through your static images in `$WALL_DIR`.
- **Accent Color Synchronization:** Just like manual selection, it triggers the entire color extraction pipeline. When transitioning between video wallpapers, it cleverly extracts the new accent color from pre-generated thumbnail previews (located in the `.thumbnails/` directory) to ensure your desktop UI changes color synchronously with the video, without any stutter.

## Customizing the Theming Engine

We've designed this system to be highly customizable. If you want to tweak how it behaves, you have several options:

1. **Disable Auto-Theming:** If you prefer a static color scheme that doesn't change with your wallpaper, simply open `~/hakucfg/setting.sh` and set `ACCENT_COLOR_BASED_ON_WALLPAPER=false`.
2. **Change the Extraction Mode:** Don't like the vivid colors? Open `~/hakucfg/setting.sh` and change `ACCENT_COLOR_MODE` to `dominant`, `brightest`, or `saturated` to suit your taste.
3. **Pick a Color Manually:** Sometimes you just want to choose the color yourself. You can run the `accent_color_picker.sh` script to open a graphical color picker. Whatever color you select there will immediately be sent through `theme_ctl.sh set-accent`, applied to your desktop, and synchronized through the HakuSpace internal icon accent engine according to `HAKU_ICON_THEME` and `HAKU_ICON_ACCENT_MODE`!
4. **Opaque Theme Mode:** Want your panels and UI elements to be solid black rather than transparent/translucent? `opaque_theme.sh` provides this functionality. When enabled (via the Haku Menu's Setting tab), it dynamically writes solid `#000000` background rules into `THEME_RENDER_DIR/opaque/`. These rules are safely included at the bottom of Waybar, SwayNC, Rofi, GTK, and Kitty configs, allowing instant toggleable opaqueness without manual config editing.

## Visual Ecosystem (Icons, GTK & Cursor Sync)

Beyond just changing your terminal and status bar colors, HakuSpace comes with its own matching visual suite - **[Haku Cursor](https://github.com/hakuimaku/haku-cursor)**, **[Hikaide GTK](https://github.com/hakuimaku/hikade-gtk-theme)**, and **[Hikaide-Symbols](https://github.com/hakuimaku/hikaide-symbols)** - installed via `hakuspace-archive` (`./scripts/assets.sh`).

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

### 2. Customizing Your Look (`appearance.env`)
Default settings live in `src/core/lib/haku_appearance.sh`, but you can easily override them by creating `~/.config/hakuspace/appearance.env`:

```bash
HAKU_GTK_THEME=Hikaide
HAKU_ICON_THEME=Hikaide-Symbols   # default: use HakuSpace's icon theme
# HAKU_ICON_THEME=Papirus-Dark    # or pick another installed icon theme
# HAKU_ICON_THEME=system          # leave your desktop icon setting untouched

HAKU_ICON_ACCENT_MODE=auto       # default: only recolor managed Hikaide-Symbols
# HAKU_ICON_ACCENT_MODE=on        # opt in to recoloring a custom icon theme in ~/.icons
# HAKU_ICON_ACCENT_MODE=off       # never recolor icons

HAKU_CURSOR_THEME=Haku-Dark
HAKU_CURSOR_SIZE=24
# HAKU_CURSOR_THEME=Haku-Light
# Optional color variants: Haku-Blue, Haku-Blue-Light, Haku-Pink, Haku-Pink-Light
```

- **How Icon Modes Work:**
  - `auto` (default): Only recolors `Hikaide-Symbols` when it was installed by HakuSpace. Any other icon theme is left alone.
  - `on`: Uses the internal scanner to safely recolor a compatible user-owned icon theme inside `~/.icons` (static themes simply report `not-applicable` and are left untouched). System-wide icons in `/usr/share/icons` are never modified.
  - `off` (or `HAKU_ICON_THEME=system`): Completely disables icon recoloring.
- **How Cursor Themes Work:**
  - Cursor themes are installed under `~/.icons/$HAKU_CURSOR_THEME` and written to `~/.config/environment.d/90-hakuspace-cursor.conf`.
  - On Hyprland, the cursor updates live via `hyprctl setcursor`; on Niri and MangoWM, the new cursor environment applies on your next login session.
  - Legacy `HAKU_CURSOR_PALETTE=blue` settings still work and automatically map to `Haku-Blue` (dark variant), though setting `HAKU_CURSOR_THEME` directly is recommended.

### 3. The Built-in Icon Recoloring Engine (`haku_icon_accent.py`)
Located at `src/core/app/icon-accent/haku_icon_accent.py` (and linked to `~/.local/bin/haku_icon_accent.py`), this pure-Python script safely updates SVG accent colors in your icon theme without needing any external dependencies.
- **Safe Backups:** Before touching any SVG file, it saves a checksum-verified backup of the original artwork in `~/.local/state/icon-accent/`. If you manually edit an icon file yourself, the engine detects the mismatch and refuses to overwrite your work!
- **Manual CLI:** You can check the current icon color or restore the original icons anytime:

```bash
python3 ~/.local/bin/haku_icon_accent.py --icons-dir ~/.icons status Hikaide-Symbols
python3 ~/.local/bin/haku_icon_accent.py --icons-dir ~/.icons restore Hikaide-Symbols
# Reapply your current HakuSpace accent after restoring:
~/.local/bin/theme_ctl.sh apply
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

### Niri Animation Switcher (`niri_animation_switcher.sh` / `niri_animation_ctl.sh`)
- **`niri_animation_switcher.sh` (Facade):** Opens the animation picker for the selected shell mode.
- **`niri_animation_rofi.sh` (Classic UI):** Displays the Rofi menu for Niri animation presets.
- **`niri_animation_ctl.sh` (Headless Backend):** Reads and updates `niri-animation.kdl` (`list [--json]`, `get <mode>`, `set <mode> <option-id>`) and validates the KDL config safely.

---
**Previous:** [Core Libraries](lib.md) | **Next:** [System Management](sys.md)
