local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Tray = astal.require("AstalTray")
local bind = astal.bind
local map = require("lib").map

return function()
	local tray = Tray.get_default()

	return Widget.Box({
		class_name = "SysTray",
		visible = bind(tray, "items"):as(function(items)
			return #items > 0
		end),
		bind(tray, "items"):as(function(items)
			return map(items, function(item)
				return Widget.MenuButton({
					tooltip_markup = bind(item, "tooltip_markup"),
					use_popover = false,
					menu_model = bind(item, "menu-model"),
					action_group = bind(item, "action-group"):as(function(ag)
						return { "dbusmenu", ag }
					end),
					Widget.Icon({
						gicon = bind(item, "gicon"),
					}),
				})
			end)
		end),
	})
end
