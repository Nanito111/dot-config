local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Variable = astal.Variable
local GLib = astal.require("GLib")

return function()
	local time = Variable(""):poll(1000, function()
		return GLib.DateTime.new_now_local():format("%H:%M:%S")
	end)

	return Widget.Label({
		class_name = "Time",
		on_destroy = function()
			time:drop()
		end,
		label = time(),
	})
end
