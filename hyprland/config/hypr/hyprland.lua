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


-------------------------
--- LOAD CONFIG FILES ---
-------------------------

require("config/config")
require("config/autostart")
require("config/environment")
require("config/animation")
require("config/keybinding")
require("config/rule")
require("config/layout")

-- uncomment this line to load the plugin config file.
-- disable this by default to avoid errors if you don't have any plugins installed.

--require("config/plugin")