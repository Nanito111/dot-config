local map = vim.keymap.set

-- Líder: espacio
vim.g.mapleader = " "

-- which-key: al pulsar el líder, mostrar las combinaciones disponibles
map("n", "<leader>", function()
  require("plugins.local.whichkey").show()
end, { silent = true, nowait = true, desc = "which-key" })

-- which-key también para prefijos integrados (g, z, <C-w>). SIN nowait, al revés que el
-- líder: estos prefijos tienen secuencias nativas (gcc, gg, zz, <C-w>v...) y nowait haría
-- que Vim disparase este mapeo al instante, sin poder desambiguar gc de gcc — gc devuelve
-- "g@" y quedaba un operador colgado. Esperando timeoutlen, teclear rápido resuelve nativo
-- y la pausa abre el popup (que es lo que popup.read_key ya asume en el primer nivel).
for _, p in ipairs({ "g", "z", "<C-w>" }) do
  map("n", p, function()
    require("plugins.local.whichkey").show(p)
  end, { silent = true, desc = "which-key (" .. p .. ")" })
end

-- Moverse entre ventanas sin Ctrl-W
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Mover líneas en visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selection up" })

-- Indentar manteniendo la selección visual (no salir a normal)
map("v", ">", ">gv", { desc = "Indent and keep selection" })
map("v", "<", "<gv", { desc = "Unindent and keep selection" })

-- Centrar la pantalla al saltar
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up and center" })
map("n", "n", "nzzzv", { desc = "Next match and center" })
map("n", "N", "Nzzzv", { desc = "Previous match and center" })

-- Pegar sin perder el registro
map("v", "p", "P", { desc = "Paste without overwriting register" })
map("v", "P", "p", { desc = "Paste overwriting register" })

-- Buffer control
map("n", "<Tab>", function()
  require("plugins.local.workspace").cycle_buffer(1)
end, { silent = true, desc = "Next buffer (workspace)" })
map("n", "<S-Tab>", function()
  require("plugins.local.workspace").cycle_buffer(-1)
end, { silent = true, desc = "Previous buffer (workspace)" })
map("n", "<leader>x", function()
  require("config.bufclose").close()
end, { silent = true, desc = "Close buffer" })

-- Quitar highlight de busqueda
map("n", "<Esc>", ":nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

-- Sacar foco de terminal
map("t", "<C-q>", [[<C-\><C-n>]], { silent = true, desc = "Exit terminal mode" })

-- Ctrl+C en inserción = Esc de verdad (dispara InsertLeave, abreviaciones, etc.)
map("i", "<C-c>", "<Esc>", { silent = true, desc = "Exit insert mode (like Esc)" })

-- Ctrl+D en inserción = borrar el carácter a la derecha (como Supr), en vez del des-sangrado
map("i", "<C-d>", "<Del>", { silent = true, desc = "Delete character to the right" })

-- Sangrar / des-sangrar la línea en inserción (Ctrl+l / Ctrl+j). Destino: los <C-t>/<C-d>
-- nativos de inserción (noremap: el <C-d> nativo des-sangra, no el remapeado a borrar).
map("i", "<C-l>", "<C-t>", { silent = true, desc = "Indent line" })
map("i", "<C-j>", "<C-d>", { silent = true, desc = "Unindent line" })

-- Marks
map("n", "<leader>m", ":marks a-z<CR>", { silent = true, desc = "List marks a-z" })

-- Diagnósticos (grupo <leader>d*) — son de vim.diagnostic, independientes del LSP.
-- D: acceso rápido al flotante de la línea (reemplaza el D por defecto = d$).
local function diag_float()
  vim.diagnostic.open_float({ scope = "line" })
end
map("n", "D", diag_float, { silent = true, desc = "Line diagnostic (float)" })
map("n", "<leader>dd", diag_float, { silent = true, desc = "Line diagnostic (float)" })
map("n", "<leader>dq", function()
  vim.diagnostic.setloclist() -- diagnósticos del buffer en una lista
end, { silent = true, desc = "Buffer diagnostics (list)" })
map("n", "<leader>dn", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { silent = true, desc = "Next diagnostic" })
map("n", "<leader>dp", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { silent = true, desc = "Previous diagnostic" })
-- Todos los diagnósticos del proyecto (buffers cargados) en el picker fuzzy, ordenados
-- por severidad; al elegir salta al archivo/línea. Nota: solo aparecen los de archivos
-- ya abiertos/analizados por el LSP (así funcionan los diagnósticos de LSP).
local function diag_project()
  local diags = vim.diagnostic.get(nil)
  if #diags == 0 then
    vim.notify("No diagnostics in the project", vim.log.levels.INFO, { title = "Diagnostics" })
    return
  end
  table.sort(diags, function(a, b)
    if a.severity ~= b.severity then
      return a.severity < b.severity -- ERROR(1) < WARN(2) < INFO(3) < HINT(4)
    end
    if a.bufnr ~= b.bufnr then
      return a.bufnr < b.bufnr
    end
    return a.lnum < b.lnum
  end)
  -- hl: color del icono/mensaje en la lista. vt: fondo del rango marcado en el preview.
  local sev = {
    [vim.diagnostic.severity.ERROR] = {
      letter = "E",
      icon = "\u{f057}",
      hl = "DiagnosticError",
      vt = "DiagnosticVirtualTextError",
    },
    [vim.diagnostic.severity.WARN] = {
      letter = "W",
      icon = "\u{f071}",
      hl = "DiagnosticWarn",
      vt = "DiagnosticVirtualTextWarn",
    },
    [vim.diagnostic.severity.INFO] = {
      letter = "I",
      icon = "\u{f05a}",
      hl = "DiagnosticInfo",
      vt = "DiagnosticVirtualTextInfo",
    },
    [vim.diagnostic.severity.HINT] = {
      letter = "H",
      icon = "\u{f0eb}",
      hl = "DiagnosticHint",
      vt = "DiagnosticVirtualTextHint",
    },
  }
  local unknown = { letter = "?", icon = "\u{f059}", hl = "Comment", vt = "Visual" }

  -- El item CRUDO (lo que se filtra) lleva la ruta completa y la severidad; lo MOSTRADO
  -- es más corto (icono + archivo:línea + mensaje) porque la lista comparte ancho con el
  -- preview. `meta` guarda ambos, más los tramos a colorear.
  local items, meta = {}, {}
  for _, d in ipairs(diags) do
    local name = vim.api.nvim_buf_get_name(d.bufnr)
    local rel = (name ~= "") and vim.fn.fnamemodify(name, ":.") or ("buf " .. d.bufnr)
    local msg = (d.message or ""):gsub("%s*\n.*$", "") -- solo la primera línea
    local s = sev[d.severity] or unknown

    local raw = string.format("%s:%d:%d: [%s] %s", rel, d.lnum + 1, d.col + 1, s.letter, msg)
    while meta[raw] do
      raw = raw .. " " -- desempatar duplicados exactos (dos servidores, mismo aviso)
    end

    local loc = string.format("%s:%d", vim.fn.fnamemodify(rel, ":t"), d.lnum + 1)
    local a = #s.icon + 2 -- inicio de loc (icono + 2 espacios)
    local b = a + #loc + 2 -- inicio del mensaje
    items[#items + 1] = raw
    meta[raw] = {
      d = d,
      vt = s.vt,
      path = (name ~= "") and name or nil,
      text = string.format("%s  %s  %s", s.icon, loc, msg),
      hls = {
        { group = s.hl, col = 0, end_col = #s.icon },
        { group = "Comment", col = a, end_col = a + #loc },
        { group = s.hl, col = b, end_col = b + #msg },
      },
    }
  end

  require("plugins.local.picker").pick({
    title = "Project diagnostics",
    items = items,
    backdrop = true,
    display = function(item)
      return meta[item] and meta[item].text or item
    end,
    display_hl = function(item)
      return meta[item] and meta[item].hls
    end,
    preview = function(item)
      local m = meta[item]
      if m and m.path then
        return {
          path = m.path,
          lnum = m.d.lnum + 1,
          col = m.d.col + 1,
          -- rango exacto del diagnóstico (el LSP lo da 0-based, end exclusiva)
          hl = {
            end_lnum = (m.d.end_lnum or m.d.lnum) + 1,
            end_col = (m.d.end_col or m.d.col) + 1,
            group = m.vt,
          },
        }
      end
    end,
    on_select = function(item, origin)
      local d = meta[item] and meta[item].d
      if not (d and vim.api.nvim_buf_is_valid(d.bufnr)) then
        return
      end
      if origin and vim.api.nvim_win_is_valid(origin) then
        vim.api.nvim_set_current_win(origin)
      end
      vim.api.nvim_set_current_buf(d.bufnr)
      pcall(vim.api.nvim_win_set_cursor, 0, { d.lnum + 1, d.col })
    end,
  })
end
map("n", "<leader>dw", diag_project, { silent = true, desc = "Project diagnostics (picker)" })

-- Buscar y reemplazar en el archivo actual (widget flotante)
map("n", "<leader>rr", function()
  require("plugins.local.replace").open(vim.fn.expand("<cword>"))
end, { silent = true, desc = "Search and replace (current file)" })
map("x", "<leader>rr", function()
  -- la selección hay que leerla ANTES de salir del modo visual
  local sel = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })[1] or ""
  vim.cmd("normal! \27")
  vim.schedule(function()
    require("plugins.local.replace").open(sel)
  end)
end, { silent = true, desc = "Search and replace selection" })

-- Buscar y reemplazar en todo el workspace (ripgrep + preview + undo)
map("n", "<leader>rw", function()
  require("plugins.local.wreplace").open(vim.fn.expand("<cword>"))
end, { silent = true, desc = "Search and replace (workspace)" })
map("x", "<leader>rw", function()
  local sel = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })[1] or ""
  vim.cmd("normal! \27")
  vim.schedule(function()
    require("plugins.local.wreplace").open(sel)
  end)
end, { silent = true, desc = "Search and replace selection (workspace)" })
map("n", "<leader>ru", function()
  require("plugins.local.wreplace").undo()
end, { silent = true, desc = "Revert last replace (workspace)" })

-- Terminales flotantes
map({ "n", "t" }, "<M-g>", "<cmd>Lazygit<CR>", { silent = true, desc = "Lazygit (float)" })
map({ "n", "t" }, "<M-c>", "<cmd>Claude<CR>", { silent = true, desc = "Claude (float)" })

-- Git
map("n", "<leader>gb", "<cmd>GitBlame<CR>", { silent = true, desc = "Git blame line (popup)" })
map("n", "]h", function()
  require("plugins.local.git").next_hunk()
end, { silent = true, desc = "Next change (hunk)" })
map("n", "[h", function()
  require("plugins.local.git").prev_hunk()
end, { silent = true, desc = "Previous change (hunk)" })

-- Pickers
map("n", "<leader>ff", "<cmd>Files<CR>", { silent = true, desc = "Find files (fuzzy)" })
map("n", "<leader>fb", "<cmd>Buffers<CR>", { silent = true, desc = "Select buffer" })
map("n", "<leader>fw", "<cmd>Grep<CR>", { silent = true, desc = "Search content in cwd" })
map("n", "<leader>ft", "<cmd>Terminals<CR>", { silent = true, desc = "Workspace terminals" })
map("n", "<leader>fT", "<cmd>Todos<CR>", { silent = true, desc = "Search project TODOs" })
map("n", "<leader>fs", "<cmd>Workspaces<CR>", { silent = true, desc = "List workspaces" })

-- Terminales con nombre
map("n", "<leader>tn", function()
  vim.ui.input({ prompt = "Terminal name: ", relative = "editor" }, function(name)
    require("config.terminal").new(name)
  end)
end, { silent = true, desc = "New terminal (named)" })
map("n", "<leader>tr", function()
  vim.ui.input({ prompt = "New terminal name: ", relative = "editor" }, function(name)
    if name and name ~= "" then
      require("config.terminal").rename(name)
    end
  end)
end, { silent = true, desc = "Rename current terminal" })

-- Workspaces (tabs con cwd propio)
map("n", "<leader>sn", function()
  require("plugins.local.dirpicker").pick({ prompt = "Workspace folder: " }, function(dir)
    if not (dir and dir ~= "") then
      return
    end
    -- Nombre editable, precargado con el basename de la carpeta (⏎ acepta, Esc cancela)
    local base = vim.fn.fnamemodify(vim.fn.expand(dir):gsub("[\\/]$", ""), ":t")
    vim.ui.input({ prompt = "Workspace name: ", default = base, relative = "editor" }, function(name)
      if name == nil then
        return -- Esc: cancelar la creación
      end
      require("plugins.local.workspace").new(dir, name)
    end)
  end)
end, { silent = true, desc = "New workspace (folder picker)" })
map("n", "<leader>sr", function()
  vim.ui.input({ prompt = "Workspace name: ", relative = "editor" }, function(name)
    if name and name ~= "" then
      require("plugins.local.workspace").rename(name)
    end
  end)
end, { silent = true, desc = "Rename workspace" })
map("n", "<leader>sx", "<cmd>tabclose<CR>", { silent = true, desc = "Close workspace (tab)" })
map("n", "<leader>sl", function()
  require("plugins.local.workspace").cycle(1)
end, { silent = true, desc = "Next workspace" })
map("n", "<leader>sh", function()
  require("plugins.local.workspace").cycle(-1)
end, { silent = true, desc = "Previous workspace" })
map("n", "<leader>sL", function()
  require("plugins.local.workspace").move(1)
end, { silent = true, desc = "Move workspace right" })
map("n", "<leader>sH", function()
  require("plugins.local.workspace").move(-1)
end, { silent = true, desc = "Move workspace left" })
-- Ir directo al workspace N (mismo número que muestra la tabline): <leader>s1 … s9
for i = 1, 9 do
  map("n", "<leader>s" .. i, function()
    require("plugins.local.workspace").jump(i)
  end, { silent = true, desc = "Go to workspace " .. i })
end

-- Notificaciones
map("n", "<leader>nh", "<cmd>Notifications<CR>", { silent = true, desc = "Notification history" })
map("n", "<leader>nd", function()
  require("plugins.local.notify").dismiss_all()
end, { silent = true, desc = "Dismiss visible notifications" })

-- UI: pickers de la statusline (con preview en vivo)
map("n", "<leader>us", function()
  require("plugins.local.statusline").pick_preset()
end, { silent = true, desc = "Statusline preset (picker)" })
map("n", "<leader>ub", function()
  require("plugins.local.statusline").pick()
end, { silent = true, desc = "Statusline border (picker)" })
map("n", "<leader>ut", function()
  require("config.themes").pick()
end, { silent = true, desc = "Theme/colorscheme (picker with preview)" })
map("n", "<leader>uv", function()
  require("plugins.local.envcloak").toggle()
end, { silent = true, desc = "Hide/show values in .env" })
map("n", "<leader>ui", function()
  require("plugins.local.indentline").pick()
end, { silent = true, desc = "Indentation guides (picker)" })
map("n", "<leader>uw", function()
  require("config.borders").pick()
end, { silent = true, desc = "Floating window border (picker)" })
map("n", "<leader>uu", function()
  require("plugins.local.settings.panel").open()
end, { silent = true, desc = "Settings panel" })
map("n", "<leader>um", function()
  require("plugins.local.minimap").toggle()
end, { silent = true, desc = "Toggle minimap" })
map("n", "<leader>ue", function()
  require("plugins.local.trailing").toggle()
end, { silent = true, desc = "Toggle trailing whitespace highlight" })

-- Explorador: alternar el foco entre el panel y el editor (lo abre si no está)
map("n", "<leader>e", function()
  require("plugins.local.sidebar").focus()
end, { silent = true, desc = "Toggle focus sidebar/editor" })
