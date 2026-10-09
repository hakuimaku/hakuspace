--      __  __                 __                __
--     / / / /_  ______  _____/ /___ _____  ____/ /
--    / /_/ / / / / __ \/ ___/ / __ `/ __ \/ __  / 
--   / __  / /_/ / /_/ / /  / / /_/ / / / / /_/ /  
--  /_/ /_/\__, / .___/_/  /_/\__,_/_/ /_/\__,_/   
--        /____/_/     

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

-- User custom config file.
local custom_dir = os.getenv("HOME") .. "/hakuspace-control/"
local ok, custom = pcall(dofile, custom_dir .. "hyprland-custom.lua")
if not ok then
    hl.dispatch(hl.dsp.exec_cmd("notify-send 'Hyprland' 'Load custom config failed' -t 5000"))
end