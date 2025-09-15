local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Hyprland = astal.require("AstalHyprland")
local bind = astal.bind
local map = require("utils").map

return function(gdkmonitor)
    local hypr = Hyprland.get_default()

    return Widget.Box({
        class_name = "Workspaces",
        bind(hypr, "workspaces"):as(function(wss)
            local filtered_workspaces = {}
            for _, workspace in ipairs(wss) do
                if workspace.monitor.model == gdkmonitor.model and workspace.id ~= 5 then
                    table.insert(filtered_workspaces, workspace)
                end
            end

            table.sort(filtered_workspaces, function(a, b)
                return a.id < b.id
            end)

            return map(filtered_workspaces, function(ws)
                if type(ws.id) == "number" and ws.id > 0 then
                    return Widget.Button({
                        class_name = bind(hypr, "focused-workspace"):as(function(fw)
                            return fw == ws and "focused" or ""
                        end),
                        halign = "CENTER",
                        valign = "CENTER",
                        hexpand = true,
                        vexpand = false,
                        on_clicked = function()
                            ws:focus()
                        end,
                    })
                else
                    return Widget.Button({
                        class_name = bind(hypr, "focused-workspace"):as(function(fw)
                            return fw == ws and "focused special" or "special"
                        end),
                        halign = "CENTER",
                        valign = "CENTER",
                        hexpand = true,
                        vexpand = false,
                        on_clicked = function()
                            ws:focus()
                        end,
                    })
                end
            end)
        end),
    })
end
