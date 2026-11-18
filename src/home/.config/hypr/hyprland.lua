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

-- Apply active mode style overrides before user custom config.
local style_ok, style = pcall(dofile, os.getenv("HOME") .. "/.local/state/hakuspace/theme/hyprland-style.lua")
if style_ok and type(style) == "table" and type(style.apply) == "function" then
    style.apply()
end

-- User custom config file.
local ok, custom = pcall(require, "../../hakucfg/wm/hyprland-custom")
if not ok then
    hl.dispatch(hl.dsp.exec_cmd("notify-send 'Hyprland' 'Load custom config failed' -t 5000"))
end
