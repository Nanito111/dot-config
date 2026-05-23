-- hyprland-configs/autostart-and-envs.lua
-- Migrated from autostart-and-envs.conf

-- Autostart
-- NOTE: en Lua se usa hl.on("hyprland.start", ...) o exec_once directamente.
-- execr-once en hyprlang = ejecutar al inicio (y reiniciar si muere).
-- En Lua usamos hl.exec_once para equivalente simple.

hl.on("hyprland.start", function()
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 32")
    hl.exec_cmd("uwsm app -- check-updates")
    hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
    hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")
    hl.exec_cmd("sleep 3 && canberra-gtk-play -i desktop-login")
    hl.exec_cmd("sleep 2 && uwsm app -- openrgb --gui --startminimized --profile 'default'")
    hl.exec_cmd("sleep 2 && uwsm app -t service -- easyeffects --gapplication-service")
end)

-- hl.exec_once("gsettings set org.gnome.desktop.interface cursor-size 32")
-- hl.exec_once("uwsm app -- check-updates")
-- 
-- -- cliphist
-- hl.exec_once("uwsm app -- wl-paste --type text --watch cliphist store")
-- hl.exec_once("uwsm app -- wl-paste --type image --watch cliphist store")
-- hl.exec_once("sleep 3 && canberra-gtk-play -i desktop-login")
-- 
-- -- openrgb / easyeffects (need delay)
-- hl.exec_once("sleep 2 && uwsm app -- openrgb --gui --startminimized --profile 'default'")
-- hl.exec_once("sleep 2 && uwsm app -t service -- easyeffects --gapplication-service")
-- 
-- -- Environment Variables
-- -- (otras variables de entorno están en uwsm/env)
-- hl.env("TERMINAL", terminal)
