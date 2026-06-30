-- Statusline tipo "framework": el motor (core) arma píldoras a partir de un
-- LAYOUT declarativo de componentes (components). La apariencia se agrupa en
-- PRESETS (border + layout + colores), elegibles en caliente. Para personalizar:
--   • presets / bordes / anchos / iconos  -> config.lua
--   • crear un componente nuevo            -> components.lua
--   • colores por defecto                  -> default_colors (abajo) + config.palette
local api = vim.api
local autocmd = api.nvim_create_autocmd
local palette = require("config.palette")
local theme = require("config.theme")
local core = require("plugins.local.statusline.core")
local C = require("plugins.local.statusline.components")
local cfg = require("plugins.local.statusline.config")

local M = {}

-- Estado activo (lo fija el preset): layout, borde, relleno y modo transparente
-- fill = nil significa "usar palette.bg dinámicamente" (mismo fondo que el editor);
-- un preset puede fijar su propio fill. Al dejarlo nil, apply_colors lee la paleta
-- fresca en cada ColorScheme y así la statusline sigue al tema activo.
local current = { layout = {}, border = "round", fill = nil, transparent = false }

-- ── Persistencia de la elección (preset + borde) entre sesiones ────
local prefs_file = vim.fn.stdpath("data") .. "/statusline.json"

-- Guarda el estado activo (preset y borde) para restaurarlo al reabrir Neovim
local function save_prefs()
  pcall(vim.fn.writefile, { vim.json.encode({ preset = cfg.preset, border = current.border }) }, prefs_file)
end

-- Lee las preferencias guardadas (o {} si no hay / están corruptas)
local function load_prefs()
  local ok, lines = pcall(vim.fn.readfile, prefs_file)
  if not ok or not lines or not lines[1] then
    return {}
  end
  local decoded_ok, prefs = pcall(vim.json.decode, lines[1])
  return (decoded_ok and type(prefs) == "table") and prefs or {}
end

-- ── Colores ────────────────────────────────────────────────────────
-- Cada preset puede traer su propio `colors(pair, palette)`; si no, se usan estos.
-- pair(grupo, fg, bg, opts?) define el grupo y su "<grupo>Sep" (medialunas).
local function default_colors(pair)
  pair("StNormal", palette.bg, palette.blue, { bold = true })
  pair("StInsert", palette.bg, palette.green, { bold = true })
  pair("StVisual", palette.bg, palette.purple, { bold = true })
  pair("StReplace", palette.bg, palette.red, { bold = true })
  pair("StCommand", palette.bg, palette.yellow, { bold = true })
  pair("StTerminal", palette.bg, palette.cyan, { bold = true })
  pair("StGit", palette.blue, palette.bg_highlight)
  pair("StFile", palette.fg, palette.bg_highlight)
  pair("StInfo", palette.fg, palette.bg_highlight)
  -- diagnósticos: color de severidad sobre el fondo de píldora "info"
  pair("StDiagError", palette.red, palette.bg_highlight)
  pair("StDiagWarn", palette.yellow, palette.bg_highlight)
  pair("StDiagInfo", palette.blue, palette.bg_highlight)
  pair("StDiagHint", palette.cyan, palette.bg_highlight)
end

local active_colors = default_colors -- función de colores del preset activo

-- Aplica los colores activos (más el relleno base). Se llama al cambiar de preset
-- y se registra en theme para reaplicarse en cada ColorScheme.
local function apply_colors()
  local transparent = current.transparent
  local fill = current.fill or palette.bg -- por defecto = fondo global del editor
  local hl = api.nvim_set_hl
  local function pair(name, fg, bg, opts)
    opts = opts or {}
    if transparent then
      -- sin fondo; el extremo fino se pinta con el color del TEXTO (no del fondo)
      opts.fg, opts.bg = fg, "NONE"
      hl(0, name, opts)
      hl(0, name .. "Sep", { fg = fg, bg = "NONE" })
    else
      opts.fg, opts.bg = fg, bg
      hl(0, name, opts)
      hl(0, name .. "Sep", { fg = bg, bg = fill })
    end
  end
  if not transparent then
    default_colors(pair, palette) -- base para presets con fondo sólido (resetea)
  end
  if active_colors and active_colors ~= default_colors then
    active_colors(pair, palette) -- el preset redefine los grupos que cambia
  end
  local base = transparent and "NONE" or fill
  hl(0, core.FILL, { bg = base }) -- relleno entre píldoras
  hl(0, "StatusLine", { bg = base }) -- base de la línea
end

-- ── Bordes ─────────────────────────────────────────────────────────
local function apply_border(name)
  local b = cfg.borders[name] or cfg.borders.round
  core.set_caps(b.left, b.right)
  current.border = cfg.borders[name] and name or "round"
end

function M.borders()
  return vim.tbl_keys(cfg.borders)
end

-- Cambia solo el estilo de borde (eje rápido, independiente del preset)
function M.set_border(name)
  if not cfg.borders[name] then
    return false
  end
  apply_border(name)
  save_prefs()
  vim.cmd("redrawstatus | redrawtabline")
  return true
end

-- Pasa al siguiente borde (orden alfabético estable)
function M.cycle()
  local names = M.borders()
  table.sort(names)
  local i = 1
  for k, n in ipairs(names) do
    if n == current.border then
      i = k
    end
  end
  M.set_border(names[(i % #names) + 1])
end

-- ── Presets (border + layout + colores) ────────────────────────────
function M.presets()
  return vim.tbl_keys(cfg.presets)
end

-- Aplica un preset completo: layout, colores y borde. Redibuja.
function M.set_preset(name)
  local p = cfg.presets[name]
  if not p then
    return false
  end
  cfg.preset = name
  if p.layout then
    current.layout = p.layout
  end
  current.fill = p.fill -- nil = seguir palette.bg dinámicamente
  current.transparent = p.transparent or false
  active_colors = p.colors or default_colors
  apply_colors()
  if p.border then
    apply_border(p.border)
  end
  save_prefs()
  vim.cmd("redrawstatus | redrawtabline")
  return true
end

-- ── Render ─────────────────────────────────────────────────────────
function _G.statusline()
  return core.build(current.layout, C.components, C.context)
end

-- ── Pickers (reutilizan el picker genérico con preview + restaurar) ──
-- Selector de borde (solo cambia los extremos)
function M.pick()
  local original = current.border
  local names = M.borders()
  table.sort(names)
  require("plugins.local.picker").pick({
    title = "Borde de la statusline",
    items = names,
    on_move = function(name)
      if name then
        M.set_border(name)
      end
    end,
    on_select = function(name)
      if name then
        M.set_border(name)
      end
    end,
    on_cancel = function()
      M.set_border(original)
    end,
  })
end

-- Selector de preset completo (border + layout + colores)
function M.pick_preset()
  local original = cfg.preset
  local names = M.presets()
  table.sort(names)
  require("plugins.local.picker").pick({
    title = "Preset de statusline",
    items = names,
    on_move = function(name)
      if name then
        M.set_preset(name)
      end
    end,
    on_select = function(name)
      if name then
        M.set_preset(name)
      end
    end,
    on_cancel = function()
      M.set_preset(original)
    end,
  })
end

-- ── Fuente de datos: rama de git (async, cacheada en vim.b.gitbranch) ──
local function update_git(buf)
  if vim.fn.executable("git") == 0 then
    return
  end
  buf = buf or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then
    return -- el buffer pudo invalidarse (p. ej. al cambiar de directorio)
  end
  local name = api.nvim_buf_get_name(buf)
  local dir = name ~= "" and vim.fn.fnamemodify(name, ":h") or vim.fn.getcwd()

  vim.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }, function(res)
    local branch = (res.code == 0) and vim.trim(res.stdout or "") or ""
    vim.schedule(function()
      if api.nvim_buf_is_valid(buf) and vim.b[buf].gitbranch ~= branch then
        vim.b[buf].gitbranch = branch
        vim.cmd("redrawstatus | redrawtabline")
      end
    end)
  end)
end

-- ── Activación ─────────────────────────────────────────────────────
theme.register(apply_colors) -- reaplica los colores del preset activo en ColorScheme

-- Restaurar la elección guardada (preset + borde); si no hay o es inválida, usar
-- el preset por defecto de config.lua.
local prefs = load_prefs()
if not (prefs.preset and M.set_preset(prefs.preset)) then
  M.set_preset(cfg.preset) -- fija layout + colores + borde del preset inicial
end
if prefs.border then
  M.set_border(prefs.border) -- restaurar el borde exacto (eje independiente del preset)
end
vim.o.laststatus = 3 -- una sola statusline global
vim.o.statusline = "%!v:lua.statusline()"

api.nvim_create_user_command("StatuslineBorder", function(o)
  if not M.set_border(o.args) then
    vim.notify("Borde desconocido: " .. o.args, vim.log.levels.WARN)
  end
end, {
  nargs = 1,
  complete = M.borders,
  desc = "Cambiar el borde de la statusline",
})

api.nvim_create_user_command("StatuslinePreset", function(o)
  if not M.set_preset(o.args) then
    vim.notify("Preset desconocido: " .. o.args, vim.log.levels.WARN)
  end
end, {
  nargs = 1,
  complete = M.presets,
  desc = "Cambiar el preset de la statusline",
})

local group = api.nvim_create_augroup("Statusline", { clear = true })

autocmd({ "BufEnter", "FocusGained", "DirChanged", "BufWritePost" }, {
  group = group,
  desc = "Actualizar rama de git",
  callback = function(ev)
    update_git(ev.buf)
  end,
})

autocmd("DiagnosticChanged", {
  group = group,
  desc = "Redibujar la statusline al cambiar los diagnósticos",
  callback = function()
    vim.cmd("redrawstatus | redrawtabline")
  end,
})

return M
