local Widget = require("astal.gtk3").Widget
local Gtk = require("astal.gtk3").Gtk
local bind = require("astal").bind

local map = require("../lib").map
local time = require("../lib").time
local file_exists = require("../lib").file_exists

---@param props { setup?: function, on_hover_lost?: function, notification: any }
return function(props)
	local n = props.notification

	local header = Widget.Box({
		class_name = "header",
		bind(n, "app-icon"):as(function(app_icon)
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
			label = n.app_name or "Unknown",
		}),
		Widget.Label({
			class_name = "time",
			hexpand = true,
			halign = "END",
			label = time(n.time),
		}),
		Widget.Button({
			on_clicked = function()
				n:dismiss()
			end,
			Widget.Icon({ icon = "window-close-symbolic" }),
		}),
	})

	local content = Widget.Box({
		class_name = "content",
		(n.image and file_exists(n.image)) and Widget.Box({
			valign = "START",
			class_name = "image",
			css = string.format("background-image: url('%s')", n.image),
		}),
		Widget.Box({
			vertical = true,
			Widget.Label({
				class_name = "summary",
				halign = "START",
				xalign = 0,
				ellipsize = "END",
				label = n.summary,
			}),
			Widget.Label({
				class_name = "body",
				wrap = true,
				use_markup = true,
				halign = "START",
				xalign = 0,
				justify = "FILL",
				label = n.body,
			}),
		}),
	})

	return Widget.EventBox({
		class_name = string.format("Notification %s", string.lower(n.urgency)),
		setup = props.setup,
		on_hover_lost = props.on_hover_lost,
		Widget.Box({
			setup = function(self)
				self:hook(n, "invoked", function()
					n:dismiss()
				end)
			end,
			vertical = true,
			header,
			Gtk.Separator({ visible = true }),
			content,
			Widget.Box({
				class_name = "actions",
				hexpand = true,
				halign = "CENTER",
				map(n.actions, function(action)
					local label, id = string.lower(action.label), action.id

					return Widget.Button({
						on_clicked = function()
							return n:invoke(id)
						end,
						Widget.Label({
							label = label,
							halign = "CENTER",
						}),
					})
				end),
			}),
		}),
	})
end
