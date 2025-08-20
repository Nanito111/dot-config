local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local bind = astal.bind

local Notifd = astal.require("AstalNotifd")
local Notification = require("notifications.Notification")
local Hyprland = astal.require("AstalHyprland")
local timeout = astal.timeout

local varmap = require("utils").varmap
local notifd = Notifd.get_default()
notifd.dont_disturb = false

local TIMEOUT_DELAY = 4 * 1000

local function setup_notification(id, notif_map)
    local M = {}
    M.notification_instance = notifd:get_notification(id)
    M.notification_setup = function()
        local t = M.notification_instance.expire_timeout
        if M.notification_instance.expire_timeout < 1000 then
            t = TIMEOUT_DELAY
        end
        timeout(t, function()
            notif_map.delete(id)
        end)
    end

    return M
end

local function NotificationMap()
    local notif_map = varmap({})

    notifd.on_notified = function(_, id)
        if notifd.dont_disturb == true then
            return
        end

        local n = setup_notification(id, notif_map)
        local notification_widget = Notification({
            notification = n.notification_instance,
            in_bar = false,
            setup = n.notification_setup,
        })

        notif_map.set(id, notification_widget)
    end

    notifd.on_resolved = function(_, id)
        timeout(200, function()
            notif_map.delete(id)
        end)
    end

    return notif_map
end

return function(gdkmonitor)
    local Anchor = astal.require("Astal").WindowAnchor
    local notifs = NotificationMap()
    local hypr = Hyprland.get_default()

    return Widget.Window({
        class_name = "NotificationPopups",
        gdkmonitor = gdkmonitor,
        namespace = "astal-notification-blur",
        anchor = Anchor.TOP,
        layer = "OVERLAY",
        visible = bind(hypr, "focused-monitor"):as(function(monitor)
            return monitor.model == gdkmonitor.model
        end),
        Widget.Box({
            vertical = true,
            notifs(),
        }),
    })
end
