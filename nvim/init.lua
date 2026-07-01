-- Desactivar netrw por completo: usamos nuestro explorador propio
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- El leader debe fijarse ANTES de cargar lazy y los plugins, para que sus mapeos
-- usen el leader correcto (también se vuelve a fijar en config.keymaps).
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

-- ── Gestor de plugins (lazy.nvim) ──────────────────────────────────
-- Solo en el PRIMER arranque. Al re-ejecutar init.lua (p. ej. :ReloadConfig) lazy
-- ya está configurado; volver a llamar lazy.setup avisa "Re-sourcing not supported"
-- (lazy marca vim.g.lazy_did_setup). La recarga de plugins la hace :ReloadConfig.
if not vim.g.lazy_did_setup then
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
    -- Checker periódico de actualizaciones: hace fetch en segundo plano cada
    -- `frequency` segundos y avisa (toast) al arrancar si hay plugins por actualizar.
    -- No descarga en cada inicio: al arrancar usa lo ya descargado (instantáneo).
    checker = { enabled = true, notify = true, frequency = 3600 },
  })
end

-- ── Configuración propia ───────────────────────────────────────────
require("config.winopts")
require("config.theme") -- registro central de highlights que reaccionan a ColorScheme
require("plugins.local.notify") -- toasts: sobrescribe vim.notify (antes del resto)
require("plugins.local.input") -- inputs flotantes: sobrescribe vim.ui.input
-- Aplicar el colorscheme LO ANTES POSIBLE (ya con theme+notify listos): así el fondo
-- del editor queda temático cuanto antes y se evita cualquier frame con colores por
-- defecto. Los módulos de UI que cargan después leen la paleta ya refrescada.
require("config.themes").setup()
require("config.keymaps")
require("config.commands")
require("config.autocmds")
require("config.updates") -- avisos de actualización (lazy + mason) al iniciar
require("config.lspkeys") -- diagnósticos + keymaps del LSP (recargables con :ReloadConfig)
require("config.treesitter") -- resaltado nativo (parsers/queries bundled de Neovim)
require("plugins.local.dashboard")
require("plugins.local.statusline")
require("plugins.local.workspace")
require("plugins.local.git")
require("plugins.local.winbar")
require("plugins.local.explorer")
require("plugins.local.cursor") -- cursor + línea del cursor coloreados según el modo
require("plugins.local.envcloak") -- ocultar valores en archivos .env
require("config.highlights")
