local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Hyprland = astal.require("AstalHyprland")
local bind = astal.bind
local map = require("lib").map

return function()
	local hypr = Hyprland.get_default()

	return Widget.Box({
		class_name = "Workspaces",
		bind(hypr, "workspaces"):as(function(wss)
			table.sort(wss, function(a, b)
				return a.id > b.id
			end)

			return map(wss, function(ws)
				if type(ws.id) == "number" and ws.id > 0 then
					return Widget.Button({
						class_name = bind(hypr, "focused-workspace"):as(function(fw)
							return fw == ws and "focused" or ""
						end),
						on_clicked = function()
							ws:focus()
						end,
						label = bind(ws, "id"):as(function(v)
							return string.format("%.0f", v)
						end),
					})
				else
					return Widget.Button({
						class_name = bind(hypr, "focused-workspace"):as(function(fw)
							return fw == ws and "focused special" or "special"
						end),
						on_clicked = function()
							ws:focus()
						end,
						label = "S",
					})
				end
			end)
		end),
	})
end
