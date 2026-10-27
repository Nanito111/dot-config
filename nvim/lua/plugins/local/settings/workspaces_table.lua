-- Tabla de nombres de workspace por ruta (se abre desde el panel → Workspaces). Columnas:
-- ruta (elegida con el dirpicker en modo carpetas) · nombre predefinido. Alta/edición/baja por
-- fila; se persiste en settings.json vía config.workspaces. El cursor se imanta a las filas.
local api = vim.api
local ws = require("config.workspaces")
local palette = require("config.palette")
local theme = require("config.theme")
local ui = require("plugins.local.ui")

local M = {}
local ns = api.nvim_create_namespace("workspaces_table")
local state = nil -- { buf, win, rows = { rowdata|false }, menu }

local function set_hl()
  api.nvim_set_hl(0, "WsTblHead", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "WsTblPath", { fg = palette.comment })
  api.nvim_set_hl(0, "WsTblName", { fg = palette.fg, bold = true })
  api.nvim_set_hl(0, "WsTblEmpty", { fg = palette.comment, italic = true })
  api.nvim_set_hl(0, "WsTblMarker", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "WsTblCursorLine", { bg = palette.bg_highlight, bold = true })
end
theme.register(set_hl)

local HEAD = { path = "Path", name = "Name" }
local GAP = 4
local PATH_MAX = 60 -- ancho máx. de la columna ruta (trunca por el inicio conservando la cola)

-- Ruta para mostrar: relativa al home (~) y truncada por delante si es muy larga.
local function disp_path(path)
  local p = vim.fn.fnamemodify(path, ":~")
  if vim.fn.strdisplaywidth(p) > PATH_MAX then
    p = "…" .. p:sub(-(PATH_MAX - 1))
  end
  return p
end

-- ── Render ─────────────────────────────────────────────────────────
local function render()
  local s = state
  if not (s and api.nvim_buf_is_valid(s.buf)) then
    return
  end
  set_hl()
  local rows = ws.rows()

  local w_path = vim.fn.strdisplaywidth(HEAD.path)
  for _, r in ipairs(rows) do
    w_path = math.max(w_path, vim.fn.strdisplaywidth(disp_path(r.path)))
  end

  local lines, meta, marks = {}, {}, {}
  local function pad(text, w)
    return text .. string.rep(" ", w - vim.fn.strdisplaywidth(text) + GAP)
  end

  lines[1] = "  " .. pad(HEAD.path, w_path) .. HEAD.name
  meta[1] = false
  marks[#marks + 1] = { 0, 0, { end_col = #lines[1], hl_group = "WsTblHead" } }

  if #rows == 0 then
    lines[2] = "  (no names set — press a to add)"
    meta[2] = false
    marks[#marks + 1] = { 1, 0, { end_col = #lines[2], hl_group = "WsTblEmpty" } }
  else
    for _, r in ipairs(rows) do
      local dp = disp_path(r.path)
      local line = "  " .. pad(dp, w_path) .. r.name
      lines[#lines + 1] = line
      meta[#lines] = r
      local row = #lines - 1
      marks[#marks + 1] = { row, 2, { end_col = 2 + #dp, hl_group = "WsTblPath" } }
      local name_col = 2 + w_path + GAP
      marks[#marks + 1] = { row, name_col, { end_col = #line, hl_group = "WsTblName" } }
    end
  end

  vim.bo[s.buf].modifiable = true
  api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
  vim.bo[s.buf].modifiable = false
  api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  ui.hl.line_marks(s.buf, ns, marks)
  s.rows = meta
  if s.menu then
    s.menu.set_rows(meta)
  end
end

local function on_cursor()
  if state and state.menu then
    state.menu.on_cursor()
  end
end

local function current_row()
  return state and state.menu and state.menu.current()
end

-- Coloca el cursor en la fila de una ruta (tras re-render por alta/edición)
local function focus_path(abs)
  for lnum, r in ipairs(state.rows or {}) do
    if r and r.path == abs then
      api.nvim_win_set_cursor(state.win, { lnum, 0 })
      break
    end
  end
  on_cursor()
end

-- ── Edición ────────────────────────────────────────────────────────
-- Input del nombre con ghost text (basename/nombre actual); vacío borra la entrada.
local function ask_name(abs, placeholder, after)
  vim.ui.input({ prompt = "Workspace name: ", placeholder = placeholder, relative = "editor" }, function(name)
    if name == nil then
      return -- Esc: no tocar
    end
    ws.set(abs, name)
    render()
    focus_path(abs)
    if after then
      after()
    end
  end)
end

local function add()
  require("plugins.local.dirpicker").pick({ prompt = "Workspace folder: " }, function(dir)
    if not (dir and dir ~= "") then
      return
    end
    local abs = ws.norm(dir)
    ask_name(abs, vim.fn.fnamemodify(abs, ":t"))
  end)
end

local function rename()
  local r = current_row()
  if r then
    ask_name(r.path, r.name)
  end
end

local function remove()
  local r = current_row()
  if not r then
    return
  end
  ws.remove(r.path)
  render()
  on_cursor()
end

-- ── Ciclo de vida ──────────────────────────────────────────────────
function M.close()
  local s = state
  if not s then
    return
  end
  state = nil
  if s.close_float then
    s.close_float() -- cierra ventana + buffer + backdrop (idempotente)
  else
    ui.close(s.win, s.buf)
  end
end

function M.open()
  if state then
    M.close()
  end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "settings"

  local width = math.floor(vim.o.columns * 0.5)
  local height = math.floor(vim.o.lines * 0.5)

  local fl = ui.float.open({
    buf = buf,
    enter = true,
    width = width,
    height = height,
    title = " Workspace names ",
    title_pos = "center",
    footer = " a add · r rename · x remove · q close ",
    footer_pos = "center",
    backdrop = true,
    exclusive = true,
    wo = { cursorline = true, winhighlight = "CursorLine:WsTblCursorLine", wrap = false },
  })
  local win = fl.win

  state = { buf = buf, win = win, rows = {}, close_float = fl.close }
  state.menu = ui.menu.new({ buf = buf, win = win, marker = { text = "▸", hl = "WsTblMarker" } })
  render()
  api.nvim_win_set_cursor(win, { 1, 0 })
  on_cursor()

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  map("a", add)
  map("r", rename)
  map("<CR>", rename)
  map("x", remove)
  map("q", M.close)
  map("<Esc>", M.close)

  api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = on_cursor })
end

return M
