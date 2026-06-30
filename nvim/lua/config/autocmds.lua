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

-- En las ventanas FLOTANTES con markdown (hover del LSP, docs), ocultar también la
-- sintaxis markdown en la línea del cursor. Neovim abre el hover con conceallevel=2
-- pero concealcursor="" (muestra el markup crudo donde está el cursor); aquí lo
-- activamos solo para esos popups, sin afectar a los archivos markdown que editas.
autocmd("FileType", {
  group = group,
  pattern = "markdown",
  desc = "Conceal en la línea del cursor dentro de popups markdown (hover LSP)",
  callback = function(args)
    for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then -- es flotante
        vim.wo[win].concealcursor = "nvic"
      end
    end
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
