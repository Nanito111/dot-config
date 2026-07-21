-- Autocomandos del explorador: refresco al guardar, limpieza de tabs cerradas,
-- seguir el cwd, resaltar/revelar el archivo actual, restaurar el dashboard y
-- corregir accidentes con `:e`.
local api = vim.api
local state = require("plugins.local.explorer.state")
local render = require("plugins.local.explorer.render")
local watch = require("plugins.local.explorer.watch")
local git = require("plugins.local.explorer.git")
local actions = require("plugins.local.explorer.actions")
local util = require("plugins.local.explorer.util")

local group = state.group
local cur = state.cur
local normpath = util.normpath
local autocmd = api.nvim_create_autocmd

-- Refrescar al guardar (respaldo del watcher), solo si hay explorador en la tab
autocmd("BufWritePost", {
  group = group,
  callback = function()
    watch.schedule_render(cur())
    git.schedule_git(cur()) -- el estado de git pudo cambiar
  end,
})

-- Refrescar las marcas de git ante operaciones EXTERNAS que el watcher no capta (en
-- Linux fs_event no es recursivo y no ve los cambios en .git/): al volver el foco a
-- Neovim, al salir/cerrar una terminal embebida (lazygit, git en :terminal) o tras un
-- comando de shell (:!git ...). Así stage/commit/checkout se reflejan sin quedar marcas.
autocmd({ "FocusGained", "TermLeave", "TermClose", "ShellCmdPost" }, {
  group = group,
  callback = function()
    git.schedule_git(cur())
  end,
})

-- Limpiar estados (watchers/timers) de tabs cerradas
autocmd("TabClosed", {
  group = group,
  callback = function()
    for tab, s in pairs(state.states) do
      if not api.nvim_tabpage_is_valid(tab) then
        watch.stop_watch(s)
        for _, t in ipairs({ "timer", "git_timer" }) do
          if s[t] then
            pcall(function()
              s[t]:stop()
              s[t]:close()
            end)
          end
        end
        if s.buf and api.nvim_buf_is_valid(s.buf) then
          pcall(api.nvim_buf_delete, s.buf, { force = true })
        end
        state.states[tab] = nil
      end
    end
  end,
})

-- El explorador sigue al cwd (tcd/cd/cambio de tab)
autocmd("DirChanged", {
  group = group,
  pattern = "*",
  callback = function()
    require("plugins.local.explorer").follow()
  end,
})

-- Resaltar y revelar en el árbol el archivo abierto en la ventana principal
autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    local s = cur()
    if not (s and s.win and api.nvim_win_is_valid(s.win)) then
      return
    end
    local name = api.nvim_buf_get_name(ev.buf)
    if vim.bo[ev.buf].buftype ~= "" or name == "" or vim.bo[ev.buf].filetype == "explorer" then
      return
    end
    if s.current_file ~= name then
      s.current_file = name
      render.reveal(s) -- expandir hasta el archivo
      render.render(s)
      -- mover el cursor del explorador al archivo (sin robar el foco)
      local target = normpath(name)
      for i, n in ipairs(s.nodes) do
        if not n.is_dir and normpath(n.path) == target then
          pcall(api.nvim_win_set_cursor, s.win, { i + 1, 0 }) -- +1 por la línea raíz
          break
        end
      end
    end
  end,
})

-- Si al cerrar una ventana queda SOLO el explorador, restaurar el dashboard
local rebuilding = false
autocmd("WinClosed", {
  group = group,
  callback = function()
    if rebuilding then
      return
    end
    vim.schedule(function()
      if rebuilding or not actions.only_explorer() then
        return
      end
      local s = cur()
      if not (s and s.win and api.nvim_win_is_valid(s.win)) then
        return
      end
      rebuilding = true
      pcall(function()
        api.nvim_set_current_win(s.win)
        -- la ventana del dashboard va al lado OPUESTO del panel (según su lado configurado)
        local right = require("plugins.local.explorer").side() == "right"
        vim.cmd(right and "noautocmd leftabove vsplit" or "noautocmd rightbelow vsplit")
        vim.cmd("noautocmd enew") -- buffer vacío (no el explorador) para el dashboard
        require("plugins.local.dashboard").open()
        if api.nvim_win_is_valid(s.win) then
          api.nvim_win_set_width(s.win, require("plugins.local.explorer").width()) -- restaurar ancho
        end
        require("config.util").wipe_orphan_buffers()
      end)
      rebuilding = false
    end)
  end,
})

-- Corrige accidentes con `:e`:
--  A) un archivo/dir reemplaza el explorador en su ventana -> recuperarla
--  B) un :e <dir> abre un buffer de directorio en una ventana normal -> deshacer
autocmd("BufWinEnter", {
  group = group,
  callback = function(ev)
    local s = cur()
    if not (s and s.win and api.nvim_win_is_valid(s.win)) then
      return
    end
    local win = api.nvim_get_current_win()
    local buf = ev.buf
    local name = api.nvim_buf_get_name(buf)
    local is_dir = name ~= "" and vim.fn.isdirectory(name) == 1

    -- A) el explorador fue reemplazado en su propia ventana (por un :e accidental; NO por
    --    el cambio de vista con <Tab> ni el auto-colapso, que son intencionales)
    if win == s.win and buf ~= s.buf and buf ~= s.settings_buf and buf ~= s.collapsed_buf then
      vim.schedule(function()
        if not (api.nvim_win_is_valid(s.win) and s.buf and api.nvim_buf_is_valid(s.buf)) then
          return
        end
        api.nvim_win_set_buf(s.win, s.buf) -- devolver el explorador
        if not is_dir and name ~= "" then
          actions.open_file(s, name) -- el archivo va a la principal
        end
      end)
      return
    end

    -- B) :e <dir> en una ventana normal -> volver al archivo anterior
    if is_dir and win ~= s.win then
      local alt = vim.fn.bufnr("#")
      local alt_ok = alt > 0
        and api.nvim_buf_is_valid(alt)
        and vim.bo[alt].buftype == ""
        and api.nvim_buf_get_name(alt) ~= ""
        and vim.fn.isdirectory(api.nvim_buf_get_name(alt)) == 0
      vim.schedule(function()
        if not api.nvim_win_is_valid(win) then
          return
        end
        if alt_ok then
          api.nvim_win_set_buf(win, alt)
        else
          api.nvim_set_current_win(win)
          require("plugins.local.dashboard").open()
        end
        if api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
          pcall(api.nvim_buf_delete, buf, { force = true })
        end
      end)
    end
  end,
})

return {}
