local astal = require("astal")
local App = require("astal.gtk3.app")
local src = require("../lib").src
local reload_css = require("../lib").reload_css
local create_css = require("../lib").create_css_from_sass

local Bar = require("bar.Bar")
local main_scss = "../_main.scss"
local scss_dir = src("sass/")
local scss = scss_dir .. "astal-bar.scss"
local css = "/tmp/astal-bar.css"

local function on_reload_css(_, event)
	reload_css(event, App, scss, css)
end

-- process scss at start
create_css(scss, css)
astal.monitor_file(scss_dir, on_reload_css)
astal.monitor_file(main_scss, on_reload_css)

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
