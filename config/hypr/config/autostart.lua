
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
    hl.exec_cmd("swaync")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hyprsunset --temperature 3000")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sway-audio-idle-inhibit")
    hl.exec_cmd("~/.local/bin/waybar_toggle")
    hl.exec_cmd("~/.local/bin/cava_manager")
    hl.exec_cmd("~/.local/bin/random_wallpaper.sh")
    hl.exec_cmd("~/.local/bin/welcome")
    hl.exec_cmd("hyprpm reload -n")
end)

