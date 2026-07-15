-- Entrada al panel de configuración. La configuración vive como una VISTA del sidebar
-- (settings.view), junto al explorador y alternable con <Tab>. Este módulo solo expone
-- el punto de entrada (:Settings, <leader>uu) que abre el sidebar en esa vista.
local M = {}

function M.open()
  require("plugins.local.explorer").open_settings()
end

vim.api.nvim_create_user_command("Settings", M.open, { desc = "Panel de configuración (sidebar)" })

return M
