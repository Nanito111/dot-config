local astal = require("astal")
local App = require("astal.gtk3.app")
local src = require("../lib").src

local Bar = require("bar.Bar")
local bar_scss = src("./style.scss")
local css = "/tmp/astal-bar.css"

local function reload_css(_, event)
	if event ~= 0 then
		return
	end
	print("style changes detected, reloading CSS")
	astal.exec("sass " .. bar_scss .. " " .. css)
	print("applying CSS to App")
	App:apply_css(css)
end

-- bar style
-- process scss at start
astal.exec("sass " .. bar_scss .. " " .. css)
astal.monitor_file(bar_scss, reload_css)

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
