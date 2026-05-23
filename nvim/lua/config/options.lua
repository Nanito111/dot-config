local opt = vim.opt

-- Línea de números
opt.number = true
opt.relativenumber = false

-- Indentación
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Búsqueda
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true    -- no resaltar tras buscar
opt.incsearch = true

-- UI
opt.signcolumn = "yes"  -- siempre mostrar la columna de signos (para LSP, git)
opt.cursorline = true   -- resaltar línea actual
opt.scrolloff = 8       -- margen vertical al hacer scroll
opt.wrap = false        -- no romper líneas largas

-- Sistema
opt.undofile = true     -- historial de undo persistente entre sesiones
opt.swapfile = false
opt.backup = false
opt.updatetime = 250    -- respuesta más rápida (para LSP)
opt.clipboard = "unnamedplus"  -- integración con el portapapeles del sistema
opt.termguicolors = true
