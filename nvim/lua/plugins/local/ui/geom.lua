-- Geometría de flotantes: cálculos de posición reutilizables.
local M = {}

-- Posición centrada en el editor para un flotante de width×height. `row_off` resta filas al
-- alto usado para el centrado vertical (p. ej. dejar hueco para un prompt encima).
function M.center(width, height, opts)
  opts = opts or {}
  return {
    row = math.max(0, math.floor((vim.o.lines - height - (opts.row_off or 0)) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  }
end

return M
