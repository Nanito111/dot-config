local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Variable = astal.Variable
local bind = astal.bind

return function()
    local show_options = Variable:new()
    show_options:set(false)

    return Widget.Box({
        class_name = bind(show_options):as(function(value)
            if value then
                return "PowerOptions show"
            else
                return "PowerOptions"
            end
        end),
        Widget.EventBox({
            on_hover = function()
                show_options:set(true)
            end,
            on_hover_lost = function()
                show_options:set(false)
            end,
            Widget.Box({
                halign = "FILL",
                hexpand = true,
                Widget.Button({
                    class_name = bind(show_options):as(function(value)
                        if value then
                            return "Option show"
                        else
                            return "Option"
                        end
                    end),
                    visible = bind(show_options),
                    halign = "FILL",
                    hexpand = false,
                    vexpand = false,
                    on_clicked = function()
                        astal.exec("pc-logout")
                    end,
                    Widget.Icon({
                        hexpand = false,
                        vexpand = false,
                        icon = "logout-symbolic",
                    }),
                }),
                Widget.Button({
                    class_name = bind(show_options):as(function(value)
                        if value then
                            return "Option show"
                        else
                            return "Option"
                        end
                    end),
                    visible = bind(show_options),
                    halign = "FILL",
                    hexpand = false,
                    vexpand = false,
                    on_clicked = function()
                        astal.exec("pc-suspend")
                    end,
                    Widget.Icon({
                        hexpand = false,
                        vexpand = false,
                        icon = "system-suspend-symbolic",
                    }),
                }),
                Widget.Button({
                    class_name = bind(show_options):as(function(value)
                        if value then
                            return "Option show"
                        else
                            return "Option"
                        end
                    end),
                    visible = bind(show_options),
                    halign = "FILL",
                    hexpand = false,
                    vexpand = false,
                    on_clicked = function()
                        astal.exec("systemctl reboot")
                    end,
                    Widget.Icon({
                        hexpand = false,
                        vexpand = false,
                        icon = "system-reboot-symbolic",
                    }),
                }),
                Widget.Button({
                    class_name = bind(show_options):as(function(value)
                        if value then
                            return "show"
                        else
                            return ""
                        end
                    end),
                    halign = "END",
                    hexpand = true,
                    vexpand = false,
                    on_clicked = function()
                        astal.exec("shutdown now")
                    end,
                    Widget.Icon({
                        icon = "system-shutdown-symbolic",
                    }),
                }),
            }),
        }),
    })
end
