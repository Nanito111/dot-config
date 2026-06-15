local autocmd = vim.api.nvim_create_autocmd
-- augroup propio con clear: evita autocomandos duplicados al recargar la config
local group = vim.api.nvim_create_augroup("UserAutocmds", { clear = true })

-- Resaltar brevemente el texto al copiarlo (yank)
autocmd("TextYankPost", {
  group = group,
  desc = "Resaltar al hacer yank",
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Abrir el explorador como panel lateral al iniciar (el dashboard se abre en la
-- ventana principal vía su propio VimEnter). El explorador y su layout/refresco
-- se autogestionan en plugins.local.explorer.
autocmd("VimEnter", {
  group = group,
  desc = "Abrir el explorador al iniciar",
  callback = function()
    require("plugins.local.explorer").open()
    vim.cmd("wincmd p") -- devolver el foco a la ventana de edición
  end,
})
