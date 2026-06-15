-- Explorador de archivos propio (MVP) — plugin-free.
-- AISLADO: no se conecta a nada todavía. Para probarlo:
--   :lua require("plugins.local.explorer").open()
-- Cargar este módulo solo registra unos autocomandos inertes (no afectan tu
-- sesión a menos que abras el explorador).

local api = vim.api
local uv = vim.uv or vim.loop
local icons = require("config.icons")
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

local FOLDER_CLOSED = "\u{f07b}" --
local FOLDER_OPEN = "\u{f07c}" --

local ns = api.nvim_create_namespace("explorer")
local group = api.nvim_create_augroup("Explorer", { clear = true })

-- Estado POR TAB (cada workspace tiene su propio explorador independiente)
local states = {} -- handle de tab -> { root, expanded, buf, win, nodes, watcher, timer }

local function cur()
  return states[api.nvim_get_current_tabpage()]
end

local function set_hl()
  local hl = api.nvim_set_hl
  hl(0, "ExplorerDir", { fg = palette.blue, bold = true })
  hl(0, "ExplorerFile", { fg = palette.fg })
  hl(0, "ExplorerRoot", { fg = palette.yellow, bold = true })
  hl(0, "ExplorerCurrent", { fg = palette.cyan_bright, bold = true }) -- archivo actual
  hl(0, "ExplorerGitNew", { fg = palette.cyan }) -- sin trackear (distinto del verde de añadido)
end

-- Define los grupos ahora y los reaplica en ColorScheme. La llamada en
-- M.open() queda como reaseguro (p. ej. tras :ReloadConfig).
theme.register(set_hl)

-- Normaliza una ruta para comparar (Windows: sin distinguir mayúsculas ni barras)
local function normpath(p)
  return p and (p:gsub("\\", "/"):gsub("/+$", ""):lower()) or ""
end

-- Símbolo + highlight para un estado de git. El código XY de `git status
-- --porcelain` separa staged (X, índice) de sin-stagear (Y, árbol de trabajo):
-- los cambios sin stagear se ven con color VIVO y los solo-staged con color
-- APAGADO (igual que el gutter). Para carpetas: "DU" = contiene algo sin stagear
-- (• vivo), "DS" = solo cambios staged (• apagado).
local function git_mark(code, is_dir)
  if is_dir then
    if code == "DS" then
      return "\u{2022}", "GitSignStagedChange" -- • carpeta: solo staged (apagado)
    end
    return "\u{2022}", "GitSignChange" -- • carpeta: hay algo sin stagear (vivo)
  end
  if code == "??" then
    return "?", "ExplorerGitNew" -- sin trackear (teal)
  end
  local x, y = code:sub(1, 1), code:sub(2, 2)
  -- los cambios sin stagear (Y) tienen prioridad visual: color vivo
  if y == "D" then
    return "-", "GitSignDelete"
  elseif y == "A" then
    return "+", "GitSignAdd"
  elseif y ~= " " then -- M, R, C, T… modificado sin stagear
    return "~", "GitSignChange"
  end
  -- solo staged (Y vacío): colores apagados
  if x == "A" or x == "C" then
    return "+", "GitSignStagedAdd"
  elseif x == "D" then
    return "-", "GitSignStagedDelete"
  elseif x == "R" then
    return "\u{2192}", "GitSignStagedChange" -- → renombrado (staged)
  end
  return "~", "GitSignStagedChange" -- M u otros (staged)
end

-- Lee un directorio: carpetas primero, luego alfabético
local function read_dir(path)
  local entries = {}
  local handle = uv.fs_scandir(path)
  if handle then
    while true do
      local name, t = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      entries[#entries + 1] = { name = name, is_dir = (t == "directory") }
    end
  end
  table.sort(entries, function(a, b)
    if a.is_dir ~= b.is_dir then
      return a.is_dir
    end
    return a.name:lower() < b.name:lower()
  end)
  return entries
end

-- Construye la lista de nodos visibles (recursivo según lo expandido)
local function build(s, path, depth, out)
  for _, e in ipairs(read_dir(path)) do
    local full = path .. "/" .. e.name
    out[#out + 1] = { path = full, name = e.name, is_dir = e.is_dir, depth = depth }
    if e.is_dir and s.expanded[full] then
      build(s, full, depth + 1, out)
    end
  end
end

-- Dibuja el árbol en el buffer de `s`
-- Grupo de highlight para un color de icono (estilo devicons)
local function icon_color_group(col)
  local name = "ExpIcon_" .. col:gsub("#", "")
  api.nvim_set_hl(0, name, { fg = col })
  return name
end

local function render(s)
  if not (s and s.buf and api.nvim_buf_is_valid(s.buf)) then
    return
  end
  s.nodes = {}
  build(s, s.root, 0, s.nodes)
  local colored = vim.g.explorer_colored_icons
  local current = s.current_file and normpath(s.current_file) or nil

  local lines = { " " .. FOLDER_OPEN .. " " .. vim.fn.fnamemodify(s.root, ":t") .. "/" }
  local hls = {} -- por nodo: { icon_end, name_end (bytes), icon_hl, type_hl, git_hl }
  for _, n in ipairs(s.nodes) do
    local indent = string.rep("  ", n.depth + 1)
    local icon = n.is_dir and (s.expanded[n.path] and FOLDER_OPEN or FOLDER_CLOSED) or icons.icon(n.name)
    local body = indent .. icon .. " " .. n.name .. (n.is_dir and "/" or "")

    local type_hl = n.is_dir and "ExplorerDir" or "ExplorerFile"
    if not n.is_dir and current and normpath(n.path) == current then
      type_hl = "ExplorerCurrent" -- el archivo abierto en la ventana principal
    end
    local icon_hl = type_hl
    if colored and not n.is_dir then
      local col = icons.color(n.name)
      if col then
        icon_hl = icon_color_group(col)
      end
    end

    -- marca de git al final
    local line, git_hl = body, nil
    local st = s.git and s.git[normpath(n.path)]
    if st then
      local sym, hlg = git_mark(st, n.is_dir)
      line = body .. "  " .. sym
      git_hl = hlg
    end
    lines[#lines + 1] = line
    hls[#hls + 1] = {
      icon_end = #indent + #icon,
      name_end = #body,
      icon_hl = icon_hl,
      type_hl = type_hl,
      git_hl = git_hl,
    }
  end

  -- preservar la posición del cursor al re-renderizar (auto-refresco)
  local cursor
  if s.win and api.nvim_win_is_valid(s.win) then
    cursor = api.nvim_win_get_cursor(s.win)
  end

  vim.bo[s.buf].modifiable = true
  api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
  vim.bo[s.buf].modifiable = false

  api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  api.nvim_buf_add_highlight(s.buf, ns, "ExplorerRoot", 0, 0, -1)
  for i, h in ipairs(hls) do
    -- línea de buffer = i (la 0 es la raíz)
    api.nvim_buf_add_highlight(s.buf, ns, h.icon_hl, i, 0, h.icon_end) -- icono
    api.nvim_buf_add_highlight(s.buf, ns, h.type_hl, i, h.icon_end, h.name_end) -- nombre
    if h.git_hl then
      api.nvim_buf_add_highlight(s.buf, ns, h.git_hl, i, h.name_end, -1) -- marca git
    end
  end

  if cursor then
    cursor[1] = math.max(1, math.min(cursor[1], #lines))
    pcall(api.nvim_win_set_cursor, s.win, cursor)
  end
end

local function node_at_cursor(s)
  local lnum = api.nvim_win_get_cursor(s.win)[1]
  return s.nodes[lnum - 1] -- la línea 1 es la raíz, no es nodo
end

-- Refresco con debounce (desde el watcher / autocomandos)
local function schedule_render(s)
  if not s then
    return
  end
  if s.timer then
    s.timer:stop()
    s.timer:close()
  end
  s.timer = uv.new_timer()
  s.timer:start(50, 0, vim.schedule_wrap(function()
    if s.win and api.nvim_win_is_valid(s.win) then
      render(s)
    end
  end))
end

-- Vigila el directorio raíz (recursivo) y refresca en tiempo real
local function stop_watch(s)
  if s and s.watcher then
    pcall(function()
      s.watcher:stop()
      s.watcher:close()
    end)
    s.watcher = nil
  end
end

-- Obtiene el estado de git de la raíz (async) y re-renderiza con las marcas
local function update_git(s)
  if not s or vim.fn.executable("git") == 0 then
    return
  end
  local root = s.root
  vim.system({ "git", "-C", root, "rev-parse", "--show-toplevel" }, { text = true }, function(r1)
    if r1.code ~= 0 then -- no es un repo
      vim.schedule(function()
        s.git = {}
        if s.win and api.nvim_win_is_valid(s.win) then
          render(s)
        end
      end)
      return
    end
    local top = vim.trim(r1.stdout or "")
    vim.system({ "git", "-C", root, "status", "--porcelain", "-uall" }, { text = true }, function(r2)
      local map = {}
      if r2.code == 0 then
        local ntop = normpath(top)
        for line in (r2.stdout or ""):gmatch("[^\r\n]+") do
          local xy = line:sub(1, 2)
          local p = line:sub(4)
          local arrow = p:find(" %-> ")
          if arrow then
            p = p:sub(arrow + 4)
          end
          p = p:gsub('^"', ""):gsub('"$', "")
          local abs = normpath(top .. "/" .. p)
          map[abs] = xy
          -- ¿el archivo tiene algo sin stagear? (untracked o Y != espacio)
          local unstaged = (xy == "??") or (xy:sub(2, 2) ~= " ")
          local dircode = unstaged and "DU" or "DS"
          -- marcar las carpetas ancestro; "DU" (sin stagear) gana sobre "DS"
          local d = abs:match("(.+)/[^/]+$")
          while d and #d > #ntop do
            local prev = map[d]
            if prev ~= "DU" and (prev == nil or dircode == "DU") then
              map[d] = dircode
            end
            d = d:match("(.+)/[^/]+$")
          end
        end
      end
      vim.schedule(function()
        s.git = map
        if s.win and api.nvim_win_is_valid(s.win) then
          render(s)
        end
      end)
    end)
  end)
end

-- update_git con debounce
local function schedule_git(s)
  if not s then
    return
  end
  if s.git_timer then
    s.git_timer:stop()
    s.git_timer:close()
  end
  s.git_timer = uv.new_timer()
  s.git_timer:start(120, 0, vim.schedule_wrap(function()
    update_git(s)
  end))
end

-- Vigila el directorio raíz (recursivo) y refresca en tiempo real
local function stop_watch(s)
  if s and s.watcher then
    pcall(function()
      s.watcher:stop()
      s.watcher:close()
    end)
    s.watcher = nil
  end
end

local function start_watch(s)
  stop_watch(s)
  local w = uv.new_fs_event()
  s.watcher = w
  pcall(function()
    w:start(s.root, { recursive = true }, function(err)
      if not err then
        schedule_render(s) -- refresco rápido del árbol
        schedule_git(s) -- y de las marcas de git
      end
    end)
  end)
end

-- Abre un archivo en una ventana de edición (evita el explorador, paneles fijos,
-- netrw y flotantes)
local function open_file(s, path)
  local target
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    local b = api.nvim_win_get_buf(w)
    if w ~= s.win
      and api.nvim_win_get_config(w).relative == ""
      and not vim.wo[w].winfixwidth
      and vim.bo[b].filetype ~= "netrw"
      and vim.bo[b].filetype ~= "explorer"
    then
      target = w
      break
    end
  end
  if target then
    api.nvim_set_current_win(target)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  else
    api.nvim_set_current_win(s.win)
    vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(path))
  end
end

-- <CR>/l: expandir/colapsar carpeta o abrir archivo
local function on_enter()
  local s = cur()
  if not s then
    return
  end
  local n = node_at_cursor(s)
  if not n then
    return
  end
  if n.is_dir then
    s.expanded[n.path] = (not s.expanded[n.path]) or nil
    render(s)
  else
    open_file(s, n.path)
  end
end

-- h: colapsar la carpeta actual, o saltar al padre
local function on_collapse()
  local s = cur()
  if not s then
    return
  end
  local n = node_at_cursor(s)
  if not n then
    return
  end
  if n.is_dir and s.expanded[n.path] then
    s.expanded[n.path] = nil
    render(s)
    return
  end
  local lnum = api.nvim_win_get_cursor(s.win)[1]
  for i = lnum - 1, 1, -1 do
    local p = s.nodes[i - 1]
    if p and p.depth < n.depth then
      api.nvim_win_set_cursor(s.win, { i, 0 })
      return
    end
  end
end

-- -: subir un nivel (cambiar la raíz al directorio padre)
local function go_up()
  local s = cur()
  if not s then
    return
  end
  s.root = vim.fn.fnamemodify(s.root, ":h")
  render(s)
  start_watch(s)
  update_git(s) -- marcas de git
end

-- ── Operaciones de archivo (etapa 2) ───────────────────────────────
-- Directorio base según el nodo bajo el cursor (dentro de carpeta, o su padre)
local function dir_of(s)
  local n = node_at_cursor(s)
  if not n then
    return s.root
  end
  return n.is_dir and n.path or vim.fn.fnamemodify(n.path, ":h")
end

-- a: crear archivo (o carpeta si termina en /)
local function create()
  local s = cur()
  if not s then
    return
  end
  local base = dir_of(s)
  vim.ui.input({ prompt = "Crear (/ al final = carpeta): ", default = base .. "/", completion = "dir" }, function(input)
    if not input or input == "" or input:sub(-1) == ":" then
      return
    end
    if input:sub(-1) == "/" then
      vim.fn.mkdir(input, "p")
    else
      vim.fn.mkdir(vim.fn.fnamemodify(input, ":h"), "p")
      if vim.fn.filereadable(input) == 0 then
        vim.fn.writefile({}, input)
      end
    end
    s.expanded[base] = true
    render(s)
  end)
end

-- d: borrar el nodo bajo el cursor (con confirmación)
local function delete()
  local s = cur()
  if not s then
    return
  end
  local n = node_at_cursor(s)
  if not n then
    return
  end
  local kind = n.is_dir and "carpeta" or "archivo"
  if vim.fn.confirm("¿Borrar " .. kind .. " '" .. n.name .. "'?", "&Si\n&No", 2) ~= 1 then
    return
  end
  vim.fn.delete(n.path, n.is_dir and "rf" or "")
  render(s)
end

-- Si el archivo está abierto en un buffer, mover el buffer al nombre nuevo
local function rename_buf(old, new)
  local b = vim.fn.bufnr(old)
  if b > 0 and api.nvim_buf_is_valid(b) then
    pcall(api.nvim_buf_set_name, b, new)
  end
end

-- r: renombrar o mover (escribiendo una ruta distinta)
local function rename()
  local s = cur()
  if not s then
    return
  end
  local n = node_at_cursor(s)
  if not n then
    return
  end
  vim.ui.input({ prompt = "Renombrar/mover: ", default = n.path, completion = "file" }, function(input)
    if not input or input == "" or input == n.path then
      return
    end
    vim.fn.mkdir(vim.fn.fnamemodify(input, ":h"), "p")
    if vim.fn.rename(n.path, input) == 0 and not n.is_dir then
      rename_buf(n.path, input)
    end
    render(s)
  end)
end

-- x / p: cortar y pegar (mover) un nodo a la carpeta bajo el cursor
local cut_path = nil
local function cut()
  local n = node_at_cursor(cur())
  if n then
    cut_path = n.path
    vim.notify("Cortado: " .. n.name)
  end
end
local function paste()
  local s = cur()
  if not (s and cut_path) then
    return
  end
  local dest_dir = dir_of(s)
  local dest = dest_dir .. "/" .. vim.fn.fnamemodify(cut_path, ":t")
  if vim.fn.rename(cut_path, dest) == 0 then
    rename_buf(cut_path, dest)
    s.expanded[dest_dir] = true
  end
  cut_path = nil
  render(s)
end

-- Abre el explorador como panel lateral izquierdo (en la tab actual)
function M.open()
  local existing = cur()
  if existing and existing.win and api.nvim_win_is_valid(existing.win) then
    api.nvim_set_current_win(existing.win)
    return
  end

  -- Tras un :ReloadConfig el estado por-tab (states) se pierde, pero la ventana del
  -- explorador anterior sigue abierta. Cerrar cualquier explorador huérfano de la
  -- tab para no acumular paneles duplicados.
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    local b = api.nvim_win_get_buf(w)
    if api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "explorer" then
      pcall(api.nvim_win_close, w, true)
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end

  set_hl()

  local s = { root = vim.fn.getcwd(), expanded = {}, nodes = {} }
  states[api.nvim_get_current_tabpage()] = s

  s.buf = api.nvim_create_buf(false, true)
  vim.bo[s.buf].buftype = "nofile"
  vim.bo[s.buf].bufhidden = "hide" -- sobrevive al ocultarse (lo borramos en close)
  vim.bo[s.buf].swapfile = false
  vim.bo[s.buf].filetype = "explorer"

  vim.cmd("topleft vsplit")
  s.win = api.nvim_get_current_win()
  api.nvim_win_set_buf(s.win, s.buf)
  api.nvim_win_set_width(s.win, 35)
  local wo = vim.wo[s.win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.cursorline = true
  wo.winfixwidth = true
  wo.list = false

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = s.buf, silent = true, nowait = true })
  end
  map("<CR>", on_enter)
  map("l", on_enter)
  map("h", on_collapse)
  map("-", go_up)
  map("R", function()
    render(cur())
  end)
  map("q", M.close)
  map("<Tab>", "<Nop>")
  map("<S-Tab>", "<Nop>")
  -- operaciones de archivo
  map("a", create)
  map("d", delete)
  map("r", rename)
  map("x", cut)
  map("p", paste)
  -- copiar ruta del nodo bajo el cursor (como tenía netrw)
  map("y", function()
    local n = node_at_cursor(cur())
    if n then
      vim.fn.setreg("+", n.path)
      vim.notify("Copiado: " .. n.path)
    end
  end)
  map("Y", function()
    local n = node_at_cursor(cur())
    if n then
      local rel = vim.fn.fnamemodify(n.path, ":.")
      vim.fn.setreg("+", rel)
      vim.notify("Copiado: " .. rel)
    end
  end)

  render(s)
  start_watch(s)
  update_git(s) -- marcas de git
end

function M.close()
  local s = cur()
  if not s then
    return
  end
  stop_watch(s)
  for _, t in ipairs({ "timer", "git_timer" }) do
    if s[t] then
      pcall(function()
        s[t]:stop()
        s[t]:close()
      end)
      s[t] = nil
    end
  end
  if s.win and api.nvim_win_is_valid(s.win) then
    api.nvim_win_close(s.win, true)
  end
  if s.buf and api.nvim_buf_is_valid(s.buf) then
    pcall(api.nvim_buf_delete, s.buf, { force = true }) -- bufhidden=hide no se borra solo
  end
  states[api.nvim_get_current_tabpage()] = nil
end

function M.toggle()
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) then
    M.close()
  else
    M.open()
  end
end

-- Alterna el FOCO entre el explorador y la edición (como el viejo <leader>e)
function M.focus()
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    M.open() -- no está abierto: abrir (queda enfocado)
    return
  end
  if api.nvim_get_current_win() == s.win then
    -- estoy en el explorador -> ir a una ventana de edición
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      if w ~= s.win and api.nvim_win_get_config(w).relative == "" and not vim.wo[w].winfixwidth then
        api.nvim_set_current_win(w)
        return
      end
    end
  else
    api.nvim_set_current_win(s.win)
  end
end

-- Re-enraíza el explorador de la tab actual al cwd (para tcd/cambio de tab)
function M.follow()
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) and s.root ~= vim.fn.getcwd() then
    s.root = vim.fn.getcwd()
    render(s)
    start_watch(s)
    update_git(s)
  end
end

-- ¿la tab actual tiene solo el explorador (sin ventana de edición)?
local function only_explorer()
  local exp, other = false, false
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(w).relative == "" then
      if vim.bo[api.nvim_win_get_buf(w)].filetype == "explorer" then
        exp = true
      else
        other = true
      end
    end
  end
  return exp and not other
end

-- Refrescar al guardar (respaldo del watcher), solo si hay explorador en la tab
api.nvim_create_autocmd("BufWritePost", {
  group = group,
  callback = function()
    schedule_render(cur())
    schedule_git(cur()) -- el estado de git pudo cambiar
  end,
})

-- Limpiar estados (watchers/timers) de tabs cerradas
api.nvim_create_autocmd("TabClosed", {
  group = group,
  callback = function()
    for tab, s in pairs(states) do
      if not api.nvim_tabpage_is_valid(tab) then
        stop_watch(s)
        for _, t in ipairs({ "timer", "git_timer" }) do
          if s[t] then
            pcall(function()
              s[t]:stop()
              s[t]:close()
            end)
          end
        end
        if s.buf and api.nvim_buf_is_valid(s.buf) then
          pcall(api.nvim_buf_delete, s.buf, { force = true })
        end
        states[tab] = nil
      end
    end
  end,
})

-- El explorador sigue al cwd (tcd/cd/cambio de tab)
api.nvim_create_autocmd("DirChanged", {
  group = group,
  pattern = "*",
  callback = function()
    M.follow()
  end,
})

-- Expande las carpetas ancestro hasta revelar `s.current_file`
local function reveal(s)
  local target = s.current_file and normpath(s.current_file)
  if not target then
    return
  end
  local root = normpath(s.root)
  if target:sub(1, #root + 1) ~= root .. "/" then
    return -- el archivo no está bajo la raíz
  end
  local dir = s.root
  while normpath(dir) ~= target do
    local next_dir
    for _, e in ipairs(read_dir(dir)) do
      if e.is_dir then
        local child = dir .. "/" .. e.name
        local nc = normpath(child)
        if target == nc or target:sub(1, #nc + 1) == nc .. "/" then
          next_dir = child
          break
        end
      end
    end
    if not next_dir then
      break -- el archivo está directamente en `dir`
    end
    s.expanded[next_dir] = true
    dir = next_dir
  end
end

-- Resaltar y revelar en el árbol el archivo abierto en la ventana principal
api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    local s = cur()
    if not (s and s.win and api.nvim_win_is_valid(s.win)) then
      return
    end
    local name = api.nvim_buf_get_name(ev.buf)
    if vim.bo[ev.buf].buftype ~= "" or name == "" or vim.bo[ev.buf].filetype == "explorer" then
      return
    end
    if s.current_file ~= name then
      s.current_file = name
      reveal(s) -- expandir hasta el archivo
      render(s)
      -- mover el cursor del explorador al archivo (sin robar el foco)
      local target = normpath(name)
      for i, n in ipairs(s.nodes) do
        if not n.is_dir and normpath(n.path) == target then
          pcall(api.nvim_win_set_cursor, s.win, { i + 1, 0 }) -- +1 por la línea raíz
          break
        end
      end
    end
  end,
})

-- Si al cerrar una ventana queda SOLO el explorador, restaurar el dashboard
local rebuilding = false
api.nvim_create_autocmd("WinClosed", {
  group = group,
  callback = function()
    if rebuilding then
      return
    end
    vim.schedule(function()
      if rebuilding or not only_explorer() then
        return
      end
      local s = cur()
      if not (s and s.win and api.nvim_win_is_valid(s.win)) then
        return
      end
      rebuilding = true
      pcall(function()
        api.nvim_set_current_win(s.win)
        vim.cmd("noautocmd rightbelow vsplit") -- nueva ventana a la derecha del panel
        vim.cmd("noautocmd enew") -- buffer vacío (no el explorador) para el dashboard
        require("plugins.local.dashboard").open()
        if api.nvim_win_is_valid(s.win) then
          api.nvim_win_set_width(s.win, 35) -- restaurar ancho del panel
        end
        require("config.util").wipe_orphan_buffers()
      end)
      rebuilding = false
    end)
  end,
})

-- Corrige accidentes con `:e`:
--  A) un archivo/dir reemplaza el explorador en su ventana -> recuperarla
--  B) un :e <dir> abre un buffer de directorio en una ventana normal -> deshacer
api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(ev)
    local s = cur()
    if not (s and s.win and api.nvim_win_is_valid(s.win)) then
      return
    end
    local win = api.nvim_get_current_win()
    local buf = ev.buf
    local name = api.nvim_buf_get_name(buf)
    local is_dir = name ~= "" and vim.fn.isdirectory(name) == 1

    -- A) el explorador fue reemplazado en su propia ventana
    if win == s.win and buf ~= s.buf then
      vim.schedule(function()
        if not (api.nvim_win_is_valid(s.win) and s.buf and api.nvim_buf_is_valid(s.buf)) then
          return
        end
        api.nvim_win_set_buf(s.win, s.buf) -- devolver el explorador
        if not is_dir and name ~= "" then
          open_file(s, name) -- el archivo va a la principal
        end
      end)
      return
    end

    -- B) :e <dir> en una ventana normal -> volver al archivo anterior
    if is_dir and win ~= s.win then
      local alt = vim.fn.bufnr("#")
      local alt_ok = alt > 0
        and api.nvim_buf_is_valid(alt)
        and vim.bo[alt].buftype == ""
        and api.nvim_buf_get_name(alt) ~= ""
        and vim.fn.isdirectory(api.nvim_buf_get_name(alt)) == 0
      vim.schedule(function()
        if not api.nvim_win_is_valid(win) then
          return
        end
        if alt_ok then
          api.nvim_win_set_buf(win, alt)
        else
          api.nvim_set_current_win(win)
          require("plugins.local.dashboard").open()
        end
        if api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
          pcall(api.nvim_buf_delete, buf, { force = true })
        end
      end)
    end
  end,
})

return M
