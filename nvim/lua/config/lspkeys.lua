-- Diagnósticos (UI) y keymaps del LSP al conectar un servidor a un buffer.
-- Vive en config.* (no en el spec de nvim-lspconfig) para que :ReloadConfig lo aplique
-- SIN reiniciar: el dofile re-ejecuta este módulo, re-registra el autocomando LspAttach
-- y reaplica los keymaps a los buffers ya conectados. Los keymaps que llaman a módulos
-- propios usan require() al invocar, así toman su versión recargada.
local api = vim.api
local M = {}

-- ── Diagnósticos (global; se reaplica en cada recarga) ─────────────
vim.diagnostic.config({
  -- virtual_lines solo en la línea del cursor: mensaje completo en línea, sin llenar
  -- la pantalla. Sin virtual_text.
  virtual_lines = { current_line = true },
  virtual_text = false,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "\u{f057}",
      [vim.diagnostic.severity.WARN] = "\u{f071}",
      [vim.diagnostic.severity.INFO] = "\u{f05a}",
      [vim.diagnostic.severity.HINT] = "\u{f0eb}",
    },
  },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded", source = true },
})

-- ── Keymaps al conectar (buffer-local) ─────────────────────────────
-- Neovim 0.11+ ya trae por defecto grn (renombrar), gra (acción de código), grr
-- (referencias), gri (implementación), gO (símbolos), K (hover) y <C-s> en inserción
-- (ayuda de firma). Aquí añadimos/ajustamos el resto.
function M.on_attach(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc, silent = true })
  end
  map("gd", vim.lsp.buf.definition, "LSP: ir a definición")
  map("gD", vim.lsp.buf.declaration, "LSP: ir a declaración")
  -- K: hover con borde redondeado (a juego con el resto)
  map("K", function()
    vim.lsp.buf.hover({ border = "rounded" })
  end, "LSP: hover (documentación)")
  -- rename propio (confirmación + undo). require() al invocar -> recargable
  map("<leader>lr", function() require("plugins.local.lsprename").rename() end, "LSP: renombrar símbolo (con confirmación)")
  map("grn", function() require("plugins.local.lsprename").rename() end, "LSP: renombrar símbolo (con confirmación)")
  map("<leader>lu", function() require("plugins.local.lsprename").undo() end, "LSP: revertir el último rename")
  map("<leader>la", vim.lsp.buf.code_action, "LSP: acciones de código")
  map("<leader>lf", function()
    vim.lsp.buf.format({ async = true })
  end, "LSP: formatear buffer")
end

-- Autocomando: al conectar, aplicar keymaps. require(self) al invocar para que, tras
-- :ReloadConfig, use la versión recargada de on_attach.
api.nvim_create_autocmd("LspAttach", {
  group = api.nvim_create_augroup("LspKeys", { clear = true }),
  callback = function(args)
    require("config.lspkeys").on_attach(args.buf)
  end,
})

-- Reaplicar a los buffers YA conectados (arranque en frío no tiene ninguno; útil tras
-- :ReloadConfig, donde LspAttach no se redispara para los buffers existentes).
for _, buf in ipairs(api.nvim_list_bufs()) do
  if api.nvim_buf_is_valid(buf) and next(vim.lsp.get_clients({ bufnr = buf })) ~= nil then
    M.on_attach(buf)
  end
end

return M
