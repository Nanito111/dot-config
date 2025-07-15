local astal = require("astal")
local astal_gtk3 = require("astal.gtk3")
local Widget = astal_gtk3.Widget
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor

-- import bar widgets
local SysTray = require("bar.widgets.SysTray")
local Ethernet = require("bar.widgets.Ethernet")
local Workspaces = require("bar.widgets.Workspaces")
local Clock = require("bar.widgets.Clock")
local PowerOptions = require("bar.widgets.PowerOptions")
local ShowAudio = require("bar.widgets.Audio").ShowAudio
local MiniCalendar = require("bar.widgets.Calendar")
local ShowMediaPlayer = require("bar.widgets.MediaPlayer").ShowMediaPlayer
local ShowNotificationCenter = require("bar.widgets.NotificationCenter")

local vertical_anchor = WindowAnchor.TOP
local bar_namespace = "astal-bar"
local blur_namespace = "astal-bar-blur"

return function(gdkmonitor)
	return Widget.Window({
		class_name = "Bar",
		gdkmonitor = gdkmonitor,
		namespace = bar_namespace,
		anchor = vertical_anchor + WindowAnchor.LEFT + WindowAnchor.RIGHT,
		-- exclusivity: "NORMAL", "EXCLUSIVE", "IGNORE"
		exclusivity = "EXCLUSIVE",
		-- layers: "BOTTOM", "TOP", "OVERLAY", "BACKGROUND"
		layer = "BOTTOM",

		Widget.CenterBox({
			Widget.Box({
				class_name = "LeftBox",
				halign = "START",
				Clock(),
				MiniCalendar(gdkmonitor, vertical_anchor, blur_namespace),
				SysTray(),
			}),
			Widget.Box({
				class_name = "MiddleBox",
				Widget.Box({
					class_name = "Notch Left",
					ShowNotificationCenter(gdkmonitor, vertical_anchor, blur_namespace),
				}),
				Widget.Box({
					class_name = "Notch",
					Workspaces(gdkmonitor),
				}),
				Widget.Box({
					class_name = "Notch Right",
					ShowMediaPlayer(gdkmonitor, vertical_anchor, blur_namespace),
				}),
			}),
			Widget.Box({
				class_name = "RightBox",
				halign = "END",
				Ethernet(),
				ShowAudio(gdkmonitor, vertical_anchor, blur_namespace),
				PowerOptions(),
			}),
		}),
	})
end
