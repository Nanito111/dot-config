-- Estado de git de la raíz (async) y re-render con las marcas.
local uv = vim.uv or vim.loop
local api = vim.api
local util = require("plugins.local.explorer.util")
local render = require("plugins.local.explorer.render")

local normpath = util.normpath
local M = {}

-- cwd válido para vim.system: si el cwd del PROCESO quedó colgado (p. ej. tras renombrar
-- el directorio que era el cwd), uv_spawn peta con ENOENT antes de ejecutar nada. git usa
-- `-C root`, así que el cwd solo tiene que ser un directorio que exista.
local function safe_cwd(root)
  if root and vim.fn.isdirectory(root) == 1 then
    return root
  end
  return uv.os_homedir() or vim.fn.stdpath("data")
end

-- Obtiene el estado de git de la raíz (async) y re-renderiza con las marcas.
-- Guard de GENERACIÓN: cada llamada incrementa s.git_gen; los callbacks async solo
-- aplican su resultado si siguen siendo la generación más reciente. Evita que un
-- refresco viejo (que terminó tarde) pise a uno nuevo y deje marcas obsoletas.
function M.update_git(s)
  if not s or vim.fn.executable("git") == 0 then
    return
  end
  s.git_gen = (s.git_gen or 0) + 1
  local gen = s.git_gen
  local root = s.root
  local cwd = safe_cwd(root)
  vim.system({ "git", "-C", root, "rev-parse", "--show-toplevel" }, { text = true, cwd = cwd }, function(r1)
    if r1.code ~= 0 then -- no es un repo
      vim.schedule(function()
        if s.git_gen ~= gen then
          return -- resultado obsoleto
        end
        s.git = {}
        if s.win and api.nvim_win_is_valid(s.win) then
          render.render(s)
        end
      end)
      return
    end
    local top = vim.trim(r1.stdout or "")
    vim.system({ "git", "-C", root, "status", "--porcelain", "-uall" }, { text = true, cwd = cwd }, function(r2)
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
        if s.git_gen ~= gen then
          return -- resultado obsoleto (llegó un refresco más nuevo)
        end
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
