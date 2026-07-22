-- Tabla de indentación por tipo de archivo (se abre desde el panel de configuración).
-- Filas = filetypes (+ la fila "(global)"), columnas = tipo de archivo · indentación
-- (espacios/tabs) · cantidad. Edición POR FILA; los cambios aplican en vivo y persisten
-- vía config.indent. El cursor se imanta a las filas de datos (no descansa en la cabecera).
local api = vim.api
local indent = require("config.indent")
local palette = require("config.palette")
local theme = require("config.theme")
local ui = require("plugins.local.ui")

local M = {}
local ns = api.nvim_create_namespace("indent_table")

local state = nil -- { buf, win, rows = { rowdata|false }, focus = ft, last }

local function set_hl()
  api.nvim_set_hl(0, "IndentTblHead", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "IndentTblFt", { fg = palette.fg })
  api.nvim_set_hl(0, "IndentTblDefault", { fg = palette.comment })
  api.nvim_set_hl(0, "IndentTblChanged", { fg = palette.green, bold = true })
  api.nvim_set_hl(0, "IndentTblMarker", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "IndentTblCursorLine", { bg = palette.bg_highlight, bold = true })
end
theme.register(set_hl)

local HEAD = { ft = "Tipo de archivo", type = "Indentación", amount = "Cantidad" }
local GAP = 22 -- separación entre columnas (más aire = ventana más ancha)

local function type_text(expand)
  return expand and "espacios" or "tabs"
end

-- ── Render ─────────────────────────────────────────────────────────
local function render()
  local s = state
  if not (s and api.nvim_buf_is_valid(s.buf)) then
    return
  end
  set_hl()
  local rows = indent.rows()

  -- anchos de columna (los datos son ASCII: byte = ancho de pantalla)
  local w_ft, w_type = vim.fn.strdisplaywidth(HEAD.ft), vim.fn.strdisplaywidth(HEAD.type)
  for _, r in ipairs(rows) do
    w_ft = math.max(w_ft, #r.ft)
    w_type = math.max(w_type, #type_text(r.expand))
  end

  local function row_line(ft, typ, amount)
    return "  " .. ft .. string.rep(" ", w_ft - vim.fn.strdisplaywidth(ft) + GAP)
      .. typ .. string.rep(" ", w_type - vim.fn.strdisplaywidth(typ) + GAP)
      .. amount
  end

  local lines, meta, marks = {}, {}, {}
  -- cabecera
  lines[1] = row_line(HEAD.ft, HEAD.type, HEAD.amount)
  meta[1] = false
  marks[#marks + 1] = { 0, 0, { end_col = #lines[1], hl_group = "IndentTblHead" } }

  for _, r in ipairs(rows) do
    local typ = type_text(r.expand)
    local line = row_line(r.ft, typ, tostring(r.width))
    if r.overridden then
      line = line .. "  ●"
    end
    lines[#lines + 1] = line
    meta[#lines] = r

    local row = #lines - 1
    local ft_col = 2 -- tras el sangrado de 2 (para el marcador ▸)
    local type_col = ft_col + w_ft + GAP
    local amt_col = type_col + w_type + GAP
    marks[#marks + 1] = { row, ft_col, { end_col = ft_col + #r.ft, hl_group = "IndentTblFt" } }
    local val_hl = r.overridden and "IndentTblChanged" or "IndentTblDefault"
    marks[#marks + 1] = { row, type_col, { end_col = amt_col + #tostring(r.width), hl_group = val_hl } }
    if r.overridden then
      marks[#marks + 1] = { row, amt_col + #tostring(r.width) + 2, { end_col = #line, hl_group = "IndentTblMarker" } }
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

-- ── Cursor imantado (delegado en ui.menu) ──────────────────────────
local function on_cursor()
  if state and state.menu then
    state.menu.on_cursor()
  end
end

local function current_row()
  return state and state.menu and state.menu.current()
end

-- Coloca el cursor en la fila de un filetype (tras re-render por añadir/quitar)
local function focus_ft(ft)
  for lnum, r in ipairs(state.rows) do
    if r and r.ft == ft then
      api.nvim_win_set_cursor(state.win, { lnum, 0 })
      on_cursor()
      return
    end
  end
  on_cursor()
end

-- ── Edición ────────────────────────────────────────────────────────
local function commit(row, val)
  if row.is_global then
    indent.set_global(val)
  else
    indent.set(row.ft, val)
  end
  render()
  focus_ft(row.ft)
end

local function toggle_type()
  local r = current_row()
  if r then
    commit(r, { width = r.width, expand = not r.expand })
  end
end

local function change_amount(dir)
  local r = current_row()
  if r then
    commit(r, { width = math.max(1, math.min(8, r.width + dir)), expand = r.expand })
  end
end

local function add_ft()
  vim.ui.input({ prompt = "Filetype: " }, function(name)
    name = name and vim.trim(name)
    if not name or name == "" then
      return
    end
    local g = nil
    for _, r in ipairs(indent.rows()) do
      if r.is_global then
        g = r
      end
    end
    indent.set(name, { width = g.width, expand = g.expand })
    render()
    focus_ft(name)
  end)
end

local function remove_ft()
  local r = current_row()
  if not r then
    return
  end
  if r.is_global then
    indent.set_global(indent.GLOBAL_DEFAULT) -- el global no se borra: se resetea
  else
    indent.remove(r.ft)
  end
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
  ui.close(s.win, s.buf)
end

function M.open()
  if state then
    M.close()
  end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "settings" -- hereda el cursor oculto del sidebar (mismo look)

  local rows = indent.rows()
  local height = math.min(#rows + 1, vim.o.lines - 6)
  -- ancho: sangrado + col ft + col tipo + cantidad + margen del ●
  local w_ft = vim.fn.strdisplaywidth(HEAD.ft)
  local w_type = vim.fn.strdisplaywidth(HEAD.type)
  for _, r in ipairs(rows) do
    w_ft = math.max(w_ft, #r.ft)
    w_type = math.max(w_type, #type_text(r.expand))
  end
  local width = 2 + w_ft + GAP + w_type + GAP + vim.fn.strdisplaywidth(HEAD.amount) + 4

  local win = ui.float.open({
    buf = buf,
    enter = true,
    width = width,
    height = height,
    title = " Indentación por tipo de archivo ",
    title_pos = "center",
    footer = " j/k · ␣ tipo · h/l cantidad · a añadir · x quitar · q cerrar ",
    footer_pos = "center",
    wo = { cursorline = true, winhighlight = "CursorLine:IndentTblCursorLine", wrap = false },
  }).win

  state = { buf = buf, win = win, rows = {} }
  state.menu = ui.menu.new({ buf = buf, win = win, marker = { text = "▸", hl = "IndentTblMarker" } })
  render()
  api.nvim_win_set_cursor(win, { 1, 0 })
  on_cursor()

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  map("<Space>", toggle_type)
  map("t", toggle_type)
  map("l", function() change_amount(1) end)
  map("<Right>", function() change_amount(1) end)
  map("+", function() change_amount(1) end)
  map("h", function() change_amount(-1) end)
  map("<Left>", function() change_amount(-1) end)
  map("-", function() change_amount(-1) end)
  map("a", add_ft)
  map("x", remove_ft)
  map("q", M.close)
  map("<Esc>", M.close)

  api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = on_cursor })
end

return M
