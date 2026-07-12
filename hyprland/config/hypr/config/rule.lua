
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Set workspaces to be persistent, they are not destroyed when empty
hl.workspace_rule({ workspace = "1", persistent = true })
hl.workspace_rule({ workspace = "2", persistent = true })
hl.workspace_rule({ workspace = "3", persistent = true })
hl.workspace_rule({ workspace = "4", persistent = true })
hl.workspace_rule({ workspace = "5", persistent = true })

local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

local fixXwaylandDrags = hl.window_rule({
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

-- Hyprland-run windowrule
local hyprlandRunRule = hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- VS Code in special workspace
local codeSpecialWorkspace = hl.window_rule({
    name  = "code-scratchpad",
    match = { class = "code" },

    workspace = "special:magic",
})

-- Set border color to red if window is fullscreen
local fullscreenBorder = hl.window_rule({
    name  = "fullscreen-border-color",
    match        = { fullscreen = true },

    border_color = "rgb(FF0000) rgb(880808)",
})


--------------------------------
------- SCROLLING LAYOUT -------
--------------------------------

local fullWidth_ScrollingLayout = hl.window_rule({
    name = "full_width_scrolling",
    match = { class = "code|zen" },

    scrolling_width = 1.0
})

local specificWidth_ScrollingLayout = hl.window_rule({
    name = "specific_width_scrolling",
    match = { class = "thunar" },

    scrolling_width = 0.6
})

--------------------------------
----------- OPACITY ------------
--------------------------------
local opacityCertainApps = hl.window_rule({
    name  = "opacity-for-certain-apps",
    match = { class = "thunar|kitty|code|jetbrains.*" },

    opacity = 0.8,
})

-- Rules for haku.sh
local hakuSpaceOpacityRule = hl.window_rule({
    name  = "opacity-haku",
    match = { class = "seycmd|seyclock|seylavat|seycava" },

    opacity = 0.7,
})

----------------------------------
----------- ANIMATIONS -----------
----------------------------------
-- Animation for Rofi
local rofiAnimation = hl.layer_rule({
    name = "rofi-slide",
    match = { namespace = "rofi" },

    animation = "slide top",
    blur = true,
})
-- Animation for Waybar
local waybarAnimation = hl.layer_rule({
    name = "waybar-fade",
    match = { namespace = "waybar" },

    animation = "fade",
})
-- Slide for Swaync
local swayncAnimation = hl.layer_rule({
    name = "swaync-control-center",
    match = { namespace = "swaync-control-center" },

    animation = "slide right",
})

-------------------------------------------------
----------- Floating window for apps ------------
-------------------------------------------------
local floatingCenter = hl.window_rule({
    name  = "floating-center",
    match = { class = "imv|mpv|org.gnome.Calculator" },

    float = true,
    size  = "1280 720",
})

local floatingApps = hl.window_rule({
    name  = "floating-apps",
    match = { title = "Picture-in-Picture" },

    float = true,
})

-- Browser popups like save, etc. should usually be floating
local floatingXdgPortal = hl.window_rule({
    name  = "xdg-desktop-portal-gtk",
    match = { class = "xdg-desktop-portal-gtk" },

    float = true,
    center = true,
    size  = "600 600",
})

---------------------------------
------- Haku Space Rules --------
---------------------------------
-- Rules for cava-underbar
hl.window_rule({
    name = "cava-underbar",
    match = { class = "cavaunderbar" },

    float = true,
    pin = true,
    border_size = 0,
    no_blur = true,
    no_focus = true,
    no_shadow = true,
    opacity = 0.5,
    size = "1920 60",
    move = "0 0",
})

-- Rules for haku.sh | scrolling layout
hl.window_rule({
    name = "haku-left",
    match = { class = "seycmd" },
    scrolling_width = 0.6,
})

hl.window_rule({
    name = "haku-right",
    match = { class = "seyclock|seylavat|seycava" },
    scrolling_width = 0.4,
})



---------------------------------------
---------- Turn on/off rules ----------
---------------------------------------
-- Hyprland useful rules, why not?
suppressMaximizeRule:set_enabled(true)
hyprlandRunRule:set_enabled(true)
fixXwaylandDrags:set_enabled(true)

codeSpecialWorkspace:set_enabled(true) -- VS Code in special workspace (SUPER + `)
fullscreenBorder:set_enabled(true) -- Red border for fullscreen windows

-- Scrolling layout rules
fullWidth_ScrollingLayout:set_enabled(true) -- Set width 100% for certain apps
specificWidth_ScrollingLayout:set_enabled(true) -- Set width 60% for certain apps

-- Opacity rules
opacityCertainApps:set_enabled(true) -- Specific apps opacity
hakuSpaceOpacityRule:set_enabled(true) -- haku.sh kitty opacity

-- Animation rules
rofiAnimation:set_enabled(true)
waybarAnimation:set_enabled(true)
swayncAnimation:set_enabled(true)

-- Floating window rules
floatingCenter:set_enabled(true) -- Floating Centered apps (mpv, imv, calculator)
floatingApps:set_enabled(true) -- Floating apps (pavucontrol)
floatingXdgPortal:set_enabled(true) -- Floating xdg-desktop-portal-gtk (save, open, etc.)