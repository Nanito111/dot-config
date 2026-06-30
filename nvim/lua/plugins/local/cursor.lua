-- Cursor y línea del cursor coloreados según el modo (plugin-free).
-- Reutiliza los colores de modo de la paleta (los mismos que la statusline):
--   normal=blue · insert=green · visual=purple · replace=red · command=yellow · terminal=cyan
--
-- El COLOR DEL CURSOR lo gestiona 'guicursor': cada modo apunta a un grupo de
-- highlight (Cursor<Modo>) cuyo bg es el color del modo; al cambiar de modo el
-- terminal usa el grupo correspondiente. La LÍNEA DEL CURSOR (CursorLine + número)
-- se recolorea en cada cambio de modo con un tinte del color del modo.
local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")

-- ── Utilidades de color ────────────────────────────────────────────
local function rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Mezcla `base` con `accent` en proporción `amount` (0 = base, 1 = accent)
local function mix(base, accent, amount)
  local br, bg, bb = rgb(base)
  local ar, ag, ab = rgb(accent)
  local function m(b, a)
    return math.floor(b + (a - b) * amount + 0.5)
  end
  return string.format("#%02x%02x%02x", m(br, ar), m(bg, ag), m(bb, ab))
end

-- Color del modo (usa el modo dado o el actual). Toma la 1ª letra del modo.
local function mode_color(mode)
  local m = (mode or api.nvim_get_mode().mode):sub(1, 1)
  if m == "i" then
    return palette.green
  elseif m == "v" or m == "V" or m == "\22" or m == "s" or m == "S" or m == "\19" then
    return palette.purple -- visual / select
  elseif m == "R" then
    return palette.red -- replace
  elseif m == "c" then
    return palette.yellow -- command
  elseif m == "t" then
    return palette.cyan -- terminal
  end
  return palette.blue -- normal / operator-pending / por defecto
end

-- Intensidad del tinte de la línea del cursor (0 = sin tinte, 1 = color pleno).
-- Súbelo si quieres la línea más marcada; bájalo si la prefieres más sutil.
local LINE_TINT = 0.15

-- Intensidad de la selección visual (más marcada que la línea, para distinguirla).
-- Garantiza que la selección siempre se vea, sea cual sea el tema.
local SEL_TINT = 0.30

-- ── Cursor: un grupo de highlight por modo (color = bg del grupo) ───
local function set_cursor_hl()
  local hl = api.nvim_set_hl
  hl(0, "CursorNormal", { bg = palette.blue, fg = palette.bg })
  hl(0, "CursorInsert", { bg = palette.green, fg = palette.bg })
  hl(0, "CursorVisual", { bg = palette.purple, fg = palette.bg })
  hl(0, "CursorReplace", { bg = palette.red, fg = palette.bg })
  hl(0, "CursorCommand", { bg = palette.yellow, fg = palette.bg })
  hl(0, "CursorTerminal", { bg = palette.cyan, fg = palette.bg })
end

-- Forma + grupo de color del cursor por modo (bloque, barra en insert, raya en replace)
vim.o.guicursor = table.concat({
  "n-o-sm:block-CursorNormal",
  "v-ve:block-CursorVisual",
  "i-ci:ver25-CursorInsert",
  "r-cr:hor20-CursorReplace",
  "c:block-CursorCommand",
  "t:block-CursorTerminal",
}, ",")

-- ── Línea del cursor: tinte del color del modo + número resaltado ───
local function set_line_hl(mode)
  local c = mode_color(mode)
  api.nvim_set_hl(0, "CursorLine", { bg = mix(palette.bg, c, LINE_TINT) })
  api.nvim_set_hl(0, "CursorLineNr", { fg = c, bold = true })
end

-- Selección visual: tinte del color de visual (morado), siempre visible. Algunos
-- temas (p. ej. carbonfox) traen un Visual demasiado tenue; esto lo garantiza.
local function set_selection_hl()
  api.nvim_set_hl(0, "Visual", { bg = mix(palette.bg, palette.purple, SEL_TINT) })
end

-- Aplicar al cargar y reaplicar en cada ColorScheme (con la paleta ya refrescada)
theme.register(function()
  set_cursor_hl()
  set_line_hl()
  set_selection_hl()
end)

-- Recolorear la línea en cada cambio de modo (el cursor lo cambia guicursor solo)
api.nvim_create_autocmd("ModeChanged", {
  group = api.nvim_create_augroup("CursorMode", { clear = true }),
  pattern = "*:*", -- todas las transiciones de modo (sin esto el default "*" no casa)
  desc = "Color de la línea del cursor según el modo",
  callback = function()
    set_line_hl(vim.v.event.new_mode)
  end,
})

return {}
