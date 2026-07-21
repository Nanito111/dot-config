-- Opciones de ventana para flotantes/paneles.
local api = vim.api
local M = {}

-- Fija opciones window-local SIN tocar el default global. Necesario porque `vim.wo[curwin]`
-- (o nvim_set_option_value sin scope) sobre una opción window-local también cambia el default
-- global, como :set — eso corrompía p. ej. `cursorline`/`number` que lee el panel de settings.
function M.set_opts(win, opts)
  for name, val in pairs(opts) do
    pcall(api.nvim_set_option_value, name, val, { win = win, scope = "local" })
  end
end

return M
