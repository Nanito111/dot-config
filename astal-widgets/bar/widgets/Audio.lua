local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local bind = astal.bind
local Wp = astal.require("AstalWp")
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor

local M = {}
local speaker = Wp.get_default().audio.default_speaker
local microphone = Wp.get_default().audio.default_microphone

function M.ShowAudio(gdkmonitor, vertical_anchor, layer_namespace)
	local audio_window = Widget.Window({
		setup = function(self)
			self:hide()
		end,
		class_name = "Audio",
		gdkmonitor = gdkmonitor,
		namespace = layer_namespace,
		layer = "TOP",
		anchor = vertical_anchor + WindowAnchor.RIGHT,
		margin_bottom = -10,
		margin_right = 20,
		Widget.EventBox({
			on_hover_lost = function(self)
				local parent = self:get_parent()
				if parent:is_visible() then
					parent:hide()
				end
			end,
			M.AudioSlider(),
		}),
	})

	return Widget.Button({
		class_name = "ShowAudio",
		on_clicked = function()
			if audio_window:is_visible() then
				audio_window:hide()
			else
				audio_window:show()
			end
		end,
		Widget.Box({
			class_name = "Icons",
			Widget.Box({
				class_name = bind(speaker, "mute"):as(function(mute)
					local mute_text = mute and "muted" or ""
					return "Speaker" .. " " .. mute_text
				end),
				Widget.Icon({
					class_name = "Speaker",
					icon = bind(speaker, "volume-icon"),
				}),
				Widget.Label({
					label = bind(speaker, "volume"):as(function(volume)
						return string.format("%.0f", volume * 100) .. " "
					end),
				}),
			}),
			Widget.Box({
				class_name = bind(microphone, "mute"):as(function(mute)
					local mute_text = mute and "muted" or ""
					return "Microphone" .. " " .. mute_text
				end),
				Widget.Icon({
					class_name = "Microphone",
					icon = bind(microphone, "volume-icon"),
				}),
				Widget.Label({
					label = bind(microphone, "volume"):as(function(volume)
						return string.format("%.0f", volume * 100) .. " "
					end),
				}),
			}),
		}),
	})
end

function M.AudioSlider()
	return Widget.Box({
		class_name = "AudioSlider",
		vertical = true,

		-- speaker
		Widget.Label({
			class_name = "Speaker",
			label = bind(speaker, "description"):as(function(name)
				if name == "Family 17h/19h/1ah HD Audio Controller Analog Stereo" then
					return "Motherboard Analog Stereo"
				elseif name == "Renoir Radeon High Definition Audio Controller Digital Stereo (HDMI)" then
					return "HDMI Digital Stereo"
				else
					return name
				end
			end),
		}),
		Widget.Box({
			Widget.Button({
				class_name = bind(speaker, "mute"):as(function(mute)
					local mute_text = mute and "muted" or ""
					return "Speaker" .. " " .. mute_text
				end),
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
				step = 1,
			}),
		}),

		-- microphone
		Widget.Label({
			class_name = "Microphone",
			label = bind(microphone, "description"),
		}),
		Widget.Box({
			Widget.Button({
				class_name = bind(microphone, "mute"):as(function(mute)
					local mute_text = mute and "muted" or ""
					return "Microphone" .. " " .. mute_text
				end),
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
				step = 1,
			}),
		}),
	})
end

return M
