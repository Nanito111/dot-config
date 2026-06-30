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
-- aquí con distinto bg. Edita a gusto.
M.themes = {
  { "tokyonight-night" },
  { "tokyonight-storm" },
  { "tokyonight-moon" },
  { "tokyonight-day", bg = "light" },
  { "catppuccin-mocha" },
  { "catppuccin-macchiato" },
  { "catppuccin-frappe" },
  { "catppuccin-latte", bg = "light" },
  { "kanagawa-wave" },
  { "kanagawa-dragon" },
  { "kanagawa-lotus", bg = "light" },
  { "gruvbox-dark", cs = "gruvbox", bg = "dark" },
  { "gruvbox-light", cs = "gruvbox", bg = "light" },
  { "rose-pine" },
  { "rose-pine-moon" },
  { "rose-pine-dawn", bg = "light" },
  { "nightfox" },
  { "dayfox", bg = "light" },
  { "duskfox" },
  { "nordfox" },
  { "carbonfox" },
}

local DEFAULT = "tokyonight-night"
local savefile = vim.fn.stdpath("data") .. "/colorscheme"

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

-- Aplica un tema (fondo + colorscheme), con protección si la variante no existe
local function apply(label)
  local t = find(label)
  vim.o.background = t.bg or "dark"
  return pcall(vim.cmd.colorscheme, t.cs or t[1])
end

-- Guarda la elección para la próxima sesión
local function save(label)
  pcall(vim.fn.writefile, { label }, savefile)
end

-- Aplica y persiste
function M.set(label)
  if apply(label) then
    save(label)
  else
    vim.notify("No se pudo aplicar el tema: " .. label, vim.log.levels.WARN)
  end
end

-- Lee el tema guardado (o el por defecto)
function M.saved()
  local ok, lines = pcall(vim.fn.readfile, savefile)
  if ok and lines and lines[1] and lines[1] ~= "" then
    return lines[1]
  end
  return DEFAULT
end

-- Aplica al arrancar el tema guardado; si falla, cae al por defecto
function M.setup()
  local name = M.saved()
  if not apply(name) and name ~= DEFAULT then
    apply(DEFAULT)
  end
end

-- Selector con vista previa en vivo y restauración si se cancela
function M.pick()
  -- estado actual para restaurar al cancelar (colorscheme + fondo)
  local original_cs = vim.g.colors_name
  local original_bg = vim.o.background
  require("plugins.local.picker").pick({
    title = "Temas",
    items = M.labels(),
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
