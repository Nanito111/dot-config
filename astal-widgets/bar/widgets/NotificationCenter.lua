local astal = require("astal")
local astal_gtk3 = require("astal.gtk3")
local Widget = astal_gtk3.Widget
local Notifd = astal.require("AstalNotifd")
local bind = astal.bind
local Variable = astal.Variable

local Notification = require("notifications.Notification")
local notifd = Notifd.get_default()

local notifications_bind = bind(notifd, "notifications")
local dnd_bind = bind(notifd, "dont-disturb")

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

local function NotificationScroll()
    local notifs = NotificationMap()

    -- create scroll content, this will contain notification items
    local scroll_content = Widget.Box({
        notifs(),
    })
    scroll_content.class_name = "scroll-content"
    scroll_content.hexpand = true
    scroll_content.vexpand = true
    scroll_content.vertical = true

    -- create scrollable widget
    local notification_scrollable = Widget.Scrollable()
    notification_scrollable.hscroll = "NEVER"
    notification_scrollable.vscroll = "AUTOMATIC"
    notification_scrollable.vexpand = true
    notification_scrollable.hexpand = true

    local toggle_notification_scroll = function(notifications)
        notification_scrollable.visible = #notifications > 0
    end
    toggle_notification_scroll(notifd.notifications)
    notifications_bind:subscribe(toggle_notification_scroll)

    -- add scroll content to scrollable
    notification_scrollable.child = scroll_content

    return notification_scrollable
end

local function NotificationCenter()
    -- create notifications center panel title
    local nc_panel_title = Widget.Label()
    nc_panel_title.class_name = "title"
    nc_panel_title.label = "notifications"
    nc_panel_title.halign = "CENTER"
    nc_panel_title.hexpand = true

    -- create nc no notifications label
    local nc_panel_no_notifications = Widget.Label()
    nc_panel_no_notifications.class_name = "no-notifications"
    nc_panel_no_notifications.label = "your notification center is empty :)"
    nc_panel_no_notifications.hexpand = true
    nc_panel_no_notifications.vexpand = true

    local toggle_no_notifications = function(n)
        nc_panel_no_notifications.visible = #n < 1
    end

    toggle_no_notifications(notifd.notifications)
    notifications_bind:subscribe(toggle_no_notifications)

    -- create nc trash button icon
    local nc_trash_button_icon = Widget.Icon()

    local set_trash_icon = function(notifications)
        if #notifications > 0 then
            nc_trash_button_icon.icon = "budgie-trash-full-symbolic"
        else
            nc_trash_button_icon.icon = "budgie-trash-empty-symbolic"
        end
    end

    set_trash_icon(notifd.notifications)
    notifications_bind:subscribe(set_trash_icon)

    -- create nc trash button
    local nc_trash_button = Widget.Button()

    nc_trash_button.class_name = "trash"
    local change_trash_class = function(n)
        nc_trash_button:toggle_class_name("full", #n > 0)
    end
    change_trash_class(notifd.notifications)
    notifications_bind:subscribe(change_trash_class)

    nc_trash_button.halign = "CENTER"
    nc_trash_button.valign = "CENTER"
    nc_trash_button.hexpand = false
    nc_trash_button.vexpand = false
    nc_trash_button.on_clicked = function()
        if #notifd.notifications > 0 then
            for _, n in pairs(notifd.notifications) do
                n:dismiss()
            end
        end
    end
    nc_trash_button.image = nc_trash_button_icon

    -- create notification center panel
    local nc_panel = Widget.Box()
    nc_panel.class_name = "NotificationCenter-panel"
    nc_panel.vertical = true

    nc_panel.children = {
        nc_panel_title,
        nc_panel_no_notifications,
        NotificationScroll(),
        nc_trash_button,
    }

    return nc_panel
end

return function(gdkmonitor, vertical_anchor, layer_namespace)
    -- create notification center eventbox
    local nc_eventbox = Widget.EventBox()
    nc_eventbox.on_hover_lost = function(self)
        local parent = self:get_parent()
        if parent:is_visible() then
            parent:hide()
        end
    end
    nc_eventbox.child = NotificationCenter()

    -- create notification center window
    local notification_center = Widget.Window()
    notification_center:hide()
    notification_center.class_name = "NotificationCenter"
    notification_center.gdkmonitor = gdkmonitor
    notification_center.namespace = layer_namespace
    notification_center.layer = "TOP"
    notification_center.anchor = vertical_anchor
    notification_center.child = nc_eventbox

    -- create notification center button icon
    local nc_button_icon = Widget.Icon()

    local set_icon = function()
        if notifd.dont_disturb then
            nc_button_icon.icon = "notifications-disabled-symbolic"
        elseif #notifd.notifications > 0 then
            nc_button_icon.icon = "notifications-new-symbolic"
        else
            nc_button_icon.icon = "notifications-symbolic"
        end
    end
    local set_icon_tooltip = function(n)
        if #n == 1 then
            nc_button_icon:set_tooltip_text("you have 1 notification")
        elseif #n > 1 then
            nc_button_icon:set_tooltip_text(string.format("you have %s notifications", #n))
        else
            nc_button_icon:set_tooltip_text("")
        end
    end

    set_icon_tooltip(notifd.notifications)
    notifications_bind:subscribe(set_icon_tooltip)

    set_icon()
    notifications_bind:subscribe(set_icon)
    dnd_bind:subscribe(set_icon)

    -- create notification center button
    local show_nc_button = Widget.Button()

    show_nc_button.class_name = "ShowNotificationCenter"
    local set_show_nc_class_name = function(n)
        show_nc_button:toggle_class_name("no-notifications", #n < 1)
    end
    set_show_nc_class_name(notifd.notifications)
    notifications_bind:subscribe(set_show_nc_class_name)

    show_nc_button.on_click_release = function(_, event)
        if event.button == "PRIMARY" then
            if notification_center:is_visible() then
                notification_center:hide()
            else
                notification_center:show()
            end
        elseif event.button == "SECONDARY" then
            notifd.dont_disturb = not notifd.dont_disturb
        end
    end

    show_nc_button.image = nc_button_icon

    return show_nc_button
end
