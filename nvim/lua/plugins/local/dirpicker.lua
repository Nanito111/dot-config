-- Selector de CARPETAS (plugin-free): un diálogo modal con un input de ruta (editable) arriba
-- y, debajo, un árbol solo de carpetas para navegar. Reutiliza el motor del explorador
-- (explorer.render en modo dirs_only). Devuelve la ruta elegida por callback.
--   ⏎  elegir la ruta del input   ·   C-n/C-p  moverse   ·   →/Tab expandir   ·   ←  colapsar
--   C-o  entrar en la carpeta (re-enraizar)   ·   C-u  subir de raíz   ·   Esc  cancelar
local api = vim.api
local render = require("plugins.local.explorer.render")
local M = {}

local function abspath(p)
  return vim.fn.fnamemodify(vim.fn.expand(p), ":p"):gsub("[\\/]$", "")
end

function M.pick(opts, on_choose)
  opts = opts or {}
  local s = { root = abspath(opts.root or vim.fn.getcwd()), expanded = {}, nodes = {}, dirs_only = true }
  local prompt = opts.prompt or "Carpeta: "
  local sel = 1 -- línea seleccionada en el árbol (1 = la raíz)

  local width = math.min(80, math.max(40, vim.o.columns - 8))
  local tree_h = math.max(6, math.min(20, vim.o.lines - 10))
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - (tree_h + 5)) / 2)

  local close_backdrop = require("plugins.local.backdrop").open()

  local tree_buf = api.nvim_create_buf(false, true)
  vim.bo[tree_buf].filetype = "dirpicker" -- NO "explorer" (evita peek/cursor-oculto del panel)
  local tree_win = api.nvim_open_win(tree_buf, false, {
    relative = "editor", width = width, height = tree_h, col = col, row = row + 3,
    style = "minimal", title = " Carpetas ", title_pos = "center",
    footer = " ⏎ elegir · C-n/C-p mover · →/Tab abrir · C-o entrar · C-u subir · Esc ",
    footer_pos = "center",
  })
  vim.wo[tree_win].cursorline = true
  vim.wo[tree_win].winhighlight = "CursorLine:ExplorerCursorLine"

  local pr = require("plugins.local.ui").input.open({
    prompt = prompt, relative = "editor", width = width, row = row, col = col, title_pos = "left",
  })
  local prompt_buf, prompt_win = pr.buf, pr.win

  s.buf, s.win = tree_buf, tree_win

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    pcall(close_backdrop)
    for _, w in ipairs({ prompt_win, tree_win }) do
      pcall(api.nvim_win_close, w, true)
    end
    for _, b in ipairs({ prompt_buf, tree_buf }) do
      pcall(api.nvim_buf_delete, b, { force = true })
    end
    vim.cmd("stopinsert")
  end

  -- Ruta de la carpeta bajo el cursor del árbol (línea 1 = raíz)
  local function candidate()
    if sel <= 1 then
      return s.root
    end
    local n = s.nodes[sel - 1]
    return n and n.path or s.root
  end

  -- Escribe la ruta candidata en el input (el usuario puede sobrescribirla escribiendo)
  local function sync_prompt()
    local path = candidate()
    vim.bo[prompt_buf].modifiable = true
    api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { path })
    pcall(api.nvim_win_set_cursor, prompt_win, { 1, #path })
  end

  local function draw()
    render.render(s)
    local n = api.nvim_buf_line_count(tree_buf)
    sel = math.max(1, math.min(sel, n))
    pcall(api.nvim_win_set_cursor, tree_win, { sel, 0 })
    sync_prompt()
  end

  local function move(delta)
    sel = math.max(1, math.min(sel + delta, #s.nodes + 1))
    pcall(api.nvim_win_set_cursor, tree_win, { sel, 0 })
    sync_prompt()
  end

  local function node_at()
    return (sel <= 1) and { path = s.root, is_dir = true } or s.nodes[sel - 1]
  end

  local function expand()
    local n = node_at()
    if n and n.is_dir and not s.expanded[n.path] then
      s.expanded[n.path] = true
      draw()
    end
  end
  local function collapse()
    local n = node_at()
    if n and n.is_dir and s.expanded[n.path] then
      s.expanded[n.path] = false
      draw()
    end
  end
  local function reroot(path)
    if vim.fn.isdirectory(path) == 1 then
      s.root, s.expanded, sel = abspath(path), {}, 1
      draw()
    else
      vim.notify("No es una carpeta: " .. path, vim.log.levels.WARN, { title = "Carpetas" })
    end
  end

  local function choose()
    local path = api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1] or ""
    path = abspath(path)
    if vim.fn.isdirectory(path) == 0 then
      vim.notify("No existe la carpeta: " .. path, vim.log.levels.WARN, { title = "Carpetas" })
      return
    end
    close()
    if on_choose then
      on_choose(path)
    end
  end

  local function map(lhs, fn)
    vim.keymap.set({ "i", "n" }, lhs, fn, { buffer = prompt_buf, nowait = true, silent = true })
  end
  map("<C-n>", function() move(1) end)
  map("<Down>", function() move(1) end)
  map("<C-p>", function() move(-1) end)
  map("<Up>", function() move(-1) end)
  map("<Right>", expand)
  map("<Tab>", expand)
  map("<Left>", collapse)
  map("<S-Tab>", collapse)
  map("<C-o>", function() reroot(candidate()) end) -- entrar en la carpeta del cursor
  map("<C-u>", function() reroot(vim.fn.fnamemodify(s.root, ":h")) end) -- subir de raíz
  map("<CR>", choose)
  map("<Esc>", close)
  map("<C-c>", close)

  api.nvim_create_autocmd("WinLeave", { buffer = prompt_buf, once = true, callback = close })

  draw()
  vim.cmd("startinsert!")
end

return M
