-- Iconos por nombre/extensión. Fachada sobre nvim-web-devicons (el spec lo instala): expone
-- icono y color por tipo, con la misma API que consumen explorer/picker/winbar/statusline.
local M = {}

M.default = "\u{f15b}" -- archivo genérico (fallback si el plugin no reconoce el nombre)

-- require memoizado y perezoso: no en cada llamada (icon() corre por cada línea del árbol),
-- y se resuelve en el primer uso, cuando el plugin ya está en el rtp (spec con lazy=false).
local devicons
local function di()
  devicons = devicons or require("nvim-web-devicons")
  return devicons
end

-- basename de una ruta
local function base(name)
  return name and (name:match("[^/\\]+$") or name) or ""
end

-- Extensión corta (en minúsculas) de un nombre, o nil
function M.ext(name)
  local e = name and base(name):match("%.([%w_%-]+)$")
  return e and e:lower() or nil
end

-- Icono (glifo) según el nombre o su extensión. get_icon hace el lookup en dos niveles
-- (nombre exacto tipo package.json/Makefile, luego extensión); default=true devuelve su
-- icono genérico para lo desconocido, que caemos a M.default por si acaso.
function M.icon(name)
  local ic = di().get_icon(base(name), M.ext(name), { default = true })
  return ic or M.default
end

-- Color (hex) del icono, o nil si el plugin no lo conoce (los consumidores ya tratan nil)
function M.color(name)
  local _, hex = di().get_icon_color(base(name), M.ext(name))
  return hex
end

return M
