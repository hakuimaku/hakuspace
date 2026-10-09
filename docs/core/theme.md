# The Theming Engine in HakuSpace

Have you ever noticed how your entire desktop environment—from Waybar and Rofi down to Kitty and SwayNC—magically changes color to match your new wallpaper? This isn't just magic; it's a carefully orchestrated pipeline of scripts working together. 

In this document, we'll take a deep dive into how the theming engine and the smart Accent Color extraction mechanism actually work under the hood. You can find all the related scripts nested inside the `src/core/theme/` directory.

## The Complete Workflow

Whenever you change your wallpaper (whether you trigger it manually via `wallpaper_select.sh` or automatically through `random_wallpaper.sh`), the system kicks off a sequence of scripts to update your entire desktop's look. Here is the step-by-step breakdown:

### 1. Setting the Wallpaper (`wallpaper_set.sh`)
Everything starts when you pick a new image. The system calls `wallpaper_set.sh`, which is responsible for physically displaying the wallpaper on your screen. 
- If you select a static image (`.png`, `.jpg`, `.gif`), it uses `awww` to render it. 
- If you pick a video wallpaper (`.mp4`), it seamlessly switches to using `mpvpaper`.
- This script also creates blurred cache versions of the wallpaper, which are used later for elements like the Niri overview backdrop or Rofi backgrounds.

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
Once we have the perfect, validated Hex color code (e.g., `#ff6699`), it is handed over to `gen_style.sh`. This is the workhorse of the theming engine.
- The script takes the Hex code and translates it into various color formats (RGB, RGBA) so different applications can understand it.
- It then dynamically generates and overwrites the `.css` and `.conf` configuration files for your desktop components. It updates the styling variables for Waybar, configures Rofi's color scheme, changes Kitty's terminal colors, and updates SwayNC's notification aesthetics.

### 5. Applying the Changes Live (`apply_style.sh`)
Generating the config files isn't enough; the applications need to know that their configs have changed. That's where `apply_style.sh` comes in.
- This script wakes up all the relevant applications and tells them to reload their configurations on the fly.
- For example, it calls `reload_config.sh` (to reload the Window Manager), and sends reload commands to SwayNC, Kitty, and Cava. Note that Waybar updates its CSS automatically via its own hot-reload mechanism.

## Customizing the Theming Engine

We've designed this system to be highly customizable. If you want to tweak how it behaves, you have several options:

1. **Disable Auto-Theming:** If you prefer a static color scheme that doesn't change with your wallpaper, simply open `~/hakucfg/setting.sh` and set `ACCENT_COLOR_BASED_ON_WALLPAPER=false`.
2. **Change the Extraction Mode:** Don't like the vivid colors? Open `~/hakucfg/setting.sh` and change `ACCENT_COLOR_MODE` to `dominant`, `brightest`, or `saturated` to suit your taste.
3. **Pick a Color Manually:** Sometimes you just want to choose the color yourself. You can run the `accent_color_picker.sh` script to open a graphical color picker. Whatever color you select there will immediately be pushed through `gen_style.sh` and applied to your entire system!
4. **Opaque Theme Mode:** Want your panels and UI elements to be solid black rather than transparent/translucent? `opaque_theme.sh` provides this functionality. When enabled (via the Haku Menu's Setting tab), it dynamically writes solid `#000000` background rules into `THEME_RENDER_DIR/opaque/`. These rules are safely included at the bottom of Waybar, SwayNC, Rofi, GTK, and Kitty configs, allowing instant toggleable opaqueness without manual config editing.

---
**Previous:** [Core Libraries](lib.md) | **Next:** [System Management](sys.md)
