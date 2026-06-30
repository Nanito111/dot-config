local map = vim.keymap.set

-- Líder: espacio
vim.g.mapleader = " "

-- which-key: al pulsar el líder, mostrar las combinaciones disponibles
map("n", "<leader>", function()
  require("plugins.local.whichkey").show()
end, { silent = true, nowait = true, desc = "which-key" })

-- which-key también para prefijos integrados (g, z, <C-w>)
for _, p in ipairs({ "g", "z", "<C-w>" }) do
  map("n", p, function()
    require("plugins.local.whichkey").show(p)
  end, { silent = true, nowait = true, desc = "which-key (" .. p .. ")" })
end

-- Moverse entre ventanas sin Ctrl-W
map("n", "<C-h>", "<C-w>h", { desc = "Ir a la ventana izquierda" })
map("n", "<C-j>", "<C-w>j", { desc = "Ir a la ventana de abajo" })
map("n", "<C-k>", "<C-w>k", { desc = "Ir a la ventana de arriba" })
map("n", "<C-l>", "<C-w>l", { desc = "Ir a la ventana derecha" })

-- Mover líneas en visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Mover selección abajo" })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Mover selección arriba" })

-- Indentar manteniendo la selección visual (no salir a normal)
map("v", ">", ">gv", { desc = "Indentar y mantener selección" })
map("v", "<", "<gv", { desc = "Desindentar y mantener selección" })

-- Centrar la pantalla al saltar
map("n", "<C-d>", "<C-d>zz", { desc = "Bajar media página y centrar" })
map("n", "<C-u>", "<C-u>zz", { desc = "Subir media página y centrar" })
map("n", "n", "nzzzv", { desc = "Siguiente coincidencia y centrar" })
map("n", "N", "Nzzzv", { desc = "Coincidencia anterior y centrar" })

-- Pegar sin perder el registro
map("v", "p", 'P', { desc = "Pegar sin sobrescribir el registro" })
map("v", "P", 'p', { desc = "Pegar sobrescribiendo el registro" })

-- Buffer control
map("n", "<Tab>", function()
  require("plugins.local.workspace").cycle_buffer(1)
end, { silent = true, desc = "Buffer siguiente (del workspace)" })
map("n", "<S-Tab>", function()
  require("plugins.local.workspace").cycle_buffer(-1)
end, { silent = true, desc = "Buffer anterior (del workspace)" })
map("n", "<leader>x", function()
  local cur = vim.api.nvim_get_current_buf()

  -- Terminal: forzar (el job en ejecución bloquea el borrado normal)
  local force = vim.bo[cur].buftype == "terminal"

  -- Buffer modificado: confirmar antes de descartar los cambios
  if not force and vim.bo[cur].modified then
    local ans = vim.fn.confirm("El buffer tiene cambios sin guardar. ¿Cerrar de todos modos?", "&Si\n&No", 2)
    if ans ~= 1 then
      return
    end
    force = true
  end

  -- Mostrar otro buffer en la ventana ANTES de borrar, para no cerrarla.
  -- Buscar un buffer real (listado, normal, con nombre) distinto al actual.
  local alt
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.bufnr ~= cur and info.name ~= "" and vim.bo[info.bufnr].buftype == "" then
      alt = info.bufnr
      break
    end
  end

  if alt then
    vim.api.nvim_set_current_buf(alt)
  else
    require("plugins.local.dashboard").open() -- no quedan buffers: mostrar el inicio
  end

  -- Borrar el buffer original; la ventana ya muestra otra cosa
  pcall(vim.api.nvim_buf_delete, cur, { force = force })
end, { silent = true, desc = "Cerrar buffer" })

-- Quitar highlight de busqueda
map("n", "<Esc>", ":nohlsearch<CR>", { silent = true, desc = "Quitar resaltado de búsqueda" })

-- Sacar foco de terminal
map("t", "<C-q>", [[<C-\><C-n>]], { silent = true, desc = "Salir del modo terminal" })

-- Marks
map("n", "<leader>m", ":marks a-z<CR>", { silent = true, desc = "Listar marcas a-z" })

-- Diagnósticos (grupo <leader>d*) — son de vim.diagnostic, independientes del LSP.
-- D: acceso rápido al flotante de la línea (reemplaza el D por defecto = d$).
local function diag_float()
  vim.diagnostic.open_float({ scope = "line", border = "rounded" })
end
map("n", "D", diag_float, { silent = true, desc = "Diagnóstico de la línea (flotante)" })
map("n", "<leader>dd", diag_float, { silent = true, desc = "Diagnóstico de la línea (flotante)" })
map("n", "<leader>dq", function()
  vim.diagnostic.setloclist() -- diagnósticos del buffer en una lista
end, { silent = true, desc = "Diagnósticos del buffer (lista)" })
map("n", "<leader>dn", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { silent = true, desc = "Siguiente diagnóstico" })
map("n", "<leader>dp", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { silent = true, desc = "Diagnóstico anterior" })

-- Terminales flotantes
map({ "n", "t" }, "<M-g>", "<cmd>Lazygit<CR>", { silent = true, desc = "Lazygit (flotante)" })
map({ "n", "t" }, "<M-c>", "<cmd>Claude<CR>", { silent = true, desc = "Claude (flotante)" })

-- Git
map("n", "<leader>gb", "<cmd>GitBlame<CR>", { silent = true, desc = "Git blame de la línea (popup)" })
map("n", "]h", function()
  require("plugins.local.git").next_hunk()
end, { silent = true, desc = "Siguiente cambio (hunk)" })
map("n", "[h", function()
  require("plugins.local.git").prev_hunk()
end, { silent = true, desc = "Cambio anterior (hunk)" })

-- Pickers
map("n", "<leader>ff", "<cmd>Files<CR>", { silent = true, desc = "Buscar archivos (fuzzy)" })
map("n", "<leader>fb", "<cmd>Buffers<CR>", { silent = true, desc = "Seleccionar buffer" })
map("n", "<leader>fw", "<cmd>Grep<CR>", { silent = true, desc = "Buscar contenido en el cwd" })
map("n", "<leader>ft", "<cmd>Terminals<CR>", { silent = true, desc = "Terminales del workspace" })

-- Terminales con nombre
map("n", "<leader>tn", function()
  vim.ui.input({ prompt = "Nombre de la terminal: " }, function(name)
    require("config.terminal").new(name)
  end)
end, { silent = true, desc = "Nueva terminal (con nombre)" })
map("n", "<leader>tr", function()
  vim.ui.input({ prompt = "Nuevo nombre de la terminal: " }, function(name)
    if name and name ~= "" then
      require("config.terminal").rename(name)
    end
  end)
end, { silent = true, desc = "Renombrar terminal actual" })

-- Workspaces (tabs con cwd propio)
map("n", "<leader>sn", function()
  vim.ui.input({ prompt = "Directorio del workspace: ", default = vim.fn.getcwd(), completion = "dir" }, function(dir)
    if dir and dir ~= "" then
      require("plugins.local.workspace").new(dir)
    end
  end)
end, { silent = true, desc = "Nuevo workspace" })
map("n", "<leader>sr", function()
  vim.ui.input({ prompt = "Nombre del workspace: " }, function(name)
    if name and name ~= "" then
      require("plugins.local.workspace").rename(name)
    end
  end)
end, { silent = true, desc = "Renombrar workspace" })
map("n", "<leader>sx", "<cmd>tabclose<CR>", { silent = true, desc = "Cerrar workspace (tab)" })
map("n", "<leader>sl", "gt", { silent = true, desc = "Workspace siguiente" })
map("n", "<leader>sh", "gT", { silent = true, desc = "Workspace anterior" })

-- Notificaciones
map("n", "<leader>nh", "<cmd>Notifications<CR>", { silent = true, desc = "Historial de notificaciones" })
map("n", "<leader>nd", function()
  require("plugins.local.notify").dismiss_all()
end, { silent = true, desc = "Descartar notificaciones visibles" })

-- UI: pickers de la statusline (con preview en vivo)
map("n", "<leader>us", function()
  require("plugins.local.statusline").pick_preset()
end, { silent = true, desc = "Preset de la statusline (picker)" })
map("n", "<leader>ub", function()
  require("plugins.local.statusline").pick()
end, { silent = true, desc = "Borde de la statusline (picker)" })
map("n", "<leader>ut", function()
  require("config.themes").pick()
end, { silent = true, desc = "Tema/colorscheme (picker con preview)" })

-- Explorador: alternar el foco entre el panel y el editor (lo abre si no está)
map("n", "<leader>e", function()
  require("plugins.local.explorer").focus()
end, { silent = true, desc = "Alternar foco explorador/editor" })

