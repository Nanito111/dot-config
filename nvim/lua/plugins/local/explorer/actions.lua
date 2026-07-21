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

-- Ruta relativa al cwd para mostrar en los prompts (más corta): "" si es el propio
-- cwd, la parte relativa si está dentro, o la ruta absoluta si queda fuera del cwd.
local function rel_cwd(path)
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("/$", "")
  local abs = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  if abs == cwd then
    return ""
  elseif abs:sub(1, #cwd + 1) == cwd .. "/" then
    return abs:sub(#cwd + 2)
  end
  return abs -- fuera del cwd: se muestra la ruta absoluta completa
end

-- Si el archivo está abierto en un buffer, mover el buffer al nombre nuevo
local function rename_buf(old, new)
  local b = vim.fn.bufnr(old)
  if b > 0 and api.nvim_buf_is_valid(b) then
    pcall(api.nvim_buf_set_name, b, new)
  end
end

-- Tras renombrar/mover una CARPETA: reapuntar los buffers abiertos que colgaban de ella y,
-- si el cwd caía dentro, seguirlo (si no, queda colgado y cualquier vim.system peta).
local function rename_dir_buffers(old, new)
  local oldp = vim.fn.fnamemodify(old, ":p"):gsub("/$", "")
  local newp = vim.fn.fnamemodify(new, ":p"):gsub("/$", "")
  for _, b in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(b) then
      local name = api.nvim_buf_get_name(b)
      if name == oldp or name:sub(1, #oldp + 1) == oldp .. "/" then
        pcall(api.nvim_buf_set_name, b, newp .. name:sub(#oldp + 1))
      end
    end
  end
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("/$", "")
  if cwd == oldp or cwd:sub(1, #oldp + 1) == oldp .. "/" then
    pcall(vim.cmd.cd, newp .. cwd:sub(#oldp + 1))
  end
end

-- a: crear archivo (o carpeta si termina en /)
function M.create()
  local s = cur()
  if not s then
    return
  end
  local base = dir_of(s)
  -- prompt con la ruta relativa al cwd (más corta); "" si es el propio cwd
  local rel = rel_cwd(base)
  local default = (rel ~= "" and rel .. "/") or ""
  vim.ui.input({ prompt = "Crear (/ al final = carpeta): ", default = default, completion = "dir" }, function(input)
    if not input or input == "" or input:sub(-1) == ":" then
      return
    end
    local is_dir = input:sub(-1) == "/"
    local path = vim.fn.fnamemodify(input, ":p") -- resolver (relativo al cwd) a absoluto
    if is_dir then
      vim.fn.mkdir(path, "p")
    else
      vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
      if vim.fn.filereadable(path) == 0 then
        vim.fn.writefile({}, path)
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
  vim.ui.input({ prompt = "Renombrar/mover: ", default = rel_cwd(n.path), completion = "file" }, function(input)
    if not input or input == "" then
      return
    end
    local target = vim.fn.fnamemodify(input, ":p") -- resolver (relativo al cwd) a absoluto
    if target == vim.fn.fnamemodify(n.path, ":p") then
      return -- sin cambios
    end
    vim.fn.mkdir(vim.fn.fnamemodify(target, ":h"), "p")
    if vim.fn.rename(n.path, target) == 0 then
      if n.is_dir then
        rename_dir_buffers(n.path, target) -- reapuntar buffers/cwd que colgaban de la carpeta
      else
        rename_buf(n.path, target)
      end
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
