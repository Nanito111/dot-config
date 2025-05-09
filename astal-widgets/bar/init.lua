local astal = require("astal")
local App = require("astal.gtk3.app")
local src = require("../lib").src
local reload_css = require("../lib").reload_css

local Bar = require("bar.Bar")
local scss = src("./style.scss")
local css = "/tmp/astal-bar.css"

local function on_reload_css(_, event)
	reload_css(event, App, scss, css)
end

-- process scss at start
astal.exec("sass " .. scss .. " " .. css)
astal.monitor_file(scss, on_reload_css)

App:start({
	instance_name = "bar",
	css = css,
	request_handler = function(msg, res)
		print(msg)
		res("ok")
	end,
	main = function()
		for _, mon in pairs(App.monitors) do
			Bar(mon)
			print(mon.model)
		end
		print("astal-bar started")
	end,
})
