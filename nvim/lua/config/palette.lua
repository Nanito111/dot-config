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

-- ── Recalcular la paleta desde el tema activo ──────────────────────
function M.refresh()
  local base_bg = bg("Normal") or M.bg
  local base_fg = fg("Normal") or M.fg
  local light = luminance(base_bg) > 0.5 -- ¿tema claro?

  M.bg = base_bg
  M.fg = base_fg
  M.comment = fg("Comment") or blend(base_fg, base_bg, 0.55)

  M.blue = fg("Function", "@function", "Identifier", "DiagnosticInfo") or M.blue
  M.cyan = fg("Special", "@string.special", "DiagnosticHint", "SpecialChar") or M.cyan
  M.green = fg("String", "@string", "DiagnosticOk", "diffAdded") or M.green
  M.purple = fg("Keyword", "@keyword", "Statement", "@constant.macro") or M.purple
  M.yellow = fg("Type", "@type", "DiagnosticWarn", "WarningMsg") or M.yellow
  M.red = fg("DiagnosticError", "Error", "@keyword.return", "ErrorMsg") or M.red
  M.orange = fg("@number", "Number", "Constant", "@constant") or blend(M.red, M.yellow, 0.5)
  M.cyan_bright = blend(M.cyan, "#ffffff", 0.15)

  -- Fondos derivados: preferir grupos del tema; si no, oscurecer/aclarar la base
  M.bg_dark = bg("StatusLine", "StatusLineNC")
    or (light and blend(base_bg, "#000000", 0.06) or blend(base_bg, "#000000", 0.30))
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
