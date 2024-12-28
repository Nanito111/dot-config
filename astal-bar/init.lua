local astal = require("astal")
local App = require("astal.gtk3.app")

local Bar = require("widget.Bar")
local src = require("lib").src

local scss = src("style.scss")
local css = "/tmp/style.css"
-- process scss at start
astal.exec("sass " .. scss .. " " .. css)

local function reload_css(_, event)
	if event == 0 then
		print("style changes detected, reloading CSS")
		astal.exec("sass " .. scss .. " " .. css)
		print("applying CSS to App")
		App:apply_css(css)
	end
end

astal.monitor_file("style.scss", reload_css)

App:start({
	css = css,
	request_handler = function(msg, res)
		print(msg)
		res("ok")
	end,
	main = function()
		for _, mon in pairs(App.monitors) do
			Bar(mon)
		end
	end,
})
