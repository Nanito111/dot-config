-- Tabla de servidores LSP por tipo de archivo (se abre desde el panel de configuración).
-- Nivel 1: una fila por lenguaje (filetype) con los servidores candidatos coloreados según
-- corran o no. Enter abre el nivel 2: un selector con un switch por servidor para activarlo o
-- desactivarlo en ese lenguaje. Los cambios aplican en vivo y persisten vía config.lsp.
local api = vim.api
local lsp = require("config.lsp")
local palette = require("config.palette")
local theme = require("config.theme")
local ui = require("plugins.local.ui")

local M = {}
local ns = api.nvim_create_namespace("lsp_table")

local SWITCH_ON = "\u{f205}" --
local SWITCH_OFF = "\u{f204}" --

local state = nil -- nivel 1: { buf, win, rows, menu }
local sub = nil -- nivel 2: { buf, win, ft, rows, menu, close }

local function set_hl()
  api.nvim_set_hl(0, "LspTblHead", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "LspTblFt", { fg = palette.fg })
  api.nvim_set_hl(0, "LspTblOn", { fg = palette.green, bold = true })
  api.nvim_set_hl(0, "LspTblOff", { fg = palette.comment })
  api.nvim_set_hl(0, "LspTblMarker", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "LspTblCursorLine", { bg = palette.bg_highlight, bold = true })
end
theme.register(set_hl)

local HEAD = { ft = "Language", count = "Active", servers = "Servers" }
local GAP = 6

-- ── Nivel 1: tabla de lenguajes ────────────────────────────────────
local function render()
  local s = state
  if not (s and api.nvim_buf_is_valid(s.buf)) then
    return
  end
  set_hl()
  local rows = lsp.rows()

  local w_ft, w_count = vim.fn.strdisplaywidth(HEAD.ft), vim.fn.strdisplaywidth(HEAD.count)
  for _, r in ipairs(rows) do
    w_ft = math.max(w_ft, #r.ft)
    w_count = math.max(w_count, #(r.enabled .. "/" .. r.total))
  end

  local function prefix(ft, count)
    return "  "
      .. ft
      .. string.rep(" ", w_ft - vim.fn.strdisplaywidth(ft) + GAP)
      .. count
      .. string.rep(" ", w_count - vim.fn.strdisplaywidth(count) + GAP)
  end

  local lines, meta, marks = {}, {}, {}
  lines[1] = prefix(HEAD.ft, HEAD.count) .. HEAD.servers
  meta[1] = false
  marks[#marks + 1] = { 0, 0, { end_col = #lines[1], hl_group = "LspTblHead" } }

  for _, r in ipairs(rows) do
    local head = prefix(r.ft, r.enabled .. "/" .. r.total)
    local line = head
    local segs = {} -- { col, end_col, hl }
    for i, name in ipairs(r.servers) do
      if i > 1 then
        line = line .. ", "
      end
      local col = #line
      line = line .. name
      segs[#segs + 1] = { col, #line, lsp.is_enabled(name, r.ft) and "LspTblOn" or "LspTblOff" }
    end
    if r.overridden then
      line = line .. "  ●"
    end
    lines[#lines + 1] = line
    meta[#lines] = r

    local row = #lines - 1
    marks[#marks + 1] = { row, 2, { end_col = 2 + #r.ft, hl_group = "LspTblFt" } }
    for _, sg in ipairs(segs) do
      marks[#marks + 1] = { row, sg[1], { end_col = sg[2], hl_group = sg[3] } }
    end
    if r.overridden then
      marks[#marks + 1] = { row, #head, { end_col = #line, hl_group = "LspTblMarker" } }
    end
  end

  vim.bo[s.buf].modifiable = true
  api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
  vim.bo[s.buf].modifiable = false
  api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  ui.hl.line_marks(s.buf, ns, marks)
  s.rows = meta
  s.menu.set_rows(meta)
end

local function on_cursor()
  if state and state.menu then
    state.menu.on_cursor()
  end
end

local function current_row()
  return state and state.menu and state.menu.current()
end

local function focus_ft(ft)
  if not (state and state.win and api.nvim_win_is_valid(state.win)) then
    return
  end
  for lnum, r in ipairs(state.rows) do
    if r and r.ft == ft then
      api.nvim_win_set_cursor(state.win, { lnum, 0 })
      break
    end
  end
  on_cursor()
end

-- ── Nivel 2: selector de servidores de un lenguaje ─────────────────
local function sub_render()
  if not (sub and api.nvim_buf_is_valid(sub.buf)) then
    return
  end
  set_hl()
  sub.servers = lsp.servers_for_ft(sub.ft)
  local w = 0
  for _, e in ipairs(sub.servers) do
    w = math.max(w, #e.name)
  end

  local lines, meta, marks = {}, {}, {}
  for _, e in ipairs(sub.servers) do
    local sw = e.enabled and SWITCH_ON or SWITCH_OFF
    local line = "   " .. e.name .. string.rep(" ", w - #e.name + 4) .. sw
    lines[#lines + 1] = line
    meta[#lines] = e
    local row = #lines - 1
    marks[#marks + 1] = { row, 3, { end_col = 3 + #e.name, hl_group = "LspTblFt" } }
    local sw_col = #line - #sw
    marks[#marks + 1] = { row, sw_col, { end_col = #line, hl_group = e.enabled and "LspTblOn" or "LspTblOff" } }
  end

  vim.bo[sub.buf].modifiable = true
  api.nvim_buf_set_lines(sub.buf, 0, -1, false, lines)
  vim.bo[sub.buf].modifiable = false
  api.nvim_buf_clear_namespace(sub.buf, ns, 0, -1)
  ui.hl.line_marks(sub.buf, ns, marks)
  sub.rows = meta
  sub.menu.set_rows(meta)
end

local function sub_toggle()
  if not (sub and sub.menu) then
    return
  end
  local e = sub.menu.current()
  if not e then
    return
  end
  lsp.set_enabled(e.name, sub.ft, not e.enabled)
  sub_render()
end

local function open_servers(ft)
  local servers = lsp.servers_for_ft(ft)
  if #servers == 0 then
    return
  end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "settings"

  local w = 0
  for _, e in ipairs(servers) do
    w = math.max(w, #e.name)
  end
  local width = math.max(3 + w + 4 + 2, vim.fn.strdisplaywidth(" " .. ft .. " ") + 4, 28)
  local height = #servers

  local f = ui.float.open({
    buf = buf,
    enter = true,
    width = width,
    height = height,
    title = " " .. ft .. " ",
    title_pos = "center",
    footer = " j/k · ␣ toggle · q back ",
    footer_pos = "center",
    backdrop = true,
    wo = { cursorline = true, winhighlight = "CursorLine:LspTblCursorLine", wrap = false },
    on_close = function()
      sub = nil
      if state and state.win and api.nvim_win_is_valid(state.win) then
        api.nvim_set_current_win(state.win)
      end
      render()
      focus_ft(ft)
    end,
  })

  sub = { buf = buf, win = f.win, ft = ft, rows = {}, close = f.close }
  sub.menu = ui.menu.new({ buf = buf, win = f.win, marker = { text = "▸", hl = "LspTblMarker" } })
  sub_render()
  api.nvim_win_set_cursor(f.win, { 1, 0 })
  sub.menu.on_cursor()

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  map("<Space>", sub_toggle)
  map("t", sub_toggle)
  map("<CR>", sub_toggle)
  map("l", sub_toggle)
  map("<Right>", sub_toggle)
  map("h", sub_toggle)
  map("<Left>", sub_toggle)
  map("q", f.close)
  map("<Esc>", f.close)
  api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = sub.menu.on_cursor })
end

local function activate()
  local r = current_row()
  if r then
    open_servers(r.ft)
  end
end

local function reset_row()
  local r = current_row()
  if r and r.overridden then
    lsp.reset_ft(r.ft)
    render()
    focus_ft(r.ft)
  end
end

-- ── Ciclo de vida ──────────────────────────────────────────────────
function M.close()
  if sub and sub.close then
    pcall(sub.close)
  end
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
  vim.bo[buf].filetype = "settings"

  local rows = lsp.rows()
  if #rows == 0 then
    vim.notify("No LSP servers installed (install one with :Mason)", vim.log.levels.INFO, { title = "LSP" })
    return
  end

  local w_ft, w_count, w_srv = vim.fn.strdisplaywidth(HEAD.ft), vim.fn.strdisplaywidth(HEAD.count), 0
  for _, r in ipairs(rows) do
    w_ft = math.max(w_ft, #r.ft)
    w_count = math.max(w_count, #(r.enabled .. "/" .. r.total))
    w_srv = math.max(w_srv, #table.concat(r.servers, ", ") + 3)
  end
  local width = math.min(2 + w_ft + GAP + w_count + GAP + math.max(w_srv, #HEAD.servers) + 4, vim.o.columns - 4)
  local height = math.min(#rows + 1, vim.o.lines - 6)

  local win = ui.float.open({
    buf = buf,
    enter = true,
    width = width,
    height = height,
    title = " LSP servers by language ",
    title_pos = "center",
    footer = " j/k · Enter choose servers · r re-enable all · q close ",
    footer_pos = "center",
    exclusive = true,
    wo = { cursorline = true, winhighlight = "CursorLine:LspTblCursorLine", wrap = false },
  }).win

  state = { buf = buf, win = win, rows = {} }
  state.menu = ui.menu.new({ buf = buf, win = win, marker = { text = "▸", hl = "LspTblMarker" } })
  render()
  api.nvim_win_set_cursor(win, { 1, 0 })
  on_cursor()

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  map("<CR>", activate)
  map("l", activate)
  map("<Right>", activate)
  map("r", reset_row)
  map("q", M.close)
  map("<Esc>", M.close)
  api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = on_cursor })
end

return M
