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
end

theme.register(set_hl)

return {}
