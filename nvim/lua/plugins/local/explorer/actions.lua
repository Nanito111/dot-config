-- Acciones del usuario: abrir archivo, navegación, operaciones de archivo y
-- copiar ruta. Más el helper de layout `only_explorer`.
local api = vim.api
local state = require("plugins.local.explorer.state")
local render = require("plugins.local.explorer.render")
local watch = require("plugins.local.explorer.watch")
local git = require("plugins.local.explorer.git")

local cur = state.cur
local node_at_cursor = render.node_at_cursor

local M = {}

-- Abre un archivo en una ventana de edición (evita el explorador, paneles fijos,
-- netrw y flotantes)
function M.open_file(s, path)
  local target
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    local b = api.nvim_win_get_buf(w)
    if
      w ~= s.win
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

-- ¿la tab actual tiene solo el explorador (sin ventana de edición)?
function M.only_explorer()
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

-- <CR>/l: expandir/colapsar carpeta o abrir archivo
function M.on_enter()
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
    render.render(s)
  else
    M.open_file(s, n.path)
  end
end

-- h: colapsar la carpeta actual, o saltar al padre
function M.on_collapse()
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
    render.render(s)
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
function M.go_up()
  local s = cur()
  if not s then
    return
  end
  s.root = vim.fn.fnamemodify(s.root, ":h")
  render.render(s)
  watch.start_watch(s)
  git.update_git(s) -- marcas de git
end

-- ── Operaciones de archivo ─────────────────────────────────────────
-- Directorio base según el nodo bajo el cursor (dentro de carpeta, o su padre)
local function dir_of(s)
  local n = node_at_cursor(s)
  if not n then
    return s.root
  end
  return n.is_dir and n.path or vim.fn.fnamemodify(n.path, ":h")
end

-- Si el archivo está abierto en un buffer, mover el buffer al nombre nuevo
local function rename_buf(old, new)
  local b = vim.fn.bufnr(old)
  if b > 0 and api.nvim_buf_is_valid(b) then
    pcall(api.nvim_buf_set_name, b, new)
  end
end

-- a: crear archivo (o carpeta si termina en /)
function M.create()
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
    render.render(s)
  end)
end

-- d: borrar el nodo bajo el cursor (con confirmación)
function M.delete()
  local s = cur()
  if not s then
    return
  end
  local n = node_at_cursor(s)
  if not n then
    return
  end
  local kind = n.is_dir and "carpeta" or "archivo"
  local confirm = require("plugins.local.confirm").confirm
  if confirm("¿Borrar " .. kind .. " '" .. n.name .. "'?", "&Si\n&No", 2) ~= 1 then
    return
  end
  vim.fn.delete(n.path, n.is_dir and "rf" or "")
  render.render(s)
end

-- r: renombrar o mover (escribiendo una ruta distinta)
function M.rename()
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
    render.render(s)
  end)
end

-- x/c + p: cortar/copiar y pegar en la carpeta bajo el cursor.
-- clip = { path = <ruta>, op = "cut" | "copy" }
local clip = nil
local uv = vim.uv or vim.loop

function M.cut()
  local n = node_at_cursor(cur())
  if n then
    clip = { path = n.path, op = "cut" }
    vim.notify("Cortado: " .. n.name)
  end
end

function M.copy()
  local n = node_at_cursor(cur())
  if n then
    clip = { path = n.path, op = "copy" }
    vim.notify("Copiado: " .. n.name)
  end
end

-- Copia recursiva (archivo o carpeta) con vim.uv (multiplataforma)
local function copy_recursive(src, dest)
  local st = uv.fs_stat(src)
  if not st then
    return false
  end
  if st.type == "directory" then
    vim.fn.mkdir(dest, "p")
    local h = uv.fs_scandir(src)
    while h do
      local name = uv.fs_scandir_next(h)
      if not name then
        break
      end
      if not copy_recursive(src .. "/" .. name, dest .. "/" .. name) then
        return false
      end
    end
    return true
  end
  return uv.fs_copyfile(src, dest) and true or false
end

-- Ruta de destino sin colisión: si ya existe, añade " copy" (útil al duplicar en la
-- misma carpeta sin sobrescribir el original)
local function unique_dest(dir, name)
  if not uv.fs_stat(dir .. "/" .. name) then
    return dir .. "/" .. name
  end
  local base, ext = name:match("^(.-)%.([^.]+)$")
  if not base then
    base, ext = name, nil
  end
  local i = 1
  while true do
    local suffix = (i == 1) and " copy" or (" copy " .. i)
    local cand = dir .. "/" .. base .. suffix .. (ext and ("." .. ext) or "")
    if not uv.fs_stat(cand) then
      return cand
    end
    i = i + 1
  end
end

function M.paste()
  local s = cur()
  if not (s and clip) then
    return
  end
  local dest_dir = dir_of(s)
  local name = vim.fn.fnamemodify(clip.path, ":t")
  if clip.op == "cut" then
    local dest = dest_dir .. "/" .. name
    if vim.fn.rename(clip.path, dest) == 0 then
      rename_buf(clip.path, dest)
      s.expanded[dest_dir] = true
    end
    clip = nil -- mover es de un solo uso
  else -- copy
    if copy_recursive(clip.path, unique_dest(dest_dir, name)) then
      s.expanded[dest_dir] = true
    end
    -- se conserva clip: puedes pegar la copia en varias carpetas
  end
  render.render(s)
end

-- y / Y: copiar al portapapeles la ruta del nodo (absoluta o relativa al cwd)
function M.copy_path(relative)
  local n = node_at_cursor(cur())
  if not n then
    return
  end
  local p = relative and vim.fn.fnamemodify(n.path, ":.") or n.path
  vim.fn.setreg("+", p)
  vim.notify("Copiado: " .. p)
end

return M
