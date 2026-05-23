-- hyprland.lua
-- Migrated from hyprlang (0.54) to Lua (0.55+)

require("colors")
require("hyprland-configs/monitors")
require("hyprland-configs/programs")
require("hyprland-configs/autostart-and-envs")
require("hyprland-configs/look-and-feel")
require("hyprland-configs/input")
require("hyprland-configs/keybinds/init")
require("hyprland-configs/rules")

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
    debug = {
        full_cm_proto = true,
    },
})
