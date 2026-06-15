local opt = vim.opt
local glob = vim.g

local is_windows = vim.fn.has("win32") == 1

-- Opciones del explorador
glob.explorer_colored_icons = false -- iconos a color (estilo devicons) en el árbol

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
opt.scrolloff = 8       -- margen vertical al hacer scroll
opt.wrap = false        -- no romper líneas largas
opt.timeout = true
opt.timeoutlen = 300    -- espera entre teclas de una secuencia (y retardo del which-key)

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

-- Netrw (común a todos los SO)
glob.netrw_browse_split = 4
glob.netrw_liststyle = 3
glob.netrw_list_hide = ""
glob.netrw_banner = 0
glob.netrw_keepdir = 1
glob.netrw_preview = 1
glob.netrw_winsize = -45  -- ancho del panel: 30 columnas (negativo = absoluto)

-- Shell y comandos de netrw según el sistema operativo
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

  -- Operaciones locales de netrw con cmdlets de PowerShell
  glob.netrw_localcopycmd = "Copy-Item"
  glob.netrw_localcopydircmd = "Copy-Item -Recurse"
  glob.netrw_localmkdir = "New-Item -ItemType Directory"
  glob.netrw_localmovecmd = "Move-Item"
  glob.netrw_localrmdir = "Remove-Item"
else
  -- Linux/Unix: bash y utilidades POSIX
  opt.shell = "bash"

  glob.netrw_localcopycmd = "cp"
  glob.netrw_localcopydircmd = "cp -r"
  glob.netrw_localmkdir = "mkdir -p"
  glob.netrw_localmovecmd = "mv"
  glob.netrw_localrmdir = "rmdir"
end
