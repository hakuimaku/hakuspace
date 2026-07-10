
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


---------------------------------------------
---------- WINDOWS AND WORKSPACES -----------
---------------------------------------------

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


local codeSpecialWorkspace = hl.window_rule({
    name  = "code-scratchpad",
    match = { class = "code" },

    workspace = "special:magic",
})
codeSpecialWorkspace:set_enabled(true) -- Disable this rule for now, as it can be annoying if you don't know how to use the special workspace

hl.workspace_rule({ workspace = "1", persistent = true })
hl.workspace_rule({ workspace = "2", persistent = true })
hl.workspace_rule({ workspace = "3", persistent = true })
hl.workspace_rule({ workspace = "4", persistent = true })
hl.workspace_rule({ workspace = "5", persistent = true })

-- Set border color to red if window is fullscreen
hl.window_rule({
  match        = { fullscreen = true },
  border_color = "rgb(FF0000) rgb(880808)",
})


--------------------------------
------- SCROLLING LAYOUT -------
--------------------------------

hl.window_rule({
    name = "full_width_scrolling",
    match = { class = "code|zen" },

    scrolling_width = 1.0
})

hl.window_rule({
    name = "specific_width_scrolling",
    match = { class = "thunar" },

    scrolling_width = 0.6
})

--------------------------------
----------- OPACITY ------------
--------------------------------
hl.window_rule({
    name  = "opacity-for-certain-apps",
    match = { class = "thunar|kitty|code|jetbrains.*" },

    opacity = 0.8,
})

-- Haku
hl.window_rule({
    name  = "opacity-haku",
    match = { class = "seycmd|seyclock|seylavat|seycava" },

    opacity = 0.7,
})

----------------------------------
----------- ANIMATIONS -----------
----------------------------------
-- Animation for Rofi
hl.layer_rule({
    name = "rofi-slide",
    match = { namespace = "rofi" },

    animation = "slide top",
    blur = true,
})
-- Animation for Waybar
hl.layer_rule({
    match = { namespace = "waybar" },
    
    animations = fade
})
-- Slide for Swaync
hl.layer_rule({
    name = "swaync-control-center",
    match = { namespace = "swaync-control-center" },

    animation = "slide right",
})

-------------------------------------------------
----------- Floating window for apps ------------
-------------------------------------------------
hl.window_rule({
    name  = "floating-imv",
    match = { class = "imv" },

    float = true,
    center = true,
    size  = "1280 720",
})

hl.window_rule({
    name  = "floating-mpv",
    match = { class = "mpv" },

    float = true,
    center = true,
    size  = "1280 720",
})

hl.window_rule({
    name = "float-calculator",
    match = { class = "org.gnome.Calculator" },

    float = true,
    move = "10 55",
    size = "600 800",
})

-- Browser popups like save, etc. should usually be floating
hl.window_rule({
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

