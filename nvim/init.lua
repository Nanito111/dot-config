-- Desactivar netrw por completo: usamos nuestro explorador propio
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- El leader debe fijarse ANTES de cargar lazy y los plugins, para que sus mapeos
-- usen el leader correcto (también se vuelve a fijar en config.keymaps).
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

-- ── Gestor de plugins (lazy.nvim) ──────────────────────────────────
-- Bootstrap: clona lazy la primera vez si no está presente.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Error al clonar lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

-- Specs de plugins: solo lua/plugins/specs/ (los módulos de lua/plugins/local/
-- NO son specs de lazy, son nuestros propios "plugins" y se cargan aparte).
require("lazy").setup({
  spec = { { import = "plugins.specs" } },
  install = { colorscheme = {} }, -- usamos nuestra paleta, no instalar tema
  change_detection = { notify = false },
  ui = { border = "rounded" },
})

-- ── Configuración propia ───────────────────────────────────────────
require("config.winopts")
require("config.theme") -- registro central de highlights que reaccionan a ColorScheme
require("plugins.local.notify") -- toasts: sobrescribe vim.notify (antes del resto)
require("config.keymaps")
require("config.commands")
require("config.autocmds")
require("config.treesitter") -- resaltado nativo (parsers/queries bundled de Neovim)
require("plugins.local.dashboard")
require("plugins.local.statusline")
require("plugins.local.workspace")
require("plugins.local.git")
require("plugins.local.winbar")
require("plugins.local.explorer")
require("config.highlights")
