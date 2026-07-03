local opt = vim.opt
local glob = vim.g

local is_windows = vim.fn.has("win32") == 1

-- Opciones del explorador
glob.explorer_colored_icons = false -- iconos a color (estilo devicons) en el árbol

-- El ftplugin de SQL de Neovim crea mapeos buffer-local <C-c>... (autocompletado)
-- que sombrean nuestro <C-c> = Esc en inserción. Los desactivamos.
glob.omni_sql_no_default_maps = 1

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
opt.hlsearch = true    -- resaltar coincidencias de búsqueda
opt.incsearch = true

-- UI
opt.signcolumn = "yes"  -- siempre mostrar la columna de signos (para LSP, git)
opt.cursorline = true   -- resaltar línea actual
opt.showmode = false    -- no mostrar "-- INSERT --"/"-- TERMINAL --": ya está en la statusline
opt.scrolloff = 8       -- margen vertical al hacer scroll
opt.wrap = false        -- no romper líneas largas
opt.timeout = true
opt.timeoutlen = 300    -- espera entre teclas de una secuencia (y retardo del which-key)

-- No mostrar la pantalla de intro de Neovim ("NVIM v… type :help"): es lo que se ve
-- como "Neovim por defecto" mientras el terminal pinta antes de aparecer el dashboard.
opt.shortmess:append("I")

-- Mostrar caracteres invisibles (espacios al final, tabs, etc.)
opt.list = true
opt.listchars = { trail = "·", tab = "→ ", nbsp = "␣", extends = "›", precedes = "‹" }

-- Ocultar los ~ de las líneas vacías bajo el final del buffer
opt.fillchars:append({ eob = " " })

-- Sistema
opt.undofile = true     -- historial de undo persistente entre sesiones
opt.swapfile = false
opt.backup = false
opt.updatetime = 250    -- respuesta más rápida (para LSP)
opt.clipboard = "unnamedplus"  -- integración con el portapapeles del sistema
opt.termguicolors = true

-- Shell según el sistema operativo (usado por las terminales)
if is_windows then
  -- forzar forward slashes (la opción 'shellslash' solo existe en Windows)
  opt.shellslash = true

  -- Windows PowerShell como shell, configurado correctamente (UTF-8, exit code)
  opt.shell = "powershell"
  opt.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command "
    .. "[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
  opt.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  opt.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  opt.shellquote = ""
  opt.shellxquote = ""
else
  -- Linux/Unix: bash y utilidades POSIX
  opt.shell = "bash"
end
