local astal = require("astal")
local astal_gtk3 = require("astal.gtk3")
local Widget = astal_gtk3.Widget
local Notifd = astal.require("AstalNotifd")
local bind = astal.bind
local Variable = astal.Variable

local Notification = require("notifications.Notification")
local notifd = Notifd.get_default()

local function notification_varmap(initial)
    local map = initial or {}
    local var = Variable.new()

    local function notify()
        local arr = {}

        for k, entry in pairs(map) do
            table.insert(arr, {
                id = k,
                widget = entry.widget,
                time = entry.time,
            })
        end

        table.sort(arr, function(a, b)
            return a.time > b.time
        end)

        local widgets = {}
        for _, item in ipairs(arr) do
            table.insert(widgets, item.widget)
        end

        var:set(widgets)
    end

    local function delete(key)
        local entry = map[key]
        if entry and entry.widget and astal_gtk3.Gtk.Widget:is_type_of(entry.widget) then
            entry.widget:destroy()
        end

        map[key] = nil
    end

    notify()

    return setmetatable({
        set = function(key, widget, time)
            delete(key)

            map[key] = {
                widget = widget,
                time = time,
            }

            notify()
        end,

        delete = function(key)
            delete(key)
            notify()
        end,

        get = function()
            return var:get()
        end,

        subscribe = function(callback)
            return var:subscribe(callback)
        end,
    }, {
        __call = function()
            return bind(var)
        end,
    })
end

local function NotificationMap()
    local notif_map = notification_varmap({})

    for _, n in pairs(notifd.notifications) do
        notif_map.set(
            n.id,
            Notification({
                notification = n,
                in_bar = true,
            }),
            n.time
        )
    end

    notifd.on_notified = function(_, id)
        local n = notifd:get_notification(id)
        notif_map.set(
            id,
            Notification({
                notification = n,
                in_bar = true,
            }),
            n.time
        )
    end

    notifd.on_resolved = function(_, id)
        notif_map.delete(id)
    end

    return notif_map
end

local function NotificationList()
    local notifs = NotificationMap()

    return Widget.Scrollable({
        hscroll = "NEVER",
        vscroll = "AUTOMATIC",
        vexpand = true,
        hexpand = true,
        visible = bind(notifd, "notifications"):as(function(notifications)
            return #notifications > 0
        end),
        Widget.Box({
            class_name = "scroll-content",
            hexpand = true,
            vexpand = true,
            vertical = true,
            notifs(),
        }),
    })
end

local function NotificationCenter()
    return Widget.Box({
        class_name = "NotificationCenter-panel",
        vertical = true,
        Widget.Label({
            class_name = "title",
            label = "notifications",
            halign = "CENTER",
            hexpand = true,
        }),
        bind(notifd, "notifications"):as(function(notifications)
            if #notifications < 1 then
                return Widget.Label({
                    class_name = "no-notifications",
                    label = "your notification center is empty :)",
                    hexpand = true,
                    vexpand = true,
                })
            end
        end),
        NotificationList(),
        Widget.Button({
            class_name = bind(notifd, "notifications"):as(function(notifications)
                if #notifications > 0 then
                    return "trash full"
                end
                return "trash"
            end),
            halign = "CENTER",
            valign = "CENTER",
            hexpand = false,
            vexpand = false,
            on_clicked = function()
                if #notifd.notifications > 1 then
                    for _, n in pairs(notifd.notifications) do
                        n:dismiss()
                    end
                end
            end,
            Widget.Icon({
                icon = bind(notifd, "notifications"):as(function(notifications)
                    if #notifications > 0 then
                        return "budgie-trash-full-symbolic"
                    end
                    return "budgie-trash-empty-symbolic"
                end),
            }),
        }),
    })
end

return function(gdkmonitor, vertical_anchor, layer_namespace)
    local notification_center = Widget.Window({
        setup = function(self)
            self:hide()
        end,
        class_name = "NotificationCenter",
        gdkmonitor = gdkmonitor,
        namespace = layer_namespace,
        layer = "TOP",
        anchor = vertical_anchor,
        Widget.EventBox({
            on_hover_lost = function(self)
                local parent = self:get_parent()
                if parent:is_visible() then
                    parent:hide()
                end
            end,
            NotificationCenter(),
        }),
    })

    local show_notification_center_icon = Widget.Icon({
        tooltip_text = bind(notifd, "notifications"):as(function(n)
            if #n == 1 then
                return "you have 1 notification"
            end
            if #n > 1 then
                return string.format("you have %s notifications", #n)
            end
            return ""
        end),
        icon = bind(notifd, "notifications"):as(function(n)
            if notifd.dont_disturb then
                return "notifications-disabled-symbolic"
            elseif #n > 0 then
                return "notifications-new-symbolic"
            else
                return "notifications-symbolic"
            end
        end),
    })

    return Widget.Button({
        class_name = bind(notifd, "notifications"):as(function(n)
            local style_class = "ShowNotificationCenter"
            if #n < 1 then
                style_class = style_class .. " " .. "no-notifications"
            end
            return style_class
        end),
        on_click_release = function(_, event)
            if event.button == "PRIMARY" then
                if notification_center:is_visible() then
                    notification_center:hide()
                else
                    notification_center:show()
                end
            elseif event.button == "SECONDARY" then
                notifd.dont_disturb = not notifd.dont_disturb

                if notifd.dont_disturb then
                    show_notification_center_icon.icon = "notifications-disabled-symbolic"
                elseif #notifd.notifications > 0 then
                    show_notification_center_icon.icon = "notifications-new-symbolic"
                else
                    show_notification_center_icon.icon = "notifications-symbolic"
                end
            end
        end,
        show_notification_center_icon,
    })
end
