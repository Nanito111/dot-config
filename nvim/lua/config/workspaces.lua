-- Nombres predefinidos de workspaces por ruta. El mapa { [ruta absoluta] = nombre } se persiste
-- en settings.json (clave workspace.names) y se edita desde el panel (sección Workspaces). Al
-- crear un workspace (<leader>sn), el input del nombre muestra name_for(dir) como ghost text;
-- si la ruta no tiene nombre guardado, usa el nombre de la carpeta.
local M = {}

local KEY = "workspace.names"

-- Ruta absoluta normalizada (expande ~/$VAR, sin barra final), para usar como clave estable.
local function norm(path)
  local a = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  if a ~= "/" then -- no reducir la raíz "/" a "" al quitar la barra final
    a = a:gsub("[\\/]+$", "")
  end
  return a
end
M.norm = norm

local names = nil -- cache; nil = aún no cargado
local function map()
  if names == nil then
    names = vim.deepcopy(require("config.settings").value(KEY, {}))
  end
  return names
end

local function persist()
  require("config.settings").record(KEY, map(), {})
end

-- Nombre sugerido para `dir`: el guardado para esa ruta, o el nombre de la carpeta.
function M.name_for(dir)
  local abs = norm(dir)
  local base = vim.fn.fnamemodify(abs, ":t")
  if base == "" then -- raíz "/": el basename es vacío
    base = abs
  end
  return map()[abs] or base
end

-- Guarda (o borra, si el nombre queda vacío) el nombre de una ruta.
function M.set(path, name)
  local abs = norm(path)
  name = name and vim.trim(name) or ""
  map()[abs] = (name ~= "") and name or nil
  persist()
end

function M.remove(path)
  map()[norm(path)] = nil
  persist()
end

-- Filas para la tabla del panel: { { path, name }, ... } ordenadas por ruta.
function M.rows()
  local out = {}
  for path, name in pairs(map()) do
    out[#out + 1] = { path = path, name = name }
  end
  table.sort(out, function(a, b)
    return a.path < b.path
  end)
  return out
end

return M
