local astal = require("astal")
local astal_gtk3 = require("astal.gtk3")
local Gtk = require("astal.gtk3").Gtk
local Widget = astal_gtk3.Widget
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor
local Notifd = astal.require("AstalNotifd")
local bind = require("astal").bind
local map = require("../lib").map
local time = require("../lib").time
local file_exists = require("../lib").file_exists

local notifd = Notifd.get_default()

local function NotificationItem(notification)
	local header = Widget.Box({
		class_name = "header",
		bind(notification, "app-icon"):as(function(app_icon)
			if string.gsub(app_icon, "%s+", "") ~= "" then
				return Widget.Icon({
					class_name = "app-icon",
					icon = app_icon,
				})
			end
		end),
		Widget.Label({
			class_name = "app-name",
			halign = "START",
			ellipsize = "END",
			label = notification.app_name or "Unknown",
		}),
		Widget.Label({
			class_name = "time",
			hexpand = true,
			halign = "END",
			label = time(notification.time),
		}),
		Widget.Button({
			on_clicked = function()
				notification:dismiss()
			end,
			Widget.Icon({ icon = "window-close-symbolic" }),
		}),
	})

	local content = Widget.Box({
		class_name = "content",
		(notification.image and file_exists(notification.image)) and Widget.Box({
			valign = "START",
			class_name = "image",
			css = string.format("background-image: url('%s')", notification.image),
		}),
		Widget.Box({
			vertical = true,
			Widget.Label({
				class_name = "summary",
				halign = "START",
				xalign = 0,
				ellipsize = "END",
				label = notification.summary,
			}),
			Widget.Label({
				class_name = "body",
				wrap = true,
				use_markup = true,
				halign = "START",
				xalign = 0,
				justify = "FILL",
				label = notification.body,
			}),
			Widget.Box({
				class_name = "actions",
				hexpand = true,
				halign = "END",
				map(notification.actions, function(action)
					local label, id = string.lower(action.label), action.id

					return Widget.Button({
						-- hexpand = true,
						on_clicked = function()
							return notification:invoke(id)
						end,
						Widget.Label({
							label = label,
							halign = "CENTER",
							-- hexpand = true,
						}),
					})
				end),
			}),
		}),
	})

	return Widget.Box({
		class_name = string.format("notification-item %s", string.lower(notification.urgency)),
		vertical = true,
		header,
		Gtk.Separator({ visible = true }),
		content,
	})
end

local function NotificationList(notifications)
	return Widget.Scrollable({
		hscroll = "NEVER",
		vscroll = "AUTOMATIC",
		vexpand = true,
		hexpand = true,
		Widget.Box({
			class_name = "scroll-content",
			hexpand = true,
			vexpand = true,
			vertical = true,
			map(notifications, function(n)
				return NotificationItem(n)
			end),
		}),
	})
end

local function NotificationCenter()
	return Widget.Box({
		class_name = "NotificationCenter-panel",
		vertical = true,
		Widget.Label({
			class_name = "title",
			label = "notifications",
			halign = "CENTER",
			hexpand = true,
		}),
		bind(notifd, "notifications"):as(function(notifications)
			if #notifications < 1 then
				return Widget.Label({
					class_name = "no-notifications",
					label = "your notification center is empty :)",
					hexpand = true,
					vexpand = true,
				})
			end
			table.sort(notifications, function(a, b)
				return a.time > b.time
			end)
			return NotificationList(notifications)
		end),
		-- Widget.Button({
		-- 	class_name = "dnd",
		-- 	label = bind(notifd, "dont-disturb"):as(function(dnd)
		-- 		return dnd == true and "Do Not Disturb is enabled" or "Do Not Disturb is disabled"
		-- 	end),
		-- 	on_clicked = function()
		-- 			notifd.dont_disturb = not notifd.dont_disturb
		-- 		end
		-- 	end,
		-- 	-- Widget.Icon({
		-- 	-- 	icon = bind(notifd, "dont-disturb"):as(function(dnd)
		-- 	-- 		if dnd then
		-- 	-- 			return "notifications-disabled-symbolic"
		-- 	-- 		end
		-- 	-- 		return "notifications-symbolic"
		-- 	-- 	end),
		-- 	-- }),
		-- }),
	})
end

return function(gdkmonitor)
	local notification_center = Widget.Window({
		setup = function(self)
			self:hide()
		end,
		class_name = "NotificationCenter",
		gdkmonitor = gdkmonitor,
		layer = "TOP",
		anchor = WindowAnchor.BOTTOM + WindowAnchor.LEFT,
		margin_bottom = -10,
		margin_left = 95,
		Widget.EventBox({
			on_hover_lost = function(self)
				local parent = self:get_parent()
				if parent:is_visible() then
					parent:hide()
				end
			end,
			NotificationCenter(),
		}),
	})
	return Widget.Button({
		class_name = bind(notifd, "notifications"):as(function(n)
			local style_class = "ShowNotificationCenter"
			if #n < 1 then
				style_class = style_class .. " " .. "no-notifications"
			end
			return style_class
		end),
		on_clicked = function()
			if notification_center:is_visible() then
				notification_center:hide()
			else
				notification_center:show()
			end
		end,
		Widget.Icon({
			tooltip_text = bind(notifd, "notifications"):as(function(n)
				if #n == 1 then
					return "you have 1 notification"
				end
				if #n > 1 then
					return string.format("you have %s notifications", #n)
				end
				return "no notifications"
			end),
			-- icon = "notifications-symbolic",
			icon = bind(notifd, "notifications"):as(function(n)
				if #n > 0 then
					return "notifications-new-symbolic"
				end
				return "notifications-symbolic"
			end),
			-- icon = bind(notifd, "dont-disturb"):as(function(dnd)
			-- 	if dnd then
			-- 		return "notifications-disabled-symbolic"
			-- 	end
			-- 	return "notifications-symbolic"
			-- end),
		}),
	})
end
