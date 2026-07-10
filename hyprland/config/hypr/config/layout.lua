-------------------------------------
-------------- LAYOUT  --------------
-------------------------------------

hl.config({
    general = {
        layout = "scrolling",
    },
})


-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true,
        special_scale_factor = 0.95
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
        new_on_top = true,
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = false,
        column_width = 0.5,
    },
})