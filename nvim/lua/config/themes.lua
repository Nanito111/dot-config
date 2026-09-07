-- Gestión de temas: lista seleccionable, aplicación del tema guardado al arrancar,
-- selector con vista previa en vivo (reutiliza el picker propio) y persistencia de
-- la elección entre sesiones. Al aplicar un tema se dispara el evento ColorScheme,
-- que recalcula la paleta dinámica y reaplica toda la UI propia.
local M = {}

-- Temas disponibles. Cada entrada es { etiqueta, cs = <colorscheme>, bg = <fondo> }.
--   etiqueta -> lo que se muestra en el selector y se guarda (por defecto = cs)
--   cs       -> nombre real de :colorscheme (por defecto = la etiqueta)
--   bg       -> "dark"/"light" (por defecto "dark")
-- Variantes claro/oscuro que comparten colorscheme (p. ej. gruvbox) se separan
-- aquí con distinto bg. Primero los oscuros y luego los claros. Edita a gusto.
M.themes = {
  -- ── Oscuros ──
  { "tokyonight-night" },
  { "tokyonight-storm" },
  { "tokyonight-moon" },
  { "catppuccin-mocha" },
  { "catppuccin-macchiato" },
  { "catppuccin-frappe" },
  { "kanagawa-wave" },
  { "kanagawa-dragon" },
  { "gruvbox-dark", cs = "gruvbox", bg = "dark" },
  { "rose-pine-main" },
  { "rose-pine-moon" },
  { "nightfox" },
  { "duskfox" },
  { "nordfox" },
  { "carbonfox" },
  { "flexoki-dark" },
  { "monokai" },
  { "monokai_pro" },
  { "monokai_soda" },
  { "monokai_ristretto" },
  { "papercolor-dark", cs = "PaperColor", bg = "dark" },
  { "melange-dark", cs = "melange", bg = "dark" },
  { "alabaster-dark", cs = "alabaster", bg = "dark" },
  -- ── Claros ──
  { "tokyonight-day", bg = "light" },
  { "catppuccin-latte", bg = "light" },
  { "kanagawa-lotus", bg = "light" },
  { "gruvbox-light", cs = "gruvbox", bg = "light" },
  { "rose-pine-dawn", bg = "light" },
  { "dayfox", bg = "light" },
  { "flexoki-light", bg = "light" },
  { "papercolor-light", cs = "PaperColor", bg = "light" },
  { "melange-light", cs = "melange", bg = "light" },
  { "alabaster-light", cs = "alabaster", bg = "light" },
}

local DEFAULT = "tokyonight-night"
local current_label = DEFAULT -- último tema aplicado (para el panel de configuración)

-- Etiquetas (strings) para el selector y el autocompletado
function M.labels()
  return vim.tbl_map(function(t)
    return t[1]
  end, M.themes)
end

-- Busca la entrada por etiqueta; si no existe, trata la etiqueta como un nombre de
-- colorscheme suelto (compatibilidad con elecciones guardadas antiguas)
local function find(label)
  for _, t in ipairs(M.themes) do
    if t[1] == label then
      return t
    end
  end
  return { label }
end

-- Aplica un tema (fondo + colorscheme), con protección si la variante no existe.
-- No persiste: solo cambia el aspecto (lo usa la vista previa del selector/panel).
local function apply(label)
  local t = find(label)
  vim.o.background = t.bg or "dark"
  local ok = pcall(vim.cmd.colorscheme, t.cs or t[1])
  if ok then
    current_label = label
  end
  return ok
end
M.apply = apply

-- Etiqueta del tema activo (para el panel de configuración)
function M.current()
  return current_label
end

-- Aplica y persiste (solo si difiere del default se guarda; lo gestiona config.settings)
function M.set(label)
  if apply(label) then
    require("config.settings").record("ui.theme", label)
  else
    vim.notify("No se pudo aplicar el tema: " .. label, vim.log.levels.WARN)
  end
end

-- Aplica al arrancar el tema guardado (solo se carga si se cambió); si falla, el default
function M.setup()
  local name = require("config.settings").value("ui.theme", DEFAULT)
  if not apply(name) and name ~= DEFAULT then
    apply(DEFAULT)
  end
end

-- ── Preview del selector ───────────────────────────────────────────
-- Código de ejemplo (lo resalta treesitter con el tema YA aplicado por on_move, así que
-- muestra los colores reales) y debajo la paleta que la UI propia deriva de ese tema.
local SAMPLE = {
  "-- Ejemplo de código",
  "local M = {}",
  "",
  "---@param n number",
  "function M.fib(n)",
  "  if n < 2 then",
  "    return n -- caso base",
  "  end",
  "  return M.fib(n - 1) + M.fib(n - 2)",
  "end",
  "",
  'local msg = ("fib(%d) = %d"):format(10, M.fib(10))',
  "vim.notify(msg, vim.log.levels.INFO)",
  "",
  "return M",
}

-- Colores de la paleta que se muestran como muestrario, en orden. Sin `bg`: su muestra
-- sería un bloque del color del fondo SOBRE el fondo, es decir, invisible (y el fondo del
-- tema ya se ve en el propio panel).
local SWATCHES = { "bg_highlight", "fg", "comment", "blue", "cyan", "green", "yellow", "orange", "red", "purple" }

-- Grupo de resaltado para un color. Se (re)define SIEMPRE: aplicar un colorscheme hace
-- `hi clear`, así que un grupo creado antes del cambio de tema quedaría vacío.
local function swatch_group(color)
  local name = "ThemeSwatch_" .. color:gsub("#", "")
  pcall(vim.api.nvim_set_hl, 0, name, { fg = color })
  return name
end

local BLOCK = "███"

-- Ancho del nombre más largo, para que las dos columnas cuadren (bg_highlight mide 12)
local KEY_W = 0
for _, key in ipairs(SWATCHES) do
  KEY_W = math.max(KEY_W, #key)
end

-- La paleta va ARRIBA y en dos columnas: el panel de preview suele mostrar ~14 líneas,
-- así que al final del ejemplo quedaría fuera de pantalla.
local function preview()
  local pal = require("config.palette")
  local lines, extmarks = { "-- Paleta del tema" }, {}

  for i = 1, #SWATCHES, 2 do
    local text = "--"
    for j = i, math.min(i + 1, #SWATCHES) do
      local key = SWATCHES[j]
      local color = pal[key]
      if type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then
        text = text .. "  "
        local col = #text -- byte donde empieza el bloque de color
        -- el nombre va al ancho del más largo y el hex siempre mide 7: columnas cuadradas
        text = text .. BLOCK .. " " .. string.format("%-" .. KEY_W .. "s %s", key, color)
        -- el bloque lleva el color real; el extmark gana por prioridad a treesitter,
        -- que si no lo pintaría como comentario
        extmarks[#extmarks + 1] = {
          #lines, -- fila 0-based: la que estamos a punto de añadir
          col,
          { end_col = col + #BLOCK, hl_group = swatch_group(color) },
        }
      end
    end
    lines[#lines + 1] = text
  end

  lines[#lines + 1] = ""
  vim.list_extend(lines, SAMPLE)
  return { lines = lines, filetype = "lua", extmarks = extmarks }
end
M.preview = preview

-- Selector con vista previa en vivo y restauración si se cancela
function M.pick()
  -- estado actual para restaurar al cancelar (colorscheme + fondo)
  local original_cs = vim.g.colors_name
  local original_bg = vim.o.background
  require("plugins.local.picker").pick({
    title = "Temas",
    items = M.labels(),
    preview = preview,
    on_move = function(label)
      if label then
        apply(label) -- vista previa sin guardar
      end
    end,
    on_select = function(label)
      if label then
        M.set(label) -- confirmar: aplicar y persistir
      end
    end,
    on_cancel = function()
      vim.o.background = original_bg
      if original_cs then
        pcall(vim.cmd.colorscheme, original_cs)
      end
    end,
  })
end

vim.api.nvim_create_user_command("Theme", function(o)
  if o.args ~= "" then
    M.set(o.args)
  else
    M.pick()
  end
end, {
  nargs = "?",
  complete = function(lead)
    return vim.tbl_filter(function(t)
      return t:find(lead, 1, true) == 1
    end, M.labels())
  end,
  desc = "Elegir tema (sin argumento abre el selector con vista previa)",
})

return M
