-- Guías de indentación (plugin-free): dibuja una línea vertical tenue en cada nivel
-- de indentación de los buffers de código. Usa extmarks de virt_text posicionados por
-- COLUMNA de ventana (virt_text_win_col), así también aparecen en líneas en blanco sin
-- desplazar el texto. Depende solo del contenido del buffer (no del scroll), por eso
-- basta redibujar al cambiar el texto; se hace con debounce para no penalizar al teclear.
local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")

local M = {}
local ns = api.nvim_create_namespace("indentline")
local char = "\u{250a}" -- ┊ carácter de la guía (configurable con el picker)
local CTX = 120 -- líneas de contexto sobre/bajo el viewport (para líneas en blanco)
local active = true -- estado global (toggle con :IndentLines / picker "vacío")

-- Catálogo de estilos para el selector (M.pick). char "" = ocultar las guías.
local CHARS = {
  { label = "\u{250a}  guiones (cuádruple)", char = "\u{250a}" }, -- ┊
  { label = "\u{2506}  guiones (triple)", char = "\u{2506}" }, -- ┆
  { label = "\u{254e}  guiones (doble)", char = "\u{254e}" }, -- ╎
  { label = "\u{2502}  continua", char = "\u{2502}" }, -- │
  { label = "\u{258f}  barra fina", char = "\u{258f}" }, -- ▏
  { label = "(vacío — ocultar)", char = "" },
}

-- Persistencia de la elección entre sesiones (vía config.settings; "" = ocultar)
local DEFAULT_CHAR = char
local function save_prefs()
  require("config.settings").record("ui.indentline", active and char or "")
end
local function load_prefs()
  local v = require("config.settings").value("ui.indentline", DEFAULT_CHAR)
  if v == "" then
    active = false
  else
    char = v
  end
end

local function set_hl()
  api.nvim_set_hl(0, "IndentLine", { fg = palette.bg_highlight }) -- línea tenue
end
theme.register(set_hl)
set_hl()

-- Filetypes/buffers donde NO tiene sentido mostrar guías
local EXCLUDE_FT = {
  dashboard = true,
  explorer = true,
  settings = true,
  help = true,
  man = true,
  gitcommit = true,
  markdown = true,
  text = true,
  checkhealth = true,
  qf = true,
}

local function eligible(buf)
  return api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buftype == "" -- solo archivos normales (no terminal/quickfix…)
    and not EXCLUDE_FT[vim.bo[buf].filetype]
end

-- Ventana que muestra `buf`: la actual si lo muestra, si no la primera que lo tenga.
local function win_of(buf)
  local cur = api.nvim_get_current_win()
  if api.nvim_win_get_buf(cur) == buf then
    return cur
  end
  return vim.fn.win_findbuf(buf)[1]
end

-- Desplazamiento horizontal (leftcol) de una ventana. Sirve para colocar las guías, que
-- usan columna de ventana, ajustadas al scroll horizontal.
local function win_leftcol(win)
  if not win then
    return 0
  end
  local ok, lc = pcall(api.nvim_win_call, win, function()
    return vim.fn.winsaveview().leftcol
  end)
  return (ok and lc) or 0
end

-- Redibuja TODAS las guías del buffer (limpia y vuelve a poner). Barato porque las
-- guías dependen solo del contenido; los extmarks se ven en cualquier ventana del buffer.
local function render(buf)
  if not (active and eligible(buf)) then
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    return
  end
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- Ventana que muestra el buffer: sin ella no hay nada visible que dibujar.
  local win = win_of(buf)
  if not win then
    return
  end

  local sw = vim.bo[buf].shiftwidth
  local ts = vim.bo[buf].tabstop
  if sw <= 0 then
    sw = ts -- shiftwidth=0 -> se usa tabstop (igual que Vim)
  end
  if sw <= 0 then
    return
  end

  -- Rango VISIBLE de la ventana (líneas de buffer). Solo dibujamos ahí -> el render es
  -- O(altura de pantalla), no O(tamaño del archivo).
  local n = api.nvim_buf_line_count(buf)
  local info = vim.fn.getwininfo(win)[1]
  local top = math.max(1, info.topline)
  local bot = math.min(n, info.botline)
  if bot < top then
    return
  end
  local leftcol = win_leftcol(win)

  -- Bloque = visible + contexto (CTX): el sangrado de las líneas en blanco de los bordes
  -- depende de su vecino no-vacío, que puede quedar fuera de pantalla.
  local b_first = math.max(1, top - CTX)
  local b_last = math.min(n, bot + CTX)
  local lines = api.nvim_buf_get_lines(buf, b_first - 1, b_last, false)

  -- indentación en COLUMNAS de pantalla de cada línea del bloque (false = línea en blanco)
  local raw = {}
  for i, l in ipairs(lines) do
    if l == "" or l:match("^%s*$") then
      raw[i] = false
    else
      local col = 0
      for k = 1, #l do
        local b = l:byte(k)
        if b == 32 then -- espacio
          col = col + 1
        elseif b == 9 then -- tab: avanza al siguiente múltiplo de tabstop
          col = col + (ts - (col % ts))
        else
          break
        end
      end
      raw[i] = col
    end
  end

  -- vecinos no-vacíos (mínimo) para el sangrado de las líneas en blanco, dentro del bloque
  local m = #lines
  local prev, plast = {}, 0
  for i = 1, m do
    if raw[i] ~= false then
      plast = raw[i]
    end
    prev[i] = plast
  end
  local nxt, nlast = {}, 0
  for i = m, 1, -1 do
    if raw[i] ~= false then
      nlast = raw[i]
    end
    nxt[i] = nlast
  end

  -- Dibujar SOLO las líneas visibles [top, bot]. La guía de la columna c va en la columna
  -- de ventana (c - leftcol): acompaña el scroll horizontal y, si queda fuera por la
  -- izquierda, se omite. Como caen en el sangrado (espacios), no tapan contenido.
  for bl = top, bot do
    local idx = bl - b_first + 1
    local indent = raw[idx]
    if indent == false then
      indent = math.min(prev[idx], nxt[idx])
    end
    local c = 0
    while c < indent do
      local wincol = c - leftcol
      if wincol >= 0 then
        pcall(api.nvim_buf_set_extmark, buf, ns, bl - 1, 0, {
          virt_text = { { char, "IndentLine" } },
          virt_text_win_col = wincol,
          hl_mode = "combine",
          priority = 1,
        })
      end
      c = c + sw
    end
  end
end

-- Debounce por buffer: coalesce ráfagas de TextChangedI mientras se teclea
local timers = {}
local function schedule(buf)
  local t = timers[buf]
  if not t then
    t = (vim.uv or vim.loop).new_timer()
    timers[buf] = t
  end
  t:stop()
  t:start(
    40,
    0,
    vim.schedule_wrap(function()
      if api.nvim_buf_is_valid(buf) then
        render(buf)
      end
    end)
  )
end

-- Redibuja las guías en todos los buffers cargados (para preview/cambios en caliente)
local function render_all()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      render(buf)
    end
  end
end

-- Fija el carácter de la guía. "" = ocultar (active=false). Redibuja al instante.
-- No persiste: es la vista previa del selector/panel.
local function apply(c)
  if c == "" then
    active = false
  else
    active = true
    char = c
  end
  render_all()
end
M.apply = apply

-- Adaptadores para el panel de configuración (config.settings)
function M.choices() -- valores posibles (el carácter; "" = ocultar)
  return vim.tbl_map(function(o)
    return o.char
  end, CHARS)
end
function M.label_of(c) -- etiqueta legible de un carácter
  for _, o in ipairs(CHARS) do
    if o.char == c then
      return o.label
    end
  end
  return c
end
function M.current() -- valor activo ("" si están ocultas)
  return active and char or ""
end
function M.set(c) -- aplicar + persistir
  apply(c)
  save_prefs()
end

-- Selector de estilo de guía (con preview en vivo y opción "vacío" para ocultar)
function M.pick()
  local orig_char, orig_active = char, active
  local items, by_label = {}, {}
  for _, o in ipairs(CHARS) do
    items[#items + 1] = o.label
    by_label[o.label] = o.char
  end
  require("plugins.local.picker").pick({
    title = "Guías de indentación",
    items = items,
    on_move = function(label) -- preview en vivo al navegar
      if label then
        apply(by_label[label])
      end
    end,
    on_select = function(label) -- confirmar: aplicar + persistir
      if label then
        apply(by_label[label])
        save_prefs()
      end
    end,
    on_cancel = function() -- restaurar lo que había
      char, active = orig_char, orig_active
      render_all()
    end,
  })
end

-- Alterna las guías en todos los buffers
function M.toggle()
  active = not active
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) then
      if active then
        schedule(buf)
      else
        api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      end
    end
  end
  save_prefs()
  vim.notify(
    "Guías de indentación " .. (active and "activadas" or "desactivadas"),
    vim.log.levels.INFO,
    { title = "IndentLine" }
  )
end

local group = api.nvim_create_augroup("IndentLine", { clear = true })

api.nvim_create_autocmd({ "BufWinEnter", "FileType", "TextChanged", "TextChangedI" }, {
  group = group,
  desc = "Redibujar las guías de indentación",
  callback = function(a)
    schedule(a.buf)
  end,
})

-- Redibujar al cambiar el RANGO VISIBLE (scroll vertical u horizontal) o el tamaño de la
-- ventana: como solo dibujamos el viewport, hay que rehacerlo cuando este cambia.
-- Con debounce (schedule) para coalescer ráfagas de scroll; el render es barato (O(alto)).
api.nvim_create_autocmd({ "WinScrolled", "WinResized" }, {
  group = group,
  desc = "Redibujar las guías al cambiar el viewport (scroll/resize)",
  callback = function(a)
    schedule(a.buf)
  end,
})

-- Redibujar al cambiar el ancho/tipo de indentación (p. ej. el botón de la statusline,
-- :set sw=4, editorconfig…): esos cambios no disparan eventos de texto.
api.nvim_create_autocmd("OptionSet", {
  group = group,
  pattern = { "shiftwidth", "tabstop", "expandtab", "softtabstop" },
  desc = "Redibujar las guías al cambiar la indentación",
  callback = function()
    schedule(api.nvim_get_current_buf())
  end,
})

-- limpiar el timer al descargar el buffer
api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function(a)
    local t = timers[a.buf]
    if t then
      t:stop()
      t:close()
      timers[a.buf] = nil
    end
  end,
})

api.nvim_create_user_command("IndentLines", M.toggle, { desc = "Alternar las guías de indentación" })
api.nvim_create_user_command("IndentLinesPick", M.pick, { desc = "Elegir el estilo de las guías de indentación" })

load_prefs() -- restaurar el carácter/estado guardado antes del primer render

-- Dibujar en los buffers ya cargados (arranque y :ReloadConfig)
for _, buf in ipairs(api.nvim_list_bufs()) do
  if api.nvim_buf_is_loaded(buf) then
    schedule(buf)
  end
end

return M
