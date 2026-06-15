-- Estado de git de la raíz (async) y re-render con las marcas.
local uv = vim.uv or vim.loop
local api = vim.api
local util = require("plugins.local.explorer.util")
local render = require("plugins.local.explorer.render")

local normpath = util.normpath
local M = {}

-- Obtiene el estado de git de la raíz (async) y re-renderiza con las marcas
function M.update_git(s)
  if not s or vim.fn.executable("git") == 0 then
    return
  end
  local root = s.root
  vim.system({ "git", "-C", root, "rev-parse", "--show-toplevel" }, { text = true }, function(r1)
    if r1.code ~= 0 then -- no es un repo
      vim.schedule(function()
        s.git = {}
        if s.win and api.nvim_win_is_valid(s.win) then
          render.render(s)
        end
      end)
      return
    end
    local top = vim.trim(r1.stdout or "")
    vim.system({ "git", "-C", root, "status", "--porcelain", "-uall" }, { text = true }, function(r2)
      local map = {}
      if r2.code == 0 then
        local ntop = normpath(top)
        for line in (r2.stdout or ""):gmatch("[^\r\n]+") do
          local xy = line:sub(1, 2)
          local p = line:sub(4)
          local arrow = p:find(" %-> ")
          if arrow then
            p = p:sub(arrow + 4)
          end
          p = p:gsub('^"', ""):gsub('"$', "")
          local abs = normpath(top .. "/" .. p)
          map[abs] = xy
          -- ¿el archivo tiene algo sin stagear? (untracked o Y != espacio)
          local unstaged = (xy == "??") or (xy:sub(2, 2) ~= " ")
          local dircode = unstaged and "DU" or "DS"
          -- marcar las carpetas ancestro; "DU" (sin stagear) gana sobre "DS"
          local d = abs:match("(.+)/[^/]+$")
          while d and #d > #ntop do
            local prev = map[d]
            if prev ~= "DU" and (prev == nil or dircode == "DU") then
              map[d] = dircode
            end
            d = d:match("(.+)/[^/]+$")
          end
        end
      end
      vim.schedule(function()
        s.git = map
        if s.win and api.nvim_win_is_valid(s.win) then
          render.render(s)
        end
      end)
    end)
  end)
end

-- update_git con debounce
function M.schedule_git(s)
  if not s then
    return
  end
  if s.git_timer then
    s.git_timer:stop()
    s.git_timer:close()
  end
  s.git_timer = uv.new_timer()
  s.git_timer:start(120, 0, vim.schedule_wrap(function()
    M.update_git(s)
  end))
end

return M
