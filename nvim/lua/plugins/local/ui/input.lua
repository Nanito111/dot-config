-- Prompt de una línea (plugin-free): buffer scratch sin autocompletado, semilla del valor por
-- defecto y un flotante minimal de altura 1 con título. Con `on_confirm` se auto-gestiona
-- (teclas + Tab de completado + cancelar al perder foco), reemplazando a vim.ui.input. Sin él,
-- solo construye y devuelve los handles para que picker/dirpicker enganchen su propia lógica.
local api = vim.api
local float = require("plugins.local.ui.float")

local M = {}

function M.open(opts)
  opts = opts or {}
  local prompt = (opts.prompt or "Input"):gsub("%s*:?%s*$", "")
  local default = opts.default or ""

  -- posición/tamaño: explícitos si el llamador los da (layouts apilados); si no, se calculan
  local width = opts.width
  if not width then
    width = math.min(math.max(#prompt + 4, #default + 8, 30), math.floor(vim.o.columns * 0.8))
  end
  local relative = opts.relative == "editor" and "editor" or "cursor"
  local row, col = opts.row, opts.col
  if row == nil then
    if relative == "editor" then
      row, col = math.floor(vim.o.lines * 0.35), math.floor((vim.o.columns - width) / 2)
    else
      row, col = 1, 0 -- justo debajo del cursor
    end
  end

  local fl = float.open({
    enter = true,
    relative = relative,
    width = width,
    height = 1,
    row = row,
    col = col,
    title = " " .. prompt .. " ",
    title_pos = opts.title_pos or "center",
  })
  local buf, win = fl.buf, fl.win
  vim.b[buf].completion = false -- sin autocompletado (blink) en el cuadro
  api.nvim_buf_set_lines(buf, 0, -1, false, { default })

  -- Modo build-only: el llamador engancha keymaps/cierre; devolvemos handles a secas.
  if not opts.on_confirm then
    return fl
  end

  -- Modo auto-gestionado (vim.ui.input): finish() cierra y responde una sola vez.
  local on_confirm = opts.on_confirm
  local done = false
  local function finish(value)
    if done then
      return
    end
    done = true
    fl.close() -- idempotente: cierra win+buf y hace stopinsert
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

  if opts.cancel_on_blur ~= false then
    api.nvim_create_autocmd("BufLeave", {
      buffer = buf,
      once = true,
      callback = function()
        finish(nil)
      end,
    })
  end

  vim.cmd("startinsert!") -- inserción al final del texto por defecto
  return fl
end

return M
