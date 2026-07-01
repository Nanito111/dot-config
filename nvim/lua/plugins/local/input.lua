-- Input flotante (plugin-free): reemplaza vim.ui.input por un popup en el centro,
-- con Enter=confirmar, Esc/Ctrl+C=cancelar y Tab=completar (si hay 'completion').
-- Lo usan el crear/renombrar del explorador, el rename del LSP, etc.
local api = vim.api
local M = {}

function M.input(opts, on_confirm)
  opts = opts or {}
  on_confirm = on_confirm or function() end
  local prompt = (opts.prompt or "Input"):gsub("%s*:?%s*$", "")
  local default = opts.default or ""

  local width = math.max(#prompt + 4, #default + 8, 30)
  width = math.min(width, math.floor(vim.o.columns * 0.8))

  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  vim.b[buf].completion = false -- sin autocompletado (blink) en el cuadro

  -- Posición: por defecto junto al cursor (bueno para inputs contextuales: explorer,
  -- rename del LSP...). Con opts.relative == "editor" se centra (para inputs no ligados
  -- al cursor: nombre de terminal/workspace, donde near-cursor queda incómodo).
  local win_cfg = {
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = " " .. prompt .. " ",
    title_pos = "center",
  }
  if opts.relative == "editor" then
    win_cfg.relative = "editor"
    win_cfg.row = math.floor(vim.o.lines * 0.35)
    win_cfg.col = math.floor((vim.o.columns - width) / 2)
  else
    win_cfg.relative = "cursor"
    win_cfg.row = 1 -- justo debajo del cursor
    win_cfg.col = 0
  end
  local win = api.nvim_open_win(buf, true, win_cfg)

  local done = false
  local function finish(value)
    if done then
      return
    end
    done = true
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    vim.cmd("stopinsert")
    on_confirm(value)
  end

  local function map(mode, lhs, fn)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  map({ "i", "n" }, "<CR>", function()
    finish(api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
  end)
  map({ "i", "n" }, "<Esc>", function()
    finish(nil)
  end)
  map("i", "<C-c>", function()
    finish(nil)
  end)

  -- Tab: completa al prefijo común más largo (rutas u otros tipos de 'completion')
  if opts.completion then
    map("i", "<Tab>", function()
      local line = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      local matches = vim.fn.getcompletion(line, opts.completion)
      if #matches == 0 then
        return
      end
      local common = matches[1]
      for _, m in ipairs(matches) do
        while #common > 0 and m:sub(1, #common) ~= common do
          common = common:sub(1, #common - 1)
        end
      end
      local pick = (#common > #line) and common or (#matches == 1 and matches[1]) or line
      api.nvim_buf_set_lines(buf, 0, 1, false, { pick })
      api.nvim_win_set_cursor(win, { 1, #pick })
    end)
  end

  -- cancelar si el cuadro pierde el foco
  api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      finish(nil)
    end,
  })

  vim.cmd("startinsert!") -- inserción al final del texto por defecto
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
