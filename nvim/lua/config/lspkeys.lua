-- Diagnósticos (UI) y keymaps del LSP al conectar un servidor a un buffer.
-- Vive en config.* (no en el spec de nvim-lspconfig) para que :ReloadConfig lo aplique
-- SIN reiniciar: el dofile re-ejecuta este módulo, re-registra el autocomando LspAttach
-- y reaplica los keymaps a los buffers ya conectados. Los keymaps que llaman a módulos
-- propios usan require() al invocar, así toman su versión recargada.
local api = vim.api
local M = {}

-- Handler `on_list` compartido para referencias/implementaciones/símbolos…: recibe
-- items estilo quickfix ({ filename, lnum, col, text }) y, en vez del quickfix nativo,
-- los muestra en el picker fuzzy propio (o salta directo si hay un único resultado).
local function open_locations(o)
  local items = o.items or {}
  if #items == 0 then
    vim.notify("Sin resultados", vim.log.levels.INFO, { title = "LSP" })
    return
  end
  local function jump(it, origin)
    if origin and api.nvim_win_is_valid(origin) then
      api.nvim_set_current_win(origin)
    end
    vim.cmd("edit " .. vim.fn.fnameescape(it.filename))
    pcall(api.nvim_win_set_cursor, 0, { it.lnum, (it.col or 1) - 1 })
  end
  if #items == 1 then
    jump(items[1]) -- un solo resultado: saltar sin picker
    return
  end
  local display, map = {}, {}
  for _, it in ipairs(items) do
    local rel = vim.fn.fnamemodify(it.filename, ":.")
    local text = (it.text or ""):gsub("^%s+", "")
    local d = string.format("%s:%d:%d: %s", rel, it.lnum, it.col or 1, text)
    display[#display + 1] = d
    map[d] = it
  end
  require("plugins.local.picker").pick({
    title = o.title or "LSP",
    items = display,
    backdrop = true,
    input = o.input ~= false, -- las listas de ubicaciones (referencias) van sin buscador
    footer = (o.input == false) and "j/k mover · Enter abrir · q cerrar" or nil,
    preview = function(item)
      local it = map[item]
      if it then
        return { path = it.filename, lnum = it.lnum, col = it.col }
      end
    end,
    on_select = function(item, origin)
      local it = map[item]
      if it then
        jump(it, origin)
      end
    end,
  })
end
M.open_locations = open_locations

-- ── Diagnósticos (UI configurable desde el panel; se reaplica en cada recarga) ──
require("config.diagnostics").apply()

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
    vim.lsp.buf.hover()
  end, "LSP: hover (documentación)")
  -- rename propio (confirmación + undo). require() al invocar -> recargable
  map("<leader>lr", function() require("plugins.local.lsprename").rename() end, "LSP: renombrar símbolo (con confirmación)")
  map("grn", function() require("plugins.local.lsprename").rename() end, "LSP: renombrar símbolo (con confirmación)")
  map("<leader>lu", function() require("plugins.local.lsprename").undo() end, "LSP: revertir el último rename")
  map("<leader>la", vim.lsp.buf.code_action, "LSP: acciones de código")
  map("<leader>lf", function()
    vim.lsp.buf.format({ async = true })
  end, "LSP: formatear buffer")

  -- Navegación por el picker (o salto directo si hay un único resultado)
  map("<leader>lR", function()
    vim.lsp.buf.references(nil, {
      on_list = function(o)
        o.input = false -- solo el listado navegable, sin buscador
        open_locations(o)
      end,
    })
  end, "LSP: referencias")
  map("<leader>ld", function()
    vim.lsp.buf.definition({ on_list = open_locations })
  end, "LSP: definición(es)")
  map("<leader>li", function()
    vim.lsp.buf.implementation({ on_list = open_locations })
  end, "LSP: implementaciones")
  map("<leader>lt", function()
    vim.lsp.buf.type_definition({ on_list = open_locations })
  end, "LSP: definición de tipo")
  map("<leader>ls", function()
    vim.lsp.buf.document_symbol({ on_list = open_locations })
  end, "LSP: símbolos del documento")
  map("<leader>lS", function()
    vim.ui.input({ prompt = "Símbolo del proyecto: " }, function(q)
      if q ~= nil then
        vim.lsp.buf.workspace_symbol(q, { on_list = open_locations })
      end
    end)
  end, "LSP: símbolos del proyecto")
  map("<leader>lh", function()
    vim.lsp.buf.signature_help()
  end, "LSP: ayuda de firma")
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
