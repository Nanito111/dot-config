-- Buscar y reemplazar en el BUFFER ACTUAL (estilo VSCode, plugin-free): un flotante con
-- los campos Buscar/Reemplazar, todas las coincidencias resaltadas en vivo, contador,
-- salto entre ellas y reemplazo de una o de todas (un solo undo).
--
-- El patrón es LITERAL por defecto (lo que escribes es lo que busca); los toggles activan
-- regex de Vim, distinguir mayúsculas y palabra completa.
local api = vim.api
local M = {}

local ns = api.nvim_create_namespace("replace")
local WIDTH = 64

-- state = { buf, origin, cursor, find_buf/win, repl_buf/win, matches, idx, opts, changed }
local state = nil

-- ── Búsqueda ───────────────────────────────────────────────────────
-- Patrón de Vim a partir de la consulta y los toggles. En modo literal se usa \V (muy
-- no-mágico): ahí solo la barra invertida es especial, así que basta con duplicarla.
local function pattern()
  local s = state
  local q = api.nvim_buf_get_lines(s.find_buf, 0, 1, false)[1] or ""
  if q == "" then
    return nil
  end
  local p = s.opts.regex and q or ("\\V" .. q:gsub("\\", "\\\\"))
  if s.opts.word then
    p = "\\<" .. p .. "\\>"
  end
  return (s.opts.case and "\\C" or "\\c") .. p
end

local function replacement()
  return api.nvim_buf_get_lines(state.repl_buf, 0, 1, false)[1] or ""
end

-- Coincidencias del buffer: { lnum (1-based), col (byte, 0-based), text }
local function search()
  local s = state
  s.pattern = pattern()
  s.matches = {}
  if not s.pattern then
    return
  end
  local ok, res = pcall(vim.fn.matchbufline, s.buf, s.pattern, 1, "$")
  if not ok then
    return -- regex inválida a medio escribir: no es un error, simplemente no hay match
  end
  for _, m in ipairs(res) do
    if m.text ~= "" then -- una coincidencia vacía no se puede resaltar ni reemplazar
      s.matches[#s.matches + 1] = { lnum = m.lnum, col = m.byteidx, text = m.text }
    end
  end
end

-- ── Pintado ────────────────────────────────────────────────────────
local function set_footer(win, text)
  if api.nvim_win_is_valid(win) then
    pcall(api.nvim_win_set_config, win, { footer = " " .. text .. " ", footer_pos = "right" })
  end
end

local function draw_toggles()
  local o = state.opts
  local function mark(on, label)
    return (on and "[x] " or "[ ] ") .. label
  end
  set_footer(
    state.repl_win,
    table.concat({
      mark(o.regex, "M-e regex"),
      mark(o.case, "M-c Aa"),
      mark(o.word, "M-w palabra"),
    }, "  ")
  )
end

-- Resalta todas las coincidencias (la actual con otro color) y lleva el cursor a ella
local function draw()
  local s = state
  api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  for i, m in ipairs(s.matches) do
    pcall(api.nvim_buf_set_extmark, s.buf, ns, m.lnum - 1, m.col, {
      end_col = m.col + #m.text,
      hl_group = (i == s.idx) and "CurSearch" or "Search",
    })
  end

  local n = #s.matches
  set_footer(s.find_win, n == 0 and "sin coincidencias" or string.format("%d/%d", s.idx, n))

  local cur = s.matches[s.idx]
  if cur and api.nvim_win_is_valid(s.origin) then
    pcall(api.nvim_win_set_cursor, s.origin, { cur.lnum, cur.col })
    pcall(api.nvim_win_call, s.origin, function()
      vim.cmd("normal! zz")
    end)
  end
end

-- Recalcula tras teclear: la coincidencia activa es la primera desde el cursor
local function update()
  local s = state
  search()
  local from = s.cursor
  s.idx = 1
  for i, m in ipairs(s.matches) do
    if m.lnum > from[1] or (m.lnum == from[1] and m.col >= from[2]) then
      s.idx = i
      break
    end
  end
  draw()
end

local function move(delta)
  local s = state
  local n = #s.matches
  if n == 0 then
    return
  end
  s.idx = ((s.idx - 1 + delta) % n) + 1
  draw()
end

-- ── Reemplazo ──────────────────────────────────────────────────────
-- Texto que sustituye a una coincidencia. En regex se pasa por substitute() para que
-- funcionen los grupos (\1, &); en literal se inserta tal cual.
local function new_text(matched)
  local r = replacement()
  if not state.opts.regex then
    return r
  end
  local ok, res = pcall(vim.fn.substitute, matched, state.pattern, r, "")
  return ok and res or r
end

local function apply(m)
  local text = new_text(m.text)
  api.nvim_buf_set_text(state.buf, m.lnum - 1, m.col, m.lnum - 1, m.col + #m.text, { text })
end

local function replace_one()
  local s = state
  local m = s.matches[s.idx]
  if not m then
    return
  end
  apply(m)
  s.changed = true
  s.cursor = { m.lnum, m.col }
  local idx = s.idx
  search()
  s.idx = math.min(idx, math.max(#s.matches, 1)) -- la siguiente ocupa el hueco
  draw()
end

local function replace_all()
  local s = state
  local n = #s.matches
  if n == 0 then
    return
  end
  -- de abajo arriba: así las posiciones de las que faltan siguen siendo válidas.
  -- undojoin une todas las ediciones en un solo undo.
  api.nvim_buf_call(s.buf, function()
    for i = n, 1, -1 do
      if i < n then
        pcall(vim.cmd, "silent! undojoin")
      end
      apply(s.matches[i])
    end
  end)
  s.changed = true
  vim.notify(
    string.format("%d %s reemplazada%s", n, n == 1 and "coincidencia" or "coincidencias", n == 1 and "" or "s"),
    vim.log.levels.INFO,
    { title = "Reemplazar" }
  )
  update()
end

local function toggle(opt)
  state.opts[opt] = not state.opts[opt]
  draw_toggles()
  update()
end

-- ── Ciclo de vida ──────────────────────────────────────────────────
local function close()
  if not state then
    return
  end
  local s = state
  state = nil
  api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  for _, w in ipairs({ s.find_win, s.repl_win }) do
    pcall(api.nvim_win_close, w, true)
  end
  for _, b in ipairs({ s.find_buf, s.repl_buf }) do
    pcall(api.nvim_buf_delete, b, { force = true })
  end
  if api.nvim_win_is_valid(s.origin) then
    api.nvim_set_current_win(s.origin)
    if not s.changed then
      pcall(api.nvim_win_set_cursor, s.origin, s.orig_cursor) -- sin cambios: no mover nada
    end
  end
  vim.cmd("stopinsert")
end
M.close = close

local function field(title, row, width, col)
  local buf = api.nvim_create_buf(false, true)
  vim.b[buf].completion = false -- sin autocompletado (blink) en los campos
  local win = api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    title = " " .. title .. " ",
    title_pos = "left",
  })
  return buf, win
end

-- Abre el widget. `query` precarga el campo de búsqueda (palabra bajo el cursor o selección).
function M.open(query)
  if state then
    close()
  end
  local buf = api.nvim_get_current_buf()
  if not vim.bo[buf].modifiable or vim.bo[buf].readonly then
    vim.notify("El buffer no es editable", vim.log.levels.WARN, { title = "Reemplazar" })
    return
  end

  local width = math.min(WIDTH, math.max(30, vim.o.columns - 6))
  local col = math.max(0, vim.o.columns - width - 4)
  local find_buf, find_win = field("Buscar", 1, width, col)
  local repl_buf, repl_win = field("Reemplazar", 4, width, col)

  local origin = api.nvim_get_current_win()
  state = {
    buf = buf,
    origin = origin,
    orig_cursor = api.nvim_win_get_cursor(origin),
    cursor = api.nvim_win_get_cursor(origin),
    find_buf = find_buf,
    find_win = find_win,
    repl_buf = repl_buf,
    repl_win = repl_win,
    matches = {},
    idx = 1,
    opts = { regex = false, case = false, word = false },
    changed = false,
  }

  if query and query ~= "" then
    api.nvim_buf_set_lines(find_buf, 0, -1, false, { query })
  end

  local function map(lhs, fn)
    for _, b in ipairs({ find_buf, repl_buf }) do
      vim.keymap.set({ "i", "n" }, lhs, fn, { buffer = b, nowait = true, silent = true })
    end
  end
  map("<Esc>", close)
  map("<C-c>", close)
  map("<Tab>", function()
    local other = api.nvim_get_current_win() == find_win and repl_win or find_win
    api.nvim_set_current_win(other)
  end)
  map("<CR>", function() move(1) end)
  map("<C-n>", function() move(1) end)
  map("<Down>", function() move(1) end)
  map("<C-p>", function() move(-1) end)
  map("<Up>", function() move(-1) end)
  map("<M-CR>", replace_one)
  map("<M-a>", replace_all)
  map("<M-e>", function() toggle("regex") end)
  map("<M-c>", function() toggle("case") end)
  map("<M-w>", function() toggle("word") end)

  api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = find_buf,
    callback = update,
  })
  -- cerrar al irse a cualquier ventana que no sea la del widget
  api.nvim_create_autocmd("WinEnter", {
    callback = function()
      if not state then
        return true -- ya cerrado: quitar el autocomando
      end
      local w = api.nvim_get_current_win()
      if w ~= state.find_win and w ~= state.repl_win then
        close()
        return true
      end
    end,
  })

  draw_toggles()
  api.nvim_set_current_win(find_win)
  vim.cmd("startinsert!")
  update()
end

return M
