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
