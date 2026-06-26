-- Utilidades para los ftplugin (config por tipo de archivo). Todo lo que tocan es
-- LOCAL al buffer/ventana, así que no se filtra a otros archivos.
local M = {}

-- Fija la indentación del buffer actual.
--   sw      -> ancho de indentación (shiftwidth/tabstop/softtabstop)
--   expand  -> usar espacios (true, por defecto) o tabuladores reales (false)
function M.indent(sw, expand)
  expand = expand ~= false
  vim.bo.expandtab = expand
  vim.bo.shiftwidth = sw
  vim.bo.tabstop = sw
  vim.bo.softtabstop = expand and sw or 0
end

return M
