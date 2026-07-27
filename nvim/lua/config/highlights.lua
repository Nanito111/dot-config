local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")

-- Igualar el fondo de las ventanas flotantes al del editor. El default de Neovim
-- pinta NormalFloat/FloatBorder más oscuros que Normal, así que las flotantes
-- (popup del which-key, blame de git…) se ven como una caja que no pega.
local function set_hl()
  local normal = api.nvim_get_hl(0, { name = "Normal", link = false })
  local bg = normal.bg -- fondo del editor (puede ser nil si es transparente)
  api.nvim_set_hl(0, "NormalFloat", { bg = bg, fg = normal.fg })
  api.nvim_set_hl(0, "FloatBorder", { bg = bg, fg = palette.comment }) -- borde tenue
  api.nvim_set_hl(0, "FloatTitle", { bg = bg, fg = palette.blue, bold = true })
  -- Separador entre ventanas: muchos temas lo pintan más oscuro que el fondo (casi
  -- invisible en temas oscuros). Lo fijamos al color de comentario para que se vea.
  api.nvim_set_hl(0, "WinSeparator", { bg = bg, fg = palette.comment })

  -- Gutter (números de línea, signos de git, plegado): algunos temas lo pintan como
  -- una banda distinta del buffer (kanagawa el número, gruvbox la columna de signos).
  -- Conservamos el color de texto de cada grupo y solo igualamos el fondo.
  -- Los signos de diagnóstico (iconos junto a los números) van en el mismo gutter: algunos
  -- temas (gruvbox) les ponen un fondo más claro que la columna, y se ven como una banda.
  -- Se conserva el color del icono (fg) y solo se iguala el fondo.
  for _, name in ipairs({
    "LineNr", "LineNrAbove", "LineNrBelow", "SignColumn", "FoldColumn",
    "DiagnosticSignError", "DiagnosticSignWarn", "DiagnosticSignInfo", "DiagnosticSignHint", "DiagnosticSignOk",
  }) do
    local h = api.nvim_get_hl(0, { name = name, link = false })
    h.bg = bg
    api.nvim_set_hl(0, name, h)
  end

  -- Línea de comandos y área de mensajes (MsgArea): con el color que el tema define
  -- para la StatusLine, para que la franja inferior sea coherente.
  api.nvim_set_hl(0, "MsgArea", { bg = palette.statusline_bg, fg = palette.statusline_fg })

  -- Completado (blink): el menú enlaza a Pmenu (color distinto); lo igualamos al
  -- fondo del editor, con la selección apenas resaltada y bordes tenues como el
  -- resto de la UI. La doc/firma ya enlazan a NormalFloat (ya fundido arriba).
  api.nvim_set_hl(0, "BlinkCmpMenu", { bg = bg, fg = normal.fg })
  api.nvim_set_hl(0, "BlinkCmpMenuBorder", { bg = bg, fg = palette.comment })
  api.nvim_set_hl(0, "BlinkCmpMenuSelection", { bg = palette.bg_highlight, bold = true })
  api.nvim_set_hl(0, "BlinkCmpDocBorder", { bg = bg, fg = palette.comment })
  api.nvim_set_hl(0, "BlinkCmpSignatureHelpBorder", { bg = bg, fg = palette.comment })
end

theme.register(set_hl)

return {}
