-- Utilidades para los ftplugin (config por tipo de archivo). Todo lo que tocan es
-- LOCAL al buffer/ventana, así que no se filtra a otros archivos.
local M = {}

-- Fija la indentación de un buffer.
--   sw      -> ancho de indentación (shiftwidth/tabstop/softtabstop)
--   expand  -> usar espacios (true, por defecto) o tabuladores reales (false)
--   buf     -> buffer al que aplicar (por defecto el actual)
function M.indent(sw, expand, buf)
  expand = expand ~= false
  local bo = buf and vim.bo[buf] or vim.bo
  bo.expandtab = expand
  bo.shiftwidth = sw
  bo.tabstop = sw
  bo.softtabstop = expand and sw or 0
end

return M
