-- Utilidades puras del explorador (sin estado ni efectos).
local uv = vim.uv or vim.loop
local M = {}

-- Normaliza una ruta para comparar (Windows: sin distinguir mayúsculas ni barras)
function M.normpath(p)
  return p and (p:gsub("\\", "/"):gsub("/+$", ""):lower()) or ""
end

-- Lee un directorio: carpetas primero, luego alfabético
function M.read_dir(path)
  local entries = {}
  local handle = uv.fs_scandir(path)
  if handle then
    while true do
      local name, t = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      entries[#entries + 1] = { name = name, is_dir = (t == "directory") }
    end
  end
  table.sort(entries, function(a, b)
    if a.is_dir ~= b.is_dir then
      return a.is_dir
    end
    return a.name:lower() < b.name:lower()
  end)
  return entries
end

return M
