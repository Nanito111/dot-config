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

-- ── Persistencia (preset + borde) vía config.settings ──────────────
-- El preset y el borde son ejes independientes: se guardan como dos claves. Solo se
-- persiste lo que difiere del default (lo gestiona config.settings).
local function save_prefs()
  local settings = require("config.settings")
  settings.record("ui.statusline_preset", cfg.preset)
  settings.record("ui.statusline_border", current.border)
end

-- ── Colores ────────────────────────────────────────────────────────
-- Cada preset puede traer su propio `colors(pair, palette)`; si no, se usan estos.
-- pair(grupo, fg, bg, opts?) define el grupo y su "<grupo>Sep" (medialunas).
local function default_colors(pair, p)
  p = p or palette
  pair("StNormal", p.bg, p.blue, { bold = true })
  pair("StInsert", p.bg, p.green, { bold = true })
  pair("StVisual", p.bg, p.purple, { bold = true })
  pair("StReplace", p.bg, p.red, { bold = true })
  pair("StCommand", p.bg, p.yellow, { bold = true })
  pair("StTerminal", p.bg, p.cyan, { bold = true })
  pair("StGit", p.blue, p.bg_highlight)
  pair("StFile", p.fg, p.bg_highlight)
  pair("StInfo", p.fg, p.bg_highlight)
  -- diagnósticos: color de severidad sobre el fondo de píldora "info"
  pair("StDiagError", p.red, p.bg_highlight)
  pair("StDiagWarn", p.yellow, p.bg_highlight)
  pair("StDiagInfo", p.blue, p.bg_highlight)
  pair("StDiagHint", p.cyan, p.bg_highlight)
end

local active_colors = default_colors -- función de colores del preset activo

-- Aplica los colores activos (más el relleno base). Se llama al cambiar de preset
-- y se registra en theme para reaplicarse en cada ColorScheme.
local function apply_colors()
  local transparent = current.transparent
  -- fill puede ser un color fijo o una FUNCIÓN del palette (para seguir el tema);
  -- se resuelve aquí, que corre en cada ColorScheme con la paleta fresca.
  local fill = current.fill
  if type(fill) == "function" then
    fill = fill(palette)
  end
  fill = fill or palette.bg -- por defecto = fondo global del editor
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

  -- Sub-grupos coloreados que van DENTRO de una píldora (contador de git y
  -- diagnósticos): comparten el fondo de SU píldora (StGit / StInfo) y solo cambian el
  -- color del texto, para que el fondo sea uniforme sea cual sea el preset. En presets
  -- `mono` (barra de color sólido: vscode/vscode_mono/blocky) NO se aplica el acento de
  -- color —los contadores usan el color del TEXTO de la píldora—, porque colores como el
  -- azul del info o el cian del hint se confundirían con el fondo azulado y no se verían.
  local function tint(pill_group, defs)
    local ok, ph = pcall(api.nvim_get_hl, 0, { name = pill_group, link = false })
    local bg = (ok and ph.bg) and string.format("#%06x", ph.bg) or "NONE"
    local mono_fg = (ok and ph.fg) and string.format("#%06x", ph.fg) or nil
    for name, fg in pairs(defs) do
      hl(0, name, { fg = current.mono and mono_fg or fg, bg = bg })
    end
  end
  tint("StGit", { StGitAdd = palette.green, StGitChange = palette.blue, StGitDelete = palette.red })
  tint("StInfo", {
    StDiagError = palette.diag_error,
    StDiagWarn = palette.diag_warn,
    StDiagInfo = palette.diag_info,
    StDiagHint = palette.diag_hint,
  })
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
  return cfg.preset_names
end

-- Preset activo (para el panel de configuración)
function M.current_preset()
  return cfg.preset
end

-- Aplica un preset completo: layout, colores y borde. Redibuja. Con persist=false solo
-- aplica sin guardar (vista previa del panel).
function M.set_preset(name, persist)
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
  current.mono = p.mono or false -- sin acento de color (contadores en el color del texto)
  active_colors = p.colors or default_colors
  apply_colors()
  if p.border then
    apply_border(p.border)
  end
  if persist ~= false then
    save_prefs()
  end
  vim.cmd("redrawstatus | redrawtabline")
  return true
end

-- ── Render ─────────────────────────────────────────────────────────
-- Con laststatus=3 la línea es única y se construye con la ventana ACTUAL. Si el foco
-- está en un flotante (picker, Mason, hover…), sus componentes pasarían a describir ESE
-- buffer: posición, porcentaje, modo… Además de no aportar nada, se recalculan a cada
-- movimiento del cursor del flotante (Mason mueve el suyo al redibujar el spinner), y
-- repintar la línea bajo una capa translúcida hace parpadear la pantalla. Mientras haya
-- un flotante enfocado se reutiliza el último render de una ventana normal.
local last_line = ""

function _G.statusline()
  if api.nvim_win_get_config(api.nvim_get_current_win()).relative ~= "" then
    return last_line
  end
  last_line = core.build(current.layout, C.components, C.context)
  return last_line
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

-- ── Fuente de datos: rama de git del WORKSPACE (cwd de la tab, async) ──
-- Depende del cwd (no del archivo) y se guarda POR TAB (vim.t.gitbranch): cada
-- workspace muestra la rama de su cwd, siempre visible. Si el cwd no es un repo,
-- queda "" y el componente se oculta.
-- Guarda rama + ahead/behind en variables de la tab; redibuja si algo cambió.
local function set_git(tab, branch, ahead, behind)
  vim.schedule(function()
    if not api.nvim_tabpage_is_valid(tab) then
      return
    end
    local changed = false
    local function tset(name, val)
      local ok, curv = pcall(api.nvim_tabpage_get_var, tab, name)
      if not ok or curv ~= val then
        api.nvim_tabpage_set_var(tab, name, val)
        changed = true
      end
    end
    tset("gitbranch", branch)
    tset("gitahead", ahead)
    tset("gitbehind", behind)
    if changed then
      vim.cmd("redrawstatus | redrawtabline")
    end
  end)
end

local function update_git()
  if vim.fn.executable("git") == 0 then
    return
  end
  local tab = api.nvim_get_current_tabpage()
  local dir = vim.fn.getcwd() -- cwd efectivo de la tab (respeta tcd del workspace)

  vim.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }, function(res)
    local branch = (res.code == 0) and vim.trim(res.stdout or "") or ""
    if branch == "" then
      return set_git(tab, "", 0, 0) -- el cwd no es un repo
    end
    -- ahead/behind vs upstream: "left\tright" = detrás\tadelante (0 si no hay upstream)
    vim.system(
      { "git", "-C", dir, "rev-list", "--left-right", "--count", "@{upstream}...HEAD" },
      { text = true },
      function(r2)
        local behind, ahead = 0, 0
        if r2.code == 0 then
          local bh, ah = (r2.stdout or ""):match("(%d+)%s+(%d+)")
          behind, ahead = tonumber(bh) or 0, tonumber(ah) or 0
        end
        set_git(tab, branch, ahead, behind)
      end
    )
  end)
end

-- ── Activación ─────────────────────────────────────────────────────
theme.register(apply_colors) -- reaplica los colores del preset activo en ColorScheme

-- Restaurar la elección guardada (preset + borde); si no hay o es inválida, usar el
-- preset por defecto de config.lua. persist=false: no reescribir el json al arrancar.
local settings = require("config.settings")
local saved_preset = settings.value("ui.statusline_preset", cfg.preset)
if not M.set_preset(saved_preset, false) then
  M.set_preset(cfg.preset, false) -- fija layout + colores + borde del preset inicial
end
local saved_border = settings.value("ui.statusline_border")
if saved_border then
  M.set_border(saved_border) -- restaurar el borde exacto (eje independiente del preset)
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

-- Debounce: al cambiar de workspace, TabEnter y DirChanged se disparan juntos, y cada
-- update_git lanza 1-2 procesos git (caro en WSL). Se coalescen en un único update diferido,
-- fuera de la ruta crítica del switch (la rama ya se muestra desde la caché por-tab).
local git_timer
local function schedule_git()
  if not git_timer then
    git_timer = vim.uv.new_timer()
  end
  git_timer:stop()
  git_timer:start(30, 0, vim.schedule_wrap(update_git))
end

-- Actualizar la rama según el cwd: al cambiar de directorio, cambiar de workspace
-- (tab), recuperar el foco (por si cambió la rama fuera), guardar, o salir/cerrar una
-- terminal embebida (capta commits/pull hechos en :terminal o lazygit).
autocmd({ "DirChanged", "TabEnter", "FocusGained", "BufWritePost", "TermLeave", "TermClose" }, {
  group = group,
  desc = "Actualizar la rama de git del workspace (cwd)",
  callback = schedule_git,
})
update_git() -- rama inicial de la tab actual

autocmd("DiagnosticChanged", {
  group = group,
  desc = "Redibujar la statusline al cambiar los diagnósticos",
  callback = function()
    -- APLAZADO, no en el propio evento: quien fija los diagnósticos puede estar a mitad
    -- de su render (Mason reemplaza las líneas, fija diagnósticos y SOLO DESPUÉS reaplica
    -- sus highlights). Un redraw síncrono aquí vacía la pantalla a medio pintar -> la UI
    -- de Mason parpadea. En el siguiente tick del bucle ya está todo dibujado.
    vim.schedule(function()
      vim.cmd("redrawstatus | redrawtabline")
    end)
  end,
})

return M
