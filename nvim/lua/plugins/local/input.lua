-- Diálogos flotantes (plugin-free): reemplazan vim.ui.input y vim.ui.select por popups.
-- El prompt de una línea vive en ui.input; aquí solo se adapta la firma (opts, on_confirm).
-- Lo usan el crear/renombrar del explorador, el rename del LSP, etc.
local M = {}

-- Posición por defecto junto al cursor (inputs contextuales: explorer, rename del LSP...).
-- Con opts.relative == "editor" se centra (inputs no ligados al cursor: terminal/workspace).
function M.input(opts, on_confirm)
  opts = opts or {}
  require("plugins.local.ui").input.open({
    prompt = opts.prompt,
    default = opts.default,
    relative = opts.relative,
    completion = opts.completion,
    on_confirm = on_confirm or function() end,
  })
end

-- ── Selector flotante (vim.ui.select) ─────────────────────────────
-- Reemplaza el menú numerado de la cmdline por el picker (con fuzzy). Lo usan las
-- acciones de código del LSP y cualquier vim.ui.select.
function M.select(items, opts, on_choice)
  opts = opts or {}
  on_choice = on_choice or function() end
  local format = opts.format_item or tostring

  local display, map = {}, {}
  for i, item in ipairs(items) do
    local s = format(item)
    while map[s] do -- desambiguar duplicados con espacios (invisibles en la lista)
      s = s .. " "
    end
    display[i] = s
    map[s] = { item = item, idx = i }
  end

  local answered = false
  local function answer(item, idx)
    if answered then
      return
    end
    answered = true
    on_choice(item, idx)
  end

  require("plugins.local.picker").pick({
    title = (opts.prompt or "Seleccionar"):gsub("%s*:?%s*$", ""),
    items = display,
    on_select = function(s)
      local e = map[s]
      answer(e and e.item or nil, e and e.idx or nil)
    end,
    on_cancel = function()
      answer(nil, nil)
    end,
  })
end

-- Reemplaza los diálogos por defecto (línea de comandos) por popups
vim.ui.input = M.input
vim.ui.select = M.select

return M
