local astal = require("astal")
local App = require("astal.gtk3.app")

local NotificationPopups = require("notifications.NotificationPopups")
local src = require("../lib").src
local reload_css = require("../lib").reload_css

local scss = src("./style.scss")
local css = "/tmp/astal-notifications.css"

local function on_reload_css(_, event)
	reload_css(event, App, scss, css)
end

-- process scss at start
astal.exec("sass " .. scss .. " " .. css)
astal.monitor_file(scss, on_reload_css)

App:start({
	instance_name = "notifications",
	css = css,
	request_handler = function(msg, res)
		print(msg)
		res("ok")
	end,
	main = function()
		for _, mon in pairs(App.monitors) do
			NotificationPopups(mon)
			print(mon.model)
		end
		print("astal-notifications started")
	end,
})
