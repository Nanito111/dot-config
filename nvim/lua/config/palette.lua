-- Paleta de colores de UI (no de iconos), centralizada. AHORA ES DINÁMICA: deriva
-- sus colores de los grupos de highlight del colorscheme activo, de modo que toda
-- la UI propia (statusline, git, notify, explorer, winbar) sigue al tema. Los
-- valores por defecto (Tokyonight Night) actúan como respaldo si un tema no define
-- algún grupo.
--
-- La tabla se MUTA en su sitio en M.refresh() (no se reemplaza), porque los módulos
-- guardan una referencia a ella; al mutar campos, todos ven los colores nuevos.
-- config.theme llama a M.refresh() en cada evento ColorScheme antes de reaplicar.

local M = {
  -- valores de respaldo (Tokyonight Night)
  bg = "#1a1b26",
  bg_dark = "#16161e",
  bg_highlight = "#2a2b3d",
  fg = "#c0caf5",
  comment = "#565f89",
  blue = "#7aa2f7",
  cyan = "#73daca",
  cyan_bright = "#7dcfff",
  green = "#9ece6a",
  purple = "#bb9af7",
  yellow = "#e0af68",
  red = "#f7768e",
  orange = "#e0875a",
  green_dim = "#5d8a4f",
  yellow_dim = "#b8924a",
  red_dim = "#b35d6e",
}

-- ── Utilidades de color ────────────────────────────────────────────
local function get_hl(name)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and h or {}
end

local function to_hex(n)
  return n and string.format("#%06x", n) or nil
end

-- Primer fg disponible de una lista de grupos
local function fg(...)
  for _, g in ipairs({ ... }) do
    local c = get_hl(g).fg
    if c then return to_hex(c) end
  end
end

-- Primer bg disponible de una lista de grupos
local function bg(...)
  for _, g in ipairs({ ... }) do
    local c = get_hl(g).bg
    if c then return to_hex(c) end
  end
end

local function rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function clamp(x)
  return math.max(0, math.min(255, math.floor(x + 0.5)))
end

-- Mezcla a y b en proporción t (0 = a, 1 = b)
local function blend(a, b, t)
  local ar, ag, ab = rgb(a)
  local br, bgc, bb = rgb(b)
  return string.format("#%02x%02x%02x", clamp(ar + (br - ar) * t), clamp(ag + (bgc - ag) * t), clamp(ab + (bb - ab) * t))
end

local function luminance(hex)
  local r, g, b = rgb(hex)
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

-- ── Tono: que un color con nombre sea de verdad de ese color ───────
-- Los temas no garantizan que el grupo del que derivamos tenga el tono que promete el
-- nombre: en carbonfox `Special` es azul (no cyan) y `Type` es teal (no amarillo), así que
-- cyan salía idéntico a blue y los avisos no eran amarillos. Se valida el tono y, si ningún
-- candidato encaja, se sintetiza uno.
local function to_hsl(hex)
  local r, g, b = rgb(hex)
  r, g, b = r / 255, g / 255, b / 255
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local l, d = (mx + mn) / 2, mx - mn
  if d < 1e-6 then
    return 0, 0, l -- gris: el tono no significa nada
  end
  local h
  if mx == r then
    h = ((g - b) / d) % 6
  elseif mx == g then
    h = (b - r) / d + 2
  else
    h = (r - g) / d + 4
  end
  local s = d / (1 - math.abs(2 * l - 1))
  return h * 60 % 360, s, l
end

local function from_hsl(h, s, l)
  local c = (1 - math.abs(2 * l - 1)) * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = l - c / 2
  local r, g, b
  if h < 60 then r, g, b = c, x, 0
  elseif h < 120 then r, g, b = x, c, 0
  elseif h < 180 then r, g, b = 0, c, x
  elseif h < 240 then r, g, b = 0, x, c
  elseif h < 300 then r, g, b = x, 0, c
  else r, g, b = c, 0, x end
  return string.format("#%02x%02x%02x", clamp((r + m) * 255), clamp((g + m) * 255), clamp((b + m) * 255))
end

-- Banda de tono de cada nombre (grados). `red` cruza el 0, de ahí el caso envolvente.
-- Son anchas a propósito: solo deben rechazar mentiras gordas (un teal llamado "amarillo"),
-- no los tonos legítimos de cada tema — hay rojos rosados (#ee5396, 334°) y amarillos ámbar
-- (#e0af68, 36°) que son el rojo/amarillo de su tema y hay que respetar.
local BANDS = {
  red = { 330, 15 },
  orange = { 15, 35 },
  yellow = { 35, 70 },
  green = { 70, 165 },
  cyan = { 165, 200 },
  blue = { 200, 255 },
  purple = { 255, 330 },
}

local function in_band(hex, band)
  local h, s = to_hsl(hex)
  if s < 0.12 then
    return false -- casi gris: no sirve como color con nombre
  end
  local lo, hi = band[1], band[2]
  if lo > hi then -- banda que cruza el 0 (rojo)
    return h >= lo or h < hi
  end
  return h >= lo and h < hi
end

local function band_center(band)
  local lo, hi = band[1], band[2]
  if lo > hi then
    return ((lo + hi + 360) / 2) % 360
  end
  return (lo + hi) / 2
end

-- ── Recalcular la paleta desde el tema activo ──────────────────────
function M.refresh()
  local base_bg = bg("Normal") or M.bg
  local base_fg = fg("Normal") or M.fg
  local light = luminance(base_bg) > 0.5 -- ¿tema claro?

  M.bg = base_bg
  M.fg = base_fg
  M.comment = fg("Comment") or blend(base_fg, base_bg, 0.55)

  -- Colores con NOMBRE DE TONO: se toma el primer grupo del tema cuyo color caiga de verdad
  -- en la banda del nombre. Sin ese filtro los temas mienten (en carbonfox `Special` es azul
  -- y `Type` teal), y dos nombres acababan con el mismo color.
  local CANDIDATES = {
    blue = { "Function", "@function", "Identifier", "DiagnosticInfo" },
    cyan = { "Special", "@string.special", "DiagnosticHint", "SpecialChar" },
    green = { "String", "@string", "DiagnosticOk", "diffAdded" },
    purple = { "Keyword", "@keyword", "Statement", "@constant.macro" },
    yellow = { "Type", "@type", "DiagnosticWarn", "WarningMsg" },
    red = { "DiagnosticError", "Error", "@keyword.return", "ErrorMsg" },
    orange = { "@number", "Number", "Constant", "@constant" },
  }
  local derived = {}
  for name, groups in pairs(CANDIDATES) do
    for _, g in ipairs(groups) do
      local c = fg(g)
      if c and in_band(c, BANDS[name]) then
        derived[name] = c
        break
      end
    end
  end

  -- Saturación/luminosidad medias de lo que SÍ se derivó: los tonos que haya que inventar
  -- (carbonfox no tiene ni un amarillo) salen con el carácter del tema, no con un color
  -- ajeno fijo. Sirve igual en temas claros, donde esa media es más oscura.
  local ssum, lsum, n = 0, 0, 0
  for _, c in pairs(derived) do
    local _, s, l = to_hsl(c)
    ssum, lsum, n = ssum + s, lsum + l, n + 1
  end
  local avg_l = n > 0 and lsum / n or (light and 0.40 or 0.65)
  -- Saturación de síntesis: capada y mezclada luego hacia `comment`. La media cruda sesga
  -- alto cuando solo derivan los colores más vivos del tema (en gruvbox derivan rojo s1.0 y
  -- amarillo s0.8 -> 0.9), y un tono de BANDA PURO a esa saturación es un primario espectral
  -- que ese tema jamás usa: se veía durísimo, sobre todo en las variantes claras.
  local syn_s = math.min(n > 0 and ssum / n or 0.60, 0.55)

  -- Cada nombre queda confinado a su banda, así que ya no pueden colisionar entre sí. Los
  -- sintetizados se acercan a `comment` para perder el brillo de primario y coger el matiz
  -- del tema; los derivados son colores reales del tema y se dejan intactos.
  for name, band in pairs(BANDS) do
    if derived[name] then
      M[name] = derived[name]
    else
      M[name] = blend(from_hsl(band_center(band), syn_s, avg_l), M.comment, 0.3)
    end
  end
  M.cyan_bright = blend(M.cyan, "#ffffff", 0.15)

  -- Fondos derivados: preferir grupos del tema; si no, oscurecer/aclarar la base
  M.bg_dark = bg("StatusLine", "StatusLineNC")
    or (light and blend(base_bg, "#000000", 0.06) or blend(base_bg, "#000000", 0.30))

  -- Color propio del tema para la statusline (bg y fg de StatusLine); si el tema no lo
  -- define, cae a bg_dark / fg. Lo usa el preset vscode para seguir el tema.
  M.statusline_bg = bg("StatusLine", "StatusLineNC") or M.bg_dark
  M.statusline_fg = fg("StatusLine", "StatusLineNC") or M.fg

  -- Colores SEMÁNTICOS de diagnósticos: tomados de los grupos Diagnostic* del tema (no
  -- de la sintaxis), para que la statusline coincida con el gutter y el virtual text.
  -- Fallback a los colores generales del palette si el tema no los define.
  M.diag_error = fg("DiagnosticError", "Error", "ErrorMsg") or M.red
  M.diag_warn = fg("DiagnosticWarn", "WarningMsg") or M.yellow
  M.diag_info = fg("DiagnosticInfo") or M.blue
  M.diag_hint = fg("DiagnosticHint") or M.cyan
  M.bg_highlight = bg("CursorLine", "Visual")
    or (light and blend(base_bg, "#000000", 0.08) or blend(base_bg, "#ffffff", 0.10))

  -- Versiones apagadas para git "staged" (mezcladas hacia el fondo)
  M.green_dim = blend(M.green, base_bg, 0.45)
  M.yellow_dim = blend(M.yellow, base_bg, 0.45)
  M.red_dim = blend(M.red, base_bg, 0.45)
end

-- Poblar con el colorscheme actual al cargar (los respaldos cubren lo que falte)
M.refresh()

return M
