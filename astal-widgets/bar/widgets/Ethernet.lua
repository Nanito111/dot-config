local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Network = astal.require("AstalNetwork")
local bind = astal.bind

return function()
	local ethernet = Network.get_default().wired

	if ethernet ~= nil then
		return Widget.Box({
			class_name = bind(ethernet, "internet"):as(function(state)
				return "Ethernet " .. string.lower(state)
			end),
			Widget.Label({
				halign = "START",
				label = bind(ethernet, "internet"):as(function(state)
					return string.upper(state)
				end),
			}),
			Widget.Icon({
				icon = bind(ethernet, "icon-name"),
			}),
		})
	end
	return Widget.Box({
		class_name = "Ethernet offline",
		Widget.Label({
			halign = "START",
			label = "OFFLINE",
		}),
		Widget.Icon({
			icon = "network-wired-offline-symbolic",
		}),
	})
end
