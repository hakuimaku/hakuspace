

--------------------------
------- ANIMATIONS -------
--------------------------
hl.curve( "myBezier", {type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve( "easeInOut", { type = "bezier", points = { {0.65, 0}, {0.35, 1} } })
hl.curve( "smoothzz", { type = "bezier", points = { {0.1, 0.8}, {0.24, 1} } })

-- Window
hl.animation({ leaf = "windows", enabled = true, duration = 1, speed = 6, bezier = "myBezier", style = "gnomed" })
hl.animation({ leaf = "windowsIn", enabled = true, duration = 1, speed = 6, bezier = "myBezier", style = "gnomed" })
hl.animation({ leaf = "windowsOut", enabled = true, duration = 1, speed = 6, bezier = "myBezier", style = "gnomed" })
hl.animation({ leaf = "windowsMove", enabled = true, duration = 1, speed = 4, bezier = "easeInOut" })

-- Layer
hl.animation({ leaf = "layers", enabled = true, duration = 1, speed = 8, bezier = "myBezier" })
hl.animation({ leaf = "layersIn", enabled = true, duration = 1, speed = 8, bezier = "myBezier" })
hl.animation({ leaf = "layersOut", enabled = true, duration = 1, speed = 8, bezier = "myBezier" })

-- Fade effects
hl.animation({ leaf = "fade", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadeIn", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadeOut", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadeSwitch", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadeShadow", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadeDim", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadePopups", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadePopupsIn", enabled = true, duration = 1, speed = 6, bezier = "default" })
hl.animation({ leaf = "fadePopupsOut", enabled = true, duration = 1, speed = 6, bezier = "default" })

-- DPMS & BORDER
hl.animation({ leaf = "fadeDpms", enabled = true, duration = 1, speed = 20, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, duration = 1, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, duration = 1, speed = 30, bezier = "default", loop = true })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, duration = 1, speed = 10, bezier = "smoothzz", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, duration = 1, speed = 10, bezier = "smoothzz", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, duration = 1, speed = 10, bezier = "smoothzz", style = "slide" })

-- Special workspace
hl.animation({ leaf = "specialWorkspace", enabled = true, duration = 1, speed = 6, bezier = "smoothzz", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, duration = 1, speed = 6, bezier = "smoothzz", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, duration = 1, speed = 8, bezier = "smoothzz", style = "slidevert" })

-- Others
hl.animation({ leaf = "zoomFactor", enabled = true, duration = 1, speed = 6, bezier = "smoothzz" })
hl.animation({ leaf = "monitorAdded", enabled = true, duration = 1, speed = 6, bezier = "smoothzz" })
