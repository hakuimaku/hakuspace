
---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "nemo"
local menu        = "rofi -show drun"
local browser = "zen-browser"

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Bind keys to Hyprland actions and commands
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | tee ~/Pictures/Screenshots/$(date +'%Y%m%d_%H%M%S').png | wl-copy && swappy -f -]]))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd([[grim - | tee ~/Pictures/Screenshots/$(date +'%Y%m%d_%H%M%S').png | wl-copy && swappy -f -]]))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("rofi -modi emoji -show emoji"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ toggle = true }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ toggle = false }))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprsunset --temperature 3000"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("pkill hyprsunset"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))

-- Script keybindings
hl.bind(mainMod .. " + V",    hl.dsp.exec_cmd("~/.local/bin/clip_menu"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.local/bin/clip_menu --wipe"))
hl.bind(mainMod .. " + F11",   hl.dsp.exec_cmd("~/.local/bin/record"))
hl.bind(mainMod .. " + TAB",   hl.dsp.exec_cmd("~/.local/bin/hakumenu"))
hl.bind(mainMod .. " + A",     hl.dsp.exec_cmd("~/.local/bin/waybar_toggle"))
hl.bind(mainMod .. " + K",     hl.dsp.exec_cmd("~/.local/bin/display_select"))
hl.bind(mainMod .. " + Y",     hl.dsp.exec_cmd("~/.local/bin/wallselect"))
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("~/.local/bin/wallmpvselect"))
hl.bind(mainMod .. " + T",     hl.dsp.exec_cmd("~/.local/bin/cava_manager --toggle"))


-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 2%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 2%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })