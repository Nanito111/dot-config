-- Utilidad de preview COMPARTIDA (por el picker y por el rename del LSP): vuelca
-- contenido en un buffer scratch y aplica el resaltado de sintaxis SOLO si el contenido
-- es acotado, para no congelar la UI con archivos grandes (treesitter/syntax parsean
-- todo el buffer al fijar el filetype).
local api = vim.api
local M = {}

M.HIGHLIGHT_MAX = 2000 -- por encima de esto: sin filetype (sin resaltado), para no congelar

-- Opciones de VENTANA que fija el preview tras cada carga. Al aplicar el filetype se
-- ejecuta su ftplugin, que puede tocar la ventana (markdown activa spell y conceallevel);
-- como son locales a la ventana, se quedarían pegadas en los items siguientes.
local WIN_OPTS = {
  spell = false,
  wrap = false,
  linebreak = false,
  breakindent = false,
  conceallevel = 0,
  list = false,
}

-- Vuelca `lines` en `buf`. opts:
--   • path      -> deriva el filetype del nombre de archivo
--   • filetype  -> filetype explícito (tiene prioridad sobre path)
--   • win       -> ventana donde se muestra: se le reponen las opciones del preview
--   • apply(b)  -> mutaciones extra sobre el buffer tras volcar (p. ej. text edits del
--                  rename), aún modificable
-- El filetype solo se aplica si el contenido no supera HIGHLIGHT_MAX. Deja el buffer no
-- modificable al terminar.
function M.load(buf, lines, opts)
  opts = opts or {}
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  -- El buffer se REUTILIZA entre items, y treesitter no suelta su highlighter al cambiar
  -- de filetype: sin esto, el parser del item anterior sigue enganchado y, además, deja
  -- el syntax clásico apagado -> los filetypes sin parser (tsx, ts…) salen sin color.
  pcall(vim.treesitter.stop, buf)

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

  if opts.win and api.nvim_win_is_valid(opts.win) then
    require("plugins.local.ui.win").set_opts(opts.win, WIN_OPTS)
  end
end

return M
