local astal = require("astal")
local astal_gtk3 = require("astal.gtk3")
local Widget = astal_gtk3.Widget
local astalify = astal_gtk3.astalify
local Gtk = astal_gtk3.Gtk
local Calendar = astalify(Gtk.Calendar)
local Variable = astal.Variable
local GLib = astal.require("GLib")
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor
local bind = astal.bind

return function(gdkmonitor, vertical_anchor, layer_namespace)
	local date = Variable(""):poll(1000, function()
		return GLib.DateTime.new_now_local():format("%A %d-%m-%Y")
	end)

	local calendar_window = Widget.Window({
		setup = function(self)
			self:hide()
		end,
		class_name = "Calendar",
		gdkmonitor = gdkmonitor,
		namespace = layer_namespace,
		anchor = vertical_anchor + WindowAnchor.LEFT,
		margin_bottom = -10,
		margin_left = 20,
		Widget.EventBox({
			on_hover_lost = function(self)
				local parent = self:get_parent()
				if parent:is_visible() then
					parent:hide()
				end
			end,
			Widget.Box({
				class_name = "Calendar",
				Calendar({
					class_name = "CalendarPanel",
				}),
			}),
		}),
	})

	return Widget.Button({
		class_name = "Date",
		on_clicked = function()
			if calendar_window:is_visible() then
				calendar_window:hide()
			else
				calendar_window:show()
			end
		end,
		on_destroy = function()
			date:drop()
		end,
		label = date(),
	})
end
