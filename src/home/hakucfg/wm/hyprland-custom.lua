--      __  __                 __                __
--     / / / /_  ______  _____/ /___ _____  ____/ /
--    / /_/ / / / / __ \/ ___/ / __ `/ __ \/ __  / 
--   / __  / /_/ / /_/ / /  / / /_/ / / / / /_/ /  
--  /_/ /_/\__, / .___/_/  /_/\__,_/_/ /_/\__,_/   
--        /____/_/     

-- This is a Hyprland custom configuration file (small hyprland.lua actually :p)
-- You can add keybindings, rules, and other configurations here.

-- Why you should custom your config in there?
-- Because for each update, my dotfiles will override your all custom configurations.

-- After changes, please reload Hyprland by `hyprctl reload` on terminal

-- See more in the Wiki: https://wiki.hypr.land/

-- Example Rule:
local thunar_rule = hl.window_rule({
    name  = "thunar-floating",
    match = { class = "thunar" },

    float = true,
    center = true,
    size  = "600 600",
})
thunar_rule:set_enabled(false) -- You can enable/disable rules

-- On/off rules. See more in ~/.config/hypr/config/rule.lua
fullWidth_ScrollingLayout:set_enabled(true) -- Set width 100% for certain apps
specificWidth_ScrollingLayout:set_enabled(true) -- Set width 60% for certain apps

-- Use my plugin config: (require hyprexpo | Make sure you have hyprexpo installed & enabled)
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
-- hl.on("hyprland.start", function () hl.exec_cmd("hyprpm reload -n && hyprctl reload") end)
-- hl.bind("SUPER + G", function() hl.plugin.hyprexpo.expo("toggle") end)
-- require("config/plugin")

-- Example change keybind for SUPER + E
-- hl.unbind("SUPER + E") -- Unbind SUPER + E: Thunar open (Based on my default config)
-- hl.bind("SUPER + E", hl.dsp.exec_cmd("discord")) -- Bind SUPER + E: Discord open (Bind new command)

-- hl.unbind("SUPER + B")
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("zen-browser"))

-- Use this mouse wheel to switch workspace if there is reverse scrolling issue
-- hl.unbind("SUPER + mouse_down")
-- hl.unbind("SUPER + mouse_up")
-- hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "r-1" }))
-- hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "r+1" }))

-- Hyprland bring back my old rounding and shadow
-- hl.config({
--     decoration = {
--         rounding       = 16,
--         rounding_power = 4,

--         shadow = {
--             enabled      = true,
--             range        = 16,
--             render_power = 8,
--             sharp        = false,
--             offset       = { 6, 6 },
--             color        = "rgba(000000cc)",
--         },
--     },
-- })

-- hl.monitor({
--     output   = "",
--     mode     = "1280x720@60",
--     position = "auto",
--     scale    = "1",
-- })
