-- Dibujo del árbol: highlights, marcas de git, construcción de nodos, render,
-- nodo bajo el cursor y "revelar" (expandir hasta el archivo actual).
local api = vim.api
local icons = require("config.icons")
local palette = require("config.palette")
local theme = require("config.theme")
local state = require("plugins.local.explorer.state")
local util = require("plugins.local.explorer.util")

local ns = state.ns
local FOLDER_CLOSED, FOLDER_OPEN = state.FOLDER_CLOSED, state.FOLDER_OPEN
local normpath, read_dir = util.normpath, util.read_dir

local M = {}

local function set_hl()
  local hl = api.nvim_set_hl
  hl(0, "ExplorerDir", { fg = palette.blue, bold = true })
  hl(0, "ExplorerFile", { fg = palette.fg })
  hl(0, "ExplorerRoot", { fg = palette.yellow, bold = true })
  -- archivo actual: fondo de línea sutil (acento mezclado hacia el fondo), sin tocar el texto
  hl(0, "ExplorerCurrentLine", { bg = palette.blue, fg = palette.bg})
  hl(0, "ExplorerGitNew", { fg = palette.cyan }) -- sin trackear (distinto del verde de añadido)
end

-- Define los grupos ahora y los reaplica en ColorScheme.
theme.register(set_hl)

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

-- Construye la lista de nodos visibles (recursivo según lo expandido). Con s.dirs_only solo
-- se incluyen carpetas (modo selector de carpetas).
local function build(s, path, depth, out)
  for _, e in ipairs(read_dir(path)) do
    if e.is_dir or not s.dirs_only then
      local full = path .. "/" .. e.name
      out[#out + 1] = { path = full, name = e.name, is_dir = e.is_dir, depth = depth }
      if e.is_dir and s.expanded[full] then
        build(s, full, depth + 1, out)
      end
    end
  end
end

-- Grupo de highlight para un color de icono (estilo devicons)
local function icon_color_group(col)
  local name = "ExpIcon_" .. col:gsub("#", "")
  api.nvim_set_hl(0, name, { fg = col })
  return name
end

-- Dibuja el árbol en el buffer de `s`
-- `reuse` = true reaprovecha s.nodes sin re-escanear el disco (build): solo re-pinta.
-- Útil cuando la estructura no cambió (p. ej. al abrir un archivo ya visible, para mover
-- el resaltado de la línea actual) — clave en FS lentos como /mnt/c (WSL).
function M.render(s, reuse)
  if not (s and s.buf and api.nvim_buf_is_valid(s.buf)) then
    return
  end
  if not reuse then
    s.nodes = {}
    build(s, s.root, 0, s.nodes)
  end
  local colored = vim.g.explorer_colored_icons
  local current = s.current_file and normpath(s.current_file) or nil

  local lines = { " " .. FOLDER_OPEN .. " " .. vim.fn.fnamemodify(s.root, ":t") .. "/" }
  local hls = {} -- por nodo: { icon_end, name_end (bytes), icon_hl, type_hl, git_hl }
  for _, n in ipairs(s.nodes) do
    local indent = string.rep("  ", n.depth + 1)
    local icon = n.is_dir and (s.expanded[n.path] and FOLDER_OPEN or FOLDER_CLOSED) or icons.icon(n.name)
    local prefix = indent .. icon .. " " -- indentación + icono de tipo + espacio
    local name = n.name .. (n.is_dir and "/" or "")

    local type_hl = n.is_dir and "ExplorerDir" or "ExplorerFile"
    local is_current = not n.is_dir and current and normpath(n.path) == current
    local icon_hl = type_hl
    if colored and not n.is_dir then
      local col = icons.color(n.name)
      if col then
        icon_hl = icon_color_group(col)
      end
    end

    -- marca de git ANTES del nombre: prefijo(icono) + [marca git] + nombre
    local git_part, git_hl, git_len = "", nil, 0
    local st = s.git and s.git[normpath(n.path)]
    if st then
      local sym, hlg = git_mark(st, n.is_dir)
      git_part = sym .. " "
      git_hl = hlg
      git_len = #sym
    end

    lines[#lines + 1] = prefix .. git_part .. name
    hls[#hls + 1] = {
      icon_end = #indent + #icon,
      git_start = #prefix, -- la marca de git empieza tras el espacio del icono
      git_end = #prefix + git_len,
      name_start = #prefix + #git_part, -- el nombre empieza tras la marca (si hay)
      icon_hl = icon_hl,
      type_hl = type_hl,
      git_hl = git_hl,
      is_current = is_current,
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
  api.nvim_buf_set_extmark(s.buf, ns, 0, 0, {
    end_row = 1,
    end_col = 0,
    hl_group = "ExplorerRoot",
  })
  for i, h in ipairs(hls) do
    -- archivo actual: fondo de toda la línea (el texto conserva su color)
    if h.is_current then
      api.nvim_buf_set_extmark(s.buf, ns, i, 0, { line_hl_group = "ExplorerCurrentLine" })
    end
    -- icono
    api.nvim_buf_set_extmark(s.buf, ns, i, 0, {
      end_col = h.icon_end,
      hl_group = h.icon_hl,
    })
    -- marca git
    if h.git_hl then
      api.nvim_buf_set_extmark(s.buf, ns, i, h.git_start, {
        end_col = h.git_end,
        hl_group = h.git_hl,
      })
    end
    -- nombre (hasta fin de línea)
    api.nvim_buf_set_extmark(s.buf, ns, i, h.name_start, {
      end_row = i + 1,
      end_col = 0,
      hl_group = h.type_hl,
    })
  end

  if cursor then
    cursor[1] = math.max(1, math.min(cursor[1], #lines))
    pcall(api.nvim_win_set_cursor, s.win, cursor)
  end

  -- Ajustar los watchers a las carpetas ahora visibles (raíz + expandidas). require
  -- perezoso: watch.lua depende de render, así que no se puede requerir arriba. Un selector
  -- transitorio (dirs_only) no vigila el disco.
  if not s.dirs_only then
    pcall(function()
      require("plugins.local.explorer.watch").reconcile(s)
    end)
  end
end

function M.node_at_cursor(s)
  local lnum = api.nvim_win_get_cursor(s.win)[1]
  return s.nodes[lnum - 1] -- la línea 1 es la raíz, no es nodo
end

-- Expande las carpetas ancestro hasta revelar `s.current_file`
function M.reveal(s)
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

return M
