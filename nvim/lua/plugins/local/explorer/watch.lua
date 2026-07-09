-- Vigilancia del árbol y refresco con debounce.
--
-- fs_event con { recursive = true } SOLO es recursivo en macOS/Windows; en Linux/WSL
-- libuv vigila únicamente el directorio indicado (no sus subcarpetas). Por eso, en vez
-- de un watcher recursivo de la raíz, vigilamos UN watcher por cada carpeta VISIBLE
-- (raíz + directorios expandidos): así todo lo que se ve en el árbol se actualiza en
-- tiempo real, sin vigilar ramas colapsadas ni árboles enormes (node_modules, etc.).
-- La lista de watchers se reconcilia en cada render (al expandir/colapsar cambia).
local uv = vim.uv or vim.loop
local api = vim.api
local render = require("plugins.local.explorer.render")
local git = require("plugins.local.explorer.git")

local M = {}

-- Refresco del árbol con debounce (desde los watchers / autocomandos)
function M.schedule_render(s)
  if not s then
    return
  end
  if s.timer then
    s.timer:stop()
    s.timer:close()
  end
  s.timer = uv.new_timer()
  s.timer:start(50, 0, vim.schedule_wrap(function()
    if s.win and api.nvim_win_is_valid(s.win) then
      render.render(s)
    end
  end))
end

-- Detiene y cierra un handle de fs_event con seguridad
local function close_watcher(w)
  pcall(function()
    w:stop()
    w:close()
  end)
end

-- Para todos los watchers del estado
function M.stop_watch(s)
  if not s then
    return
  end
  if s.watchers then
    for dir, w in pairs(s.watchers) do
      close_watcher(w)
      s.watchers[dir] = nil
    end
  end
  if s.watcher then -- watcher único heredado (compat. con estados viejos)
    close_watcher(s.watcher)
    s.watcher = nil
  end
end

-- Directorios cuyo contenido se MUESTRA en el árbol: la raíz + los expandidos.
local function visible_dirs(s)
  local want = { [s.root] = true }
  for path, expanded in pairs(s.expanded or {}) do
    if expanded then
      want[path] = true
    end
  end
  return want
end

-- Reconcilia el conjunto de watchers para que coincida con las carpetas visibles:
-- arranca los nuevos, detiene los que ya no se muestran. Idempotente y barato.
function M.reconcile(s)
  if not s then
    return
  end
  s.watchers = s.watchers or {}
  local want = visible_dirs(s)

  -- detener los que ya no hacen falta (carpeta colapsada, borrada o fuera de la raíz)
  for dir, w in pairs(s.watchers) do
    if not want[dir] then
      close_watcher(w)
      s.watchers[dir] = nil
    end
  end

  -- arrancar los nuevos
  for dir in pairs(want) do
    if not s.watchers[dir] and vim.fn.isdirectory(dir) == 1 then
      local w = uv.new_fs_event()
      local ok = pcall(function()
        w:start(dir, {}, function(err) -- {} = no recursivo (una carpeta)
          if not err then
            M.schedule_render(s)
            git.schedule_git(s)
          end
        end)
      end)
      if ok then
        s.watchers[dir] = w
      else
        close_watcher(w)
      end
    end
  end
end

-- Inicia la vigilancia (equivale a reconciliar desde cero)
function M.start_watch(s)
  M.reconcile(s)
end

return M
