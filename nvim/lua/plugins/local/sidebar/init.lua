-- Panel lateral genérico (plugin-free): gestiona UNA ventana lateral por workspace (tab) que
-- hospeda VISTAS registrables (el explorador, la configuración…). Se encarga de todo lo común:
-- abrir/cerrar, ancho y lado configurables, auto-colapsar al perder el foco (mostrando el
-- título de la vista en vertical), la winbar de pestañas y el cambio de vista con <Tab>.
-- Cada vista implementa: { id, order, icon, title, filetype, create()->buf, attach(win,buf),
-- on_focus(win,focused)?, destroy(buf)? }.
local api = vim.api
local theme = require("config.theme")
local palette = require("config.palette")
local uiwin = require("plugins.local.ui.win") -- set_opts: window-local sin tocar el default global
local M = {}

local DEFAULT_WIDTH = 47
local COLLAPSED_WIDTH = 4 -- ancho al perder el foco (muestra el título en vertical)
local collapsed_ns = api.nvim_create_namespace("sidebar_collapsed")

theme.register(function()
  api.nvim_set_hl(0, "SidebarActivePanel", { fg = palette.blue, bold = true }) -- pestaña activa
  api.nvim_set_hl(0, "SidebarInactivePanel", { fg = palette.comment }) -- pestaña inactiva
  -- cursor "oculto": mismo fg y bg (queda invisible sobre la línea marcada, en col 0 = espacio)
  api.nvim_set_hl(0, "SidebarHiddenCursor", { fg = palette.bg_highlight, bg = palette.bg_highlight })
end)

-- ── Registro de vistas ─────────────────────────────────────────────
local views = {} -- id -> view
local order = {} -- ids ordenados por view.order

---@class SidebarView
---@field id string           Identificador único del panel
---@field order? number       Posición en el sidebar (menor = antes, default 99)
---@field icon string         Icono para la vista colapsada
---@field filetype string     Filetype del buffer que crea este panel
---@field create fun(win?: integer): integer Crea el contenido del panel en la ventana dada
---@field attach? fun(win: integer, buf: integer) Llamado al re-adjuntar una ventana existente
---@field on_focus? fun(win: integer, focused: boolean) Llamado al ganar/perder foco
---@field destroy? fun()      Limpieza al cerrar el panel

---@param view SidebarView
function M.register(view)
  views[view.id] = view
  order = vim.tbl_keys(views)
  table.sort(order, function(a, b)
    return (views[a].order or 99) < (views[b].order or 99)
  end)
end
local function view_ft()
  local set = {}
  for _, v in pairs(views) do
    if v.filetype then
      set[v.filetype] = true
    end
  end
  return set
end

-- ── Estado por tab ─────────────────────────────────────────────────
-- SB[tab] = { win, view, collapsed, collapsed_buf, saved_cursor, bufs = { [id]=buf } }
local SB = {}
local function cur()
  return SB[api.nvim_get_current_tabpage()]
end

function M.width()
  return require("config.settings").value("ui.sidebar_width", DEFAULT_WIDTH)
end
function M.side()
  return require("config.settings").value("ui.sidebar_side", "left")
end

-- ¿el buffer pertenece al sidebar del tab actual? (vistas + colapsado). Lo usa el explorer
-- para no revertir sus propios swaps al detectar buffers "foráneos" en la ventana.
function M.owns_buf(buf)
  local sb = cur()
  if not sb then
    return false
  end
  if buf == sb.collapsed_buf then
    return true
  end
  for _, b in pairs(sb.bufs) do
    if b == buf then
      return true
    end
  end
  return false
end
function M.active_buf()
  local sb = cur()
  return sb and sb.bufs[sb.view]
end
-- Ventana del sidebar del tab actual (o nil)
function M.win()
  local sb = cur()
  return sb and sb.win
end
function M.view()
  local sb = cur()
  return sb and sb.view
end
function M.is_collapsed()
  local sb = cur()
  return sb ~= nil and sb.collapsed == true
end

-- ── Winbar de pestañas ─────────────────────────────────────────────
function M.set_winbar(sb)
  if not (sb and sb.win and api.nvim_win_is_valid(sb.win)) then
    return
  end
  local cells = {}
  for i, id in ipairs(order) do
    local hl = (sb.view == id) and "%#SidebarActivePanel#" or "%#SidebarInactivePanel#"
    cells[#cells + 1] = string.format("%%%d@v:lua.__sidebar_go@ %s  %s  %%X%%*", i, hl, views[id].icon)
  end
  uiwin.set_opts(sb.win, { winbar = "%=" .. table.concat(cells) .. "%=" })
end
function _G.__sidebar_go(minwid)
  local id = order[minwid]
  if id then
    M.show(id)
  end
end

-- ── Colapsar / expandir ────────────────────────────────────────────
local function render_collapsed(sb)
  local buf = sb.collapsed_buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local h = api.nvim_win_is_valid(sb.win) and api.nvim_win_get_height(sb.win) or #order
  local top = math.max(0, math.floor((h - #order) / 2))
  local col = math.max(0, math.floor((COLLAPSED_WIDTH - 1) / 2))
  local lines = {}
  for _ = 1, top do
    lines[#lines + 1] = ""
  end
  for _, id in ipairs(order) do
    lines[#lines + 1] = string.rep(" ", col) .. views[id].icon
  end
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  api.nvim_buf_clear_namespace(buf, collapsed_ns, 0, -1)

  for i, id in ipairs(order) do
    local line = top + i - 1  -- índice de línea 0-based
    local hl = (sb.view == id) and "SidebarActivePanel" or "SidebarInactivePanel"
      pcall(api.nvim_buf_set_extmark, buf, collapsed_ns, line, col, {
          end_col = col + #views[id].icon,
          hl_group = hl,
      })
  end
end

local function collapse(sb)
  if not (sb and sb.win and api.nvim_win_is_valid(sb.win)) or sb.collapsed then
    return
  end
  if api.nvim_get_current_win() == sb.win then
    return -- enfocado: no colapsar
  end
  if not (sb.collapsed_buf and api.nvim_buf_is_valid(sb.collapsed_buf)) then
    sb.collapsed_buf = api.nvim_create_buf(false, true)
    vim.bo[sb.collapsed_buf].bufhidden = "hide"
  end
  vim.bo[sb.collapsed_buf].filetype = (views[sb.view] and views[sb.view].filetype) or "sidebar"
  sb.saved_cursor = api.nvim_win_get_cursor(sb.win) -- restaurar al expandir
  uiwin.set_opts(sb.win, { winbar = "" })
  api.nvim_win_set_buf(sb.win, sb.collapsed_buf)
  -- limpiar la ventana: el swap de buffer no dispara winopts sobre ESTA ventana (corre sobre
  -- la actual, el editor), así que sin esto el panel colapsado heredaría los números del global.
  for name, val in pairs({ number = false, relativenumber = false, signcolumn = "no", list = false, cursorline = false }) do
    pcall(api.nvim_set_option_value, name, val, { win = sb.win, scope = "local" })
  end
  render_collapsed(sb)
  api.nvim_win_set_width(sb.win, COLLAPSED_WIDTH)
  sb.collapsed = true
end

local function expand(sb)
  if not (sb and sb.win and api.nvim_win_is_valid(sb.win)) or not sb.collapsed then
    return
  end
  sb.collapsed = false
  local buf = sb.bufs[sb.view]
  if buf and api.nvim_buf_is_valid(buf) then
    api.nvim_win_set_buf(sb.win, buf)
  end
  api.nvim_win_set_width(sb.win, M.width())
  M.set_winbar(sb)
  if views[sb.view] and buf then
    views[sb.view].attach(sb.win, buf) -- repone opciones/estilo de la vista
  end
  if sb.saved_cursor then
    local n = api.nvim_buf_line_count(api.nvim_win_get_buf(sb.win))
    pcall(api.nvim_win_set_cursor, sb.win, { math.min(sb.saved_cursor[1], n), sb.saved_cursor[2] })
    sb.saved_cursor = nil
  end
end

-- Reajusta según el foco: expandir si el sidebar es el activo, colapsar si no. Los flotantes
-- (pickers) no cuentan como "salir" del panel.
function M.refresh()
  local sb = cur()
  if not (sb and sb.win and api.nvim_win_is_valid(sb.win)) then
    return
  end
  local w = api.nvim_get_current_win()
  if api.nvim_win_get_config(w).relative ~= "" then
    return
  end
  if w == sb.win then
    expand(sb)
  else
    collapse(sb)
  end
end

-- ── Ancho / lado ───────────────────────────────────────────────────
function M.set_width(w)
  require("config.settings").record("ui.sidebar_width", w, DEFAULT_WIDTH)
  local sb = cur()
  if sb and sb.win and api.nvim_win_is_valid(sb.win) and not sb.collapsed then
    api.nvim_win_set_width(sb.win, w)
  end
end
function M.set_side(side)
  require("config.settings").record("ui.sidebar_side", side, "left")
  local sb = cur()
  if sb and sb.win and api.nvim_win_is_valid(sb.win) then
    pcall(api.nvim_win_call, sb.win, function()
      vim.cmd("wincmd " .. (side == "right" and "L" or "H"))
    end)
    api.nvim_win_set_width(sb.win, sb.collapsed and COLLAPSED_WIDTH or M.width())
  end
  vim.cmd("redrawtabline") -- las píldoras de workspace se alinean al lado del sidebar
end
-- Reconcilia el sidebar de un tab con los ajustes globales (lo llama TabEnter: el sidebar es
-- por-tab, y cambiar lado/ancho desde el panel solo movió el del tab activo).
function M.reconcile(sb)
  sb = sb or cur()
  if not (sb and sb.win and api.nvim_win_is_valid(sb.win)) then
    return
  end
  local want = M.side()
  local is_left = api.nvim_win_get_position(sb.win)[2] == 0
  if (want == "left") ~= is_left then
    pcall(api.nvim_win_call, sb.win, function()
      vim.cmd("noautocmd wincmd " .. (want == "right" and "L" or "H"))
    end)
  end
  -- reponer el ancho SIEMPRE (wincmd L/H re-ensancha; colapsado debe conservar su ancho)
  api.nvim_win_set_width(sb.win, sb.collapsed and COLLAPSED_WIDTH or M.width())
end

-- ── Abrir / mostrar / cerrar ───────────────────────────────────────
local function clean_win(win)
  for name, val in pairs({ number = false, relativenumber = false, signcolumn = "no", list = false, winfixwidth = true }) do
    pcall(api.nvim_set_option_value, name, val, { win = win, scope = "local" })
  end
end

-- Muestra una vista (crea su buffer si hace falta) en la ventana del sidebar
function M.show(id)
  local sb = cur()
  if not (sb and sb.win and api.nvim_win_is_valid(sb.win)) or not views[id] then
    return
  end
  api.nvim_set_current_win(sb.win)
  sb.collapsed = false
  local buf = sb.bufs[id]
  if not (buf and api.nvim_buf_is_valid(buf)) then
    buf = views[id].create()
    sb.bufs[id] = buf
  end
  api.nvim_win_set_buf(sb.win, buf)
  sb.view = id
  api.nvim_win_set_width(sb.win, M.width())
  views[id].attach(sb.win, buf)
  M.set_winbar(sb)
end

-- Abre el sidebar (en la vista `id`, por defecto la primera). Si ya está abierto, enfoca y
-- muestra la vista pedida.
function M.open(id)
  id = id or order[1]
  if not id then
    return
  end
  local tab = api.nvim_get_current_tabpage()
  local sb = SB[tab]
  if sb and sb.win and api.nvim_win_is_valid(sb.win) then
    api.nvim_set_current_win(sb.win)
    if id ~= sb.view then
      M.show(id)
    end
    return
  end
  -- huérfanos tras :ReloadConfig: cerrar cualquier ventana de sidebar sin estado
  local fts = view_ft()
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    local b = api.nvim_win_get_buf(w)
    if api.nvim_buf_is_valid(b) and fts[vim.bo[b].filetype] then
      pcall(api.nvim_win_close, w, true)
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end
  sb = { view = id, bufs = {} }
  SB[tab] = sb
  vim.cmd(M.side() == "right" and "botright vsplit" or "topleft vsplit")
  sb.win = api.nvim_get_current_win()
  clean_win(sb.win)
  api.nvim_win_set_width(sb.win, M.width())
  local buf = views[id].create()
  sb.bufs[id] = buf
  api.nvim_win_set_buf(sb.win, buf)
  views[id].attach(sb.win, buf)
  M.set_winbar(sb)
end

function M.close()
  local sb = cur()
  if not sb then
    return
  end
  for id, buf in pairs(sb.bufs) do
    if views[id] and views[id].destroy then
      pcall(views[id].destroy, buf)
    end
  end
  if sb.win and api.nvim_win_is_valid(sb.win) then
    api.nvim_win_close(sb.win, true)
  end
  for _, buf in pairs(sb.bufs) do
    if buf and api.nvim_buf_is_valid(buf) then
      pcall(api.nvim_buf_delete, buf, { force = true })
    end
  end
  if sb.collapsed_buf and api.nvim_buf_is_valid(sb.collapsed_buf) then
    pcall(api.nvim_buf_delete, sb.collapsed_buf, { force = true })
  end
  SB[api.nvim_get_current_tabpage()] = nil
end

function M.toggle()
  local sb = cur()
  if sb and sb.win and api.nvim_win_is_valid(sb.win) then
    M.close()
  else
    M.open()
  end
end

-- Alterna el foco entre el sidebar y la edición
function M.focus()
  local sb = cur()
  if not (sb and sb.win and api.nvim_win_is_valid(sb.win)) then
    M.open()
    return
  end
  if api.nvim_get_current_win() == sb.win then
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      if w ~= sb.win and api.nvim_win_get_config(w).relative == "" and not vim.wo[w].winfixwidth then
        api.nvim_set_current_win(w)
        return
      end
    end
  else
    api.nvim_set_current_win(sb.win)
  end
end

-- Cambia de vista en `dir` (+1 siguiente / -1 anterior), ciclando.
local function step(dir)
  local sb = cur()
  if not sb then
    return
  end
  local i = 1
  for k, id in ipairs(order) do
    if id == sb.view then
      i = k
    end
  end
  M.show(order[((i - 1 + dir) % #order) + 1])
end

function M.next() -- <Tab>
  step(1)
end
function M.prev() -- <S-Tab>
  step(-1)
end

-- ── Autocomandos genéricos ─────────────────────────────────────────
api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  group = api.nvim_create_augroup("SidebarFocus", { clear = true }),
  desc = "Colapsar/expandir y atenuar el sidebar según el foco",
  callback = function()
    local sb = cur()
    if sb and sb.win and api.nvim_win_is_valid(sb.win) then
      local v = views[sb.view]
      if v and v.on_focus then
        v.on_focus(sb.win, api.nvim_get_current_win() == sb.win)
      end
    end
    M.refresh()
  end,
})

api.nvim_create_autocmd("TabEnter", {
  group = api.nvim_create_augroup("SidebarReconcile", { clear = true }),
  callback = function()
    M.reconcile()
  end,
})

-- Cursor oculto dentro del sidebar (guicursor es global: se guarda y se repone al salir)
local saved_guicursor
api.nvim_create_autocmd("BufEnter", {
  group = api.nvim_create_augroup("SidebarCursor", { clear = true }),
  desc = "Ocultar el cursor dentro del sidebar",
  callback = function(ev)
    if view_ft()[vim.bo[ev.buf].filetype] then
      if not saved_guicursor then
        saved_guicursor = vim.o.guicursor
        vim.o.guicursor = "n:SidebarHiddenCursor"
      end
    elseif saved_guicursor then
      vim.o.guicursor = saved_guicursor
      saved_guicursor = nil
    end
  end,
})

return M
