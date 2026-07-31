-- Frontend de Mason como VISTA del sidebar (junto a explorer/settings, alternables con <Tab>):
-- gestiona los paquetes instalados con progreso en vivo; instalar nuevos usa el picker.
-- Este módulo registra la vista y expone el punto de entrada (:Mason, <leader>m).
local sidebar = require("plugins.local.sidebar")
local M = {}

sidebar.register({
  id = "mason",
  order = 3,
  icon = "\u{f0ad}", -- llave inglesa: herramientas
  filetype = "mason",
  create = function()
    return require("plugins.local.mason.view").create()
  end,
  attach = function(win, buf)
    require("plugins.local.mason.view").attach(win, buf)
  end,
})

function M.open()
  -- mason es lazy (cmd/dependencia): asegurar que esté cargado antes de leer su registro
  pcall(function()
    require("lazy").load({ plugins = { "mason.nvim" } })
  end)
  sidebar.open("mason")
end

-- Nuestro :Mason abre esta vista en vez de la UI oficial. mason.nvim recrea su propio :Mason
-- al cargar (lazy), así que lo reponemos cuando eso ocurra.
local function register_cmd()
  vim.api.nvim_create_user_command("Mason", M.open, { desc = "Gestor de herramientas (sidebar)" })
end
register_cmd()
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(ev)
    if ev.data == "mason.nvim" then
      vim.schedule(register_cmd)
    end
  end,
})

return M
