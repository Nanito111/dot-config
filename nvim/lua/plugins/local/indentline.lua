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
local MAX_LINES = 5000 -- por encima de esto no se dibuja (protección de rendimiento)
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

-- Persistencia de la elección entre sesiones
local prefs_file = vim.fn.stdpath("data") .. "/indentline.txt"
local function save_prefs()
  pcall(vim.fn.writefile, { active and char or "" }, prefs_file)
end
local function load_prefs()
  local ok, lines = pcall(vim.fn.readfile, prefs_file)
  if ok and lines and lines[1] ~= nil then
    if lines[1] == "" then
      active = false
    else
      char = lines[1]
    end
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

-- Redibuja TODAS las guías del buffer (limpia y vuelve a poner). Barato porque las
-- guías dependen solo del contenido; los extmarks se ven en cualquier ventana del buffer.
local function render(buf)
  if not (active and eligible(buf)) then
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    return
  end
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local n = api.nvim_buf_line_count(buf)
  if n > MAX_LINES then
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

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)

  -- indentación en COLUMNAS de pantalla de cada línea (false = línea en blanco)
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

  -- indentación efectiva de las líneas en blanco: el MÍNIMO de sus vecinos no vacíos,
  -- para que las guías fluyan por los huecos internos de un bloque sin sobrar al cerrarlo.
  local prev, last = {}, 0
  for i = 1, n do
    if raw[i] ~= false then
      last = raw[i]
    end
    prev[i] = last
  end
  local nxt, nlast = {}, 0
  for i = n, 1, -1 do
    if raw[i] ~= false then
      nlast = raw[i]
    end
    nxt[i] = nlast
  end

  for i = 1, n do
    local indent = raw[i]
    if indent == false then
      indent = math.min(prev[i], nxt[i])
    end
    local c = 0
    while c < indent do
      pcall(api.nvim_buf_set_extmark, buf, ns, i - 1, 0, {
        virt_text = { { char, "IndentLine" } },
        virt_text_win_col = c, -- columna de ventana (funciona en líneas vacías)
        hl_mode = "combine", -- respeta cursorline/otros fondos
        priority = 1,
      })
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
local function apply(c)
  if c == "" then
    active = false
  else
    active = true
    char = c
  end
  render_all()
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
