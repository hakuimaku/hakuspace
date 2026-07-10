hl.config({
    plugin = {
        hyprexpo = {
            columns = 3,
            gaps_in = 20,
            gaps_out = 20,
            border_width = 4,
            workspace_method = "current current",
            gesture_distance = 500,
            cancel_key = "escape",

            show_cursor = 1,
            max_workspace = 9,
            show_pinned_windows = 1,
            tile_rounding = 12,

            label_font_size = font_size,
            label_font_family = font_family,
            border_color_hover = border_color,
        },
    },
})


-- hyprexpo
hl.define_submap("hyprexpo", function()
    hl.bind("left",   function() hl.plugin.hyprexpo.kb_focus("left") end)
    hl.bind("right",  function() hl.plugin.hyprexpo.kb_focus("right") end)
    hl.bind("up",     function() hl.plugin.hyprexpo.kb_focus("up") end)
    hl.bind("down",   function() hl.plugin.hyprexpo.kb_focus("down") end)
    hl.bind("return", function() hl.plugin.hyprexpo.kb_confirm() end)
    hl.bind("escape", function() hl.plugin.hyprexpo.expo("cancel") end)
end)

-- hyprfocus
hl.animation({ leaf = "hyprfocusIn", enabled = true, duration = 1, speed = 10, bezier = "default" })
hl.animation({ leaf = "hyprfocusOut", enabled = true, duration = 1, speed = 30, bezier = "default" })

hl.config({
    plugin = {
        hyprfocus = {
        },
    },
})

