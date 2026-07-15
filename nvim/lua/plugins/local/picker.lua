local api = vim.api
local M = {}

local ns = api.nvim_create_namespace("picker")
local ns_prev = api.nvim_create_namespace("picker_preview")
local ns_disp = api.nvim_create_namespace("picker_display") -- highlights del listado (iconos)
local MAX = 300 -- máximo de resultados mostrados

-- ── Iconos en el listado (opción activable) ────────────────────────
-- Un picker muestra iconos solo si (1) declara cómo obtener la ruta de cada item
-- (opts.icon_path) —"iconos disponibles"— y (2) esta opción está activada.
M.icons_enabled = require("config.settings").value("ui.picker_icons", true)

-- Fija el estado (sin notificar): lo usa el panel de configuración
function M.set_icons(v)
  M.icons_enabled = v
  require("config.settings").record("ui.picker_icons", v)
end

-- Alterna la opción, la persiste y avisa
function M.toggle_icons()
  M.set_icons(not M.icons_enabled)
  vim.notify(
    "Iconos en el picker " .. (M.icons_enabled and "activados" or "desactivados"),
    vim.log.levels.INFO,
    { title = "Picker" }
  )
end

-- Grupo de resaltado para un color de icono (cacheado por color, estilo devicons)
local icon_groups = {}
local function icon_group(col)
  local name = icon_groups[col]
  if not name then
    name = "PickerIcon_" .. col:gsub("#", "")
    pcall(api.nvim_set_hl, 0, name, { fg = col })
    icon_groups[col] = name
  end
  return name
end

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
  if s.close_backdrop then
    s.close_backdrop() -- cerrar la capa oscura antes que las ventanas
  end
  if s.preview_win then
    pcall(api.nvim_win_close, s.preview_win, true)
    pcall(api.nvim_buf_delete, s.preview_buf, { force = true })
  end
  if s.preview_timer then
    pcall(function()
      s.preview_timer:stop()
      s.preview_timer:close()
    end)
  end
  if s.origin and api.nvim_win_is_valid(s.origin) then
    api.nvim_set_current_win(s.origin)
  end
  vim.cmd("stopinsert") -- salir del insert mode que dejó el prompt
  if not s.confirmed and s.on_cancel then
    s.on_cancel() -- se cerró sin elegir (Esc / foco fuera): deshacer el preview
  end
end

-- ── Preview (carga acotada + asíncrona) ────────────────────────────
-- Para no congelar el picker con archivos grandes, el preview:
--   • lee SOLO hasta el match + contexto (no el archivo entero),
--   • lee de disco en un SUBPROCESO (sed, async) -> no bloquea la UI,
--   • aplica sintaxis solo si el contenido es chico (evita el freeze de treesitter),
--   • usa debounce + guard de secuencia: navegar rápido no dispara una carga por móvil.
local PREVIEW_CONTEXT = 100 -- líneas tras el match a leer (para centrarlo)
local PREVIEW_MAX = 10000 -- tope de líneas leídas (protección con archivos enormes)

-- ¿sigue vigente esta carga? (mismo picker y misma secuencia)
local function preview_current(s, seq)
  return state == s and s.preview_seq == seq and s.preview_win and api.nvim_win_is_valid(s.preview_win)
end

-- Salta a la línea/columna en el preview y la resalta, centrada. Con `hl`
-- ({ end_lnum, end_col, group? }; 1-based, end_col exclusiva) marca solo ese rango en vez
-- de la línea entera; si el rango es vacío o inválido, cae de vuelta a la línea.
local function preview_jump(s, seq, lnum, col, hl)
  if not preview_current(s, seq) then
    return
  end
  local n = math.max(api.nvim_buf_line_count(s.preview_buf), 1)
  lnum = math.min(math.max(lnum or 1, 1), n)
  pcall(api.nvim_win_set_cursor, s.preview_win, { lnum, math.max((col or 1) - 1, 0) })
  pcall(api.nvim_win_call, s.preview_win, function()
    vim.cmd("normal! zz")
  end)
  api.nvim_buf_clear_namespace(s.preview_buf, ns_prev, 0, -1)

  if hl then
    local el = math.min(math.max(hl.end_lnum or lnum, lnum), n)
    local sc = math.max((col or 1) - 1, 0)
    local ec = math.max((hl.end_col or 1) - 1, 0)
    -- acotar a la longitud real de las líneas (el rango del LSP puede desbordarlas)
    local function len(l)
      return #(api.nvim_buf_get_lines(s.preview_buf, l - 1, l, false)[1] or "")
    end
    sc = math.min(sc, len(lnum))
    ec = math.min(ec, len(el))
    if el > lnum or ec > sc then
      local ok = pcall(api.nvim_buf_set_extmark, s.preview_buf, ns_prev, lnum - 1, sc, {
        end_row = el - 1,
        end_col = ec,
        hl_group = hl.group or "Visual",
      })
      if ok then
        return
      end
    end
  end

  api.nvim_buf_set_extmark(s.preview_buf, ns_prev, lnum - 1, 0, { line_hl_group = "Visual", hl_eol = true })
end

-- Muestra un placeholder "Cargando…" mientras llega el contenido async. Solo se nota
-- si la lectura tarda (archivos grandes); en los chicos se reemplaza casi al instante.
local function preview_loading(s, seq)
  if not preview_current(s, seq) then
    return
  end
  vim.bo[s.preview_buf].modifiable = true
  api.nvim_buf_set_lines(s.preview_buf, 0, -1, false, { "", "   Cargando…" })
  vim.bo[s.preview_buf].modifiable = false
  pcall(function()
    vim.bo[s.preview_buf].filetype = ""
  end)
  api.nvim_buf_clear_namespace(s.preview_buf, ns_prev, 0, -1)
  api.nvim_buf_set_extmark(s.preview_buf, ns_prev, 1, 0, { line_hl_group = "Comment" })
end

-- Vuelca las líneas en el buffer de preview (usa la utilidad compartida, que aplica el
-- filetype solo si el contenido es chico para no congelar con archivos grandes)
local function preview_set(s, seq, path, lines)
  if not preview_current(s, seq) then
    return false
  end
  require("plugins.local.preview").load(s.preview_buf, lines, { path = path, win = s.preview_win })
  s.preview_loaded = { path = path, count = #lines }
  return true
end

-- Carga real del preview del elemento actual (llamada desde el debounce)
local function do_preview(s, seq)
  if not preview_current(s, seq) then
    return
  end
  local item = s.count > 0 and s.shown[s.idx] or nil
  local info = item and s.preview_fn(item)

  -- Contenido PERSONALIZADO ya calculado por el consumidor ({ lines, filetype?, cursor?,
  -- extmarks? }): se vuelca tal cual, con sus propios highlights (p. ej. el resultado de
  -- un rename con el diff resaltado). No usa lectura de disco ni caché.
  if info and info.lines then
    require("plugins.local.preview").load(s.preview_buf, info.lines, {
      filetype = info.filetype,
      win = s.preview_win,
    })
    s.preview_loaded = nil
    api.nvim_buf_clear_namespace(s.preview_buf, ns_prev, 0, -1)
    for _, m in ipairs(info.extmarks or {}) do
      pcall(api.nvim_buf_set_extmark, s.preview_buf, ns_prev, m[1], m[2], m[3] or {})
    end
    if info.cursor then
      local nn = math.max(api.nvim_buf_line_count(s.preview_buf), 1)
      local l = math.min(math.max(info.cursor[1] or 1, 1), nn)
      pcall(api.nvim_win_set_cursor, s.preview_win, { l, math.max((info.cursor[2] or 1) - 1, 0) })
      pcall(api.nvim_win_call, s.preview_win, function()
        vim.cmd("normal! zz")
      end)
    end
    return
  end

  if not (info and info.path) then
    preview_set(s, seq, nil, {}) -- sin resultado: limpiar
    return
  end
  local path, lnum, col, hl = info.path, info.lnum or 1, info.col or 1, info.hl

  -- ya cargado ese archivo y la línea cae dentro -> solo saltar (sin recargar)
  if s.preview_loaded and s.preview_loaded.path == path and lnum <= s.preview_loaded.count then
    preview_jump(s, seq, lnum, col, hl)
    return
  end

  local last = math.min(lnum + PREVIEW_CONTEXT, PREVIEW_MAX)

  -- si el archivo ya está abierto en un buffer: leer del buffer (rápido, en memoria)
  local b = vim.fn.bufnr(path)
  if b > 0 and api.nvim_buf_is_loaded(b) then
    local lines = api.nvim_buf_get_lines(b, 0, last, false)
    if preview_set(s, seq, path, lines) then
      preview_jump(s, seq, lnum, col, hl)
    end
    return
  end

  -- de disco: leer SOLO [1, last] en un subproceso (sed), sin bloquear la UI
  if vim.fn.executable("sed") == 1 then
    preview_loading(s, seq) -- placeholder mientras llega (se nota solo si tarda)
    vim.system({ "sed", "-n", "1," .. last .. "p", path }, { text = true }, function(res)
      vim.schedule(function()
        if not preview_current(s, seq) then
          return
        end
        local lines = vim.split(res.stdout or "", "\n", { plain = true })
        if lines[#lines] == "" then
          lines[#lines] = nil -- quitar el salto final
        end
        if preview_set(s, seq, path, lines) then
          preview_jump(s, seq, lnum, col, hl)
        end
      end)
    end)
  else
    -- sin sed: lectura acotada (síncrona, pero limitada a `last` líneas)
    local ok, lines = pcall(vim.fn.readfile, path, "", last)
    if ok and preview_set(s, seq, path, lines or {}) then
      preview_jump(s, seq, lnum, col, hl)
    end
  end
end

-- Punto de entrada con debounce: agenda la carga y descarta las anteriores (secuencia).
local function update_preview()
  local s = state
  if not (s and s.preview_win and s.preview_fn) then
    return
  end
  s.preview_seq = (s.preview_seq or 0) + 1
  local seq = s.preview_seq
  if not s.preview_timer then
    s.preview_timer = (vim.uv or vim.loop).new_timer()
  end
  s.preview_timer:stop()
  s.preview_timer:start(
    30,
    0,
    vim.schedule_wrap(function()
      do_preview(s, seq)
    end)
  )
end

-- Resalta la línea seleccionada y la mantiene visible
local function highlight()
  local s = state
  api.nvim_buf_clear_namespace(s.res_buf, ns, 0, -1)
  if s.count == 0 then
    update_preview()
    return
  end
  api.nvim_buf_set_extmark(s.res_buf, ns, s.idx - 1, 0, {
    line_hl_group = "Visual",
    hl_eol = true,
  })
  pcall(api.nvim_win_set_cursor, s.res_win, { s.idx, 0 })
  update_preview() -- panel de preview (si está activo)
  if s.on_move then
    s.on_move(s.shown[s.idx]) -- callback de preview en vivo (statusline, etc.)
  end
end

-- Vuelca una lista de resultados en la ventana. `s.display(item)` transforma el texto
-- mostrado (p. ej. añadir icono) sin afectar el filtrado/selección (que usan el item
-- crudo). `s.display_hl(item)` devuelve highlights por línea (p. ej. color del icono).
local function set_results(lines)
  local s = state
  if not s then
    return
  end
  local n = math.min(#lines, MAX)
  local display = {}
  for i = 1, n do
    display[i] = s.display and s.display(lines[i]) or lines[i]
  end
  s.shown = lines
  s.count = n

  vim.bo[s.res_buf].modifiable = true
  api.nvim_buf_set_lines(s.res_buf, 0, -1, false, display)
  vim.bo[s.res_buf].modifiable = false

  -- highlights del listado (iconos coloreados, etc.)
  api.nvim_buf_clear_namespace(s.res_buf, ns_disp, 0, -1)
  if s.display_hl then
    for i = 1, n do
      for _, h in ipairs(s.display_hl(lines[i]) or {}) do
        pcall(api.nvim_buf_set_extmark, s.res_buf, ns_disp, i - 1, h.col or 0, {
          end_col = h.end_col,
          hl_group = h.group,
        })
      end
    end
  end

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
    -- Modo estático: coincidencia fuzzy (matchfuzzy) o exacta (substring, sin importar
    -- mayúsculas), según s.fuzzy.
    local res
    if query == "" then
      res = s.items
    elseif s.fuzzy then
      res = vim.fn.matchfuzzy(s.items, query)
    else
      res = {}
      local q = query:lower()
      for _, item in ipairs(s.items) do
        if item:lower():find(q, 1, true) then
          res[#res + 1] = item
        end
      end
    end
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

-- Crea las ventanas flotantes. Con `input`, un prompt arriba (búsqueda) y los resultados
-- debajo; sin `input`, no hay prompt y la lista lleva el título. Con `preview`, la lista
-- ocupa la izquierda y se añade un panel de preview a la derecha.
local function create_windows(title, preview, input, footer)
  local width = math.min(preview and 140 or 100, math.floor(vim.o.columns * (preview and 0.9 or 0.8)))
  local height = math.min(preview and 26 or 20, math.max(5, math.floor(vim.o.lines * (preview and 0.6 or 0.5))))
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.max(0, math.floor((vim.o.lines - height - 3) / 2))
  local res_row = input and (row + 3) or row -- sin prompt, la lista empieza arriba

  local prompt_buf, prompt_win
  if input then
    prompt_buf = api.nvim_create_buf(false, true)
    vim.b[prompt_buf].completion = false -- sin autocompletado (blink) en el prompt
    prompt_win = api.nvim_open_win(prompt_buf, true, {
      relative = "editor",
      width = width,
      height = 1,
      row = row,
      col = col,
      style = "minimal",
      title = " " .. title .. " ",
      title_pos = "center",
    })
  end

  local res_w = preview and math.floor(width * 0.4) or width
  local res_buf = api.nvim_create_buf(false, true)
  local res_win = api.nvim_open_win(res_buf, not input, {
    relative = "editor",
    width = res_w,
    height = height,
    row = res_row,
    col = col,
    style = "minimal",
    title = (not input) and (" " .. title .. " ") or nil, -- el título va aquí si no hay prompt
    title_pos = (not input) and "center" or nil,
    footer = footer and (" " .. footer .. " ") or nil, -- pista de teclas opcional
    footer_pos = footer and "center" or nil,
  })
  if not input then
    vim.wo[res_win].cursorline = false -- el resaltado lo da el extmark de la selección
  end

  local preview_buf, preview_win
  if preview then
    preview_buf = api.nvim_create_buf(false, true)
    preview_win = api.nvim_open_win(preview_buf, false, {
      relative = "editor",
      width = width - res_w - 2, -- el resto, a la derecha (el -2 son los bordes)
      height = height,
      row = res_row,
      col = col + res_w + 2,
      style = "minimal",
    })
    vim.wo[preview_win].number = true
    vim.wo[preview_win].cursorline = false
    vim.wo[preview_win].wrap = false
  end

  return prompt_buf, prompt_win, res_buf, res_win, preview_buf, preview_win
end

-- Picker genérico y componible: todas las features son opcionales, activables por opts.
-- opts = {
--   title,
--   items | source,        -- lista estática (fuzzy) o fuente live async
--   on_select(item, origin),
--   on_move(item)?,         -- al cambiar el resaltado (para preview en vivo externo)
--   on_cancel()?,           -- al cerrar sin elegir (para deshacer el preview)
--   preview(item)?,         -- panel de preview. Devuelve:
--                           --   { path, lnum, col?, hl? }               -> lee el archivo
--                           --     hl = { end_lnum, end_col, group? }: resalta solo ese
--                           --     rango (1-based, end_col exclusiva) en vez de la línea
--                           --   { lines, filetype?, cursor?, extmarks? } -> contenido custom
--   icon_path(item)?,       -- ruta del item para el icono (activa iconos si M.icons_enabled)
--   display(item)?,         -- texto mostrado del item (el filtrado/selección usan el crudo)
--   display_hl(item)?,      -- highlights de esa línea: { { group, col, end_col }, ... }
--   input = true?,          -- false = sin input de búsqueda: solo el selector navegable
--   fuzzy = true?,          -- true = coincidencia fuzzy; false = exacta (substring)
--   footer?,                -- texto de pie (pista de teclas) en la ventana de la lista
--   keymaps = { [lhs] = fn(ctx) }?, -- teclas extra; ctx = { item(), index(), count(),
--                           --   list_win/buf, preview_win/buf, move(d), confirm(), close() }
--   backdrop = false?,      -- true = oscurece el editor detrás (modal). No usar en pickers
--                           --   que previsualizan el aspecto del editor (tema/statusline).
-- }
function M.pick(opts)
  if state then
    close()
  end

  -- Iconos: si el picker sabe la ruta de cada item (icon_path) y la opción está activa,
  -- se añade el icono al MOSTRAR (el filtrado/selección siguen con el item crudo).
  local display, display_hl = opts.display, opts.display_hl
  if not display and opts.icon_path and M.icons_enabled then
    local ic = require("config.icons")
    display = function(item)
      local p = opts.icon_path(item)
      return p and (ic.icon(p) .. "  " .. item) or item
    end
    display_hl = function(item)
      local p = opts.icon_path(item)
      local col = p and ic.color(p)
      if col then
        return { { group = icon_group(col), col = 0, end_col = #ic.icon(p) } }
      end
    end
  end

  local input = opts.input ~= false -- mostrar el input de búsqueda (false = solo selector)
  local fuzzy = opts.fuzzy ~= false -- coincidencia fuzzy; si false, exacta (substring)

  local origin = api.nvim_get_current_win()
  local prompt_buf, prompt_win, res_buf, res_win, preview_buf, preview_win =
    create_windows(opts.title, opts.preview ~= nil, input, opts.footer)

  -- backdrop opcional: oscurece el editor detrás del picker (por debajo de sus ventanas)
  local close_backdrop = opts.backdrop and require("plugins.local.backdrop").open() or nil

  state = {
    display = display,
    display_hl = display_hl,
    close_backdrop = close_backdrop,
    input = input,
    fuzzy = fuzzy,
    prompt_buf = prompt_buf,
    prompt_win = prompt_win,
    res_buf = res_buf,
    res_win = res_win,
    preview_buf = preview_buf,
    preview_win = preview_win,
    preview_fn = opts.preview,
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

  -- teclas de navegación/confirmación/cierre (compartidas por ambos modos)
  local function nav(kmap)
    kmap("<CR>", confirm)
    kmap("<C-n>", function() move(1) end)
    kmap("<C-p>", function() move(-1) end)
    kmap("<Down>", function() move(1) end)
    kmap("<Up>", function() move(-1) end)
    kmap("<Esc>", close)
    kmap("<C-c>", close)
  end

  if input then
    -- Con input: prompt con foco, filtrado al teclear (fuzzy o exacto según s.fuzzy)
    api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
      buffer = prompt_buf,
      callback = refilter,
    })
    api.nvim_create_autocmd("BufLeave", { buffer = prompt_buf, once = true, callback = close })
    nav(function(lhs, fn)
      vim.keymap.set({ "i", "n" }, lhs, fn, { buffer = prompt_buf, nowait = true, silent = true })
    end)
    refilter()
    vim.cmd("startinsert")
  else
    -- Modo lista: sin prompt; se navega la lista en modo normal (j/k además de C-n/C-p)
    api.nvim_create_autocmd("BufLeave", { buffer = res_buf, once = true, callback = close })
    nav(function(lhs, fn)
      vim.keymap.set("n", lhs, fn, { buffer = res_buf, nowait = true, silent = true })
    end)
    vim.keymap.set("n", "j", function() move(1) end, { buffer = res_buf, nowait = true, silent = true })
    vim.keymap.set("n", "k", function() move(-1) end, { buffer = res_buf, nowait = true, silent = true })
    vim.keymap.set("n", "q", close, { buffer = res_buf, nowait = true, silent = true })
    set_results(opts.items or {}) -- volcar la lista tal cual (sin filtrar)
    pcall(api.nvim_set_current_win, res_win)
  end

  -- Keymaps PERSONALIZADOS (opt-in): reciben un `ctx` con el estado y acciones del picker.
  -- Se aplican después de los por defecto, así pueden sobrescribirlos (p. ej. un diálogo
  -- de rename que use <C-n>/<C-p> para saltar entre cambios en vez de mover items).
  if opts.keymaps then
    local ctx = {
      item = function() return state and state.count > 0 and state.shown[state.idx] or nil end,
      index = function() return state and state.idx or 0 end,
      count = function() return state and state.count or 0 end,
      list_win = res_win,
      list_buf = res_buf,
      preview_win = preview_win,
      preview_buf = preview_buf,
      move = function(d) if state then move(d) end end,
      confirm = function() if state then confirm() end end,
      close = close,
    }
    local target = input and prompt_buf or res_buf
    local modes = input and { "i", "n" } or { "n" }
    for lhs, fn in pairs(opts.keymaps) do
      vim.keymap.set(modes, lhs, function() fn(ctx) end, { buffer = target, nowait = true, silent = true })
    end
  end
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
    backdrop = true,
    icon_path = function(f)
      return f -- el item ya es la ruta
    end,
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
    backdrop = true,
    icon_path = function(item)
      local b = map[item]
      local name = b and api.nvim_buf_get_name(b)
      return (name and name ~= "") and name or nil
    end,
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
-- Se usa `rg --json` (y no --vimgrep) porque trae los offsets de inicio Y FIN de cada
-- coincidencia: con eso el preview resalta el match exacto, no la línea entera.
function M.grep()
  if vim.fn.executable("rg") == 0 then
    vim.notify("ripgrep (rg) no está en el PATH", vim.log.levels.ERROR)
    return
  end
  -- item mostrado -> posición del match. Se acumula (no se reinicia por consulta) para que
  -- una respuesta lenta y ya descartada no borre las posiciones de la lista visible.
  local meta = {}
  pick({
    title = "Contenido (cwd)",
    backdrop = true,
    icon_path = function(item)
      return item:match("^(.-):%d+:%d+:") -- ruta del formato vimgrep
    end,
    source = function(query, cb)
      if query == "" then
        cb({})
        return
      end
      vim.system({ "rg", "--json", "--smart-case", "--path-separator", "/", query }, { text = true }, function(res)
        local lines, seen = {}, {}
        for line in (res.stdout or ""):gmatch("[^\r\n]+") do
          local ok, ev = pcall(vim.json.decode, line)
          if ok and type(ev) == "table" and ev.type == "match" then
            local d = ev.data
            local path = d.path and d.path.text
            local text = (d.lines and d.lines.text or ""):gsub("[\r\n]+$", "")
            for _, sm in ipairs(d.submatches or {}) do
              -- offsets de rg: bytes 0-based dentro de la línea, `end` exclusivo
              if path and sm.start then
                local col = sm.start + 1
                local item = string.format("%s:%d:%d:%s", path, d.line_number, col, text)
                if not seen[item] then
                  seen[item] = true
                  lines[#lines + 1] = item
                  meta[item] = { path = path, lnum = d.line_number, col = col, end_col = sm["end"] + 1 }
                end
              end
            end
          end
        end
        cb(lines)
      end)
    end,
    preview = function(item)
      local it = meta[item]
      if it then
        return {
          path = vim.fn.fnamemodify(it.path, ":p"),
          lnum = it.lnum,
          col = it.col,
          hl = { end_lnum = it.lnum, end_col = it.end_col, group = "Search" },
        }
      end
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
    backdrop = true,
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
