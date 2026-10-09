--    __  __                      _                 _ 
--   / / / /_  ______  _________ / /___ _____  ____/ /
--  / /_/ / / / / __ \/ ___/ __  / __  / __ \/ __  / 
-- / __  / /_/ / /_/ / /  / /_/ / /_/ / / / / /_/ /  
--/_/ /_/\__, / .___/_/   \__,_/\__,_/_/ /_/\__,_/   
--      /____/_/                                     

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    --mode     = "1280x720@60",
    position = "auto",
    scale    = "1",
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "0x0",
    scale    = "1",
    mirror   = "eDP-1",
})



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
hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")



local config_dir = os.getenv("HOME") .. "/.config/hypr/config/"
dofile(config_dir .. "config.lua") -- include: input, misc, layout, desgin,...
dofile(config_dir .. "autostart.lua")
dofile(config_dir .. "environment.lua")
dofile(config_dir .. "animation.lua")
dofile(config_dir .. "keybinding.lua")
dofile(config_dir .. "windowrule.lua")

-- Load plugin configuration
local plugin_file = config_dir .. "plugin.lua"
pcall(function() dofile(plugin_file) end)