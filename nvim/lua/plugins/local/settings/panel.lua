-- Configuración como VISTA del sidebar (plugins.local.sidebar): se registra aquí y comparte
-- la ventana lateral con el explorador (alternables con <Tab>). Este módulo registra la vista
-- y expone el punto de entrada (:Settings, <leader>uu).
local sidebar = require("plugins.local.sidebar")
local M = {}

sidebar.register({
  id = "settings",
  order = 2,
  icon = "\u{f013}", --
  title = "CONFIGURACIÓN",
  filetype = "settings",
  create = function()
    return require("plugins.local.settings.view").create()
  end,
  attach = function(win, buf)
    require("plugins.local.settings.view").attach(win, buf)
  end,
})

function M.open()
  sidebar.open("settings")
end

vim.api.nvim_create_user_command("Settings", M.open, { desc = "Panel de configuración (sidebar)" })

return M
