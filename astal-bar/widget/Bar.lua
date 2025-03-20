local astal = require("astal")
-- local App = require("astal.gtk3.app")
local astal_gtk3 = require("astal.gtk3")
local astalify = astal_gtk3.astalify
local Widget = astal_gtk3.Widget
local Variable = astal.Variable
local Gtk = astal_gtk3.Gtk
-- local Gtd = astal_gtk3.Gtd
-- local Gdk = astal.require("Gdk", "3.0")
local GLib = astal.require("GLib")
local bind = astal.bind
local Mpris = astal.require("AstalMpris")
local Wp = astal.require("AstalWp")
local Network = astal.require("AstalNetwork")
local Tray = astal.require("AstalTray")
local Hyprland = astal.require("AstalHyprland")
local map = require("lib").map
local Calendar = astalify(Gtk.Calendar)
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor

local function SysTray()
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

local function Ethernet()
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

local speaker = Wp.get_default().audio.default_speaker
local microphone = Wp.get_default().audio.default_microphone

local function AudioSlider()
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
			}),
		}),
	})
end

local function ShowAudio(gdkmonitor)
	local audio_window = Widget.Window({
		setup = function(self)
			self:hide()
		end,
		class_name = "Audio",
		gdkmonitor = gdkmonitor,
		layer = "TOP",
		anchor = WindowAnchor.BOTTOM + WindowAnchor.RIGHT,
		margin_bottom = 10,
		margin_right = 20,
		Widget.EventBox({
			on_hover_lost = function(self)
				local parent = self:get_parent()
				if parent:is_visible() then
					parent:hide()
				end
			end,
			AudioSlider(),
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

local function MediaPlayer(mpris_instance)
	return bind(mpris_instance, "players"):as(function(players)
		local player = nil
		if #players > 0 then
			player = players[1]
		end
		if player == nil then
			return Widget.Box({
				class_name = "Media offline",
				vertical = true,
				Widget.Box({
					class_name = "interface offline",
					vertical = true,
					Widget.Icon({
						icon = "music-app-symbolic",
					}),
					Widget.Label({
						label = "no media playing",
					}),
				}),
			})
		end

		local play_button_icon = {
			["PLAYING"] = "media-playback-pause-symbolic",
			["PAUSED"] = "media-playback-start-symbolic",
			["STOPPED"] = "media-playback-stop-symbolic",
			_ = "media-playback-start-symbolic",
		}

		return Widget.Box({
			class_name = "Media",
			vertical = true,
			bind(player, "cover-art"):as(function(cover_art)
				if cover_art == nil or cover_art == "" then
					return Widget.Icon({
						class_name = "image",
						icon = "music-app-symbolic",
					})
				end

				return Widget.Box({
					class_name = "image",
					css = "background-image: url('" .. cover_art .. "');",
				})
			end),
			Widget.Box({
				class_name = "interface",
				vertical = true,
				Widget.Box({
					class_name = "slider-parent",
					visible = bind(player, "length"):as(function(length)
						return length ~= nil and length > 0
					end),
					Widget.Slider({
						hexpand = true,
						value = bind(player, "position"):as(function(position)
							return position
						end),
						min = 0,
						max = bind(player, "length"):as(function(value)
							return value
						end),
						on_dragged = function(self)
							if player.position == nil then
								return
							end
							player.position = self.value
						end,
					}),
				}),
				Widget.Box({
					class_name = "controls",
					halign = "CENTER",
					Widget.Button({
						on_clicked = function()
							if player.can_go_previous then
								player:previous()
							end
						end,
						Widget.Icon({
							icon = "media-skip-backward-symbolic",
						}),
					}),
					Widget.Button({
						on_clicked = function()
							if player.can_play and player.can_pause then
								player:play_pause()
							end
						end,
						Widget.Icon({
							icon = bind(player, "playback-status"):as(function(playback_status)
								return play_button_icon[playback_status]
							end),
						}),
					}),
					Widget.Button({
						on_clicked = function()
							if player.can_go_next then
								player:next()
							end
						end,
						Widget.Icon({
							icon = "media-skip-forward-symbolic",
						}),
					}),
				}),
				Widget.Label({
					class_name = "title",
					max_width_chars = 22,
					lines = 2,
					wrap = true,
					ellipsize = "END",
					justify = "CENTER",
					halign = "CENTER",
					visible = bind(player, "title"):as(function(title)
						if title == nil or title == "" then
							return false
						end
						return true
					end),
					label = bind(player, "title"),
					tooltip_text = bind(player, "title"),
				}),
				Widget.Label({
					class_name = "artist",
					wrap = true,
					justify = "CENTER",
					visible = bind(player, "artist"):as(function(artist)
						if artist == nil or artist == "" then
							return false
						end
						return true
					end),
					label = bind(player, "artist"):as(function(artist)
						if artist == nil or artist == "" then
							return
						end
						return artist
					end),
				}),
				Widget.Label({
					class_name = "album",
					max_width_chars = 20,
					width_chars = 8,
					wrap = true,
					justify = "CENTER",
					halign = "CENTER",
					visible = bind(player, "album"):as(function(album)
						if album == nil or album == "" then
							return false
						end
						return true
					end),
					label = bind(player, "album"):as(function(album)
						if album == nil or album == "" then
							return
						end
						return album
					end),
				}),
			}),
		})
	end)
end

local function Media(gdkmonitor)
	local default_media = Mpris.get_default()
	local window_player = Widget.Window({
		setup = function(self)
			self:hide()
		end,
		class_name = "Media",
		gdkmonitor = gdkmonitor,
		layer = "TOP",
		anchor = WindowAnchor.BOTTOM + WindowAnchor.RIGHT,
		margin_bottom = 10,
		margin_right = 100,
		Widget.EventBox({
			on_hover_lost = function(self)
				local parent = self:get_parent()
				if parent:is_visible() then
					parent:hide()
				end
			end,
			MediaPlayer(default_media),
		}),
	})
	return bind(default_media, "players"):as(function(players)
		if #players == 0 then
			return Widget.Button({
				class_name = "Media offline",
				on_clicked = function()
					if window_player:is_visible() then
						window_player:hide()
					else
						window_player:show()
					end
				end,
				Widget.Icon({
					icon = "music-app-symbolic",
				}),
			})
		else
			local player = players[1]
			return Widget.Button({
				class_name = bind(player, "playback-status"):as(function(playback_status)
					if playback_status == "PAUSED" then
						return "Media paused"
					end
					return "Media"
				end),
				on_clicked = function()
					if window_player:is_visible() then
						window_player:hide()
					else
						window_player:show()
					end
				end,
				Widget.Icon({
					icon = bind(player, "playback-status"):as(function(playback_status)
						if playback_status == "PAUSED" then
							return "media-playback-pause-symbolic"
						end
						return "media-playback-start-symbolic"
					end),
				}),
			})
		end
	end)
end

local function Workspaces()
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

local function Clock()
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

local function MiniCalendar(gdkmonitor)
	local date = Variable(""):poll(1000, function()
		return GLib.DateTime.new_now_local():format("%A %d-%m-%Y")
	end)

	local calendar_window = Widget.Window({
		setup = function(self)
			self:hide()
		end,
		class_name = "Calendar",
		gdkmonitor = gdkmonitor,
		anchor = WindowAnchor.BOTTOM + WindowAnchor.LEFT,
		margin_bottom = 10,
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

local function PowerOptions()
	local show_options = Variable(false)
	return Widget.Box({
		class_name = "PowerOptions",
		Widget.EventBox({
			on_hover_lost = function()
				show_options:set(false)
			end,
			Widget.Box({
				Widget.Box({
					class_name = "Options",
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

return function(gdkmonitor)
	return Widget.Window({
		class_name = "Bar",
		gdkmonitor = gdkmonitor,
		anchor = WindowAnchor.BOTTOM + WindowAnchor.LEFT + WindowAnchor.RIGHT,
		exclusivity = "EXCLUSIVE",
		layer = "BOTTOM",

		Widget.CenterBox({
			Widget.Box({
				class_name = "LeftBox",
				halign = "START",
				Clock(),
				MiniCalendar(gdkmonitor),
			}),
			Widget.Box({
				class_name = "MiddleBox",
				Workspaces(),
			}),
			Widget.Box({
				class_name = "RightBox",
				halign = "END",
				SysTray(),
				Ethernet(),
				Media(gdkmonitor),
				ShowAudio(gdkmonitor),
				PowerOptions(),
			}),
		}),
	})
end
