local App = require("astal.gtk3.app")
local astal = require("astal")

local NotificationPopups = require("notifications.NotificationPopups")
local utils = require("utils")
local src = utils.src
local reload_css = utils.reload_css
local create_css = utils.create_css_from_sass

local main = "main.scss"
local colors = "colors.scss"
local scss = src("./notifications.scss")
local css = "/tmp/astal-notifications.css"
local INSTANCE_NAME = "notifications"

local function on_reload_css(_, event)
    reload_css(event, App, scss, css)
end

-- process scss at start
create_css(scss, css)
astal.monitor_file(scss, on_reload_css)
astal.monitor_file(main, on_reload_css)
astal.monitor_file(colors, on_reload_css)

local reloading_app = false
-- check changes in widgets
local function reload_app()
    if not reloading_app then
        reloading_app = true
        astal.exec_async("systemctl --user restart astal@" .. INSTANCE_NAME)
    end
end

astal.monitor_file(src("NotificationPopups.lua"), reload_app)
astal.monitor_file(src("Notification.lua"), reload_app)
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
            NotificationPopups(mon)
            print(mon.model)
        end
        print("astal-notifications started")
    end,
})
