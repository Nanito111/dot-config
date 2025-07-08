local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Variable = astal.Variable
local bind = astal.bind

return function()
	local show_options = Variable(false)
	return Widget.Box({
		class_name = bind(show_options):as(function(value)
			if value then
				return "PowerOptions show"
			else
				return "PowerOptions"
			end
		end),
		Widget.EventBox({
			on_hover_lost = function()
				show_options:set(false)
			end,
			Widget.Box({
				Widget.Box({
					visible = bind(show_options),
					Widget.Button({
						on_clicked = function()
							astal.exec("systemctl suspend")
						end,
						Widget.Icon({
							icon = "system-suspend-symbolic",
						}),
					}),
					Widget.Button({
						on_clicked = function()
							astal.exec("systemctl reboot")
						end,
						Widget.Icon({
							icon = "system-reboot-symbolic",
						}),
					}),
					Widget.Button({
						on_clicked = function()
							astal.exec("shutdown now")
						end,
						Widget.Icon({
							icon = "system-shutdown-symbolic",
						}),
					}),
				}),
				Widget.Box({
					Widget.Button({
						class_name = "CloseOptions",
						visible = bind(show_options):as(function(value)
							return value
						end),
						on_clicked = function()
							show_options:set(not show_options:get())
						end,
						Widget.Icon({
							icon = "close-symbolic",
						}),
					}),
					Widget.Button({
						class_name = "ShowOptions",
						visible = bind(show_options):as(function(value)
							return not value
						end),
						on_clicked = function()
							show_options:set(not show_options:get())
						end,
						Widget.Icon({
							icon = "system-shutdown-symbolic",
						}),
					}),
				}),
			}),
		}),
	})
end
