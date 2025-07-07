local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local bind = astal.bind

local Notifd = astal.require("AstalNotifd")
local Notification = require("notifications.Notification")
local Hyprland = astal.require("AstalHyprland")
local timeout = astal.timeout

local varmap = require("../lib").varmap
local notifd = Notifd.get_default()

-- notifd.ignore_timeout = true
local TIMEOUT_DELAY = 4000

local function NotificationMap()
	local notif_map = varmap({})

	notifd.on_notified = function(_, id)
		notif_map.set(
			id,
			Notification({
				notification = notifd:get_notification(id),
				setup = function()
					local notification = notifd:get_notification(id)
					if notification.expire_timeout < 1000 then
						timeout(TIMEOUT_DELAY, function()
							notif_map.delete(id)
						end)
					else
						timeout(notification.expire_timeout, function()
							notif_map.delete(id)
						end)
					end
				end,
			})
		)
	end

	notifd.on_resolved = function(_, id)
		notif_map.delete(id)
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
		anchor = Anchor.TOP,
		visible = bind(hypr, "focused-monitor"):as(function(monitor)
			return monitor.model == gdkmonitor.model
		end),
		Widget.Box({
			vertical = true,
			notifs(),
		}),
	})
end
