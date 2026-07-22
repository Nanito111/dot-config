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

-- Archivo cambiado/eliminado fuera de Neovim: por defecto, al volver a un buffer cuyo
-- archivo ya no existe, Neovim imprime "E211: File ... no longer available" en la línea
-- de comandos. Definir un FileChangedShell suprime ese mensaje y nos cede el control
-- (v:fcs_reason = por qué; v:fcs_choice = qué hacer). Para "deleted" mostramos una
-- notificación simple y conservamos el buffer; el resto de casos conservan el diálogo
-- estándar de recarga.
autocmd("FileChangedShell", {
  group = group,
  desc = "Archivo eliminado/cambiado fuera de Neovim: notificar en vez de E211",
  callback = function(args)
    local name = vim.fn.fnamemodify(args.file, ":t")
    if vim.v.fcs_reason == "deleted" then
      vim.v.fcs_choice = "" -- no hacer nada: mantener el buffer en memoria
      vim.b[args.buf].file_deleted = true -- el winbar lo pinta como [deleted]
      vim.notify(name .. " ya no existe en disco (buffer conservado)", vim.log.levels.WARN, { title = "Archivo" })
    else
      vim.v.fcs_choice = "ask" -- cambios en disco: preguntar como de costumbre
      vim.b[args.buf].file_deleted = nil -- el archivo volvió: quitar la marca
    end
  end,
})

-- Al guardar (o releer) un buffer, el archivo vuelve a existir: quitar la marca
-- [deleted] del winbar si la tenía.
autocmd({ "BufWritePost", "BufReadPost" }, {
  group = group,
  desc = "Limpiar la marca [deleted] al recrear/releer el archivo",
  callback = function(args)
    vim.b[args.buf].file_deleted = nil
  end,
})

-- Abrir el sidebar al iniciar (el dashboard se abre en la
-- ventana principal vía su propio VimEnter)
autocmd("VimEnter", {
  group = group,
  desc = "Arrancar el sidebar al iniciar",
  callback = function()
    require("plugins.local.sidebar").open()
    vim.cmd("wincmd p") -- devolver el foco a la ventana de edición
    require("plugins.local.sidebar").refresh() -- arrancar minimizado (el foco ya está fuera)
  end,
})
