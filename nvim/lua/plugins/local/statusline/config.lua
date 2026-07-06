-- Ajustes de la statusline EN UN SOLO LUGAR.
--   • presets -> se autocargan desde presets/*.lua (un archivo = un preset, como
--                los "plugins"). NO hay que registrarlos en ningún lado: basta crear
--                el archivo. El activo se elige con :StatuslinePreset / <leader>us.
--   • borders -> catálogo de extremos de píldora (eje rápido: <leader>ub / cycle).
--   • width   -> ancho fijo (columnas) de cada componente.
--   • icons   -> glifos usados por los componentes.
-- Componentes nuevos -> components.lua. Forma de la píldora -> core.lua.
--
-- Para AÑADIR un preset: crea presets/<nombre>.lua que devuelva una tabla
--   { border, fill?, transparent?, layout = { left, center, right }, colors? }
-- donde colors = function(pair, palette) redefine grupos; pair(grupo, fg, bg, opts?)
-- define el grupo y su "<grupo>Sep". Se detecta solo al reiniciar / :ReloadConfig.

-- Carga todos los presets de presets/*.lua (nombre del archivo = nombre del preset).
local function load_presets()
  local presets = {}
  local dir = "lua/plugins/local/statusline/presets"
  for _, path in ipairs(vim.api.nvim_get_runtime_file(dir .. "/*.lua", true)) do
    local name = vim.fn.fnamemodify(path, ":t:r")
    local ok, preset = pcall(require, "plugins.local.statusline.presets." .. name)
    if ok and type(preset) == "table" then
      presets[name] = preset
    else
      vim.schedule(function()
        vim.notify("Preset de statusline inválido: " .. name, vim.log.levels.WARN)
      end)
    end
  end
  return presets
end

return {
  -- ── Presets de statusline ─────────────────────────────────────────
  preset = "default", -- preset activo al arrancar (si no hay preferencia guardada)
  presets = load_presets(),

  -- ── Catálogo de bordes (extremos de píldora) ──────────────────────
  borders = {
    round = { left = "\u{e0b6}", right = "\u{e0b4}" }, --   mediaslunas
    arrow = { left = "\u{e0b2}", right = "\u{e0b0}" }, --   flechas
    slant = { left = "\u{e0ba}", right = "\u{e0b8}" }, --   diagonales
    thin = { left = "\u{e0b7}", right = "\u{e0b5}" }, --   medialuna fina
    square = { left = "", right = "" }, -- sin extremos (bloques planos)
  },

  -- ── Anchos fijos (columnas) de cada componente ────────────────────
  width = {
    git = 16,
    filetype = 8,
    position = 9,
    percent = 4,
  },

  -- ── Glifos (Nerd Font) ────────────────────────────────────────────
  icons = {
    branch = "\u{e0a0}", --  rama de git
    ahead = "\u{2191}", -- ↑ commits por delante del upstream
    behind = "\u{2193}", -- ↓ commits por detrás del upstream
    terminal = "\u{f489}", --  buffer de terminal
    files = "\u{f07b}", --  explorador de archivos
    lsp = "\u{f085}", --  servidor(es) LSP activos
    indent = "\u{f036}", --  tipo de indentación (espacios/tabs)
    diag_error = "\u{f057}", --  diagnóstico: error
    diag_warn = "\u{f071}", --  diagnóstico: aviso
    diag_info = "\u{f05a}", --  diagnóstico: info
    diag_hint = "\u{f0eb}", --  diagnóstico: pista
  },
}
