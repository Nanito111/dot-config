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
      local is_link = (t == "link")
      local is_dir = (t == "directory")
      if is_link then
        -- fs_scandir_next reporta "link" sin resolver; fs_stat SÍ sigue el enlace, así un
        -- symlink a una carpeta se trata (icono/expandir/navegar) como carpeta. Si está roto
        -- (destino inexistente), fs_stat devuelve nil y queda como archivo.
        local st = uv.fs_stat(path .. "/" .. name)
        is_dir = st ~= nil and st.type == "directory"
      end
      entries[#entries + 1] = { name = name, is_dir = is_dir, is_link = is_link }
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
