-- Vigilancia del directorio raíz (fs_event recursivo) y refresco con debounce.
local uv = vim.uv or vim.loop
local api = vim.api
local render = require("plugins.local.explorer.render")
local git = require("plugins.local.explorer.git")

local M = {}

-- Refresco del árbol con debounce (desde el watcher / autocomandos)
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

function M.stop_watch(s)
  if s and s.watcher then
    pcall(function()
      s.watcher:stop()
      s.watcher:close()
    end)
    s.watcher = nil
  end
end

-- Vigila el directorio raíz (recursivo) y refresca en tiempo real
function M.start_watch(s)
  M.stop_watch(s)
  local w = uv.new_fs_event()
  s.watcher = w
  pcall(function()
    w:start(s.root, { recursive = true }, function(err)
      if not err then
        M.schedule_render(s) -- refresco rápido del árbol
        git.schedule_git(s) -- y de las marcas de git
      end
    end)
  end)
end

return M
