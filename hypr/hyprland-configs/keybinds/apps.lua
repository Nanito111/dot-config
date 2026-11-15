-- hyprland-configs/keybinds/apps.lua
-- Migrated from keybinds/apps.conf

-- Terminal
hl.bind(MainMod .. " + C",       hl.dsp.exec_cmd("uwsm app -- " .. terminal))
hl.bind(MainMod .. " + SHIFT + C", hl.dsp.exec_cmd("uwsm app -- " .. colorPicker))
hl.bind(MainMod .. " + E",       hl.dsp.exec_cmd("uwsm app -- " .. fileManager))

-- Launchers
hl.bind(MainMod .. " + space",   hl.dsp.exec_cmd("caelestia shell drawers toggle launcher"))
hl.bind(MainMod .. " + Y",       hl.dsp.exec_cmd("uwsm app -- uuctl " .. appLauncher))
hl.bind(MainMod .. " + V",       hl.dsp.exec_cmd("uwsm app -- bash " .. clipboard_history))
hl.bind(MainMod .. " + period",  hl.dsp.exec_cmd("uwsm app -- " .. emoji_picker))

-- Hyprshot / screenshots
hl.bind(MainMod .. " + S",       hl.dsp.global("caelestia:screenshotFreeze"))
hl.bind(MainMod .. " + SHIFT + S", hl.dsp.exec_cmd("caelestia screenshot"))
