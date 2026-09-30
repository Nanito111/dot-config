-- Buscar y reemplazar a nivel WORKSPACE (plugin-free): mezcla el widget del reemplazo
-- local (campos Buscar/Reemplazar, toggles regex/mayúsculas/palabra, contador en vivo)
-- con el preview de dos paneles del rename LSP (lista de archivos + resultado resaltado,
-- confirmación y undo).
--
-- Busca con ripgrep en el directorio de trabajo. El reemplazo es literal (los toggles y
-- la regex afectan a la BÚSQUEDA, no sustituyen grupos de captura: para \1 usá <leader>rr).
local api = vim.api
local lsprename = require("plugins.local.lsprename")
local M = {}

local WIDTH = 64
local state = nil -- widget activo: { find_buf/win, repl_buf/win, opts, timer, count_token }
local snapshot = nil -- { { buf, lines }, ... } del último reemplazo aplicado

-- ── ripgrep ────────────────────────────────────────────────────────
-- Argumentos comunes; `--count-matches` para el contador, `--json` para las posiciones.
local function rg_args(query, opts, mode)
  local a = { "rg", mode, "--color=never", "--no-messages" }
  a[#a + 1] = opts.case and "--case-sensitive" or "--ignore-case"
  if not opts.regex then
    a[#a + 1] = "--fixed-strings"
  end
  if opts.word then
    a[#a + 1] = "--word-regexp"
  end
  a[#a + 1] = "--"
  a[#a + 1] = query
  return a
end

-- Busca (síncrono, para el paso de confirmar) y devuelve { { uri, edits }, ... } con
-- ediciones LSP en offsets de bytes (por eso todo usa encoding "utf-8").
local function search(query, repl, opts)
  local ok, out = pcall(vim.fn.systemlist, rg_args(query, opts, "--json"))
  if not ok then
    return {}
  end
  local by_path, order = {}, {}
  for _, line in ipairs(out) do
    local jok, ev = pcall(vim.json.decode, line)
    if jok and ev.type == "match" and ev.data.path then
      local path = ev.data.path.text
      if path then
        if not by_path[path] then
          by_path[path] = {}
          order[#order + 1] = path
        end
        local lnum = ev.data.line_number - 1
        for _, sm in ipairs(ev.data.submatches or {}) do
          by_path[path][#by_path[path] + 1] = {
            range = {
              start = { line = lnum, character = sm.start },
              ["end"] = { line = lnum, character = sm["end"] },
            },
            newText = repl,
          }
        end
      end
    end
  end
  table.sort(order)
  local files = {}
  for _, path in ipairs(order) do
    files[#files + 1] = {
      uri = vim.uri_from_fname(vim.fn.fnamemodify(path, ":p")),
      edits = by_path[path],
    }
  end
  return files
end

-- ── Aplicar / deshacer (estilo rename LSP, con su propio undo) ──────
local function write_buf(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  if api.nvim_buf_get_name(buf) == "" or vim.bo[buf].buftype ~= "" then
    return
  end
  api.nvim_buf_call(buf, function()
    pcall(vim.cmd, "silent keepalt write")
  end)
end

local function take_snapshot(files)
  snapshot = {}
  for _, f in ipairs(files) do
    local b = vim.fn.bufadd(vim.uri_to_fname(f.uri))
    vim.fn.bufload(b)
    snapshot[#snapshot + 1] = { buf = b, lines = api.nvim_buf_get_lines(b, 0, -1, false) }
  end
end

-- Guarda cada archivo ANTES (persiste cambios pendientes) y DESPUÉS (deja el reemplazo).
function M.apply(files)
  take_snapshot(files)
  for _, s in ipairs(snapshot) do
    write_buf(s.buf)
  end
  local changes = {}
  for _, f in ipairs(files) do
    changes[f.uri] = f.edits
  end
  vim.lsp.util.apply_workspace_edit({ changes = changes }, "utf-8")
  for _, s in ipairs(snapshot) do
    write_buf(s.buf)
  end
end

function M.undo()
  if not snapshot then
    vim.notify("No hay ningún reemplazo que revertir", vim.log.levels.INFO, { title = "Reemplazar" })
    return
  end
  local n = 0
  for _, s in ipairs(snapshot) do
    if api.nvim_buf_is_valid(s.buf) then
      api.nvim_buf_set_lines(s.buf, 0, -1, false, s.lines)
      write_buf(s.buf)
      n = n + 1
    end
  end
  snapshot = nil
  vim.notify(string.format("Reemplazo revertido en %d archivo(s)", n), vim.log.levels.INFO, { title = "Reemplazar" })
end

-- ── Widget: pintado del contador y los toggles ─────────────────────
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

local function find_text()
  return api.nvim_buf_get_lines(state.find_buf, 0, 1, false)[1] or ""
end

local function repl_text()
  return api.nvim_buf_get_lines(state.repl_buf, 0, 1, false)[1] or ""
end

-- Recorta la ruta por la izquierda si no entra, dejando visible el sufijo con el conteo.
local function fit_line(path, count, w)
  local suffix = string.format("  (%d)", count)
  local avail = math.max(4, w - #suffix)
  if #path > avail then
    path = "…" .. path:sub(#path - avail + 2)
  end
  return path .. suffix
end

-- Vuelca en la lista (flotante inferior) los archivos con coincidencias y ajusta el alto.
local function fill_list(entries)
  local s = state
  if not s or not api.nvim_win_is_valid(s.list_win) then
    return
  end
  local lines = {}
  if #entries == 0 then
    lines = { "  (sin coincidencias)" }
  else
    for _, e in ipairs(entries) do
      lines[#lines + 1] = "  " .. fit_line(e.path, e.count, s.width - 4)
    end
  end
  vim.bo[s.list_buf].modifiable = true
  api.nvim_buf_set_lines(s.list_buf, 0, -1, false, lines)
  vim.bo[s.list_buf].modifiable = false
  pcall(api.nvim_win_set_config, s.list_win, { height = math.max(1, math.min(#lines, 10)) })
end

-- Contador en vivo (async, con token para descartar resultados viejos) + lista de archivos
local function update_count()
  local s = state
  if not s then
    return
  end
  local q = find_text()
  if q == "" then
    set_footer(s.find_win, "⏎/C-a reemplazar · sin término")
    fill_list({})
    return
  end
  s.count_token = (s.count_token or 0) + 1
  local token = s.count_token
  pcall(vim.system, rg_args(q, s.opts, "--count-matches"), { text = true }, function(res)
    vim.schedule(function()
      if not state or state.count_token ~= token then
        return
      end
      local entries, files, matches = {}, 0, 0
      for _, line in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
        local path, c = line:match("^(.*):(%d+)$")
        if path and c then
          entries[#entries + 1] = { path = path, count = tonumber(c) }
          files = files + 1
          matches = matches + tonumber(c)
        end
      end
      table.sort(entries, function(a, b)
        return a.path < b.path
      end)
      local count = matches == 0 and "sin coincidencias"
        or string.format("%d en %d archivo(s)", matches, files)
      set_footer(s.find_win, "⏎/C-a reemplazar · " .. count)
      fill_list(entries)
    end)
  end)
end

local function schedule_count()
  local s = state
  if not s then
    return
  end
  if not s.timer then
    s.timer = vim.uv.new_timer()
  end
  s.timer:stop()
  s.timer:start(150, 0, vim.schedule_wrap(update_count))
end

local function toggle(opt)
  state.opts[opt] = not state.opts[opt]
  draw_toggles()
  update_count()
end

-- ── Ciclo de vida del widget ───────────────────────────────────────
local function close()
  if not state then
    return
  end
  local s = state
  state = nil
  if s.timer then
    s.timer:stop()
    s.timer:close()
  end
  for _, w in ipairs({ s.find_win, s.repl_win, s.list_win }) do
    pcall(api.nvim_win_close, w, true)
  end
  for _, b in ipairs({ s.find_buf, s.repl_buf, s.list_buf }) do
    pcall(api.nvim_buf_delete, b, { force = true })
  end
  if api.nvim_win_is_valid(s.origin) then
    api.nvim_set_current_win(s.origin)
  end
  vim.cmd("stopinsert")
end
M.close = close

-- Confirmar: busca de una y salta al preview de dos paneles (rename LSP) -> apply -> undo
local function confirm()
  local s = state
  local q = find_text()
  if q == "" then
    return
  end
  local r = repl_text()
  local opts = s.opts
  local files = search(q, r, opts)
  if #files == 0 then
    vim.notify(string.format("Sin coincidencias de '%s'", q), vim.log.levels.INFO, { title = "Reemplazar" })
    return
  end
  local total = 0
  for _, f in ipairs(files) do
    total = total + #f.edits
  end
  close()
  local title = string.format("Reemplazar '%s' → '%s' — %d en %d archivo(s)", q, r, total, #files)
  lsprename.confirm(files, title, "utf-8", function(ok)
    if not ok then
      return
    end
    local sure = require("plugins.local.confirm").confirm(
      string.format("¿Reemplazar %d coincidencia(s) en %d archivo(s)?\nSe puede deshacer con <leader>ru", total, #files),
      "&Sí\n&No",
      1,
      { backdrop = true }
    )
    if sure ~= 1 then
      return
    end
    M.apply(files)
    vim.notify(
      string.format(
        "Reemplazadas %d coincidencia(s) en %d archivo(s).  :ReplaceUndo (o <leader>ru) para revertir",
        total,
        #files
      ),
      vim.log.levels.INFO,
      { title = "Reemplazar" }
    )
  end)
end

local function field(title, row, width, col)
  local pr = require("plugins.local.ui").input.open({
    prompt = title,
    relative = "editor",
    width = width,
    row = row,
    col = col,
    title_pos = "left",
    enter = false,
  })
  return pr.buf, pr.win
end

-- Abre el widget. `query` precarga el campo de búsqueda (palabra bajo el cursor o selección).
function M.open(query)
  if state then
    close()
  end
  if vim.fn.executable("rg") ~= 1 then
    vim.notify("ripgrep (rg) no está disponible", vim.log.levels.WARN, { title = "Reemplazar" })
    return
  end

  local width = math.min(WIDTH, math.max(30, vim.o.columns - 6))
  local col = math.max(0, vim.o.columns - width - 4)
  local find_buf, find_win = field("Buscar (workspace)", 1, width, col)
  local repl_buf, repl_win = field("Reemplazar", 4, width, col)

  -- Lista en vivo de archivos con coincidencias (para no esperar al paso de revisión)
  local list_buf = api.nvim_create_buf(false, true)
  local list_win = require("plugins.local.ui").float.open({
    buf = list_buf,
    enter = false,
    focusable = false,
    relative = "editor",
    row = 7,
    col = col,
    width = width,
    height = 1,
    title = " Coincidencias ",
    title_pos = "left",
    wo = { cursorline = false, number = false, wrap = false },
  }).win

  state = {
    origin = api.nvim_get_current_win(),
    find_buf = find_buf,
    find_win = find_win,
    repl_buf = repl_buf,
    repl_win = repl_win,
    list_buf = list_buf,
    list_win = list_win,
    width = width,
    opts = { regex = false, case = false, word = false },
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
  map("<CR>", confirm)
  map("<C-a>", confirm)
  map("<M-CR>", confirm)
  map("<M-e>", function()
    toggle("regex")
  end)
  map("<M-c>", function()
    toggle("case")
  end)
  map("<M-w>", function()
    toggle("word")
  end)

  api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = find_buf,
    callback = schedule_count,
  })
  api.nvim_create_autocmd("WinEnter", {
    callback = function()
      if not state then
        return true
      end
      local w = api.nvim_get_current_win()
      if w ~= state.find_win and w ~= state.repl_win and w ~= state.list_win then
        close()
        return true
      end
    end,
  })

  draw_toggles()
  api.nvim_set_current_win(find_win)
  vim.cmd("startinsert!")
  update_count()
end

api.nvim_create_user_command("ReplaceUndo", M.undo, { desc = "Revertir el último reemplazo en el workspace" })

return M
