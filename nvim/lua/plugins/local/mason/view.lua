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
  api.nvim_set_hl(0, "MasonInfo", { fg = palette.comment }) -- línea de salida del instalador
  api.nvim_set_hl(0, "MasonMarker", { fg = palette.blue, bold = true }) -- ▸
  api.nvim_set_hl(0, "MasonAdd", { fg = palette.green, bold = true }) -- fila "instalar"
  api.nvim_set_hl(0, "MasonArrow", { fg = palette.comment }) -- → del botón (como en settings)
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
  local width = (v.win and api.nvim_win_is_valid(v.win)) and api.nvim_win_get_width(v.win) or 30

  local lines, rows, marks = {}, {}, {}
  local function push(text, value)
    lines[#lines + 1] = text
    rows[#rows + 1] = value or false -- false = no seleccionable (ui.menu)
  end

  -- fila-acción arriba: ⏎ abre el picker para instalar algo nuevo (más intuitivo que 'a').
  -- Con → a la derecha, como los botones "action" del panel de settings.
  local label = "  \u{f067}  Instalar herramienta"
  local arrow = "→"
  local pad = math.max(1, width - 3 - vim.fn.strdisplaywidth(label) - vim.fn.strdisplaywidth(arrow))
  local add = label .. string.rep(" ", pad) .. arrow
  push(add, { action = "install" })
  marks[#marks + 1] = { 0, 0, { end_col = #label, hl_group = "MasonAdd" } }
  marks[#marks + 1] = { 0, #label + pad, { end_col = #add, hl_group = "MasonArrow" } }

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
        -- 2.ª línea (no seleccionable): comando/última salida del instalador, como en mason
        local info = (prog.line ~= "" and prog.line) or (prog.spawn ~= "" and prog.spawn) or nil
        if info then
          local text = "      " .. ui.text.fit(info, math.max(1, width - 7))
          push(text, nil)
          marks[#marks + 1] = { #lines - 1, 0, { end_col = #text, hl_group = "MasonInfo" } }
        end
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

-- Picker fuzzy sobre el registro completo para instalar algo nuevo. Además del fuzzy por
-- nombre, dos chips que se ciclan acotan el universo: categoría (<C-g>) y lenguaje (<C-l>).
-- La lista de lenguajes depende de la categoría activa (así ciclar no es interminable).
local function distinct_sorted(set)
  local out = {}
  for k in pairs(set) do
    out[#out + 1] = k
  end
  table.sort(out)
  return out
end

local function install_new()
  local catalog = actions.catalog()
  if #catalog == 0 then
    vim.notify("No hay más paquetes disponibles", vim.log.levels.INFO, { title = "Mason" })
    return
  end

  local meta = {} -- name -> { categories, languages }
  local cat_set = {}
  for _, e in ipairs(catalog) do
    meta[e.name] = e
    for _, c in ipairs(e.categories) do
      cat_set[c] = true
    end
  end
  local cats = distinct_sorted(cat_set)
  table.insert(cats, 1, "*")

  -- lenguajes presentes en los paquetes de la categoría activa (o de todo si cat == "*")
  local function langs_for(cat)
    local set = {}
    for _, e in ipairs(catalog) do
      local in_cat = cat == "*" or vim.tbl_contains(e.categories, cat)
      if in_cat then
        for _, l in ipairs(e.languages) do
          set[l] = true
        end
      end
    end
    local out = distinct_sorted(set)
    table.insert(out, 1, "*")
    return out
  end

  local ci, li = 1, 1 -- índices de categoría/lenguaje (1 = "*")
  local langs = langs_for("*")

  -- nombres del catálogo que pasan ambos chips
  local function filtered()
    local cat, lang = cats[ci], langs[li]
    local out = {}
    for _, e in ipairs(catalog) do
      local ok_cat = cat == "*" or vim.tbl_contains(e.categories, cat)
      local ok_lang = lang == "*" or vim.tbl_contains(e.languages, lang)
      if ok_cat and ok_lang then
        out[#out + 1] = e.name
      end
    end
    return out
  end

  local function footer_text()
    return string.format(
      "[Cat: %s]  [Lang: %s]   <C-g> categoría · <C-l> lenguaje",
      cats[ci],
      langs[li]
    )
  end

  local function apply(ctx)
    ctx.set_items(filtered())
    if ctx.list_win and api.nvim_win_is_valid(ctx.list_win) then
      pcall(api.nvim_win_set_config, ctx.list_win, {
        footer = " " .. footer_text() .. " ",
        footer_pos = "center",
      })
    end
  end

  -- fila del picker: ● nombre  + sufijo atenuado "categoría · lenguajes"
  local NAMEW = 24
  local function render_row(name)
    local m = meta[name] or {}
    local cat = (m.categories or {})[1]
    local langs2 = {}
    for i = 1, math.min(2, #(m.languages or {})) do
      langs2[i] = m.languages[i]
    end
    local right = cat or ""
    if #langs2 > 0 then
      right = (right ~= "" and (right .. " · ") or "") .. table.concat(langs2, ", ")
    end
    local left = "● " .. name
    local pad = math.max(2, NAMEW - vim.fn.strdisplaywidth(name))
    local text = left .. string.rep(" ", pad) .. right
    return text, #left + pad -- texto, columna donde empieza el sufijo
  end

  require("plugins.local.picker").pick({
    title = "Instalar herramienta",
    items = filtered(),
    footer = footer_text(),
    backdrop = true,
    list_ratio = 0.6, -- lista más ancha (los nombres+categoría necesitan sitio)
    preview_numbers = false, -- el preview es texto (descripción), no un archivo
    preview_wrap = true, -- la descripción se ajusta en vez de cortarse
    display = function(name)
      return (render_row(name))
    end,
    display_hl = function(name)
      local text, rstart = render_row(name)
      return {
        { group = "MasonInstalled", col = 0, end_col = #("●") },
        { group = "Comment", col = rstart, end_col = #text },
      }
    end,
    preview = function(name)
      local pkg = actions.get(name)
      return pkg and { lines = require("plugins.local.mason.details").lines(pkg) } or nil
    end,
    keymaps = {
      ["<C-g>"] = function(ctx)
        ci = ci % #cats + 1
        li = 1
        langs = langs_for(cats[ci]) -- la lista de lenguajes depende de la categoría
        apply(ctx)
      end,
      ["<C-l>"] = function(ctx)
        li = li % #langs + 1
        apply(ctx)
      end,
    },
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
