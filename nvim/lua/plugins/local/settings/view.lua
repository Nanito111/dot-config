-- Vista de configuración para el SIDEBAR (comparte panel con el explorador; se alterna
-- con <Tab>). Cada línea es un setting editable en vivo; solo lo distinto del default se
-- guarda (lo gestiona config.settings). El cursor se "imanta" a las líneas de opción (no
-- descansa nunca en cabeceras ni blancos), así la acción siempre recae sobre lo marcado.
local api = vim.api
local settings = require("config.settings")
local palette = require("config.palette")
local theme = require("config.theme")

local M = {}
local ns = api.nvim_create_namespace("settings_view")
local mark_ns = api.nvim_create_namespace("settings_marker")

local views = {} -- [buf] = { win, rows = { spec|nil }, last }

local function set_hl()
  api.nvim_set_hl(0, "SettingsSection", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "SettingsLabel", { fg = palette.fg })
  api.nvim_set_hl(0, "SettingsDefault", { fg = palette.comment })
  api.nvim_set_hl(0, "SettingsChanged", { fg = palette.green, bold = true })
  api.nvim_set_hl(0, "SettingsMarker", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "SettingsCursorLine", { bg = palette.bg_highlight, bold = true })
end
theme.register(set_hl)
set_hl()

-- Iconos de switch (FontAwesome toggle-on/off) para los booleanos
local SWITCH_ON = "\u{f205}" --
local SWITCH_OFF = "\u{f204}" --

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
    return s == "" and "(oculto)" or s
  end
  return tostring(v)
end

-- ── Render ─────────────────────────────────────────────────────────
local function render(buf)
  local v = views[buf]
  if not (v and api.nvim_buf_is_valid(buf)) then
    return
  end
  set_hl()
  local width = (v.win and api.nvim_win_is_valid(v.win)) and api.nvim_win_get_width(v.win) or 30
  local lines, rows, marks = {}, {}, {}
  -- rows[i] = spec de la línea i, o `false` si no es seleccionable (cabecera/blanco). Se
  -- usa `false` y no `nil` para no dejar huecos: con un nil en medio, #rows es ambiguo.
  local function push(text, spec)
    lines[#lines + 1] = text
    rows[#rows + 1] = spec or false
  end

  for si, section in ipairs(settings.registry()) do
    if si > 1 then
      push("", nil)
    end
    local header = "  " .. section.title
    push(header, nil)
    marks[#marks + 1] = { #lines - 1, 0, { end_col = #header, hl_group = "SettingsSection" } }

    for _, spec in ipairs(section.items) do
      local label = "  " .. spec.label
      local marker = spec.overridden() and "● " or ""
      local val = marker .. value_text(spec)
      local pad = width - 1 - vim.fn.strdisplaywidth(label) - vim.fn.strdisplaywidth(val)
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

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    pcall(api.nvim_buf_set_extmark, buf, ns, m[1], m[2], m[3])
  end
  v.rows = rows
end

-- ── Imantar el cursor a una línea de opción ────────────────────────
-- Recorre desde `from` en la dirección `dir` hasta la primera línea que es un setting.
local function scan(rows, from, dir)
  local n = #rows
  local a = from
  while a >= 1 and a <= n do
    if rows[a] then
      return a
    end
    a = a + dir
  end
end

-- Marcador ▸ en la línea activa (se mueve con el cursor)
local function draw_marker(buf, lnum)
  api.nvim_buf_clear_namespace(buf, mark_ns, 0, -1)
  pcall(api.nvim_buf_set_extmark, buf, mark_ns, lnum - 1, 0, {
    virt_text = { { "▸", "SettingsMarker" } },
    virt_text_pos = "overlay",
  })
end

-- Al mover el cursor: si cae en cabecera/blanco, saltar a la opción más cercana en el
-- sentido del movimiento (o el contrario si no hay). Deja el marcador en la opción activa.
function M.on_cursor(buf)
  local v = views[buf]
  if not (v and v.win and api.nvim_win_is_valid(v.win)) then
    return
  end
  local lnum = api.nvim_win_get_cursor(v.win)[1]
  if not v.rows[lnum] then
    local dir = (v.last and lnum < v.last) and -1 or 1
    local target = scan(v.rows, lnum, dir) or scan(v.rows, lnum, -dir)
    if target and target ~= lnum then
      api.nvim_win_set_cursor(v.win, { target, 0 })
      return -- el propio set redispara CursorMoved: el marcador se pinta entonces
    end
    lnum = target or lnum
  end
  v.last = lnum
  draw_marker(buf, lnum)
end

local function current_spec(buf)
  local v = views[buf]
  local lnum = api.nvim_win_get_cursor(v.win)[1]
  return v.rows[lnum]
end

-- ── Edición ────────────────────────────────────────────────────────
local function clamp(x, lo, hi)
  return math.max(lo, math.min(hi, x))
end

local function adjust(buf, dir)
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
      lbl = "(vacío — ocultar)"
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

-- ── Ciclo de vida ──────────────────────────────────────────────────
-- Crea el buffer de la vista (una vez por sidebar). Los keymaps son buffer-local.
function M.create()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "settings"
  views[buf] = { rows = {}, last = nil }

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, function()
      fn(buf)
    end, { buffer = buf, silent = true, nowait = true })
  end
  map("l", function(b) adjust(b, 1) end)
  map("<Right>", function(b) adjust(b, 1) end)
  map("h", function(b) adjust(b, -1) end)
  map("<Left>", function(b) adjust(b, -1) end)
  map("<CR>", activate)
  -- OJO: no mapear <Space> aquí — es el leader; hacerlo impediría <leader>e y demás atajos
  map("r", reset)
  map("<Tab>", function()
    require("plugins.local.sidebar").next()
  end)
  map("q", function()
    require("plugins.local.sidebar").close()
  end)

  api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      M.on_cursor(buf)
    end,
  })
  return buf
end

-- Muestra la vista en la ventana del sidebar: aspecto propio + primer render + cursor.
function M.attach(win, buf)
  views[buf] = views[buf] or { rows = {}, last = nil }
  views[buf].win = win
  -- scope="local": win puede ser la ventana actual, y vim.wo[curwin] sobre una opción
  -- window-local también fija el default global (como :set). Sin esto, mostrar la vista
  -- de configuración apagaba números/cursorline en todo (y el panel leía ese global mal).
  local function wset(name, val)
    api.nvim_set_option_value(name, val, { win = win, scope = "local" })
  end
  wset("winhighlight", "CursorLine:SettingsCursorLine")
  wset("cursorline", true)
  wset("number", false)
  wset("relativenumber", false)
  wset("signcolumn", "no")
  wset("list", false)
  wset("wrap", false)
  render(buf)
  -- colocar el cursor en la primera opción
  api.nvim_win_set_cursor(win, { 1, 0 })
  M.on_cursor(buf)
end

return M
