local astal = require("astal")
local Variable = require("astal").Variable
local Gtk = require("astal.gtk3").Gtk
local GLib = astal.require("GLib")
local bind = astal.bind

local M = {}

function M.src(path)
    local str = debug.getinfo(2, "S").source:sub(2)
    local src = str:match("(.*/)") or str:match("(.*\\)") or "./"
    return src .. path
end

---@generic T, R
---@param arr T[]
---@param func fun(T, integer): R
---@return R[]
function M.map(arr, func)
    local new_arr = {}
    for i, v in ipairs(arr) do
        new_arr[i] = func(v, i)
    end
    return new_arr
end

---@param path string
---@return boolean
function M.file_exists(path)
    return GLib.file_test(path, "EXISTS")
end

function M.varmap(initial)
    local map = initial
    local var = Variable.new()

    local function notify()
        local arr = {}
        for _, value in pairs(map) do
            table.insert(arr, value)
        end
        var:set(arr)
    end

    local function delete(key)
        if Gtk.Widget:is_type_of(map[key]) then
            map[key]:destroy()
        end

        map[key] = nil
    end

    notify()

    return setmetatable({
        set = function(key, value)
            delete(key)
            map[key] = value
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

---@param time number
---@param format? string
function M.time(time, format)
    format = format or "%H:%M"
    return GLib.DateTime.new_from_unix_local(time):format(format)
end

function M.reload_css(event, app, scss, css)
    if event ~= 0 then
        return
    end
    print("style changes detected in" .. scss .. ", reloading CSS")
    M.create_css_from_sass(scss, css)
    print("applying CSS to App")
    app:apply_css(css)
end

function M.create_css_from_sass(scss, css)
    astal.exec("sass " .. scss .. " " .. css)
end

function M.sort_by_key(tbl, sort_fn)
    local keys = {}

    for k in pairs(tbl) do
        table.insert(keys, k)
    end

    if sort_fn then
        table.sort(keys, sort_fn)
    else
        table.sort(keys)
    end

    local sorted = {}
    for _, k in ipairs(keys) do
        sorted[k] = tbl[k]
    end

    return sorted
end

return M
