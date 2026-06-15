-- Integración con git (plugin-free): colores, signos en el gutter, navegación de
-- hunks y blame. La lógica vive en los submódulos:
--   signs (gutter + navegación) · blame (popup)
local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local signs = require("plugins.local.git.signs")
local blame = require("plugins.local.git.blame")

local M = {}

-- ── Colores ────────────────────────────────────────────────────────
local function set_hl()
  local hl = api.nvim_set_hl
  -- cambios sin stagear (en el árbol de trabajo): colores vivos
  hl(0, "GitSignAdd", { fg = palette.green })
  hl(0, "GitSignChange", { fg = palette.yellow })
  hl(0, "GitSignDelete", { fg = palette.red })
  hl(0, "GitSignChangedelete", { fg = palette.orange }) -- cambio que además quitó líneas
  -- cambios ya en el índice (staged): los mismos tonos pero apagados
  hl(0, "GitSignStagedAdd", { fg = palette.green_dim })
  hl(0, "GitSignStagedChange", { fg = palette.yellow_dim })
  hl(0, "GitSignStagedDelete", { fg = palette.red_dim })
  hl(0, "GitBlame", { fg = palette.comment, italic = true })
  hl(0, "GitBlameAuthor", { fg = palette.blue, bold = true })
end

theme.register(set_hl)

-- ── API pública ────────────────────────────────────────────────────
M.next_hunk = signs.next_hunk
M.prev_hunk = signs.prev_hunk
M.blame = blame.blame

return M
