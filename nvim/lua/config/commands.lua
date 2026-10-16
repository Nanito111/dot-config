local usr_cmd = vim.api.nvim_create_user_command

-- Nota sobre blink.cmp y :ReloadConfig:
-- blink mantiene MUCHO estado interno (contexto de completado, worker rust async,
-- fuentes, keymaps buffer-local y autocmds sin augroup en varios eventos). Recargarlo
-- en caliente lo deja inconsistente: la petición async se queda colgada ("loading"
-- pegado) y los comandos de navegación operan sobre una instancia distinta a la del
-- menú visible. Por eso NO lo recargamos: se deja intacto (está en SKIP_RELOAD, así que
-- ni la recarga de lazy ni este comando lo tocan) y sigue funcionando como al arrancar.
-- Para aplicar cambios en la config de blink -> reiniciar Neovim.

usr_cmd("ReloadConfig", function(o)
  local uv = vim.uv or vim.loop
  local t0 = uv.hrtime()

  -- 1. limpiar el caché de los módulos propios (config.* y plugins.*, incluidos los
  --    specs de lazy) para que se vuelvan a ejecutar con los cambios; los módulos de
  --    Neovim y de los plugins se conservan.
  for name, _ in pairs(package.loaded) do
    if name:match("^config") or name:match("^plugins") then
      package.loaded[name] = nil
    end
  end

  -- 2. re-ejecutar init.lua. Si algo falla (p. ej. un error de sintaxis recién
  --    introducido), avisar con el error y NO seguir (evita dejar todo a medias).
  local ok, err = pcall(dofile, vim.env.MYVIMRC)
  if not ok then
    vim.notify("Error reloading:\n" .. tostring(err), vim.log.levels.ERROR, { title = "ReloadConfig" })
    return
  end

  -- 3. recargar los plugins para reaplicar su config/opts (keymaps de blink, settings
  --    del LSP, etc.). Con :ReloadConfig! se omite este paso (solo config, más rápido).
  --    lazy.setup es no-op tras el arranque, así que re-parseamos los specs a mano y
  --    recargamos los plugins que estaban activos.
  local reloaded = 0
  if not o.bang then
    -- Plugins que NO se deben recargar en caliente (su deactivate de lazy no limpia
    -- bien y quedan en estado inconsistente):
    --   lazy.nvim       -> es el propio gestor, no puede desactivarse a sí mismo
    --   nvim-lspconfig  -> al desactivarlo lazy hace require('lspconfig'), que dispara
    --                      su framework deprecado y suelta errores.
    --   blink.cmp       -> aplica keymaps buffer-local; al recargarlo quedan apuntando
    --                      a la instancia vieja y <C-n>/<C-p> se comportan mal.
    --   colorschemes    -> solo proveen :colorscheme y el tema se re-aplica al final; al
    --                      desactivarlos lazy hace require de su módulo principal (que en
    --                      algunos no existe, p. ej. alabaster/melange) y suelta errores.
    -- Para cambios en estos, reinicia Neovim (o :LspRestart para el LSP).
    local SKIP_RELOAD = {
      ["lazy.nvim"] = true,
      ["nvim-lspconfig"] = true,
      ["blink.cmp"] = true,
    }
    -- todos los temas declarados en specs/themes.lua (nombre lazy = name o basename del repo)
    local ok_th, theme_specs = pcall(require, "plugins.specs.themes")
    if ok_th then
      for _, spec in ipairs(theme_specs) do
        SKIP_RELOAD[spec.name or spec[1]:match("[^/]+$")] = true
      end
    end
    local okc, Config = pcall(require, "lazy.core.config")
    if okc then
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
        if pcall(loader.reload, name) then
          reloaded = reloaded + 1
        end
        pcall(require("lazy").load, { plugins = { name } })
      end

      -- Recargar plugins puede reaplicar el colorscheme (hi clear) y borrar nuestros
      -- highlights locales (cursor, git, statusline, floats, tabline...). Reaplicamos
      -- el tema para dispararlos de nuevo y restaurarlos.
      pcall(function()
        require("config.themes").setup()
      end)
    end
    -- blink.cmp NO se recarga a propósito (ver nota arriba): se deja intacto para que
    -- el completado siga funcionando tras :ReloadConfig. Cambios en su config -> reiniciar.
  end

  local ms = math.floor((uv.hrtime() - t0) / 1e6)
  local msg = o.bang and string.format("Config reloaded (config only) · %d ms", ms)
    or string.format("Config reloaded · %d plugins · %d ms", reloaded, ms)
  vim.notify(msg, vim.log.levels.INFO, { title = "ReloadConfig", ephemeral = true })
end, {
  bang = true,
  desc = "Reload config (with ! config only, no plugins)",
})

-- Terminales flotantes
local floatterm = require("plugins.local.floatterm")

usr_cmd("Claude", function()
  floatterm.toggle("Claude 󰚩", { "claude" })
end, { desc = "Open Claude in a floating window" })

usr_cmd("Lazygit", function()
  floatterm.toggle("LazyGit 󰊢", { "lazygit" })
end, { desc = "Open lazygit in a floating window" })

-- Pickers (ripgrep + matchfuzzy)
usr_cmd("Files", function()
  require("plugins.local.picker").files()
end, { desc = "Find files (fuzzy)" })

usr_cmd("Buffers", function()
  require("plugins.local.picker").buffers()
end, { desc = "Select buffer (fuzzy)" })

usr_cmd("Grep", function()
  require("plugins.local.picker").grep()
end, { desc = "Search content in cwd (live grep)" })

usr_cmd("Terminals", function()
  require("plugins.local.picker").terminals()
end, { desc = "Workspace terminals (except claude/lazygit)" })

usr_cmd("PickerIcons", function()
  require("plugins.local.picker").toggle_icons()
end, { desc = "Toggle file icons in pickers" })

usr_cmd("TermNew", function(o)
  require("config.terminal").new(o.args)
end, { nargs = "?", desc = "New terminal (optional name)" })

usr_cmd("TermRename", function(o)
  require("config.terminal").rename(o.args)
end, { nargs = 1, desc = "Rename current terminal" })

-- Workspaces (tabs con su propio cwd y nombre)
usr_cmd("Workspace", function(o)
  require("plugins.local.workspace").new(o.args)
end, { nargs = "?", complete = "dir", desc = "New workspace (tab with own cwd)" })

usr_cmd("WorkspaceRename", function(o)
  require("plugins.local.workspace").rename(o.args)
end, { nargs = 1, desc = "Rename current workspace" })

usr_cmd("Workspaces", function()
  require("plugins.local.workspace").pick()
end, { desc = "List workspaces (picker)" })

-- Cerrar buffer respetando el workspace (misma lógica que <leader>x): al cerrar el
-- actual se muestra otro del MISMO workspace, no uno global de otra tab. Con argumento
-- (nº o nombre de buffer) se delega al :bdelete nativo; sin argumento cierra el actual.
usr_cmd("Bdelete", function(o)
  if o.args ~= "" then
    vim.cmd("bdelete" .. (o.bang and "!" or "") .. " " .. o.args)
  else
    require("config.bufclose").close({ force = o.bang })
  end
end, { bang = true, nargs = "?", complete = "buffer", desc = "Close buffer respecting the workspace" })

-- Redirigir :bd / :bdelete a :Bdelete, pero SOLO cuando son el comando en sí (no
-- cuando "bd" aparece como argumento de otro comando). Conserva bang y argumentos.
local function bd_abbrev(lhs)
  vim.cmd(
    string.format("cnoreabbrev <expr> %s (getcmdtype() ==# ':' && getcmdline() ==# %q) ? 'Bdelete' : %q", lhs, lhs, lhs)
  )
end
bd_abbrev("bd")
bd_abbrev("bdelete")

-- Barrer manualmente los buffers [No Name] vacíos huérfanos
usr_cmd("WipeNoName", function()
  require("config.util").wipe_orphan_buffers()
end, { desc = "Delete orphan empty [No Name] buffers" })

-- Git blame de la línea actual (popup)
usr_cmd("GitBlame", function()
  require("plugins.local.git").blame()
end, { desc = "Git blame current line (popup)" })

-- Resaltar espacios al final (toggle)
usr_cmd("TrailingSpaces", function()
  require("plugins.local.trailing").toggle()
end, { desc = "Toggle trailing whitespace highlight" })

-- Quitar los espacios al final del buffer actual
usr_cmd("TrailingTrim", function()
  require("plugins.local.trailing").trim()
end, { desc = "Trim trailing whitespace in current buffer" })

-- Info de los linters del buffer (como :LspInfo pero para nvim-lint)
usr_cmd("LintInfo", function()
  require("config.lintinfo").show()
end, { desc = "Buffer linters: command, availability and status" })
