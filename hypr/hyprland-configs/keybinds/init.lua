-- hyprland-configs/keybinds/init.lua
-- Migrated from keybinds/init.conf

MainMod = "SUPER"

hl.config({
    binds = {
        scroll_event_delay = false,
    },
})

require("hyprland-configs/keybinds/apps")
require("hyprland-configs/keybinds/window-manager")
require("hyprland-configs/keybinds/system")
