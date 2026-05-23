-- hyprland-configs/keybinds/window-manager.lua
-- Migrated from keybinds/window-manager.conf

hl.bind(mainMod .. " + Q",   hl.dsp.window.close())
hl.bind(mainMod .. " + F",   hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + G",   hl.dsp.window.pseudo())
hl.bind(mainMod .. " + X",   hl.dsp.layout("togglesplit"))   -- dwindle
hl.bind(mainMod .. " + F11", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Move focus (vim keys)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- Move window (vim keys)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l", group_aware = true }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r", group_aware = true }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u", group_aware = true }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d", group_aware = true }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Switch workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Scroll through workspaces on monitor
hl.bind(mainMod .. " + CONTROL + H", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + L", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m+1" }))

-- Move window to workspace
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(mainMod .. " + SHIFT + CONTROL + H", hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + SHIFT + CONTROL + L", hl.dsp.window.move({ workspace = "m+1" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + A",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:magic" }))

-- Window groups
hl.bind(mainMod .. " + T",         hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.group.lock_active({ action = "toggle" }))

-- Change group tab
hl.bind(mainMod .. " + ALT + L",         hl.dsp.group.next(), { repeating = true })
hl.bind(mainMod .. " + ALT + mouse_up",  hl.dsp.group.next())
hl.bind(mainMod .. " + ALT + H",         hl.dsp.group.prev(), { repeating = true })
hl.bind(mainMod .. " + ALT + mouse_down",hl.dsp.group.prev())
