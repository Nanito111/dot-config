-- Almacén central de configuración + registro para el panel (:Settings, <leader>uu).
-- Un ÚNICO settings.json guarda SOLO los valores distintos del default: al arrancar cada
-- proveedor pide el suyo con value(id, default) y solo "pesan" las opciones cambiadas.
-- Volver una opción a su default borra su clave del json.
--
-- Dos capas:
--   • store (value/record) — puro I/O sobre el json, sin dependencias. Lo usan los
--     proveedores en su arranque/set, así que es seguro llamarlo muy temprano.
--   • registry() — la lista de settings que ve el PANEL (con apply/get/choices). Se
--     construye en diferido (requiere los módulos proveedores), solo al abrir el panel.
local api = vim.api
local M = {}

local FILE = vim.fn.stdpath("data") .. "/settings.json"
local function data(name)
  return vim.fn.stdpath("data") .. "/" .. name
end

-- Defaults del código (una sola fuente para prune y para el registro). El del preset de
-- statusline sale de su config, que es un módulo de datos puro (sin efectos al requerir).
local DEFAULTS = {
  ["ui.theme"] = "tokyonight-night",
  ["ui.border"] = "rounded",
  ["ui.statusline_preset"] = require("plugins.local.statusline.config").preset,
  ["ui.statusline_border"] = "round",
  ["ui.indentline"] = "\u{250a}",
  ["ui.picker_icons"] = true,
  ["ui.sidebar_width"] = 35,
  ["ui.sidebar_side"] = "left",
}
M.DEFAULTS = DEFAULTS

local overrides = nil -- cache en memoria; nil = aún no cargado del disco

local function persist()
  pcall(vim.fn.writefile, { vim.json.encode(overrides) }, FILE)
end

-- ── Migración de los archivitos sueltos de versiones anteriores ─────
local function read_line(path, allow_empty)
  local ok, lines = pcall(vim.fn.readfile, path)
  if ok and lines and lines[1] ~= nil and (allow_empty or lines[1] ~= "") then
    return lines[1]
  end
end

local function migrate()
  local function take(file, id, value)
    if vim.fn.filereadable(data(file)) == 1 then
      if value ~= nil and overrides[id] == nil then
        overrides[id] = value
      end
      pcall(vim.fn.delete, data(file))
    end
  end
  take("colorscheme", "ui.theme", read_line(data("colorscheme")))
  take("winborder", "ui.border", read_line(data("winborder")))
  do -- indentline: "" (cadena vacía) = ocultar, es un valor válido
    local v = read_line(data("indentline.txt"), true)
    take("indentline.txt", "ui.indentline", v)
  end
  do -- picker_icons: "0"/"1"; solo "0" difiere del default (true)
    local v = read_line(data("picker_icons"))
    take("picker_icons", "ui.picker_icons", v == "0" and false or nil)
  end
  if vim.fn.filereadable(data("statusline.json")) == 1 then
    local raw = read_line(data("statusline.json"))
    local ok, p = pcall(vim.json.decode, raw or "")
    if ok and type(p) == "table" then
      if p.preset and overrides["ui.statusline_preset"] == nil then
        overrides["ui.statusline_preset"] = p.preset
      end
      if p.border and overrides["ui.statusline_border"] == nil then
        overrides["ui.statusline_border"] = p.border
      end
    end
    pcall(vim.fn.delete, data("statusline.json"))
  end
end

-- Quita del json las claves cuyo valor coincide con el default: mantiene el archivo
-- mínimo aunque la migración o una edición externa hayan dejado un valor redundante.
local function prune()
  for id, v in pairs(overrides) do
    if DEFAULTS[id] ~= nil and vim.deep_equal(v, DEFAULTS[id]) then
      overrides[id] = nil
    end
  end
end

local function ensure_loaded()
  if overrides ~= nil then
    return
  end
  overrides = {}
  local ok, lines = pcall(vim.fn.readfile, FILE)
  if ok and lines and lines[1] then
    local decoded_ok, tbl = pcall(vim.json.decode, lines[1])
    if decoded_ok and type(tbl) == "table" then
      overrides = tbl
    end
  end
  migrate()
  prune()
  persist()
end

-- ── API de store (sin dependencias de proveedores) ─────────────────
-- Valor persistido de `id`, o `default` si no se ha cambiado. Lo usan los proveedores
-- en su arranque: solo las opciones cambiadas se "cargan".
function M.value(id, default)
  ensure_loaded()
  local v = overrides[id]
  if v == nil then
    return default
  end
  return v
end

-- Registra el cambio (tras aplicarlo). Si vuelve al default, borra la clave. `default`
-- por defecto sale de DEFAULTS. No aplica nada: eso es cosa de quien lo llama.
function M.record(id, value, default)
  ensure_loaded()
  default = default == nil and DEFAULTS[id] or default
  if default ~= nil and vim.deep_equal(value, default) then
    overrides[id] = nil
  else
    overrides[id] = value
  end
  persist()
end

function M.is_overridden(id)
  ensure_loaded()
  return overrides[id] ~= nil
end

-- Default del CÓDIGO (previo a aplicar overrides) de cada opción de Vim con override.
-- Necesario para no confundir "valor guardado" con "default" al construir el registro.
local vim_defaults = {}

-- Opciones de Vim que expone el panel. Su default "de código" (el de options.lua) se
-- fotografía al arrancar, ANTES de aplicar overrides y antes de que nada las cambie (los
-- botones del statusline, un toggle previo…). Si no, `spec.default` se capturaría tarde,
-- leyendo un global ya modificado, y el prune guardaría claves redundantes.
-- Mantener en sync con las entradas `vimopt(...)` de build().
local PANEL_VIM_OPTS = {
  "wrap", "number", "relativenumber", "cursorline", "scrolloff", "ignorecase", "smartcase",
}

-- Fuente FIABLE del valor deseado para una opción del panel: el override persistido o el
-- default de código. nil si la opción no la gestiona el panel. La usa winopts en vez del
-- "global": el global de una opción window-local queda contaminado por ventana al editarla
-- con :set desde el sidebar (revierte con solo cambiar de ventana), así que no sirve para
-- propagar el valor a las demás ventanas.
local PANEL_OPT_SET = {}
for _, n in ipairs(PANEL_VIM_OPTS) do
  PANEL_OPT_SET[n] = true
end
function M.win_opt(name)
  if not PANEL_OPT_SET[name] then
    return nil
  end
  ensure_loaded()
  local v = overrides["opt." .. name]
  if v ~= nil then
    return v
  end
  return vim_defaults[name] -- default de código (nil si aún no se fotografió: winopts cae al global)
end

-- Reaplica al arrancar los overrides de opciones de Vim (claves "opt.*"): a diferencia de
-- los settings con proveedor, nadie más los reaplica. Se llama pronto (tras options.lua).
function M.apply_vim_overrides()
  ensure_loaded()
  -- 1) fotografiar el default de código de cada opción del panel
  for _, name in ipairs(PANEL_VIM_OPTS) do
    vim_defaults[name] = api.nvim_get_option_value(name, { scope = "global" })
  end
  -- 2) podar overrides opt.* que ya igualan ese default (redundantes: quedaron de una
  --    versión anterior o de un default capturado mal)
  local changed = false
  for id in pairs(overrides) do
    local name = id:match("^opt%.(.+)$")
    if name and vim_defaults[name] ~= nil and vim.deep_equal(overrides[id], vim_defaults[name]) then
      overrides[id] = nil
      changed = true
    end
  end
  if changed then
    persist()
  end
  -- 3) aplicar los overrides que sí difieren del default
  for id, v in pairs(overrides) do
    local name = id:match("^opt%.(.+)$")
    if name then
      pcall(function()
        vim.go[name] = v -- setglobal: en :ReloadConfig hay varias ventanas y vim.o contaminaría
      end)
    end
  end
end

-- ── Registro para el panel (en diferido) ───────────────────────────
local registry = nil

-- Helper para settings de opción de Vim (globales). scope: "win"/"buf"/nil(global-only).
-- El default es el global EN EL MOMENTO de construir el registro (lo que fijó options.lua
-- más los overrides ya aplicados al arrancar). apply lo fija en el global y en lo abierto.
local function vimopt(spec)
  local name = spec.opt
  -- default del código: el snapshot pre-override si lo hay, si no el global actual
  spec.default = vim_defaults[name]
  if spec.default == nil then
    spec.default = api.nvim_get_option_value(name, { scope = "global" })
  end
  spec.get = function()
    return api.nvim_get_option_value(name, { scope = "global" })
  end
  spec.apply = function(v)
    -- vim.go (setglobal), NO vim.o: para opciones window-local, vim.o (=:set) fija también
    -- el local de la ventana ACTUAL y deja el "global" contaminado según la ventana (si el
    -- panel se edita desde el sidebar, winopts leería el global viejo al salir y revertiría).
    vim.go[name] = v -- default global limpio (nuevos buffers); winopts lo propaga a las abiertas
    if spec.scope == "win" then
      -- apariencia de ventana: delegar en winopts, que respeta los buffers especiales
      -- (explorador, dashboard, configuración, terminales, flotantes). Fijarla a ciegas
      -- en cada ventana metería números/cursorline también en esos.
      local winopts = require("config.winopts")
      for _, w in ipairs(api.nvim_list_wins()) do
        winopts.apply(w)
      end
    elseif spec.scope == "buf" then
      for _, b in ipairs(api.nvim_list_bufs()) do
        pcall(api.nvim_set_option_value, name, v, { buf = b })
      end
    end
  end
  spec.set = function(v)
    -- registrar ANTES de aplicar: apply() propaga vía winopts, que lee el valor deseado de
    -- settings (win_opt); si registrásemos después, la propagación usaría el override viejo.
    M.record("opt." .. name, v, spec.default)
    spec.apply(v)
  end
  spec.id = "opt." .. name
  spec.overridden = function()
    return M.is_overridden(spec.id)
  end
  return spec
end

-- Construye la lista de secciones. Cada setting: id, section, label, type, get, apply,
-- set, default, overridden(); enum añade choices()/display(); number añade min/max/step.
local function build()
  local themes = require("config.themes")
  local borders = require("config.borders")
  local indent = require("plugins.local.indentline")
  local statusline = require("plugins.local.statusline")
  local picker = require("plugins.local.picker")

  -- adaptador para settings respaldados por un proveedor (apply puro + set que persiste)
  local function provider(spec)
    spec.overridden = function()
      return M.is_overridden(spec.id)
    end
    return spec
  end

  -- Toggle booleano de la UI de diagnósticos (config.diagnostics)
  local diag = require("config.diagnostics")
  local function diagopt(key, label)
    return {
      id = "diag." .. key,
      label = label,
      type = "bool",
      default = diag.DEFAULTS[key],
      get = function()
        return diag.get(key)
      end,
      apply = function(v)
        diag.set(key, v)
      end,
      set = function(v)
        diag.set(key, v)
      end,
      overridden = function()
        return M.is_overridden("diag." .. key)
      end,
    }
  end

  return {
    {
      title = "Apariencia",
      items = {
        provider({
          id = "ui.theme",
          label = "Tema",
          type = "enum",
          default = DEFAULTS["ui.theme"],
          choices = themes.labels,
          get = themes.current,
          apply = themes.apply,
          set = themes.set,
          preview = themes.preview,
        }),
        provider({
          id = "ui.border",
          label = "Borde de flotantes",
          type = "enum",
          default = DEFAULTS["ui.border"],
          choices = borders.labels,
          get = function()
            return vim.o.winborder
          end,
          apply = borders.apply,
          set = borders.set,
        }),
        provider({
          id = "ui.statusline_preset",
          label = "Preset de statusline",
          type = "enum",
          default = DEFAULTS["ui.statusline_preset"],
          choices = statusline.presets,
          get = statusline.current_preset,
          apply = function(v)
            statusline.set_preset(v, false)
          end,
          set = function(v)
            statusline.set_preset(v, true)
          end,
        }),
        provider({
          id = "ui.indentline",
          label = "Guías de indentación",
          type = "enum",
          default = DEFAULTS["ui.indentline"],
          choices = indent.choices,
          display = indent.label_of,
          get = indent.current,
          apply = indent.apply,
          set = indent.set,
        }),
        provider({
          id = "ui.picker_icons",
          label = "Iconos en los pickers",
          type = "bool",
          default = DEFAULTS["ui.picker_icons"],
          get = function()
            return picker.icons_enabled
          end,
          apply = picker.set_icons, -- set_icons ya persiste (bool: no hay preview/cancel)
          set = picker.set_icons,
        }),
        provider({
          id = "ui.sidebar_width",
          label = "Ancho del panel lateral",
          type = "number",
          default = DEFAULTS["ui.sidebar_width"],
          min = 20,
          max = 60,
          step = 2,
          get = function()
            return require("plugins.local.explorer").width()
          end,
          apply = function(v)
            require("plugins.local.explorer").set_width(v)
          end,
          set = function(v)
            require("plugins.local.explorer").set_width(v)
          end,
        }),
        provider({
          id = "ui.sidebar_side",
          label = "Lado del panel lateral",
          type = "enum",
          default = DEFAULTS["ui.sidebar_side"],
          choices = function()
            return { "left", "right" }
          end,
          display = function(v)
            return v == "right" and "derecha" or "izquierda"
          end,
          get = function()
            return require("plugins.local.explorer").side()
          end,
          apply = function(v)
            require("plugins.local.explorer").set_side(v)
          end,
          set = function(v)
            require("plugins.local.explorer").set_side(v)
          end,
        }),
      },
    },
    {
      title = "Editor",
      items = {
        {
          id = "indent.per_ft",
          label = "Indentación por tipo de archivo",
          type = "action",
          overridden = function()
            return false
          end,
          run = function()
            require("plugins.local.settings.indent_table").open()
          end,
        },
        vimopt({ opt = "wrap", label = "Ajuste de línea", type = "bool", scope = "win" }),
        vimopt({ opt = "number", label = "Números de línea", type = "bool", scope = "win" }),
        vimopt({ opt = "relativenumber", label = "Números relativos", type = "bool", scope = "win" }),
        vimopt({ opt = "cursorline", label = "Resaltar línea del cursor", type = "bool", scope = "win" }),
        vimopt({ opt = "scrolloff", label = "Margen de scroll", type = "number", scope = nil, min = 0, max = 30, step = 1 }),
        vimopt({ opt = "ignorecase", label = "Ignorar mayúsculas al buscar", type = "bool", scope = nil }),
        vimopt({ opt = "smartcase", label = "…salvo si escribes mayúsculas", type = "bool", scope = nil }),
      },
    },
    {
      title = "Diagnósticos",
      items = {
        diagopt("virtual_text", "Texto virtual (en línea)"),
        diagopt("signs", "Signos en el gutter"),
        diagopt("underline", "Subrayado"),
        diagopt("inlay_hints", "Inlay hints (tipos/parámetros)"),
      },
    },
  }
end

-- Registro cacheado. Los settings de proveedor son estables; los de opción de Vim leen
-- su valor en vivo, así que no hace falta reconstruir. Se marca la sección de cada item.
function M.registry()
  if not registry then
    registry = build()
    for _, section in ipairs(registry) do
      for _, item in ipairs(section.items) do
        item.section = section.title
      end
    end
  end
  return registry
end

-- Devuelve el spec por id (busca en el registro)
function M.spec(id)
  for _, section in ipairs(M.registry()) do
    for _, item in ipairs(section.items) do
      if item.id == id then
        return item
      end
    end
  end
end

return M
