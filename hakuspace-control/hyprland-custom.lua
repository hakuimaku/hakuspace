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

-- Example Keybinding:
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))

-- Example Rule:
local thunar_rule = hl.window_rule({
    name  = "thunar-floating",
    match = { class = "thunar" },

    float = true,
    center = true,
    size  = "600 600",
})
thunar_rule:set_enabled(false)
