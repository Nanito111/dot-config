-- Helper para el patrón repetido "definir highlights ahora y reaplicarlos al
-- cambiar de colorscheme". Cada módulo de UI (statusline, winbar, git, etc.)
-- llama a theme.register(fn): fn se ejecuta de inmediato y queda registrada
-- para volver a ejecutarse en el autocomando ColorScheme (compartido por
-- todos los módulos, en vez de un augroup+autocmd por archivo).

local M = {}
M._callbacks = {}

local group = vim.api.nvim_create_augroup("Theme", { clear = true })
local registered = false

-- Ejecuta `fn` ahora y la deja para reaplicarse en cada ColorScheme
function M.register(fn)
  fn()
  M._callbacks[#M._callbacks + 1] = fn

  if not registered then
    registered = true
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      desc = "Reaplicar highlights de UI registrados",
      callback = function()
        -- recalcular la paleta desde el tema nuevo ANTES de reaplicar la UI
        require("config.palette").refresh()
        for _, f in ipairs(M._callbacks) do
          f()
        end
      end,
    })
  end
end

return M
