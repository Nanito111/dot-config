local astal = require("astal")
local App = require("astal.gtk3.app")
local Widget = require("astal.gtk3.widget")
local Variable = astal.Variable
local Gdk = astal.require("Gdk", "3.0")
local GLib = astal.require("GLib")
local bind = astal.bind
-- local Mpris = astal.require("AstalMpris")
local Wp = astal.require("AstalWp")
-- local Network = astal.require("AstalNetwork")
local Tray = astal.require("AstalTray")
local Hyprland = astal.require("AstalHyprland")
local map = require("lib").map

local function SysTray()
	local tray = Tray.get_default()

	return Widget.Box({
		class_name = "Tray",
		visible = bind(tray, "items"):as(function(items)
			return #items > 0
		end),
		bind(tray, "items"):as(function(items)
			return map(items, function(item)
				if item.icon_theme_path ~= nil then
					App:add_icons(item.icon_theme_path)
				end
				local menu = item:create_menu()

				return Widget.Button({
					tooltip_markup = bind(item, "tooltip_markup"),
					on_destroy = function()
						if menu ~= nil then
							menu:destroy()
						end
					end,
					on_click_release = function(self)
						if menu ~= nil then
							menu:popup_at_widget(self, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, nil)
						end
					end,
					Widget.Icon({
						g_icon = bind(item, "gicon"),
					}),
				})
			end)
		end),
	})
end

-- local function FocusedClient()
-- 	local hypr = Hyprland.get_default()
-- 	local focused = bind(hypr, "focused-client")
--
-- 	return Widget.Box({
-- 		class_name = "Focused",
-- 		visible = focused,
-- 		focused:as(function(client)
-- 			return client and Widget.Label({
-- 				label = bind(client, "title"):as(tostring),
-- 			})
-- 		end),
-- 	})
-- end

-- local function Wifi()
-- 	local wifi = Network.get_default().wifi
--
-- 	return Widget.Icon({
-- 		tooltip_text = bind(wifi, "ssid"):as(tostring),
-- 		class_name = "Wifi",
-- 		icon = bind(wifi, "icon-name"),
-- 	})
-- end

local function AudioSlider()
	local speaker = Wp.get_default().audio.default_speaker
	local microphone = Wp.get_default().audio.default_microphone

	return Widget.Box({
		class_name = "AudioSlider",
		-- speaker
		Widget.Button({
			class_name = "Speaker",
			on_clicked = function()
				speaker.mute = not speaker.mute
			end,
			Widget.Icon({
				class_name = "Speaker",
				icon = bind(speaker, "volume-icon"),
			}),
		}),
		Widget.Slider({
			hexpand = true,
			on_dragged = function(self)
				speaker.volume = self.value
			end,
			value = bind(speaker, "volume"),
		}),
		-- microphone
		Widget.Button({
			class_name = "Microphone",
			on_clicked = function()
				microphone.mute = not microphone.mute
			end,
			Widget.Icon({
				class_name = "Microphone",
				icon = bind(microphone, "volume-icon"),
			}),
		}),
		Widget.Slider({
			hexpand = true,
			on_dragged = function(self)
				microphone.volume = self.value
			end,
			value = bind(microphone, "volume"),
		}),
	})
end

-- local function Media()
-- 	local player = Mpris.Player.new("spotify")
--
-- 	return Widget.Box({
-- 		class_name = "Media",
-- 		visible = bind(player, "available"),
-- 		Widget.Box({
-- 			class_name = "Cover",
-- 			valign = "CENTER",
-- 			css = bind(player, "cover-art"):as(function(cover)
-- 				return "background-image: url('" .. (cover or "") .. "');"
-- 			end),
-- 		}),
-- 		Widget.Label({
-- 			label = bind(player, "metadata"):as(function()
-- 				return (player.title or "") .. " - " .. (player.artist or "")
-- 			end),
-- 		}),
-- 	})
-- end

local function Workspaces()
	local hypr = Hyprland.get_default()

	return Widget.Box({
		class_name = "Workspaces",
		bind(hypr, "workspaces"):as(function(wss)
			table.sort(wss, function(a, b)
				return a.id < b.id
			end)

			return map(wss, function(ws)
				return Widget.Button({
					class_name = bind(hypr, "focused-workspace"):as(function(fw)
						return fw == ws and "focused" or ""
					end),
					on_clicked = function()
						ws:focus()
					end,
					label = bind(ws, "id"):as(function(v)
						return type(v) == "number" and string.format("%.0f", v) or v
					end),
				})
			end)
		end),
	})
end

local function DateTime(class_name, format)
	local time = Variable(""):poll(1000, function()
		return GLib.DateTime.new_now_local():format(format)
	end)

	return Widget.Label({
		class_name = class_name,
		on_destroy = function()
			time:drop()
		end,
		label = time(),
	})
end

return function(gdkmonitor)
	local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor

	return Widget.Window({
		class_name = "Bar",
		gdkmonitor = gdkmonitor,
		anchor = WindowAnchor.TOP + WindowAnchor.LEFT + WindowAnchor.RIGHT,
		exclusivity = "EXCLUSIVE",

		Widget.CenterBox({
			Widget.Box({
				class_name = "LeftBox",
				halign = "START",
				DateTime("Time", "%H:%M:%S"),
				DateTime("Date", "%A %e-%m-%Y"),
			}),
			Widget.Box({
				class_name = "MiddleBox",
				Workspaces(),
			}),
			Widget.Box({
				class_name = "RightBox",
				halign = "END",
				SysTray(),
				AudioSlider(),
			}),
		}),
	})
end
