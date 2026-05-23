-- hyprland-configs/look-and-feel.lua
-- Migrated from look-and-feel.conf
--
-- NOTE sobre colores: los valores $primary, $surface_bright, etc. venían de colors.conf.
-- Debes reemplazarlos con los valores reales de tu colors.conf (o importarlos desde colors.lua).
-- Ejemplo: col.active_border = primary  (si definiste `primary` como variable global en colors.lua)

hl.config({
    general = {
        gaps_in    = 3,
        gaps_out   = 4,
        border_size = 1,

        col = {
            -- Reemplaza con tus valores reales de colors.conf:
            active_border   = { colors = { primary } },
            inactive_border = { colors = { surface_bright } },
        },

        resize_on_border = false,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding = 10,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range   = 4,
            sharp   = false,
            offset  = { 0, 1 },
            -- NOTA: shadow:ignore_window fue removido en 0.55 (ahora siempre activo).
            -- color: reemplaza con tu valor real de $shadow
            color   = shadow,
        },

        blur = {
            enabled           = true,
            new_optimizations = true,
            ignore_opacity    = true,
            xray              = false,
            size              = 5,
            passes            = 2,
            brightness        = 0.8,
            noise             = 0,
        },
    },

    master = {
        new_status = "master",
    },

    misc = {
        middle_click_paste      = false,
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        font_family             = "JetBrainsMono Nerd Font",
    },
})

-- Animations
hl.config({
    animations = {
        enabled            = true,
        workspace_wraparound = true,
    },
})

-- Bezier curves
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1.00}, {0.32, 1.00} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1.00} } })
hl.curve("linear",         { type = "bezier", points = { {0.00, 0.00}, {1.00, 1.00} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.50, 0.50}, {0.75, 1.00} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0.00}, {0.10, 1.00} } })
hl.curve("easeOutBack",    { type = "bezier", points = { {0.68,-0.55}, {0.27, 1.55} } })
hl.curve("easeInBack",     { type = "bezier", points = { {0.60,-0.28}, {0.74, 0.05} } })
hl.curve("easeInOutBack",  { type = "bezier", points = { {0.68,-0.55}, {0.27, 1.55} } })
hl.curve("easeOutCirc",    { type = "bezier", points = { {0.08, 0.82}, {0.17, 1.00} } })

-- Animations
hl.animation({ leaf = "global",          enabled = true,  speed = 3.00, bezier = "default" })
hl.animation({ leaf = "windowsIn",       enabled = true,  speed = 1.50, bezier = "quick",       style = "gnome" })
hl.animation({ leaf = "windowsOut",      enabled = true,  speed = 1.50, bezier = "quick",       style = "gnome" })
hl.animation({ leaf = "windowsMove",     enabled = true,  speed = 1.50, bezier = "quick" })
hl.animation({ leaf = "fadeIn",          enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",         enabled = true,  speed = 1.00, bezier = "almostLinear" })
hl.animation({ leaf = "fade",            enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layersIn",        enabled = true,  speed = 0.80, bezier = "quick",       style = "popin" })
hl.animation({ leaf = "layersOut",       enabled = true,  speed = 0.30, bezier = "quick",       style = "fade" })
hl.animation({ leaf = "workspaces",      enabled = true,  speed = 1.50, bezier = "quick",       style = "slide" })
hl.animation({ leaf = "specialWorkspace",enabled = true,  speed = 1.50, bezier = "almostLinear",style = "fade" })
hl.animation({ leaf = "zoomFactor",      enabled = true,  speed = 1.60, bezier = "easeOutCirc" })
hl.animation({ leaf = "monitorAdded",    enabled = true,  speed = 3.00, bezier = "easeInOutCubic" })

-- Groups
hl.config({
    group = {
        col = {
            border_active          = { colors = { primary } },
            border_inactive        = { colors = { surface_bright } },
            border_locked_active   = { colors = { tertiary } },
            border_locked_inactive = { colors = { tertiary_container } },
        },

        groupbar = {
            text_color               = background,
            text_color_inactive      = primary,
            text_color_locked_active = background,
            text_color_locked_inactive = tertiary_container,
            font_size                = 12,
            font_weight_active       = "medium",
            font_weight_inactive     = "light",

            gradients                = true,
            col = {
                active         = { colors = { primary } },
                inactive       = { colors = { background } },
                locked_active  = { colors = { tertiary } },
                locked_inactive = { colors = { background } },
            },

            height           = 18,
            indicator_height = false,
            rounding         = false,
            gradient_rounding       = 7,
            gradient_rounding_power = 2,

            gaps_in        = 0,
            gaps_out       = 3,
            keep_upper_gap = false,
        },
    },
})
