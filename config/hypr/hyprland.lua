--    __  __                      _                 _ 
--   / / / /_  ______  _________ / /___ _____  ____/ /
--  / /_/ / / / / __ \/ ___/ __  / __  / __ \/ __  / 
-- / __  / /_/ / /_/ / /  / /_/ / /_/ / / / / /_/ /  
--/_/ /_/\__, / .___/_/   \__,_/\__,_/_/ /_/\__,_/   
--      /____/_/                                     


-- Keybinding
local config_dir = os.getenv("HOME") .. "/.config/hypr/"
dofile(config_dir .. "keybinding.lua")

-- Look and feel, accent color for border
local style_dir = os.getenv("HOME") .. "/.local/state/haku_theme/"
local ok, style = pcall(dofile, style_dir .. "hyprland-style.lua")
if not ok then
    style = { font_family = "monospace", font_size = 16, border_color = "rgba(ffffffff)" }
end

local font_family = style.font_family
local font_size = style.font_size
local border_color = style.border_color

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "1920x1080@60",
    position = "auto",
    scale    = "1",
})

-- hl.monitor({
--     output   = "",
--     mode     = "1280x720@60",
--     position = "auto",
--     scale    = "1",
-- })


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

hl.on("hyprland.start", function () 
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hyprsunset --temperature 3000")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sway-audio-idle-inhibit")
    hl.exec_cmd("~/.local/bin/welcome")
    hl.exec_cmd("~/.local/bin/cava_manager")
end)



-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

--hl.env("XCURSOR_SIZE", "24")
--hl.env("HYPRCURSOR_SIZE", "24")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Toolkit backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- Input method
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "fcitx")
-- hl.env("GTK_IM_MODULE", "fcitx")  # uncomment if you use GTK apps and want to use fcitx in them as well

-- Scale factor
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0") -- Disable if you want to set a custom scale factor with QT_SCALE_FACTOR
--hl.env("QT_SCALE_FACTOR", "1.25")



-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = border_color,
            --active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(ffffff00)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 16,
        rounding_power = 4,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 0.8,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 4,
            passes    = 3,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

--------------------------
------- ANIMATIONS -------
--------------------------
hl.curve( "myBezier", {type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve( "easeInOut", { type = "bezier", points = { {0.65, 0}, {0.35, 1} } })

-- Window
hl.animation({ leaf = "windows", enabled = true, duration = 1, speed = 6, bezier = "myBezier" })
hl.animation({ leaf = "windowsIn", enabled = true, duration = 1, speed = 6, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, duration = 1, speed = 10, bezier = "myBezier" })
hl.animation({ leaf = "windowsMove", enabled = true, duration = 1, speed = 6, bezier = "easeInOut" })

-- Layer
hl.animation({ leaf = "layers", enabled = true, duration = 1, speed = 8, bezier = "myBezier" })
hl.animation({ leaf = "layersIn", enabled = true, duration = 1, speed = 8, bezier = "myBezier" })
hl.animation({ leaf = "layersOut", enabled = true, duration = 1, speed = 14, bezier = "myBezier" })

-- Fade effects
hl.animation({ leaf = "fade", enabled = true, duration = 1, speed = 10, bezier = "default" })
hl.animation({ leaf = "fadeIn", enabled = true, duration = 1, speed = 10, bezier = "default" })
hl.animation({ leaf = "fadeOut", enabled = true, duration = 1, speed = 10, bezier = "default" })
hl.animation({ leaf = "fadeSwitch", enabled = true, duration = 1, speed = 14, bezier = "default" })
hl.animation({ leaf = "fadeShadow", enabled = true, duration = 1, speed = 14, bezier = "default" })
hl.animation({ leaf = "fadeDim", enabled = true, duration = 1, speed = 10, bezier = "default" })
hl.animation({ leaf = "fadePopups", enabled = true, duration = 1, speed = 10, bezier = "default" })

-- DPMS & BORDER
hl.animation({ leaf = "fadeDpms", enabled = true, duration = 1, speed = 20, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, duration = 1, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, duration = 1, speed = 30, bezier = "default", loop = true })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, duration = 1, speed = 8, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, duration = 1, speed = 8, bezier = "myBezier" })
hl.animation({ leaf = "workspacesOut", enabled = true, duration = 1, speed = 8, bezier = "myBezier" })

-- Special workspace
hl.animation({ leaf = "specialWorkspace", enabled = true, duration = 1, speed = 6, bezier = "myBezier", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, duration = 1, speed = 6, bezier = "myBezier" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, duration = 1, speed = 6, bezier = "myBezier" })

-- Others
hl.animation({ leaf = "zoomFactor", enabled = true, duration = 1, speed = 6, bezier = "myBezier" })
hl.animation({ leaf = "monitorAdded", enabled = true, duration = 1, speed = 6, bezier = "myBezier" })



-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.workspace_rule({workspace = "1", persistent = true})
hl.workspace_rule({workspace = "2", persistent = true})
hl.workspace_rule({workspace = "3", persistent = true})
hl.workspace_rule({workspace = "4", persistent = true})
hl.workspace_rule({workspace = "5", persistent = true})

local codeSpecialWorkspace = hl.window_rule({
    name  = "code-scratchpad",
    match = { class = "code" },

    workspace = "special:magic",
})
codeSpecialWorkspace:set_enabled(false) -- Disable this rule for now, as it can be annoying if you don't know how to use the special workspace

hl.layer_rule({match = { namespace = "waybar" }, animations = fade})

hl.window_rule({
    name  = "floating-nemo",
    match = { class = "(?i)nemo" },

    float = true,
    center = true,
    size  = "1280 720",
    opacity = 0.9,
})

hl.window_rule({
    name  = "opacity-for-certain-apps",
    match = { class = "(?i)nemo|code|kitty|jetbrains.*" },

    opacity = 0.8,
})

hl.window_rule({
    name  = "floating-mpv",
    match = { class = "mpv" },

    float = true,
    center = true,
    size  = "1280 720",
})

hl.window_rule({
    name  = "floating-imv",
    match = { class = "imv" },

    float = true,
    center = true,
    size  = "1280 720",
})

---------------------------------------------------------

hl.layer_rule({
    name = "rofi-slide",
    match = { namespace = "rofi" },
    animation = "slide top",
    blur = true,
    blur_popups = true,
})

hl.layer_rule({
    name = "swaync-control-center",
    match = { namespace = "swaync-control-center" },

    animation = "slide right",
})


-- Browser popups like save, etc. should usually be floating
hl.window_rule({
    name  = "xdg-desktop-portal-gtk",
    match = { class = "xdg-desktop-portal-gtk" },

    float = true,
    center = true,
    size  = "600 600",
})


-- Haku Space - Global
hl.window_rule({
    name = "haku-space",
    match = { class = "seyclock|seypipes|seycava|seycmd|seymatrix|seylavat" },

    float = true,
})

-- Haku Space - haku
hl.window_rule({ match = { title = "hakuclock" }, size = "385 450", move = "15 55" })
hl.window_rule({ match = { title = "hakupipes" }, size = "775 545", move = "15 520" })
hl.window_rule({ match = { title = "hakumatrix" }, size = "375 450", move = "415 55" })
hl.window_rule({ match = { title = "hakucmd" }, size = "1100 690", move = "805 55" })
hl.window_rule({ match = { title = "hakulavat" }, size = "1100 305", move = "805 760" })

-- Haku Space - hakunet
hl.window_rule({ match = { title = "hakunetclock" }, size = "300 450", move = "15 55" })
hl.window_rule({ match = { title = "hakunetlavat" }, size = "300 550", move = "15 515" })
hl.window_rule({ match = { title = "hakunetcmd" }, size = "1270 1010", move = "330 55" })
hl.window_rule({ match = { title = "hakunetcava" }, size = "290 1010", move = "1615 55" })

-- Cava Underbar
hl.window_rule({
    name = "cava-underbar",
    match = { class = "cavaunderbar" },

    float = true,
    pin = true,
    border_size = 0,
    rounding = 10,
    rounding_power = 6,
    no_anim = true,
    no_blur = true,
    no_focus = true,
    no_shadow = true,
    opacity = 0.6,
    size = "1920 100",
    move = "0 0",
})
