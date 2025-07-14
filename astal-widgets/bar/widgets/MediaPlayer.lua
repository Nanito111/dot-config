local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Mpris = astal.require("AstalMpris")
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor
local bind = astal.bind

local M = {}
function M.MediaPlayer(mpris_instance)
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

function M.ShowMediaPlayer(gdkmonitor, vertical_anchor, layer_namespace)
	local default_media = Mpris.get_default()
	local window_player = Widget.Window({
		setup = function(self)
			self:hide()
		end,
		class_name = "Media",
		gdkmonitor = gdkmonitor,
		namespace = layer_namespace,
		layer = "TOP",
		anchor = vertical_anchor + WindowAnchor.RIGHT,
		margin_bottom = -10,
		margin_right = 70,
		Widget.EventBox({
			on_hover_lost = function(self)
				local parent = self:get_parent()
				if parent:is_visible() then
					parent:hide()
				end
			end,
			M.MediaPlayer(default_media),
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
return M
