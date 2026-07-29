-- Vista de Mason para el SIDEBAR (comparte panel con explorer/settings, se alterna con <Tab>).
-- Lista los paquetes INSTALADOS agrupados por categoría, con versión, marca de actualizable y
-- progreso en vivo al instalar/actualizar. Instalar nuevos se hace con el picker (tecla 'a').
-- El cursor se imanta a las filas de paquete (no descansa en las cabeceras), como en settings.
local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local ui = require("plugins.local.ui")
local actions = require("plugins.local.mason.actions")

local M = {}
local ns = api.nvim_create_namespace("mason_view")
local views = {} -- [buf] = { win, rows, menu }

local function set_hl()
  api.nvim_set_hl(0, "MasonSection", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "MasonName", { fg = palette.fg })
  api.nvim_set_hl(0, "MasonInstalled", { fg = palette.green, bold = true }) -- ●
  api.nvim_set_hl(0, "MasonVersion", { fg = palette.comment })
  api.nvim_set_hl(0, "MasonOutdated", { fg = palette.yellow, bold = true }) -- ↑
  api.nvim_set_hl(0, "MasonProgress", { fg = palette.blue, bold = true }) -- spinner
  api.nvim_set_hl(0, "MasonMarker", { fg = palette.blue, bold = true }) -- ▸
  api.nvim_set_hl(0, "MasonAdd", { fg = palette.green, bold = true }) -- fila "instalar"
  api.nvim_set_hl(0, "MasonCursorLine", { bg = palette.bg_highlight, bold = true })
end
theme.register(set_hl)
set_hl()

-- ── Render ─────────────────────────────────────────────────────────
local function render(buf)
  local v = views[buf]
  if not (v and api.nvim_buf_is_valid(buf)) then
    return
  end
  set_hl()

  local lines, rows, marks = {}, {}, {}
  local function push(text, value)
    lines[#lines + 1] = text
    rows[#rows + 1] = value or false -- false = no seleccionable (ui.menu)
  end

  -- fila-acción arriba: ⏎ abre el picker para instalar algo nuevo (más intuitivo que 'a')
  local add = "  \u{f067}  Instalar herramienta"
  push(add, { action = "install" })
  marks[#marks + 1] = { 0, 0, { end_col = #add, hl_group = "MasonAdd" } }

  -- entradas: instalados ∪ los que se están instalando por PRIMERA vez (aún no instalados,
  -- así que no salen en get_installed_packages; sin esto no se vería su progreso).
  local entries = actions.installed()
  local seen = {}
  for _, e in ipairs(entries) do
    seen[e.name] = true
  end
  for name, st in pairs(actions.in_progress) do
    if not seen[name] then
      entries[#entries + 1] = {
        name = name,
        pkg = st.pkg,
        category = (st.pkg and st.pkg.spec and (st.pkg.spec.categories or {})[1]) or "Instalando",
      }
    end
  end

  local by_cat = {}
  for _, e in ipairs(entries) do
    by_cat[e.category] = by_cat[e.category] or {}
    table.insert(by_cat[e.category], e)
  end
  local cats = vim.tbl_keys(by_cat)
  table.sort(cats)

  for _, cat in ipairs(cats) do
    push("", nil)
    local header = "  " .. cat
    push(header, nil)
    marks[#marks + 1] = { #lines - 1, 0, { end_col = #header, hl_group = "MasonSection" } }

    for _, e in ipairs(by_cat[cat]) do
      local prog = actions.in_progress[e.name]
      local line, name_hl_end
      if prog then
        -- en curso: ⟳ nombre  <spinner> <estado>
        local right = actions.spinner() .. " " .. (prog.state or ""):lower()
        line = "  ⟳ " .. e.name
        name_hl_end = #line
        line = line .. "   " .. right
        push(line, e)
        local row = #lines - 1
        marks[#marks + 1] = { row, 2, { end_col = 2 + #("⟳"), hl_group = "MasonProgress" } }
        marks[#marks + 1] = { row, name_hl_end - #e.name, { end_col = name_hl_end, hl_group = "MasonName" } }
        marks[#marks + 1] = { row, name_hl_end, { end_col = #line, hl_group = "MasonProgress" } }
      else
        local marker = "● "
        local ver = e.version and ("  " .. e.version) or ""
        local up = e.outdated and "  ↑" or ""
        line = "  " .. marker .. e.name .. ver .. up
        push(line, e)
        local row = #lines - 1
        local mstart = 2
        marks[#marks + 1] = { row, mstart, { end_col = mstart + #marker - 1, hl_group = "MasonInstalled" } }
        local nstart = mstart + #marker
        marks[#marks + 1] = { row, nstart, { end_col = nstart + #e.name, hl_group = "MasonName" } }
        if ver ~= "" then
          marks[#marks + 1] = { row, nstart + #e.name, { end_col = nstart + #e.name + #ver, hl_group = "MasonVersion" } }
        end
        if up ~= "" then
          marks[#marks + 1] = { row, #line - #up, { end_col = #line, hl_group = "MasonOutdated" } }
        end
      end
    end
  end

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  ui.hl.line_marks(buf, ns, marks)
  v.rows = rows
  v.menu.set_rows(rows)
end

-- re-render de todas las vistas mason vivas (lo llama actions al cambiar el estado)
function M.render_all()
  for buf in pairs(views) do
    if api.nvim_buf_is_valid(buf) then
      render(buf)
    else
      views[buf] = nil
    end
  end
end

function M.on_cursor(buf)
  local v = views[buf]
  if v and v.menu then
    v.menu.on_cursor()
  end
end

local function current(buf)
  local v = views[buf]
  return v and v.menu and v.menu.current()
end

-- ── Acciones de teclado ────────────────────────────────────────────
local function do_update(buf)
  local e = current(buf)
  if e and e.pkg then
    actions.update(e.pkg)
  end
end

local function do_uninstall(buf)
  local e = current(buf)
  if not (e and e.pkg) then
    return
  end
  local ans = require("plugins.local.confirm").confirm(
    "¿Desinstalar «" .. e.name .. "»?",
    "&Si\n&No",
    2,
    { backdrop = true }
  )
  if ans == 1 then
    actions.uninstall(e.pkg)
  end
end

local function update_all(buf)
  local n = 0
  for _, e in ipairs(actions.installed()) do
    if e.outdated then
      actions.update(e.pkg)
      n = n + 1
    end
  end
  if n == 0 then
    vim.notify("Todo está al día", vim.log.levels.INFO, { title = "Mason" })
  end
end

-- Picker fuzzy sobre el registro completo para instalar algo nuevo.
local function install_new()
  local items = actions.available()
  if #items == 0 then
    vim.notify("No hay más paquetes disponibles", vim.log.levels.INFO, { title = "Mason" })
    return
  end
  require("plugins.local.picker").pick({
    title = "Instalar herramienta",
    items = items,
    backdrop = true,
    preview_numbers = false, -- el preview es texto (descripción), no un archivo
    preview = function(name)
      local pkg = actions.get(name)
      return pkg and { lines = require("plugins.local.mason.details").lines(pkg) } or nil
    end,
    on_select = function(name)
      if name then
        actions.install(name)
      end
    end,
  })
end

-- ⏎ / K: en la fila-acción abre el picker de instalar; sobre un paquete, sus detalles.
local function activate(buf)
  local e = current(buf)
  if not e then
    return
  end
  if e.action == "install" then
    install_new()
  elseif e.pkg then
    require("plugins.local.mason.details").open(e.pkg)
  end
end

-- ── Ciclo de vida (vista del sidebar) ──────────────────────────────
function M.create()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "mason"
  views[buf] = { rows = {} }
  views[buf].menu = ui.menu.new({
    buf = buf,
    get_win = function()
      return views[buf].win
    end,
    marker = { text = "▸", hl = "MasonMarker" },
  })

  actions.set_on_change(M.render_all) -- progreso/eventos -> re-render
  actions.subscribe()

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, function()
      fn(buf)
    end, { buffer = buf, silent = true, nowait = true })
  end
  map("u", do_update)
  map("x", do_uninstall)
  map("U", update_all)
  map("a", function()
    install_new()
  end)
  map("K", activate)
  map("r", function(b)
    render(b)
  end)
  map("R", function(b)
    render(b)
  end)
  map("<CR>", activate)
  map("<Tab>", function()
    require("plugins.local.sidebar").next()
  end)
  map("<S-Tab>", function()
    require("plugins.local.sidebar").prev()
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

function M.attach(win, buf)
  if not (views[buf] and views[buf].menu) then
    M.create() -- defensivo (normalmente create() ya corrió)
  end
  views[buf].win = win
  ui.win.set_opts(win, {
    winhighlight = "CursorLine:MasonCursorLine",
    cursorline = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    list = false,
    wrap = false,
  })
  render(buf)
  api.nvim_win_set_cursor(win, { 1, 0 })
  M.on_cursor(buf)
end

return M
