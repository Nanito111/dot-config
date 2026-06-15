-- Explorador de archivos propio — plugin-free.
-- API pública y cableado. La lógica vive en los submódulos:
--   state · util · render · git · watch · actions · autocmds
local api = vim.api
local state = require("plugins.local.explorer.state")
local render = require("plugins.local.explorer.render")
local watch = require("plugins.local.explorer.watch")
local git = require("plugins.local.explorer.git")
local actions = require("plugins.local.explorer.actions")

local cur = state.cur
local states = state.states

local M = {}

-- Abre el explorador como panel lateral izquierdo (en la tab actual)
function M.open()
  local existing = cur()
  if existing and existing.win and api.nvim_win_is_valid(existing.win) then
    api.nvim_set_current_win(existing.win)
    return
  end

  -- Tras un :ReloadConfig el estado por-tab (states) se pierde, pero la ventana del
  -- explorador anterior sigue abierta. Cerrar cualquier explorador huérfano de la
  -- tab para no acumular paneles duplicados.
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    local b = api.nvim_win_get_buf(w)
    if api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "explorer" then
      pcall(api.nvim_win_close, w, true)
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end

  local s = { root = vim.fn.getcwd(), expanded = {}, nodes = {} }
  states[api.nvim_get_current_tabpage()] = s

  s.buf = api.nvim_create_buf(false, true)
  vim.bo[s.buf].buftype = "nofile"
  vim.bo[s.buf].bufhidden = "hide" -- sobrevive al ocultarse (lo borramos en close)
  vim.bo[s.buf].swapfile = false
  vim.bo[s.buf].filetype = "explorer"

  vim.cmd("topleft vsplit")
  s.win = api.nvim_get_current_win()
  api.nvim_win_set_buf(s.win, s.buf)
  api.nvim_win_set_width(s.win, 35)
  local wo = vim.wo[s.win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.cursorline = true
  wo.winfixwidth = true
  wo.list = false

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = s.buf, silent = true, nowait = true })
  end
  map("<CR>", actions.on_enter)
  map("l", actions.on_enter)
  map("h", actions.on_collapse)
  map("-", actions.go_up)
  map("R", function()
    render.render(cur())
  end)
  map("q", M.close)
  map("<Tab>", "<Nop>")
  map("<S-Tab>", "<Nop>")
  -- operaciones de archivo
  map("a", actions.create)
  map("d", actions.delete)
  map("r", actions.rename)
  map("x", actions.cut)
  map("p", actions.paste)
  -- copiar ruta del nodo bajo el cursor (como tenía netrw)
  map("y", function()
    actions.copy_path(false)
  end)
  map("Y", function()
    actions.copy_path(true)
  end)

  render.render(s)
  watch.start_watch(s)
  git.update_git(s) -- marcas de git
end

function M.close()
  local s = cur()
  if not s then
    return
  end
  watch.stop_watch(s)
  for _, t in ipairs({ "timer", "git_timer" }) do
    if s[t] then
      pcall(function()
        s[t]:stop()
        s[t]:close()
      end)
      s[t] = nil
    end
  end
  if s.win and api.nvim_win_is_valid(s.win) then
    api.nvim_win_close(s.win, true)
  end
  if s.buf and api.nvim_buf_is_valid(s.buf) then
    pcall(api.nvim_buf_delete, s.buf, { force = true }) -- bufhidden=hide no se borra solo
  end
  states[api.nvim_get_current_tabpage()] = nil
end

function M.toggle()
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) then
    M.close()
  else
    M.open()
  end
end

-- Alterna el FOCO entre el explorador y la edición (como el viejo <leader>e)
function M.focus()
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    M.open() -- no está abierto: abrir (queda enfocado)
    return
  end
  if api.nvim_get_current_win() == s.win then
    -- estoy en el explorador -> ir a una ventana de edición
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      if w ~= s.win and api.nvim_win_get_config(w).relative == "" and not vim.wo[w].winfixwidth then
        api.nvim_set_current_win(w)
        return
      end
    end
  else
    api.nvim_set_current_win(s.win)
  end
end

-- Re-enraíza el explorador de la tab actual al cwd (para tcd/cambio de tab)
function M.follow()
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) and s.root ~= vim.fn.getcwd() then
    s.root = vim.fn.getcwd()
    render.render(s)
    watch.start_watch(s)
    git.update_git(s)
  end
end

require("plugins.local.explorer.autocmds") -- registra los autocomandos

return M
