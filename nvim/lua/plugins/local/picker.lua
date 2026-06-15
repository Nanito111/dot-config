local api = vim.api
local M = {}

local ns = api.nvim_create_namespace("picker")
local MAX = 300 -- máximo de resultados mostrados

-- state: { prompt_buf, prompt_win, res_buf, res_win, origin,
--          items, source, on_select, shown, idx, count, seq }
local state = nil

-- Cierra el picker y vuelve a la ventana de origen
local function close()
  if not state then
    return
  end
  local s = state
  state = nil
  pcall(api.nvim_win_close, s.prompt_win, true)
  pcall(api.nvim_win_close, s.res_win, true)
  pcall(api.nvim_buf_delete, s.prompt_buf, { force = true })
  pcall(api.nvim_buf_delete, s.res_buf, { force = true })
  if s.origin and api.nvim_win_is_valid(s.origin) then
    api.nvim_set_current_win(s.origin)
  end
  vim.cmd("stopinsert") -- salir del insert mode que dejó el prompt
  if not s.confirmed and s.on_cancel then
    s.on_cancel() -- se cerró sin elegir (Esc / foco fuera): deshacer el preview
  end
end

-- Resalta la línea seleccionada y la mantiene visible
local function highlight()
  local s = state
  api.nvim_buf_clear_namespace(s.res_buf, ns, 0, -1)
  if s.count == 0 then
    return
  end
  api.nvim_buf_set_extmark(s.res_buf, ns, s.idx - 1, 0, {
    line_hl_group = "Visual",
    hl_eol = true,
  })
  pcall(api.nvim_win_set_cursor, s.res_win, { s.idx, 0 })
  if s.on_move then
    s.on_move(s.shown[s.idx]) -- preview en vivo del elemento resaltado
  end
end

-- Vuelca una lista de resultados en la ventana
local function set_results(lines)
  local s = state
  if not s then
    return
  end
  local display = {}
  for i = 1, math.min(#lines, MAX) do
    display[i] = lines[i]
  end
  s.shown = lines
  s.count = #display

  vim.bo[s.res_buf].modifiable = true
  api.nvim_buf_set_lines(s.res_buf, 0, -1, false, display)
  vim.bo[s.res_buf].modifiable = false

  s.idx = 1
  highlight()
end

-- Re-filtra según el texto del prompt (fuzzy estático o fuente live async)
local function refilter()
  local s = state
  if not s then
    return
  end
  local query = api.nvim_buf_get_lines(s.prompt_buf, 0, 1, false)[1] or ""

  if s.source then
    -- Modo live: la fuente decide los resultados (async)
    s.seq = s.seq + 1
    local myseq = s.seq
    s.source(query, function(lines)
      vim.schedule(function()
        if state == s and s.seq == myseq then
          set_results(lines)
        end
      end)
    end)
  else
    -- Modo estático: filtrado fuzzy con matchfuzzy
    local res = (query == "") and s.items or vim.fn.matchfuzzy(s.items, query)
    set_results(res)
  end
end

-- Mueve la selección (con wrap-around)
local function move(delta)
  local s = state
  if s.count == 0 then
    return
  end
  s.idx = ((s.idx - 1 + delta) % s.count) + 1
  highlight()
end

-- Confirma la selección actual
local function confirm()
  local s = state
  s.confirmed = true -- para que close() no dispare on_cancel
  local item = s.shown and s.shown[s.idx]
  local on_select = s.on_select
  local origin = s.origin
  close()
  if item and on_select then
    on_select(item, origin)
  end
end

-- Crea las dos ventanas flotantes (prompt arriba, resultados abajo)
local function create_windows(title)
  local width = math.min(100, math.floor(vim.o.columns * 0.8))
  local height = math.min(20, math.max(5, math.floor(vim.o.lines * 0.5)))
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.max(0, math.floor((vim.o.lines - height - 3) / 2))

  local prompt_buf = api.nvim_create_buf(false, true)
  local prompt_win = api.nvim_open_win(prompt_buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  local res_buf = api.nvim_create_buf(false, true)
  local res_win = api.nvim_open_win(res_buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row + 3, -- 1 línea de prompt + 2 de borde
    col = col,
    style = "minimal",
    border = "rounded",
  })

  return prompt_buf, prompt_win, res_buf, res_win
end

-- Picker genérico.
-- opts = {
--   title,
--   items | source,        -- lista estática (fuzzy) o fuente live async
--   on_select(item, origin),
--   on_move(item)?,         -- al cambiar el resaltado (para preview en vivo)
--   on_cancel()?,           -- al cerrar sin elegir (para deshacer el preview)
-- }
function M.pick(opts)
  if state then
    close()
  end

  local origin = api.nvim_get_current_win()
  local prompt_buf, prompt_win, res_buf, res_win = create_windows(opts.title)

  state = {
    prompt_buf = prompt_buf,
    prompt_win = prompt_win,
    res_buf = res_buf,
    res_win = res_win,
    origin = origin,
    items = opts.items,
    source = opts.source,
    on_select = opts.on_select,
    on_move = opts.on_move,
    on_cancel = opts.on_cancel,
    shown = opts.items or {},
    idx = 1,
    count = 0,
    seq = 0,
  }

  api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = prompt_buf,
    callback = refilter,
  })
  api.nvim_create_autocmd("BufLeave", {
    buffer = prompt_buf,
    once = true,
    callback = close,
  })

  local function kmap(lhs, fn)
    vim.keymap.set({ "i", "n" }, lhs, fn, { buffer = prompt_buf, nowait = true, silent = true })
  end
  kmap("<CR>", confirm)
  kmap("<C-n>", function() move(1) end)
  kmap("<C-p>", function() move(-1) end)
  kmap("<Down>", function() move(1) end)
  kmap("<Up>", function() move(-1) end)
  kmap("<Esc>", close)
  kmap("<C-c>", close)

  refilter()
  vim.cmd("startinsert")
end

local pick = M.pick -- alias para los buscadores de abajo

-- Enfoca una ventana normal (evita netrw y terminales)
local function goto_normal_win(origin)
  local win = origin
  if not (win and api.nvim_win_is_valid(win))
    or vim.bo[api.nvim_win_get_buf(win)].filetype == "netrw" then
    win = nil
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      local b = api.nvim_win_get_buf(w)
      if vim.bo[b].filetype ~= "netrw" and vim.bo[b].filetype ~= "explorer" and vim.bo[b].buftype ~= "terminal" then
        win = w
        break
      end
    end
  end
  if win then
    api.nvim_set_current_win(win)
  end
end

-- ── Buscador de archivos (rg --files) ──────────────────────────────
function M.files()
  if vim.fn.executable("rg") == 0 then
    vim.notify("ripgrep (rg) no está en el PATH", vim.log.levels.ERROR)
    return
  end
  local files = vim.fn.systemlist({ "rg", "--files", "--path-separator", "/" })
  if vim.v.shell_error ~= 0 then
    vim.notify("rg --files falló", vim.log.levels.ERROR)
    return
  end
  pick({
    title = "Archivos",
    items = files,
    on_select = function(file, origin)
      goto_normal_win(origin)
      vim.cmd("edit " .. vim.fn.fnameescape(file))
    end,
  })
end

-- ── Selector de buffers ────────────────────────────────────────────
function M.buffers()
  local items, map = {}, {}
  -- solo los buffers del workspace (tab) actual
  for _, b in ipairs(require("plugins.local.workspace").tab_buffers()) do
    local name = api.nvim_buf_get_name(b)
    local disp = (name ~= "") and vim.fn.fnamemodify(name, ":.") or ("[No Name] " .. b)
    items[#items + 1] = disp
    map[disp] = b
  end
  if #items == 0 then
    vim.notify("No hay buffers en este workspace", vim.log.levels.INFO)
    return
  end
  pick({
    title = "Buffers",
    items = items,
    on_select = function(item, origin)
      local b = map[item]
      if b and api.nvim_buf_is_valid(b) then
        goto_normal_win(origin)
        api.nvim_set_current_buf(b)
      end
    end,
  })
end

-- ── Búsqueda de contenido en el cwd (live grep con rg) ──────────────
function M.grep()
  if vim.fn.executable("rg") == 0 then
    vim.notify("ripgrep (rg) no está en el PATH", vim.log.levels.ERROR)
    return
  end
  pick({
    title = "Contenido (cwd)",
    source = function(query, cb)
      if query == "" then
        cb({})
        return
      end
      vim.system(
        { "rg", "--vimgrep", "--smart-case", "--path-separator", "/", query },
        { text = true },
        function(res)
          local lines = {}
          for line in (res.stdout or ""):gmatch("[^\r\n]+") do
            lines[#lines + 1] = line
          end
          cb(lines)
        end
      )
    end,
    on_select = function(item, origin)
      -- formato vimgrep: archivo:línea:columna:texto
      local file, lnum, col = item:match("^(.-):(%d+):(%d+):")
      if not file then
        return
      end
      goto_normal_win(origin)
      vim.cmd("edit " .. vim.fn.fnameescape(file))
      pcall(api.nvim_win_set_cursor, 0, { tonumber(lnum), tonumber(col) - 1 })
    end,
  })
end

-- ── Terminales del workspace (excepto claude/lazygit) ──────────────
function M.terminals()
  local terms = require("plugins.local.workspace").tab_terminals()
  if #terms == 0 then
    vim.notify("No hay terminales en este workspace", vim.log.levels.INFO)
    return
  end

  local items, map = {}, {}
  for _, buf in ipairs(terms) do
    local label = vim.b[buf].term_name
    if not label or label == "" then
      -- sin nombre: usar el comando (term://{cwd}//{pid}:{cmd})
      local name = api.nvim_buf_get_name(buf)
      label = vim.fn.fnamemodify(name:gsub("^term://.*//%d+:", ""), ":t")
    end
    local disp = string.format("[%d] %s", buf, label)
    items[#items + 1] = disp
    map[disp] = buf
  end

  pick({
    title = "Terminales",
    items = items,
    on_select = function(item, origin)
      local buf = map[item]
      if not (buf and api.nvim_buf_is_valid(buf)) then
        return
      end
      -- mostrar el terminal en la ventana normal (no flotante)
      goto_normal_win(origin)
      api.nvim_set_current_buf(buf)
      vim.cmd("startinsert")
    end,
  })
end

return M
