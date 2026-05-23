-- hyprland-configs/keybinds/apps.lua
-- Migrated from keybinds/apps.conf

-- Terminal
hl.bind(mainMod .. " + C",       hl.dsp.exec_cmd("uwsm app -- " .. terminal))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("uwsm app -- " .. colorPicker))
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd("uwsm app -- " .. fileManager))

-- Launchers
hl.bind(mainMod .. " + space",   hl.dsp.exec_cmd("caelestia shell drawers toggle launcher"))
hl.bind(mainMod .. " + Y",       hl.dsp.exec_cmd("uwsm app -- uuctl " .. appLauncher))
hl.bind(mainMod .. " + V",       hl.dsp.exec_cmd("uwsm app -- bash " .. clipboard_history))
hl.bind(mainMod .. " + period",  hl.dsp.exec_cmd("uwsm app -- " .. emoji_picker))

-- Hyprshot / screenshots
hl.bind(mainMod .. " + S",       hl.dsp.global("caelestia:screenshotFreeze"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("caelestia screenshot"))
