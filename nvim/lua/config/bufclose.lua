-- Cierre de buffer respetando el workspace: al cerrar el buffer actual, la ventana
-- pasa a mostrar OTRO buffer del mismo workspace (tab), no uno global de otro. Si el
-- workspace se queda sin archivos, muestra el dashboard. Lo usan <leader>x y :Bdelete.
local api = vim.api
local M = {}

-- Cierra el buffer actual. opts.force = saltar la confirmación de cambios sin guardar
-- (equivale al ! de :bd). Los terminales se fuerzan siempre (su job bloquea el borrado).
function M.close(opts)
  opts = opts or {}
  local cur = api.nvim_get_current_buf()
  local force = opts.force or vim.bo[cur].buftype == "terminal"

  -- Buffer modificado: confirmar antes de descartar los cambios
  if not force and vim.bo[cur].modified then
    local ans = require("plugins.local.confirm").confirm(
      "El buffer tiene cambios sin guardar. ¿Cerrar de todos modos?",
      "&Si\n&No",
      2
    )
    if ans ~= 1 then
      return
    end
    force = true
  end

  -- Elegir el siguiente buffer del MISMO workspace (no saltar a otro): tomamos la
  -- lista de la tab y saltamos al vecino del actual.
  local ws = require("plugins.local.workspace").tab_buffers()
  local alt, idx
  for i, b in ipairs(ws) do
    if b == cur then
      idx = i
      break
    end
  end
  if idx then
    alt = ws[idx - 1] or ws[idx + 1] -- vecino en el mismo workspace
  else
    alt = ws[1] -- el actual no es archivo del workspace (p. ej. terminal): el primero
  end

  if alt then
    api.nvim_set_current_buf(alt)
  else
    require("plugins.local.dashboard").open() -- no quedan buffers del workspace: inicio
  end

  pcall(api.nvim_buf_delete, cur, { force = force })
end

return M
