-- Indentación POR TIPO DE ARCHIVO, centralizada. Antes cada ftplugin llamaba a
-- config.ft.indent(); ahora esto es la fuente única: un default por filetype + los
-- overrides del usuario (editables en la tabla del panel de configuración), aplicados a
-- cada buffer en FileType. Solo se persiste lo que difiere del default (vía config.settings).
local api = vim.api
local ft_util = require("config.ft")
local M = {}

local function spaces(n)
  return { width = n, expand = true }
end
local function tabs(n)
  return { width = n, expand = false }
end

-- Defaults por filetype (replican lo que hacían los ftplugin)
M.DEFAULTS = {
  css = spaces(2),
  html = spaces(2),
  scss = spaces(2),
  javascript = spaces(2),
  javascriptreact = spaces(2),
  typescript = spaces(2),
  typescriptreact = spaces(2),
  json = spaces(2),
  jsonc = spaces(2),
  lua = spaces(2),
  sh = spaces(2),
  yaml = spaces(2),
  markdown = spaces(2),
  python = spaces(4),
  go = tabs(4),
}
M.GLOBAL_DEFAULT = spaces(4) -- el de options.lua

-- Etiqueta de la fila global en la tabla (no es un filetype real)
M.GLOBAL = "(global)"

-- ── Overrides persistidos (config.settings, overrides-only) ────────
-- Mapa de filetype -> {width,expand} que difiere del DEFAULT, y el override global.
local function load_overrides()
  return vim.deepcopy(require("config.settings").value("indent.ft", {}))
end
local function load_global()
  return require("config.settings").value("indent.global", nil)
end

local overrides = nil -- cache; nil = aún no cargado
local function ov()
  if overrides == nil then
    overrides = load_overrides()
  end
  return overrides
end

local function eq(a, b)
  return a and b and a.width == b.width and a.expand == b.expand
end

local function global_effective()
  return load_global() or M.GLOBAL_DEFAULT
end

-- Indentación efectiva de un filetype: override -> default del ft -> global
function M.effective(ft)
  return ov()[ft] or M.DEFAULTS[ft] or global_effective()
end

-- ── Aplicación ─────────────────────────────────────────────────────
function M.apply(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  local e = M.effective(vim.bo[buf].filetype)
  ft_util.indent(e.width, e.expand, buf)
end

-- Aplica a todos los buffers abiertos de un filetype (nil = todos)
local function apply_ft(ft)
  for _, b in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(b) and (ft == nil or vim.bo[b].filetype == ft) then
      M.apply(b)
    end
  end
end

-- ── Edición + persistencia ─────────────────────────────────────────
local function persist()
  require("config.settings").record("indent.ft", ov(), {})
end

-- Fija (o resetea) la indentación de un filetype. Si iguala el default, borra el override.
function M.set(ft, val)
  if eq(val, M.DEFAULTS[ft]) then
    ov()[ft] = nil
  else
    ov()[ft] = { width = val.width, expand = val.expand }
  end
  persist()
  apply_ft(ft)
end

-- Quita el override de un filetype (vuelve al default o al global)
function M.remove(ft)
  ov()[ft] = nil
  persist()
  apply_ft(ft)
end

-- Fija la indentación global (fila "(global)"): base para los filetypes sin regla propia
function M.set_global(val)
  require("config.settings").record("indent.global", { width = val.width, expand = val.expand }, M.GLOBAL_DEFAULT)
  local g = global_effective()
  vim.o.expandtab = g.expand
  vim.o.shiftwidth = g.width
  vim.o.tabstop = g.width
  vim.o.softtabstop = g.expand and g.width or 0
  apply_ft(nil) -- recalcular todos (los que dependen del global cambian)
end

-- ── Filas para la tabla ────────────────────────────────────────────
function M.rows()
  local g = global_effective()
  local rows = {
    { ft = M.GLOBAL, is_global = true, width = g.width, expand = g.expand, overridden = load_global() ~= nil },
  }
  local seen, names = {}, {}
  for name in pairs(M.DEFAULTS) do
    seen[name] = true
  end
  for name in pairs(ov()) do
    seen[name] = true
  end
  for name in pairs(seen) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local e = M.effective(name)
    rows[#rows + 1] = { ft = name, width = e.width, expand = e.expand, overridden = ov()[name] ~= nil }
  end
  return rows
end

-- ── Arranque ───────────────────────────────────────────────────────
function M.setup()
  overrides = load_overrides()
  local g = global_effective()
  vim.o.expandtab = g.expand
  vim.o.shiftwidth = g.width
  vim.o.tabstop = g.width
  vim.o.softtabstop = g.expand and g.width or 0
  apply_ft(nil) -- buffers ya abiertos (sesiones / :ReloadConfig)
end

api.nvim_create_autocmd("FileType", {
  group = api.nvim_create_augroup("Indent", { clear = true }),
  desc = "Aplicar la indentación por tipo de archivo",
  callback = function(a)
    M.apply(a.buf)
  end,
})

M.setup()

return M
