
-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

--hl.env("XCURSOR_SIZE", "24")
--hl.env("HYPRCURSOR_SIZE", "24")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Toolkit backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- Input method
--hl.env("XMODIFIERS", "@im=fcitx")
--hl.env("QT_IM_MODULE", "fcitx")
--hl.env("GTK_IM_MODULE", "fcitx")

-- Scale factor
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1") -- Disable if you want to set a custom scale factor with QT_SCALE_FACTOR
--hl.env("QT_SCALE_FACTOR", "1.25")


