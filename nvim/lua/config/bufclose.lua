-- Cierre de buffer respetando el workspace: al cerrar el buffer actual, la ventana
-- pasa a mostrar OTRO buffer del mismo workspace (tab), no uno global de otro. Si el
-- workspace se queda sin archivos, muestra el dashboard. Lo usan <leader>x y :Bdelete.
local api = vim.api
local M = {}

-- Cierra un buffer CONCRETO (no tiene por qué ser el actual; lo usa el listado de buffers).
-- Las ventanas que lo muestren pasan a un vecino del MISMO workspace, o al dashboard si no
-- queda ninguno. No pregunta nada: quien llama decide qué hacer con los cambios sin guardar.
function M.close_buf(buf, opts)
  opts = opts or {}
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  local force = opts.force or vim.bo[buf].buftype == "terminal"

  -- Elegir el siguiente buffer del MISMO workspace (no saltar a otro): tomamos la
  -- lista de la tab y saltamos al vecino del que se cierra.
  local ws = require("plugins.local.workspace").tab_buffers()
  local alt, idx
  for i, b in ipairs(ws) do
    if b == buf then
      idx = i
      break
    end
  end
  if idx then
    alt = ws[idx - 1] or ws[idx + 1] -- vecino en el mismo workspace
  else
    alt = ws[1] -- no es archivo del workspace (p. ej. terminal): el primero
  end
  if alt == buf then
    alt = nil
  end

  -- reponer el contenido de TODA ventana que lo muestre (normalmente solo la principal)
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(w) and api.nvim_win_get_buf(w) == buf then
      if alt then
        api.nvim_win_set_buf(w, alt)
      else
        pcall(api.nvim_win_call, w, function()
          require("plugins.local.dashboard").open() -- sin buffers del workspace: inicio
        end)
      end
    end
  end

  pcall(api.nvim_buf_delete, buf, { force = force })
end

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

  M.close_buf(cur, { force = force })
end

return M
