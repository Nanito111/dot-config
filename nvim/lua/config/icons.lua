-- Iconos por nombre/extensión, basados en las tablas de nvim-web-devicons.
-- Expone icono y color por tipo.
local by_name = require("config.icons_filename") -- nombre exacto (package.json, Makefile…)
local db = require("config.icons_data") -- por extensión (lua, ts, go…)
local M = {}

M.default = "\u{f15b}" -- archivo genérico

-- basename de una ruta
local function base(name)
  return name and (name:match("[^/\\]+$") or name) or ""
end

-- Extensión corta (en minúsculas) de un nombre, o nil
function M.ext(name)
  local e = name and base(name):match("%.([%w_%-]+)$")
  return e and e:lower() or nil
end

-- Entrada para `name`: 1) nombre exacto (package.json, Makefile…),
-- 2) por extensión (respetando mayúsculas, p. ej. "R", y en minúsculas)
local function entry(name)
  if not name or name == "" then
    return nil
  end
  local b = base(name)
  local e = by_name[b] or db[b]
  if e then
    return e
  end
  local ext = b:match("%.([%w_%-]+)$")
  if ext then
    return db[ext] or db[ext:lower()]
  end
  return nil
end

-- Icono (glifo) según el nombre o su extensión
function M.icon(name)
  local e = entry(name)
  return (e and e.icon) or M.default
end

-- Color (hex) del icono, o nil
function M.color(name)
  local e = entry(name)
  return e and e.color or nil
end

return M
