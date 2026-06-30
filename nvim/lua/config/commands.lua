local usr_cmd = vim.api.nvim_create_user_command

usr_cmd("ReloadConfig", function()
  -- 1. limpiar el caché de los módulos propios (config.* y plugins.*, incluidos los
  --    specs de lazy) para que se vuelvan a ejecutar con los cambios; los módulos de
  --    Neovim y de los plugins se conservan
  for name, _ in pairs(package.loaded) do
    if name:match("^config") or name:match("^plugins") then
      package.loaded[name] = nil
    end
  end

  -- 2. re-ejecutar init.lua: opciones, keymaps, módulos propios y re-importar los
  --    specs en lazy (toma los cambios de lua/plugins/specs/*)
  dofile(vim.env.MYVIMRC)

  -- 3. recargar los plugins para reaplicar su config/opts (keymaps de blink, settings
  --    del LSP, etc.). lazy.setup es no-op tras el arranque, así que re-parseamos los
  --    specs a mano y volvemos a cargar los plugins que estaban activos.
  -- Plugins que NO se deben recargar en caliente (su deactivate de lazy falla):
  --   lazy.nvim       -> es el propio gestor, no puede desactivarse a sí mismo
  --   nvim-lspconfig  -> al desactivarlo lazy hace require('lspconfig'), que dispara
  --                      su framework deprecado y suelta errores. Para cambios de LSP,
  --                      reinicia Neovim (o :LspRestart).
  local SKIP_RELOAD = { ["lazy.nvim"] = true, ["nvim-lspconfig"] = true }

  local ok, Config = pcall(require, "lazy.core.config")
  local reloaded = 0
  if ok then
    -- nombres de los plugins cargados ANTES de re-parsear (el re-parseo resetea su estado)
    local loaded = {}
    for name, plugin in pairs(Config.plugins) do
      if plugin._ and plugin._.loaded and not SKIP_RELOAD[name] then
        loaded[#loaded + 1] = name
      end
    end

    -- re-leer lua/plugins/specs/* con los cambios (lazy.setup no lo hace dos veces)
    pcall(function()
      require("lazy.core.plugin").load()
    end)

    -- re-aplicar cada uno: reload (desactiva + reengancha) + load (re-ejecuta su config)
    local loader = require("lazy.core.loader")
    for _, name in ipairs(loaded) do
      local okr = pcall(loader.reload, name)
      pcall(require("lazy").load, { plugins = { name } })
      if okr then
        reloaded = reloaded + 1
      end
    end
  end

  vim.notify(string.format("Configuración recargada (%d plugins)", reloaded))
end, { desc = "Recargar config (config.*, plugins.local.*) y los plugins de lazy" })

-- Terminales flotantes
local floatterm = require("plugins.local.floatterm")

usr_cmd("Claude", function()
  floatterm.toggle("Claude 󰚩", { "claude" })
end, { desc = "Abrir Claude en una ventana flotante" })

usr_cmd("Lazygit", function()
  floatterm.toggle("LazyGit 󰊢", { "lazygit" })
end, { desc = "Abrir lazygit en una ventana flotante" })

-- Pickers (ripgrep + matchfuzzy)
usr_cmd("Files", function()
  require("plugins.local.picker").files()
end, { desc = "Buscar archivos (fuzzy)" })

usr_cmd("Buffers", function()
  require("plugins.local.picker").buffers()
end, { desc = "Seleccionar buffer (fuzzy)" })

usr_cmd("Grep", function()
  require("plugins.local.picker").grep()
end, { desc = "Buscar contenido en el cwd (live grep)" })

usr_cmd("Terminals", function()
  require("plugins.local.picker").terminals()
end, { desc = "Terminales del workspace (excepto claude/lazygit)" })

usr_cmd("TermNew", function(o)
  require("config.terminal").new(o.args)
end, { nargs = "?", desc = "Nueva terminal (con nombre opcional)" })

usr_cmd("TermRename", function(o)
  require("config.terminal").rename(o.args)
end, { nargs = 1, desc = "Renombrar la terminal actual" })

-- Workspaces (tabs con su propio cwd y nombre)
usr_cmd("Workspace", function(o)
  require("plugins.local.workspace").new(o.args)
end, { nargs = "?", complete = "dir", desc = "Nuevo workspace (tab con cwd propio)" })

usr_cmd("WorkspaceRename", function(o)
  require("plugins.local.workspace").rename(o.args)
end, { nargs = 1, desc = "Renombrar el workspace actual" })

-- Barrer manualmente los buffers [No Name] vacíos huérfanos
usr_cmd("WipeNoName", function()
  require("config.util").wipe_orphan_buffers()
end, { desc = "Eliminar buffers [No Name] vacíos huérfanos" })

-- Git blame de la línea actual (popup)
usr_cmd("GitBlame", function()
  require("plugins.local.git").blame()
end, { desc = "Git blame de la línea actual (popup)" })

-- Resaltar espacios al final (toggle)
usr_cmd("TrailingSpaces", function()
  require("plugins.local.trailing").toggle()
end, { desc = "Alternar resaltado de espacios al final" })

