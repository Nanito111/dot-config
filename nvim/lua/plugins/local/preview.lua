-- Utilidad de preview COMPARTIDA (por el picker y por el rename del LSP): vuelca
-- contenido en un buffer scratch y aplica el resaltado de sintaxis SOLO si el contenido
-- es acotado, para no congelar la UI con archivos grandes (treesitter/syntax parsean
-- todo el buffer al fijar el filetype).
local api = vim.api
local M = {}

M.HIGHLIGHT_MAX = 2000 -- por encima de esto: sin filetype (sin resaltado), para no congelar

-- Vuelca `lines` en `buf`. opts:
--   • path      -> deriva el filetype del nombre de archivo
--   • filetype  -> filetype explícito (tiene prioridad sobre path)
--   • apply(b)  -> mutaciones extra sobre el buffer tras volcar (p. ej. text edits del
--                  rename), aún modificable
-- El filetype solo se aplica si el contenido no supera HIGHLIGHT_MAX. Deja el buffer no
-- modificable al terminar.
function M.load(buf, lines, opts)
  opts = opts or {}
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if opts.apply then
    opts.apply(buf) -- p. ej. aplicar el WorkspaceEdit del rename
  end
  vim.bo[buf].modifiable = false

  local ft = ""
  if api.nvim_buf_line_count(buf) <= M.HIGHLIGHT_MAX then
    ft = opts.filetype
      or (opts.path and opts.path ~= "" and vim.filetype.match({ filename = opts.path }))
      or ""
  end
  pcall(function()
    vim.bo[buf].filetype = ft
  end)
end

return M
