local App = require("astal.gtk3.app")
local Bar = require("bar.Bar")
local astal = require("astal")
local src = require("utils").src

local reload_css = require("utils").reload_css
local create_css = require("utils").create_css_from_sass
local scss_dir = src("sass/")
local scss = scss_dir .. "astal-bar.scss"
local css = "/tmp/astal-bar.css"
local INSTANCE_NAME = "bar"

local function on_reload_css(_, event)
    reload_css(event, App, scss, css)
end

-- process scss at start
create_css(scss, css)
astal.monitor_file(scss_dir, on_reload_css)
astal.monitor_file("main.scss", on_reload_css)

local reloading_app = false
-- check changes in widgets
local function reload_app()
    if not reloading_app then
        reloading_app = true
        astal.exec_async("systemctl --user restart astal@" .. INSTANCE_NAME)
    end
end

astal.monitor_file(src("widgets/"), reload_app)
astal.monitor_file(src("widgets/Bar.lua"), reload_app)
astal.monitor_file(src("init.lua"), reload_app)
astal.monitor_file("utils.lua", reload_app)

App:start({
    instance_name = INSTANCE_NAME,
    css = css,
    request_handler = function(msg, res)
        print(msg)
        res("ok")
    end,
    main = function()
        for _, mon in pairs(App.monitors) do
            print(mon.model)
            Bar(mon)
        end
        print("astal-bar started")
    end,
})
