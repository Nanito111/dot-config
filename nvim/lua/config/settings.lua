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

-- Reaplica al arrancar los overrides de opciones de Vim (claves "opt.*"): a diferencia de
-- los settings con proveedor, nadie más los reaplica. Se llama pronto (tras options.lua).
-- Antes de sobrescribir, guarda el global actual como default real del código.
function M.apply_vim_overrides()
  ensure_loaded()
  for id, v in pairs(overrides) do
    local name = id:match("^opt%.(.+)$")
    if name then
      vim_defaults[name] = api.nvim_get_option_value(name, { scope = "global" })
      pcall(function()
        vim.o[name] = v
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
    vim.o[name] = v -- default global (nuevos buffers)
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
    spec.apply(v)
    M.record("opt." .. name, v, spec.default)
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
