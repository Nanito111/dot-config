-- Paleta de colores de UI (no de iconos), centralizada para no repetir hex en
-- cada módulo. Nombres tomados de la convención de Tokyonight; si cambias de
-- colorscheme, basta editar este archivo.

return {
  -- fondos
  bg = "#1a1b26",          -- fondo principal del editor
  bg_dark = "#16161e",      -- fondo de statusline/tabline (relleno)
  bg_highlight = "#2a2b3d", -- fondo de píldoras "info" (git, filetype, posición)

  -- texto
  fg = "#c0caf5",     -- texto principal
  comment = "#565f89", -- texto tenue (rutas, comentarios, blame)

  -- acentos
  blue = "#7aa2f7",        -- normal mode, git branch, acentos generales
  cyan = "#73daca",        -- terminal mode, git change (staged vivo)
  cyan_bright = "#7dcfff", -- archivo actual en el explorador
  green = "#9ece6a",       -- insert mode, git add
  purple = "#bb9af7",      -- visual mode
  yellow = "#e0af68",      -- command mode, git change
  red = "#f7768e",         -- replace mode, git delete, trailing whitespace
  orange = "#e0875a",      -- git changedelete

  -- git "staged" (versiones apagadas de green/yellow/red)
  green_dim = "#5d8a4f",
  yellow_dim = "#b8924a",
  red_dim = "#b35d6e",
}
