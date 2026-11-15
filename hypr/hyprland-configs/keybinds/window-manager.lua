-- hyprland-configs/keybinds/window-manager.lua
-- Migrated from keybinds/window-manager.conf

hl.bind(MainMod .. " + Q",   hl.dsp.window.close())
hl.bind(MainMod .. " + F",   hl.dsp.window.float({ action = "toggle" }))
hl.bind(MainMod .. " + G",   hl.dsp.window.pseudo())
hl.bind(MainMod .. " + X",   hl.dsp.layout("togglesplit"))   -- dwindle
hl.bind(MainMod .. " + F11", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Move focus (vim keys)
hl.bind(MainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(MainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(MainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(MainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- Move focus (mouse scrolling)
hl.bind(MainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ direction = "l" }))
hl.bind(MainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ direction = "r" }))

-- Move window (vim keys)
hl.bind(MainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l", group_aware = true }))
hl.bind(MainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r", group_aware = true }))
hl.bind(MainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u", group_aware = true }))
hl.bind(MainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d", group_aware = true }))

-- Move/resize with mouse
hl.bind(MainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(MainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Switch workspaces
hl.bind(MainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(MainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(MainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(MainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(MainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(MainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(MainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(MainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(MainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Scroll through workspaces on monitor
hl.bind(MainMod .. " + CONTROL + H", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(MainMod .. " + CONTROL + L", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(MainMod .. " + CONTROL + mouse_up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(MainMod .. " + CONTROL + mouse_down",   hl.dsp.focus({ workspace = "m+1" }))

-- Move window to workspace
hl.bind(MainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(MainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(MainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(MainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(MainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(MainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(MainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(MainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(MainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(MainMod .. " + SHIFT + CONTROL + H", hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(MainMod .. " + SHIFT + CONTROL + L", hl.dsp.window.move({ workspace = "m+1" }))

-- Special workspace (scratchpad)
hl.bind(MainMod .. " + A",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(MainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:magic" }))

-- Window groups
hl.bind(MainMod .. " + T",         hl.dsp.group.toggle())
hl.bind(MainMod .. " + SHIFT + T", hl.dsp.group.lock({ action = "toggle" }))

-- Change group tab
hl.bind(MainMod .. " + ALT + L",         hl.dsp.group.next(), { repeating = true })
hl.bind(MainMod .. " + ALT + mouse_up",  hl.dsp.group.next())
hl.bind(MainMod .. " + ALT + H",         hl.dsp.group.prev(), { repeating = true })
hl.bind(MainMod .. " + ALT + mouse_down",hl.dsp.group.prev())
