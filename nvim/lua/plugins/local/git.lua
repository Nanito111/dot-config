local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

local ns = api.nvim_create_namespace("git_signs")

-- index_cache[buf]     = versión en el índice  (git show :./archivo)
-- committed_cache[buf] = versión en HEAD        (git show HEAD:./archivo)
-- hunk_cache[buf]      = { { start=<línea>, kind=... }, ... } para navegación
local index_cache = {}
local committed_cache = {}
local hunk_cache = {}
local timers = {}

-- ── Colores ────────────────────────────────────────────────────────
local function set_hl()
  local hl = api.nvim_set_hl
  -- cambios sin stagear (en el árbol de trabajo): colores vivos
  hl(0, "GitSignAdd", { fg = palette.green })
  hl(0, "GitSignChange", { fg = palette.yellow })
  hl(0, "GitSignDelete", { fg = palette.red })
  hl(0, "GitSignChangedelete", { fg = palette.orange }) -- cambio que además quitó líneas
  -- cambios ya en el índice (staged): los mismos tonos pero apagados
  hl(0, "GitSignStagedAdd", { fg = palette.green_dim })
  hl(0, "GitSignStagedChange", { fg = palette.yellow_dim })
  hl(0, "GitSignStagedDelete", { fg = palette.red_dim })
  hl(0, "GitBlame", { fg = palette.comment, italic = true })
  hl(0, "GitBlameAuthor", { fg = palette.blue, bold = true })
end

local SIGNS = {
  add = { "▎", "GitSignAdd" },
  change = { "▎", "GitSignChange" },
  delete = { "▎", "GitSignDelete" },
  topdelete = { "▔", "GitSignDelete" }, -- borrado al inicio del archivo
  changedelete = { "▌", "GitSignChangedelete" }, -- cambio + líneas quitadas
  staged_add = { "▎", "GitSignStagedAdd" },
  staged_change = { "▎", "GitSignStagedChange" },
  staged_delete = { "▎", "GitSignStagedDelete" },
}

-- ¿es un buffer de archivo normal en disco?
local function is_file(buf)
  return api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buftype == ""
    and api.nvim_buf_get_name(buf) ~= ""
end

-- ── Signos de líneas cambiadas ─────────────────────────────────────
local function place(buf, lnum, kind, priority)
  local s = SIGNS[kind]
  pcall(api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
    sign_text = s[1],
    sign_hl_group = s[2],
    priority = priority or 8,
  })
end

-- Traduce una línea del ÍNDICE a la línea correspondiente del BUFFER, usando los
-- hunks sin stagear (índice -> buffer). Devuelve nil si esa línea del índice cae
-- dentro de un cambio sin stagear (esa señal manda y la staged se omite).
local function index_to_buf(li, unstaged)
  local delta = 0
  for _, h in ipairs(unstaged) do
    local sa, ca, cb = h[1], h[2], h[4] -- índice: inicio/contador ; buffer: contador
    if ca == 0 then -- inserción en el buffer tras la línea sa del índice
      if li > sa then
        delta = delta + cb
      end
    else
      local ea = sa + ca - 1
      if ea < li then
        delta = delta + (cb - ca)
      elseif sa <= li and li <= ea then
        return nil -- línea modificada/borrada sin stagear -> omitir staged
      end
    end
  end
  return li + delta
end

-- Recalcula los diffs y coloca los signos:
--   sin stagear = buffer vs índice  (colores vivos, prioridad alta)
--   staged      = índice vs HEAD    (colores apagados, prioridad baja)
local function refresh(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  hunk_cache[buf] = {}

  local index = index_cache[buf]
  if not index then
    return -- archivo no rastreado o fuera de un repo
  end
  local cur = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  if vim.bo[buf].eol then
    cur = cur .. "\n" -- el archivo termina en newline (como lo guarda git)
  end
  local unstaged = vim.diff(index, cur, { result_type = "indices", algorithm = "histogram" }) or {}

  -- ── cambios sin stagear (buffer vs índice) ──
  for _, h in ipairs(unstaged) do
    local _, ca, sb, cb = h[1], h[2], h[3], h[4]
    local kind, first
    if ca == 0 then -- añadidas
      kind, first = "add", sb
      for i = 0, cb - 1 do
        place(buf, sb + i, "add")
      end
    elseif cb == 0 then -- borradas
      first = math.max(sb, 1)
      kind = (sb == 0) and "topdelete" or "delete"
      place(buf, first, kind)
    else -- modificadas (changedelete si además se quitaron líneas)
      kind, first = (ca > cb) and "changedelete" or "change", sb
      for i = 0, cb - 1 do
        place(buf, sb + i, kind)
      end
    end
    hunk_cache[buf][#hunk_cache[buf] + 1] = { start = first, kind = kind }
  end

  -- ── cambios staged (índice vs HEAD) ──
  local committed = committed_cache[buf]
  if not committed then
    return -- sin versión en HEAD (p. ej. archivo recién añadido): no marcamos staged
  end
  local staged = vim.diff(committed, index, { result_type = "indices", algorithm = "histogram" }) or {}
  for _, h in ipairs(staged) do
    local _, ch, si, ci = h[1], h[2], h[3], h[4]
    if ci == 0 then -- borrado staged: marcar junto a la línea del índice
      local lb = index_to_buf(math.max(si, 1), unstaged)
      if lb then
        place(buf, lb, "staged_delete", 6)
      end
    else
      local kind = (ch == 0) and "staged_add" or "staged_change"
      for i = 0, ci - 1 do
        local lb = index_to_buf(si + i, unstaged)
        if lb then
          place(buf, lb, kind, 6)
        end
      end
    end
  end
end

-- Refresco con debounce (para mientras escribes)
local function debounced_refresh(buf)
  local t = timers[buf]
  if t then
    t:stop()
    t:close()
  end
  t = vim.uv.new_timer()
  timers[buf] = t
  t:start(80, 0, vim.schedule_wrap(function()
    refresh(buf)
  end))
end

-- Trae una versión del archivo (async) y la cachea; refresca al terminar
local function fetch(buf, rev, store, dir, file)
  vim.system({ "git", "show", rev .. ":./" .. file }, { cwd = dir, text = true }, function(res)
    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) then
        return
      end
      -- existe esa versión -> guardar tal cual (conservando el \n final, para que
      -- el diff ancle bien las adiciones al final del archivo); si falla -> nil
      store[buf] = (res.code == 0) and (res.stdout or "") or nil
      refresh(buf)
    end)
  end)
end

-- Trae las versiones del índice y de HEAD (async) y refresca
local function update_head(buf)
  if not api.nvim_buf_is_valid(buf) then
    return -- el buffer pudo invalidarse (p. ej. al cambiar de directorio)
  end
  if vim.fn.executable("git") == 0 or not is_file(buf) then
    return
  end
  local name = api.nvim_buf_get_name(buf)
  local dir = vim.fn.fnamemodify(name, ":h")
  local file = vim.fn.fnamemodify(name, ":t")
  fetch(buf, "", index_cache, dir, file) -- índice  (git show :./archivo)
  fetch(buf, "HEAD", committed_cache, dir, file) -- HEAD (git show HEAD:./archivo)
end

-- Navegación entre hunks
local function goto_hunk(dir)
  local buf = api.nvim_get_current_buf()
  local hunks = hunk_cache[buf] or {}
  if #hunks == 0 then
    return
  end
  local cur = api.nvim_win_get_cursor(0)[1]
  local target
  if dir > 0 then
    for _, h in ipairs(hunks) do
      if h.start > cur then
        target = h.start
        break
      end
    end
    target = target or hunks[1].start -- wrap
  else
    for i = #hunks, 1, -1 do
      if hunks[i].start < cur then
        target = hunks[i].start
        break
      end
    end
    target = target or hunks[#hunks].start -- wrap
  end
  api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zz")
end

function M.next_hunk()
  goto_hunk(1)
end
function M.prev_hunk()
  goto_hunk(-1)
end

-- ── Git blame inline ───────────────────────────────────────────────
local function reltime(ts)
  if not ts then
    return "?"
  end
  local diff = os.time() - tonumber(ts)
  local mins = math.floor(diff / 60)
  if mins < 1 then
    return "ahora"
  elseif mins < 60 then
    return "hace " .. mins .. "m"
  end
  local hrs = math.floor(mins / 60)
  if hrs < 24 then
    return "hace " .. hrs .. "h"
  end
  local days = math.floor(hrs / 24)
  if days < 30 then
    return "hace " .. days .. "d"
  end
  local months = math.floor(days / 30)
  if months < 12 then
    return "hace " .. months .. " mes"
  end
  return "hace " .. math.floor(months / 12) .. " a"
end

-- Abre un popup flotante junto al cursor con el blame de la línea actual
local function open_popup(lines, line_hls)
  local width = 1
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end

  local pbuf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(pbuf, 0, -1, false, lines)
  for i, hl in ipairs(line_hls) do
    if hl then
      pcall(api.nvim_buf_add_highlight, pbuf, -1, hl, i - 1, 0, -1)
    end
  end
  vim.bo[pbuf].modifiable = false

  local pwin = api.nvim_open_win(pbuf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = "  git blame ",
    title_pos = "left",
  })

  local function close()
    if api.nvim_win_is_valid(pwin) then
      api.nvim_win_close(pwin, true)
    end
  end
  for _, k in ipairs({ "<Esc>", "q", "<C-c>" }) do
    vim.keymap.set("n", k, close, { buffer = pbuf, nowait = true, silent = true })
  end
  -- cerrar también si el foco sale del popup
  api.nvim_create_autocmd("WinLeave", { buffer = pbuf, once = true, callback = close })
end

-- Muestra el blame de la línea actual en un popup
function M.blame()
  local buf = api.nvim_get_current_buf()
  if vim.fn.executable("git") == 0 or not is_file(buf) then
    vim.notify("git blame: no disponible aquí", vim.log.levels.WARN)
    return
  end
  local name = api.nvim_buf_get_name(buf)
  local dir = vim.fn.fnamemodify(name, ":h")
  local file = vim.fn.fnamemodify(name, ":t")
  local line = api.nvim_win_get_cursor(0)[1]

  vim.system(
    { "git", "blame", "-L", line .. "," .. line, "--porcelain", "--", file },
    { cwd = dir, text = true },
    function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          vim.notify("git blame falló (¿archivo no rastreado?)", vim.log.levels.WARN)
          return
        end
        local out = res.stdout or ""
        local hash = out:match("^(%x+)")
        if hash and hash:match("^0+$") then
          open_popup({ " Sin confirmar (cambios locales)" }, { "GitBlame" })
          return
        end
        local author = out:match("author ([^\n]+)") or "?"
        local ts = tonumber(out:match("author%-time (%d+)"))
        local summary = out:match("summary ([^\n]+)") or ""
        local fecha = ts and (reltime(ts) .. " (" .. os.date("%Y-%m-%d", ts) .. ")") or "?"
        open_popup({
          " " .. author,
          " " .. (hash and hash:sub(1, 8) or "") .. " · " .. fecha,
          " " .. summary,
        }, { "GitBlameAuthor", "GitBlame", "Normal" })
      end)
    end
  )
end

-- ── Activación ─────────────────────────────────────────────────────
theme.register(set_hl)
local group = api.nvim_create_augroup("Git", { clear = true })
local autocmd = api.nvim_create_autocmd

autocmd({ "BufReadPost", "BufWritePost", "BufEnter" }, {
  group = group,
  desc = "Actualizar signos de git",
  callback = function(ev)
    update_head(ev.buf)
  end,
})

autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  desc = "Refrescar signos de git en vivo",
  callback = function(ev)
    debounced_refresh(ev.buf)
  end,
})

autocmd("BufDelete", {
  group = group,
  callback = function(ev)
    index_cache[ev.buf] = nil
    committed_cache[ev.buf] = nil
    hunk_cache[ev.buf] = nil
  end,
})

return M
