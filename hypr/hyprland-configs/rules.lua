-- hyprland-configs/rules.lua
-- Migrated from rules.conf

----------------------------------------
-- WINDOW RULES
----------------------------------------

-- Global: suppress maximize
hl.window_rule({
    name = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Global: no focus for blank xwayland floating windows
hl.window_rule({
    name = "no-focus-blank-xwayland",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Global: no blur except zen, thunar, Thunar
hl.window_rule({
    name = "no-blur-most",
    match = { class = "^(?!zen$|thunar$|Thunar$).*$" },
    no_blur = true,
})

-- checkupdates (foot)
hl.window_rule({
    name = "checkupdates-workspace",
    match = { initial_title = "^System Update$", initial_class = "^foot$" },
    workspace = "special:magic",
})
hl.window_rule({
    name = "checkupdates-pseudo",
    match = { initial_title = "^System Update$", initial_class = "^foot$" },
    pseudo = true,
})
hl.window_rule({
    name = "checkupdates-size",
    match = { initial_title = "^System Update$", initial_class = "^foot$" },
    size = { 1064, 902 },
})

-- postman save file
hl.window_rule({
    name = "postman-save-float",
    match = { initial_class = "^postman$", initial_title = "^Select path to save file$" },
    float = true,
    size  = { 900, 600 },
})

-- postman open file
hl.window_rule({
    name = "postman-open-float",
    match = { initial_class = "^postman$", initial_title = "^Open Files$" },
    float = true,
    size  = { 900, 600 },
})

-- xdg-desktop-portal-gtk open file
hl.window_rule({
    name = "xdg-portal-open-float",
    match = { initial_class = "^xdg-desktop-portal-gtk$", initial_title = "^Open Files$" },
    float = true,
    size  = { 900, 600 },
})

-- signal open file
hl.window_rule({
    name = "signal-open-float",
    match = { initial_class = "^signal-desktop$", initial_title = "^Open Files$" },
    float = true,
    size  = { 900, 600 },
})

-- slack open file
hl.window_rule({
    name = "slack-open-float",
    match = { initial_class = "^slack$", initial_title = "^Open Files$" },
    float = true,
    size  = { 900, 600 },
})

-- slack main window
hl.window_rule({
    name = "slack-no-screen-share",
    match = { initial_class = "Slack", initial_title = "Slack", class = "Slack" },
    no_screen_share = true,
})

-- bitwarden
hl.window_rule({
    name = "bitwarden-no-screen-share",
    match = { initial_class = "Bitwarden", initial_title = "Bitwarden", class = "Bitwarden", title = "Bitwarden" },
    no_screen_share = true,
})

-- thunar rename
hl.window_rule({
    name = "thunar-rename-float",
    match = { initial_class = "thunar", initial_title = [[^Rename ".+"$]] },
    float = true,
    size  = { 500, 200 },
})

-- dbeaver splash
hl.window_rule({
    name = "dbeaver-splash",
    match = { initial_class = "java", initial_title = "Dbeaver" },
    float            = true,
    size             = { 600, 300 },
    keep_aspect_ratio = true,
    center           = true,
    border_size      = 0,
})

-- zen picture in picture
hl.window_rule({
    name = "zen-pip",
    match = { initial_class = "zen", initial_title = "Picture-in-Picture" },
    float             = true,
    keep_aspect_ratio = true,
    no_anim           = true,
    rounding          = 0,
    size              = { 1280, 720 },
})

-- waterfox picture in picture
hl.window_rule({
    name = "waterfox-pip",
    match = { initial_class = "waterfox", initial_title = "Picture-in-Picture" },
    float             = true,
    keep_aspect_ratio = true,
    no_anim           = true,
    rounding          = 0,
    size              = { 1280, 720 },
})

-- steam games
hl.window_rule({
    name    = "steam-games",
    match   = { class = "^steam_app_%d+$" },
    monitor = "HDMI-A-1",
    workspace = "5",
    content = "game",
    opaque  = true,
    no_anim = true,
    immediate = true,
})

-- gamescope
hl.window_rule({
    name    = "gamescope",
    match   = { class = "gamescope" },
    monitor = "HDMI-A-1",
    workspace = "5",
    content = "game",
    opaque  = true,
    no_anim = true,
    immediate = true,
})

----------------------------------------
-- WORKSPACE RULES
----------------------------------------

-- Games workspace
hl.workspace_rule({
    workspace  = "5",
    monitor    = "HDMI-A-1",
    no_border    = true,
    no_rounding  = true,
    decorate   = false,
    no_shadow     = true,
    persistent = false,
    gaps_in    = 0,
    gaps_out   = 0,
})

-- Regular workspaces
hl.workspace_rule({ workspace = "1",  monitor = "HDMI-A-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "2",  monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "3",  monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "4",  monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "7",  monitor = "DVI-D-1",  default = true, persistent = true })
hl.workspace_rule({ workspace = "8",  monitor = "DVI-D-1",  persistent = true })
hl.workspace_rule({ workspace = "9",  monitor = "DVI-D-1",  persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "DVI-D-1",  persistent = true })

----------------------------------------
-- LAYER RULES
----------------------------------------

-- hyprpicker / selection
hl.layer_rule({ name = "hyprpicker-no-anim", match = { namespace = "hyprpicker" }, no_anim = true })
hl.layer_rule({ name = "selection-no-anim",  match = { namespace = "selection" },  no_anim = true })

-- fuzzel
hl.layer_rule({ name = "launcher-blur",         match = { namespace = "launcher" }, blur = true })
hl.layer_rule({ name = "launcher-ignore-alpha",  match = { namespace = "launcher" }, ignore_alpha = 0.8 })

-- hyprpaper
hl.layer_rule({ name = "hyprpaper-fade", match = { namespace = "hyprpaper" }, animation = "fade" })
