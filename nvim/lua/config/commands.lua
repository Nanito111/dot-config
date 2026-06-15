local usr_cmd = vim.api.nvim_create_user_command

usr_cmd("ReloadConfig", function()
  -- limpiar el caché de los módulos propios (config.* y plugins.local.*) para que
  -- dofile vuelva a ejecutarlos con los cambios; los demás (de Neovim) se conservan
  for name, _ in pairs(package.loaded) do
    if name:match("^config") or name:match("^plugins") then
      package.loaded[name] = nil
    end
  end
  dofile(vim.env.MYVIMRC)
  vim.notify("Configuración recargada")
end, { desc = "Recargar la configuración (config.* y plugins.local.*)" })

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

