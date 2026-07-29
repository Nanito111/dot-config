-- Explorador de archivos — VISTA del sidebar (plugins.local.sidebar). La ventana, el ancho,
-- el lado, el auto-colapso y las pestañas los gestiona el sidebar; aquí vive la lógica del
-- árbol (render · git · watch · actions · peek). Se registra como una vista y conserva alias
-- de compatibilidad (open/focus/…) que delegan en el sidebar.
local api = vim.api
local state = require("plugins.local.explorer.state")
local render = require("plugins.local.explorer.render")
local watch = require("plugins.local.explorer.watch")
local git = require("plugins.local.explorer.git")
local actions = require("plugins.local.explorer.actions")
local theme = require("config.theme")
local palette = require("config.palette")
local sidebar = require("plugins.local.sidebar")

local cur = state.cur
local states = state.states
local M = {}

-- ── Colores del explorador (los del sidebar viven en su módulo) ────
theme.register(function()
  api.nvim_set_hl(0, "ExplorerCursorLine", { bg = palette.bg_highlight, bold = true })
  api.nvim_set_hl(0, "ExplorerPeek", { bg = palette.bg_highlight, fg = palette.fg }) -- fondo del tooltip
  api.nvim_set_hl(0, "ExplorerBold", { bold = true }) -- negrita del item seleccionado
  api.nvim_set_hl(0, "ExplorerDim", { fg = palette.comment }) -- panel atenuado (sin foco)
end)

-- ── Negrita en el item seleccionado (línea del cursor) ─────────────
local bold_ns = api.nvim_create_namespace("explorer_bold")
local function bold_current()
  local s = cur()
  if not (s and s.buf and api.nvim_buf_is_valid(s.buf) and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  api.nvim_buf_clear_namespace(s.buf, bold_ns, 0, -1)
  local lnum = api.nvim_win_get_cursor(s.win)[1]
  local len = #(api.nvim_buf_get_lines(s.buf, lnum - 1, lnum, false)[1] or "")
  pcall(api.nvim_buf_set_extmark, s.buf, bold_ns, lnum - 1, 0, {
    end_col = len,
    hl_group = "ExplorerBold",
    hl_mode = "combine",
    priority = 300,
  })
end

-- ── Which-key del explorador (? muestra los atajos del buffer) ─────
local function explorer_help()
  local entries = {}
  for _, m in ipairs(api.nvim_buf_get_keymap(0, "n")) do
    if m.desc and m.desc ~= "" and m.lhs ~= "?" then
      entries[#entries + 1] = { key = m.lhsraw or m.lhs, label = m.desc }
    end
  end
  table.sort(entries, function(a, b)
    return a.key:lower() < b.key:lower()
  end)
  local ch = require("plugins.local.whichkey.popup").read_key("Explorador", entries, true)
  if ch and ch ~= "" and ch ~= "\27" then
    api.nvim_feedkeys(string(ch), "m", false)
  end
end

-- ── Atenuar el panel cuando no tiene el foco (on_focus de la vista) ──
local FOCUSED_WINHL = "CursorLine:ExplorerCursorLine"
local DIMMED_WINHL
do
  local groups = {
    "ExplorerDir", "ExplorerFile", "ExplorerRoot", "ExplorerGitNew",
    "GitSignAdd", "GitSignChange", "GitSignDelete", "GitSignChangedelete",
    "GitSignStagedAdd", "GitSignStagedChange", "GitSignStagedDelete",
  }
  local parts = {}
  for _, g in ipairs(groups) do
    parts[#parts + 1] = g .. ":ExplorerDim"
  end
  DIMMED_WINHL = table.concat(parts, ",")
end

local function apply_focus(focused)
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  local wo = vim.wo[s.win]
  if focused then
    wo.winhighlight = FOCUSED_WINHL
    wo.cursorline = true
    bold_current()
  else
    wo.winhighlight = DIMMED_WINHL
    wo.cursorline = false
    if s.buf and api.nvim_buf_is_valid(s.buf) then
      api.nvim_buf_clear_namespace(s.buf, bold_ns, 0, -1)
    end
  end
end

-- ── Peek: tooltip con el nombre completo cuando la línea está cortada ──
local peek_win, peek_buf
local function peek_close()
  if peek_win and api.nvim_win_is_valid(peek_win) then
    pcall(api.nvim_win_close, peek_win, true)
  end
  peek_win = nil
end

local function peek_update()
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) or api.nvim_get_current_win() ~= s.win then
    return peek_close()
  end
  local width = api.nvim_win_get_width(s.win)
  local lnum = api.nvim_win_get_cursor(s.win)[1]
  local line = api.nvim_buf_get_lines(s.buf, lnum - 1, lnum, false)[1] or ""
  if vim.fn.strdisplaywidth(line) <= width then
    return peek_close()
  end

  local text = line .. " "
  local w = math.min(vim.fn.strdisplaywidth(text), vim.o.columns)
  if not (peek_buf and api.nvim_buf_is_valid(peek_buf)) then
    peek_buf = api.nvim_create_buf(false, true)
  end
  vim.bo[peek_buf].modifiable = true
  api.nvim_buf_set_lines(peek_buf, 0, -1, false, { text })
  vim.bo[peek_buf].modifiable = false

  local ns = state.ns
  api.nvim_buf_clear_namespace(peek_buf, ns, 0, -1)
  for _, m in ipairs(api.nvim_buf_get_extmarks(s.buf, ns, { lnum - 1, 0 }, { lnum - 1, -1 }, { details = true })) do
    local start_col, det = m[3], m[4]
    if det.hl_group then
      pcall(api.nvim_buf_set_extmark, peek_buf, ns, 0, start_col, {
        end_col = det.end_col,
        hl_group = det.hl_group,
      })
    end
  end
  pcall(api.nvim_buf_set_extmark, peek_buf, ns, 0, 0, {
    end_col = #text,
    hl_group = "ExplorerBold",
    hl_mode = "combine",
    priority = 300,
  })

  local cfg = {
    relative = "win",
    win = s.win,
    row = vim.fn.winline() - 1,
    col = 0,
    width = math.max(1, w),
    height = 1,
    style = "minimal",
    border = "none",
    focusable = false,
    noautocmd = true,
    zindex = 60,
  }
  if peek_win and api.nvim_win_is_valid(peek_win) then
    api.nvim_win_set_config(peek_win, cfg)
  else
    peek_win = api.nvim_open_win(peek_buf, false, cfg)
    vim.w[peek_win].borderless = true
    require("plugins.local.ui.win").set_opts(peek_win, { winhighlight = "NormalFloat:ExplorerPeek" })
  end
end

local peek_group = api.nvim_create_augroup("ExplorerPeek", { clear = true })
api.nvim_create_autocmd({ "CursorMoved", "WinScrolled" }, {
  group = peek_group,
  desc = "Tooltip con el nombre completo de la línea del explorador",
  callback = function(ev)
    if vim.bo[ev.buf].filetype == "explorer" then
      local pos = api.nvim_win_get_cursor(0)
      if pos[2] ~= 0 then
        pcall(api.nvim_win_set_cursor, 0, { pos[1], 0 }) -- fijar a la 1.ª columna (cursor oculto limpio)
      end
      bold_current()
      peek_update()
    end
  end,
})
api.nvim_create_autocmd({ "WinLeave", "BufLeave", "CursorMovedI" }, {
  group = peek_group,
  desc = "Cerrar el tooltip del explorador al salir",
  callback = peek_close,
})

-- ── Vista del sidebar ──────────────────────────────────────────────
-- Crea el buffer del árbol + su estado por tab (una vez). Devuelve el buffer.
local function ex_create()
  local tab = api.nvim_get_current_tabpage()
  local s = states[tab]
  if s and s.buf and api.nvim_buf_is_valid(s.buf) then
    return s.buf
  end
  s = { root = vim.fn.getcwd(), expanded = {}, nodes = {} }
  states[tab] = s
  s.buf = api.nvim_create_buf(false, true)
  vim.bo[s.buf].buftype = "nofile"
  vim.bo[s.buf].bufhidden = "hide"
  vim.bo[s.buf].swapfile = false
  vim.bo[s.buf].filetype = "explorer"

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = s.buf, silent = true, nowait = true, desc = desc })
  end
  map("<CR>", actions.on_enter, "Abrir archivo / expandir carpeta")
  map("l", actions.on_enter, "Abrir archivo / expandir carpeta")
  map("h", actions.on_collapse, "Colapsar carpeta")
  map("-", actions.go_up, "Subir la raíz un nivel")
  map("=", actions.set_cwd, "Fijar la carpeta como cwd (tcd)")
  map("f", actions.reveal_current, "Centrar en el archivo actual")
  map("R", function()
    render.render(cur())
  end, "Refrescar el árbol")
  map("q", sidebar.close, "Cerrar el panel")
  map("<Tab>", sidebar.next, "Vista siguiente")
  map("<S-Tab>", sidebar.prev, "Vista anterior")
  map("<leader>x", "<Nop>") -- desactivar cerrar-buffer global dentro del explorador
  map("a", actions.create, "Crear archivo/carpeta")
  map("d", actions.delete, "Borrar")
  map("r", actions.rename, "Renombrar")
  map("x", actions.cut, "Cortar")
  map("y", actions.copy, "Copiar archivo/carpeta")
  map("p", actions.paste, "Pegar")
  map("c", function()
    actions.copy_path(false)
  end, "Copiar ruta relativa")
  map("C", function()
    actions.copy_path(true)
  end, "Copiar ruta absoluta")
  map("?", explorer_help, "Atajos del explorador (which-key)")
  return s.buf
end

-- Se muestra en `win`: guarda la ventana, renderiza, arranca watch/git (una vez), aplica estilo.
local function ex_attach(win)
  local s = cur()
  if not s then
    return
  end
  s.win = win
  render.render(s)
  if not s.started then
    watch.start_watch(s)
    git.update_git(s)
    s.started = true
  end
  apply_focus(true)
end

-- Al cerrar el sidebar: parar watchers/timers y soltar el estado del tab.
local function ex_destroy()
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
  states[api.nvim_get_current_tabpage()] = nil
end

sidebar.register({
  id = "explorer",
  order = 1,
  icon = "\u{f07b}",
  filetype = "explorer",
  create = ex_create,
  attach = function(win)
    ex_attach(win)
  end,
  on_focus = function(_, focused)
    apply_focus(focused)
  end,
  destroy = function()
    ex_destroy()
  end,
})

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

require("plugins.local.explorer.autocmds") -- registra los autocomandos del explorador

return M
