local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Network = astal.require("AstalNetwork")
local bind = astal.bind

return function()
	local ethernet = Network.get_default().wired

	if ethernet ~= nil then
		return Widget.Icon({
			tooltip_text = bind(ethernet, "internet"):as(function(state)
				return string.lower(state)
			end),
			class_name = bind(ethernet, "internet"):as(function(state)
				return "Ethernet " .. string.lower(state)
			end),
			icon = bind(ethernet, "icon-name"),
		})
	end
	return Widget.Icon({
		tooltip_text = "offline",
		class_name = "Ethernet offline",
		icon = "network-wired-offline-symbolic",
	})
end
