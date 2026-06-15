-- Desactivar netrw por completo: usamos nuestro explorador propio
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("config.options")
require("config.winopts")
require("config.theme") -- registro central de highlights que reaccionan a ColorScheme
require("config.keymaps")
require("config.commands")
require("config.autocmds")
require("plugins.local.dashboard")
require("plugins.local.statusline")
require("plugins.local.workspace")
require("plugins.local.git")
require("plugins.local.winbar")
require("plugins.local.explorer")
require("config.highlights")
