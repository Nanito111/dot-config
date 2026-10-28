-- Vista de configuración para el SIDEBAR (comparte panel con el explorador; se alterna
-- con <Tab>). Cada línea es un setting editable en vivo; solo lo distinto del default se
-- guarda (lo gestiona config.settings). El cursor se "imanta" a las líneas de opción (no
-- descansa nunca en cabeceras ni blancos), así la acción siempre recae sobre lo marcado.
local api = vim.api
local settings = require("config.settings")
local palette = require("config.palette")
local theme = require("config.theme")
local ui = require("plugins.local.ui")

local M = {}
local ns = api.nvim_create_namespace("settings_view")

local views = {} -- [buf] = { win, rows, menu } (menu = controlador de lista imantada)

local function set_hl()
  api.nvim_set_hl(0, "SettingsSection", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "SettingsLabel", { fg = palette.fg })
  api.nvim_set_hl(0, "SettingsDefault", { fg = palette.comment })
  api.nvim_set_hl(0, "SettingsChanged", { fg = palette.green, bold = true })
  api.nvim_set_hl(0, "SettingsMarker", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "SettingsSeparator", { fg = palette.comment })
  api.nvim_set_hl(0, "SettingsCursorLine", { bg = palette.bg_highlight, bold = true })
end
theme.register(set_hl)
set_hl()

-- Cheurón de la cabecera de sección (colapsable). El estado colapsado se guarda en
-- config.settings (solo lo colapsado; por defecto todo expandido) y persiste entre sesiones.
local CHEV_OPEN = "▾"
local CHEV_CLOSED = "▸"

local collapsed = nil -- cache; nil = aún no cargado
local function collapsed_tbl()
  if collapsed == nil then
    collapsed = vim.deepcopy(settings.value("panel.collapsed", {}))
  end
  return collapsed
end
local function is_collapsed(title)
  return collapsed_tbl()[title] == true
end
local function set_collapsed(title, val)
  local c = collapsed_tbl()
  c[title] = val or nil
  settings.record("panel.collapsed", c, {})
end

-- Iconos de switch (FontAwesome toggle-on/off) para los booleanos
local SWITCH_ON = "\u{f205}" --
local SWITCH_OFF = "\u{f204}" --

-- Icono por sección (nerd-font), indexado por el título del registro. Si falta, no se dibuja.
local SECTION_ICONS = {
  ["Theme & colors"] = "\u{f1fc}", --
  ["Statusline"] = "\u{f0c9}", --
  ["Interface"] = "\u{f108}", --
  ["Dashboard"] = "\u{f0e4}", --
  ["Winbar"] = "\u{f2d0}", --
  ["Sidebar"] = "\u{f0db}", --
  ["Minimap"] = "\u{f279}", --
  ["Tools by language"] = "\u{f0ad}", --
  ["Workspaces"] = "\u{f009}", --
  ["Editing"] = "\u{f044}", --
  ["Spelling"] = "\u{f02d}", --
  ["Buffer view"] = "\u{f06e}", --
  ["Search"] = "\u{f002}", --
  ["Diagnostics"] = "\u{f188}", --
}

-- Columnas libres entre el valor y el borde derecho de la ventana (las etiquetas llevan 2
-- de sangrado a la izquierda; a la derecha va algo más porque el separador de ventana
-- "come" espacio visualmente y los valores quedaban pegados).
local RIGHT_PAD = 3

-- ── Valor mostrado ─────────────────────────────────────────────────
local function value_text(spec)
  if spec.type == "action" then
    return "→" -- abre otra ventana (p. ej. la tabla de indentación)
  end
  local v = spec.get()
  if spec.type == "bool" then
    return v and SWITCH_ON or SWITCH_OFF
  elseif spec.type == "enum" then
    local s = spec.display and spec.display(v) or tostring(v)
    return s == "" and "(hidden)" or s
  end
  return tostring(v)
end

-- Items visibles de una sección según el filtro de búsqueda (query ya en minúsculas, o nil =
-- sin filtro). Si el título de la sección coincide, se muestran todos; si no, solo los items
-- cuyo label contiene el término (búsqueda literal, sin regex).
local function visible_items(section, query)
  if not query then
    return section.items
  end
  if section.title:lower():find(query, 1, true) then
    return section.items
  end
  local out = {}
  for _, spec in ipairs(section.items) do
    if spec.label:lower():find(query, 1, true) then
      out[#out + 1] = spec
    end
  end
  return out
end

local SEARCH_ICON = "\u{f002}" --

-- Contenido del panel: separador superior + secciones (filtradas si hay término). Devuelve
-- líneas, filas (spec|false por línea; false = no seleccionable), marcas de resaltado (fila 0 =
-- primera línea de contenido) y el total de coincidencias. query = término crudo o nil.
local function build_content(width, query)
  local q = (query and query ~= "") and query:lower() or nil
  local lines, rows, marks = {}, {}, {}
  local function push(text, spec)
    lines[#lines + 1] = text
    rows[#rows + 1] = spec or false
  end

  local sep = string.rep("─", math.max(width, 1))
  push(sep, nil) -- separador bajo el campo de búsqueda
  marks[#marks + 1] = { #lines - 1, 0, { end_col = #sep, hl_group = "SettingsSeparator" } }

  local total, shown = 0, 0
  for _, section in ipairs(settings.registry()) do
    local items, show
    if q then
      items = visible_items(section, q)
      total = total + #items
      show = #items > 0
    else
      items = is_collapsed(section.title) and {} or section.items
      show = true
    end
    if show then
      shown = shown + 1
      if shown > 1 then
        push(sep, nil)
        marks[#marks + 1] = { #lines - 1, 0, { end_col = #sep, hl_group = "SettingsSeparator" } }
      end
      -- con filtro activo las secciones van siempre expandidas
      local col = (not q) and is_collapsed(section.title) or false
      local chev = col and CHEV_CLOSED or CHEV_OPEN
      local icon = SECTION_ICONS[section.title]
      local header = "  " .. chev .. " "
      if icon then
        header = header .. icon .. "  "
      end
      header = header .. section.title
      local title_end = #header
      if col then
        header = header .. "  (" .. #section.items .. ")"
      end
      push(header, { header = true, title = section.title })
      marks[#marks + 1] = { #lines - 1, 0, { end_col = title_end, hl_group = "SettingsSection" } }
      if col then
        marks[#marks + 1] = { #lines - 1, title_end, { end_col = #header, hl_group = "SettingsDefault" } }
      end

      for _, spec in ipairs(items) do
        local label = "  " .. spec.label
        local marker = spec.overridden() and "● " or ""
        local val = marker .. value_text(spec)
        local pad = width - RIGHT_PAD - vim.fn.strdisplaywidth(label) - vim.fn.strdisplaywidth(val)
        if pad < 1 then
          pad = 1
        end
        local line = label .. string.rep(" ", pad) .. val
        push(line, spec)

        local row = #lines - 1
        local val_col = #label + pad
        -- color del valor: los switches se colorean por su ESTADO (verde=on, tenue=off);
        -- el resto, por si difieren del default. El `●` (cuando lo hay) marca "cambiado".
        local val_hl
        if spec.type == "bool" then
          val_hl = spec.get() and "SettingsChanged" or "SettingsDefault"
        else
          val_hl = spec.overridden() and "SettingsChanged" or "SettingsDefault"
        end
        marks[#marks + 1] = { row, 0, { end_col = #label, hl_group = "SettingsLabel" } }
        if #marker > 0 then
          marks[#marks + 1] = { row, val_col, { end_col = val_col + #marker, hl_group = "SettingsMarker" } }
        end
        marks[#marks + 1] = { row, val_col + #marker, { end_col = #line, hl_group = val_hl } }
      end
    end
  end
  return lines, rows, marks, total
end

-- ── Render ─────────────────────────────────────────────────────────
-- La línea 0 es el campo de búsqueda (editable en vivo con /). keep_input=true no la reescribe
-- (para no pisar lo que el usuario está tipeando); solo refresca el contenido y el contador.
local function render(buf, keep_input)
  local v = views[buf]
  if not (v and api.nvim_buf_is_valid(buf)) then
    return
  end
  set_hl()
  local width = (v.win and api.nvim_win_is_valid(v.win)) and api.nvim_win_get_width(v.win) or 30
  local query = v.query
  local clines, crows, cmarks, total = build_content(width, query)

  vim.bo[buf].modifiable = true
  if keep_input then
    api.nvim_buf_set_lines(buf, 1, -1, false, clines)
  else
    -- con la búsqueda enfocada y vacía se siembra 1 espacio: en una línea vacía el cursor
    -- solo puede ir a la col 0 (pegado al icono); el espacio le da sitio a la derecha. El
    -- término se recorta (vim.trim) en on_type, así que ese espacio no cuenta.
    local input_line = (v.searching and (query == nil or query == "")) and " " or (query or "")
    local all = { input_line }
    for _, l in ipairs(clines) do
      all[#all + 1] = l
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, all)
  end
  vim.bo[buf].modifiable = v.searching == true

  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local shifted = {} -- el contenido va desplazado 1 fila (línea 0 = campo de búsqueda)
  for _, m in ipairs(cmarks) do
    shifted[#shifted + 1] = { m[1] + 1, m[2], m[3] }
  end
  ui.hl.line_marks(buf, ns, shifted)

  -- campo de búsqueda (línea 0): icono + placeholder si está vacío + contador al final.
  -- OJO: el virt_text "inline" NO se dibuja en una línea vacía (no hay carácter al que
  -- anclarse), así que con la línea vacía se usa "overlay" para que el icono se vea igual.
  local line0 = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  local chunks = { { " " .. SEARCH_ICON .. "  ", "SettingsSection" } }
  if line0 == "" and not v.searching then
    chunks[#chunks + 1] = { "Search settings  (/)", "SettingsDefault" }
  end
  api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_text = chunks,
    virt_text_pos = (line0 == "") and "overlay" or "inline",
  })
  if query and query ~= "" then
    local tail = total == 0 and "  no matches" or ("  (" .. total .. ")")
    api.nvim_buf_set_extmark(buf, ns, 0, 0, { virt_text = { { tail, "SettingsDefault" } }, virt_text_pos = "eol" })
  end

  v.rows = { false } -- la línea 0 (búsqueda) no es seleccionable por el imán
  for _, r in ipairs(crows) do
    v.rows[#v.rows + 1] = r
  end
  v.menu.set_rows(v.rows)
end

-- ── Imantar el cursor (delegado en ui.menu) ────────────────────────
function M.on_cursor(buf)
  local v = views[buf]
  if not v or v.searching then
    return -- mientras se escribe en el campo de búsqueda no se imanta el cursor
  end
  if v.menu then
    v.menu.on_cursor()
  end
end

local function current_value(buf)
  local v = views[buf]
  return v and v.menu and v.menu.current()
end

-- La opción bajo el cursor, o nil si es una cabecera de sección (las cabeceras son
-- seleccionables para poder colapsarlas, pero no son "settings" sobre los que operar).
local function current_spec(buf)
  local val = current_value(buf)
  if val and not val.header and val.type then
    return val
  end
  return nil
end

-- Lleva el cursor a la cabecera `title` tras colapsar/expandir (el layout cambió de líneas).
local function focus_header(buf, title)
  local v = views[buf]
  if not (v and v.win and api.nvim_win_is_valid(v.win)) then
    return
  end
  for lnum, r in ipairs(v.rows) do
    if type(r) == "table" and r.header and r.title == title then
      api.nvim_win_set_cursor(v.win, { lnum, 0 })
      break
    end
  end
  M.on_cursor(buf)
end

-- ── Edición ────────────────────────────────────────────────────────
local function clamp(x, lo, hi)
  return math.max(lo, math.min(hi, x))
end

local function adjust(buf, dir)
  local val = current_value(buf)
  if val and val.header then
    if views[buf] and views[buf].query then
      return -- con el filtro activo las secciones no se colapsan
    end
    set_collapsed(val.title, dir < 0) -- h (dir<0) colapsa, l (dir>0) expande
    render(buf)
    focus_header(buf, val.title)
    return
  end
  local spec = current_spec(buf)
  if not spec then
    return
  end
  if spec.type == "bool" then
    spec.set(not spec.get())
  elseif spec.type == "number" then
    spec.set(clamp(spec.get() + dir * (spec.step or 1), spec.min or 0, spec.max or math.huge))
  elseif spec.type == "enum" then
    local choices = spec.choices()
    local cur, i = spec.get(), 1
    for k, val in ipairs(choices) do
      if val == cur then
        i = k
      end
    end
    spec.set(choices[((i - 1 + dir) % #choices) + 1])
  end
  render(buf)
end

-- Selector rico para un enum (vista previa en vivo + restaurar al cancelar). La ventana
-- del sidebar persiste: al cerrarse el picker basta re-renderizar.
local function open_enum_picker(buf)
  local spec = current_spec(buf)
  if not spec or spec.type ~= "enum" then
    return
  end
  local original = spec.get()
  local labels, to_value = {}, {}
  for _, val in ipairs(spec.choices()) do
    local lbl = spec.display and spec.display(val) or tostring(val)
    if lbl == "" then
      lbl = "(empty — hide)"
    end
    labels[#labels + 1] = lbl
    to_value[lbl] = val
  end
  require("plugins.local.picker").pick({
    title = spec.label,
    items = labels,
    preview = spec.preview,
    on_move = function(lbl)
      if lbl and spec.apply then
        spec.apply(to_value[lbl])
      end
    end,
    on_select = function(lbl)
      if lbl then
        spec.set(to_value[lbl])
      end
      render(buf)
    end,
    on_cancel = function()
      if spec.apply then
        spec.apply(original)
      end
      render(buf)
    end,
  })
end

local function activate(buf)
  local val = current_value(buf)
  if val and val.header then
    if views[buf] and views[buf].query then
      return -- con el filtro activo las secciones no se colapsan
    end
    set_collapsed(val.title, not is_collapsed(val.title))
    render(buf)
    focus_header(buf, val.title)
    return
  end
  local spec = current_spec(buf)
  if not spec then
    return
  end
  if spec.type == "action" then
    spec.run()
  elseif spec.type == "enum" then
    open_enum_picker(buf)
  else
    adjust(buf, 1)
  end
end

local function reset(buf)
  local spec = current_spec(buf)
  if spec and spec.set then -- las entradas "action" no tienen set/default
    spec.set(spec.default)
    render(buf)
  end
end

-- ── Búsqueda / filtro ───────────────────────────────────────────────
local function cursor_top(buf)
  local v = views[buf]
  if v and v.win and api.nvim_win_is_valid(v.win) then
    api.nvim_win_set_cursor(v.win, { 1, 0 })
  end
  M.on_cursor(buf)
end

-- `/`: enfoca el campo de búsqueda (línea 0) y entra en inserción; el filtrado es en vivo
-- (ver los autocomandos de create). Vuelve a / para editar el término ya escrito.
local function search(buf)
  local v = views[buf]
  if not (v and v.win and api.nvim_win_is_valid(v.win)) then
    return
  end
  v.searching = true
  ui.win.set_opts(v.win, { cursorline = false }) -- sin resaltado de línea sobre el input
  render(buf) -- quita el placeholder y deja el término actual en la línea 0
  api.nvim_win_set_cursor(v.win, { 1, 0 })
  vim.cmd("startinsert!") -- al final de la línea 0 (como `A`)
end

-- `<Esc>` (en la lista): quita el filtro (si hay uno activo).
local function clear_search(buf)
  local v = views[buf]
  if v and v.query and v.query ~= "" then
    v.query = nil
    render(buf)
    cursor_top(buf)
  end
end

-- Actualiza el filtro en vivo desde lo escrito en la línea 0 (sin reescribir esa línea).
local function on_type(buf)
  local v = views[buf]
  if not (v and v.searching) or v._busy then
    return
  end
  v._busy = true
  local raw = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  local q = vim.trim(raw)
  v.query = (q ~= "") and q or nil
  if q == "" then
    -- vacío: mantener 1 espacio para que el cursor no quede pegado al icono
    if raw ~= " " then
      api.nvim_buf_set_lines(buf, 0, 1, false, { " " })
    end
    pcall(api.nvim_win_set_cursor, v.win, { 1, 1 })
  end
  render(buf, true)
  v._busy = false
end

-- Al salir de inserción: fija el filtro y lleva el foco a los resultados.
local function end_search(buf)
  local v = views[buf]
  if not (v and v.searching) then
    return
  end
  v.searching = false
  if v.win and api.nvim_win_is_valid(v.win) then
    ui.win.set_opts(v.win, { cursorline = true }) -- restaurar el resaltado en la lista
  end
  render(buf)
  cursor_top(buf)
end

-- ── Ciclo de vida ──────────────────────────────────────────────────
-- Crea el buffer de la vista (una vez por sidebar). Los keymaps son buffer-local.
function M.create()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "settings"
  vim.b[buf].completion = false -- sin autocompletado (blink) en el campo de búsqueda
  views[buf] = { rows = {} }
  views[buf].menu = ui.menu.new({
    buf = buf,
    get_win = function()
      return views[buf].win
    end,
    marker = { text = "▸", hl = "SettingsMarker" },
  })

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, function()
      fn(buf)
    end, { buffer = buf, silent = true, nowait = true })
  end
  map("l", function(b)
    adjust(b, 1)
  end)
  map("<Right>", function(b)
    adjust(b, 1)
  end)
  map("h", function(b)
    adjust(b, -1)
  end)
  map("<Left>", function(b)
    adjust(b, -1)
  end)
  map("<CR>", activate)
  map("/", search) -- buscar/filtrar ajustes por nombre
  map("<Esc>", clear_search) -- quitar el filtro
  map("za", activate) -- colapsar/expandir la sección bajo el cursor (estilo fold de vim)
  -- OJO: no mapear <Space> aquí — es el leader; hacerlo impediría <leader>e y demás atajos
  map("r", reset)
  map("<Tab>", function()
    require("plugins.local.sidebar").next()
  end)
  map("<S-Tab>", function()
    require("plugins.local.sidebar").prev()
  end)
  map("q", function()
    require("plugins.local.sidebar").close()
  end)
  -- en el campo de búsqueda (inserción): ⏎ / ↓ salen a los resultados; sin saltos de línea
  vim.keymap.set("i", "<CR>", "<Esc>", { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("i", "<Down>", "<Esc>", { buffer = buf, nowait = true, silent = true })

  api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      M.on_cursor(buf)
    end,
  })
  -- filtrado en vivo mientras se escribe en la línea 0
  api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = buf,
    callback = function()
      on_type(buf)
    end,
  })
  api.nvim_create_autocmd("InsertLeave", {
    buffer = buf,
    callback = function()
      end_search(buf)
    end,
  })
  -- si el cursor deja la línea 0 estando en inserción, salir de la búsqueda a los resultados
  api.nvim_create_autocmd("CursorMovedI", {
    buffer = buf,
    callback = function()
      local v = views[buf]
      if v and v.searching and v.win and api.nvim_win_get_cursor(v.win)[1] > 1 then
        vim.cmd("stopinsert")
      end
    end,
  })
  return buf
end

-- Muestra la vista en la ventana del sidebar: aspecto propio + primer render + cursor.
function M.attach(win, buf)
  if not (views[buf] and views[buf].menu) then -- defensivo (create() normalmente ya corrió)
    views[buf] = { rows = {} }
    views[buf].menu = ui.menu.new({
      buf = buf,
      get_win = function()
        return views[buf].win
      end,
      marker = { text = "▸", hl = "SettingsMarker" },
    })
  end
  views[buf].win = win
  -- ui.win.set_opts usa scope="local": sin él, fijar estas window-local sobre la ventana
  -- actual también cambiaría el default global (apagaba números/cursorline en todo).
  ui.win.set_opts(win, {
    winhighlight = "CursorLine:SettingsCursorLine",
    cursorline = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    list = false,
    wrap = false,
  })
  render(buf)
  -- colocar el cursor en la primera opción
  api.nvim_win_set_cursor(win, { 1, 0 })
  M.on_cursor(buf)
end

return M
