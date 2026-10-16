-- Menú contextual (click derecho / PopUp) enriquecido, plugin-free. Reemplaza el PopUp por
-- defecto de Neovim por uno organizado: edición común arriba y submenús para las acciones de
-- la config (LSP, buscar/reemplazar en archivo y workspace, git, diagnósticos, pickers).
-- El mouse está activo en normal/visual/insert, así que cada entrada se define para todos
-- esos modos: si no, al abrir el menú en un modo sin mapeo da "E335: Menu not defined for…".
local M = {}

-- Define una entrada del menú. `modes` es el prefijo de modo ("a"/"n"/"v"/"i"), `pri` la
-- prioridad punteada por nivel (controla el orden), `path` el nombre con el '.' como
-- separador (los espacios se escapan solos) y `rhs` la acción.
local function item(modes, pri, path, rhs)
  local name = path:gsub(" ", "\\ ")
  pcall(vim.cmd, string.format("%snoremenu %s %s %s", modes, pri, name, rhs))
end

local function sep(pri, path)
  item("a", pri, path, "<Nop>")
  item("i", pri, path, "<Nop>")
end

-- Acción basada en <Cmd> (se comporta igual en cualquier modo): se define para normal/
-- visual/select/op-pending y para inserción (saliendo a normal antes de ejecutar).
local function act(pri, path, rhs)
  item("a", pri, path, rhs)
  item("i", pri, path, "<C-\\><C-N>" .. rhs)
end

local LUA = "<Cmd>lua "

function M.setup()
  vim.o.mousemodel = "popup_setpos" -- click derecho: posiciona el cursor y abre el PopUp
  pcall(vim.cmd, "silent! aunmenu PopUp") -- partir del menú por defecto limpio
  -- Los defaults de Neovim traen un autocomando MenuPopup que habilita/deshabilita las
  -- entradas por su nombre en inglés; al renombrarlas falla (E329). Como este menú es
  -- estático, se desactiva ese grupo.
  pcall(vim.api.nvim_clear_autocmds, { group = "nvim.popupmenu" })

  -- ── Edición común ──────────────────────────────────────────────
  -- En normal/insert operan sobre la línea; en visual sobre la selección.
  item("n", "500.10", "PopUp.Copy", '"+yy')
  item("v", "500.10", "PopUp.Copy", '"+y')
  item("i", "500.10", "PopUp.Copy", '<C-\\><C-O>"+yy')
  item("n", "500.20", "PopUp.Cut", '"+dd')
  item("v", "500.20", "PopUp.Cut", '"+x')
  item("i", "500.20", "PopUp.Cut", '<C-\\><C-O>"+dd')
  item("n", "500.30", "PopUp.Paste", '"+gP')
  item("v", "500.30", "PopUp.Paste", '"+P')
  item("i", "500.30", "PopUp.Paste", "<C-R>+")
  item("n", "500.40", "PopUp.Select all", "ggVG")
  item("v", "500.40", "PopUp.Select all", "ggVG")
  item("i", "500.40", "PopUp.Select all", "<C-\\><C-N>ggVG")
  sep("500.45", "PopUp.-sep1-")

  -- ── Código (LSP) ───────────────────────────────────────────────
  act("500.50.10", "PopUp.Code.Go to definition", LUA .. "vim.lsp.buf.definition()<CR>")
  act("500.50.20", "PopUp.Code.References", LUA .. "vim.lsp.buf.references()<CR>")
  act("500.50.30", "PopUp.Code.Documentation", LUA .. "vim.lsp.buf.hover()<CR>")
  act("500.50.40", "PopUp.Code.Rename", LUA .. "require('plugins.local.lsprename').rename()<CR>")
  act("500.50.50", "PopUp.Code.Code action", LUA .. "vim.lsp.buf.code_action()<CR>")
  act("500.50.60", "PopUp.Code.Format", LUA .. "require('config.format').format()<CR>")

  -- ── Buscar / Reemplazar ────────────────────────────────────────
  act(
    "500.60.10",
    "PopUp.Search.Replace (file)",
    LUA .. "require('plugins.local.replace').open(vim.fn.expand('<cword>'))<CR>"
  )
  act(
    "500.60.20",
    "PopUp.Search.Replace (workspace)",
    LUA .. "require('plugins.local.wreplace').open(vim.fn.expand('<cword>'))<CR>"
  )
  sep("500.60.30", "PopUp.Search.-sep-")
  act("500.60.40", "PopUp.Search.Files", "<Cmd>Files<CR>")
  act("500.60.50", "PopUp.Search.In files (grep)", "<Cmd>Grep<CR>")
  act("500.60.60", "PopUp.Search.Buffers", "<Cmd>Buffers<CR>")

  -- ── Git ────────────────────────────────────────────────────────
  act("500.70.10", "PopUp.Git.Line blame", "<Cmd>GitBlame<CR>")
  act("500.70.20", "PopUp.Git.Next change", LUA .. "require('plugins.local.git').next_hunk()<CR>")
  act("500.70.30", "PopUp.Git.Previous change", LUA .. "require('plugins.local.git').prev_hunk()<CR>")

  -- ── Diagnósticos ───────────────────────────────────────────────
  act("500.80.10", "PopUp.Diagnostics.Show (float)", LUA .. "vim.diagnostic.open_float()<CR>")
  act("500.80.20", "PopUp.Diagnostics.All (quickfix)", LUA .. "vim.diagnostic.setqflist()<CR>")

  sep("500.90", "PopUp.-sep2-")
  act("500.91", "PopUp.Open in browser", LUA .. "pcall(vim.ui.open, vim.fn.expand('<cfile>'))<CR>")
  act("500.92", "PopUp.Inspect", "<Cmd>Inspect<CR>")

  -- El submenú "Código" (acciones LSP) solo sirve con un servidor LSP: sus entradas se
  -- habilitan o deshabilitan (gris) al abrir el menú según el buffer bajo el cursor.
  -- Se actúa sobre las hojas (deshabilitar el submenú padre no se refleja en el popup).
  local COD = {
    "PopUp.Code.Go\\ to\\ definition",
    "PopUp.Code.References",
    "PopUp.Code.Documentation",
    "PopUp.Code.Rename",
    "PopUp.Code.Code\\ action",
    "PopUp.Code.Format",
  }
  local grp = vim.api.nvim_create_augroup("ContextMenu", { clear = true })
  vim.api.nvim_create_autocmd("MenuPopup", {
    group = grp,
    desc = "Enable code actions only with LSP",
    callback = function()
      local action = next(vim.lsp.get_clients({ bufnr = 0 })) ~= nil and "enable" or "disable"
      for _, path in ipairs(COD) do
        pcall(vim.cmd, "silent! amenu " .. action .. " " .. path)
      end
    end,
  })
end

M.setup()
return M
