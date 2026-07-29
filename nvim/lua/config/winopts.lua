local api = vim.api
local M = {}

-- Regla central de opciones de ventana POR TIPO DE BUFFER.
-- Los buffers "especiales" (dashboard, explorador, terminales) se ven limpios:
-- sin números, sin columna de signos, sin cursorline ni listchars. El resto usa
-- los valores por defecto del usuario. Un autocomando reaplica la regla cada vez
-- que una ventana cambia lo que muestra, así siempre concuerdan ventana y buffer.

-- Valores "limpios" para buffers especiales
local CLEAN = {
  number = false,
  relativenumber = false,
  cursorline = false,
  signcolumn = "no",
  list = false,
}

-- Ajustes de prosa por filetype. Van aquí y NO en el ftplugin porque son opciones de
-- VENTANA: puestas desde el ftplugin se quedan pegadas al siguiente buffer que se abra
-- en esa ventana (un .ts heredaba el corrector del markdown anterior).
local PROSE = {
  markdown = { spell = true, wrap = true, linebreak = true, breakindent = true, conceallevel = 2 },
  gitcommit = { spell = true, colorcolumn = "73" },
}

-- Valor deseado de una opción, leído en vivo (no cacheado): así el panel de configuración
-- puede cambiarla y esta regla la respeta en vez de reponer un valor viejo. Para las
-- opciones del panel la fuente es settings (override o default de código): el "global" de
-- una opción window-local queda contaminado por ventana al editarla con :set desde el
-- sidebar, y reponerlo aquí revertiría el cambio al salir del panel. El resto usa el global.
local function global_of(name)
  local pref = require("config.settings").win_opt(name)
  if pref ~= nil then
    return pref
  end
  return api.nvim_get_option_value(name, { scope = "global" })
end
-- Opciones de prosa que hay que reponer a su global en buffers que no son prosa
local PROSE_KEYS = {}
for _, opts in pairs(PROSE) do
  for name in pairs(opts) do
    PROSE_KEYS[name] = true
  end
end

-- ¿el buffer debe verse "limpio"?
local function is_special(buf)
  local ft = vim.bo[buf].filetype
  return ft == "dashboard"
    or ft == "explorer"
    or ft == "settings"
    or ft == "mason"
    or ft == "netrw"
    or vim.bo[buf].buftype == "terminal"
end

-- Aplica la regla a una ventana según el buffer que muestra. Expuesto para poder
-- llamarlo explícitamente (p. ej. el dashboard al iniciar, donde el VimEnter no es
-- nested y el BufWinEnter del autocomando quedaría suprimido).
function M.apply(win)
  win = win or api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then
    return
  end
  local buf = api.nvim_win_get_buf(win)

  -- scope="local" en todos los sets: fijar una opción window-local en la ventana ACTUAL
  -- sin él también cambia el default global (como :set), y al limpiar el sidebar enfocado
  -- (number=false) contaminaría a las demás ventanas.

  if api.nvim_win_get_config(win).relative ~= "" then
    -- Las flotantes (hover del LSP, diagnósticos, pickers) son visores: nunca corrigen
    -- ortografía. Heredan las opciones de la ventana desde la que se abren, así que
    -- desde un markdown llegaban con el corrector puesto. El resto no se toca.
    api.nvim_set_option_value("spell", false, { win = win, scope = "local" })
    return
  end

  if is_special(buf) then
    for name, value in pairs(CLEAN) do
      api.nvim_set_option_value(name, value, { win = win, scope = "local" })
    end
    -- especiales: nunca prosa (sin ajuste de línea ni corrector), pase lo que pase con
    -- los globales del usuario (el panel de configuración puede activarlos).
    api.nvim_set_option_value("spell", false, { win = win, scope = "local" })
    api.nvim_set_option_value("wrap", false, { win = win, scope = "local" })
    -- explorador y configuración: con el cursor oculto, la línea marcada es la única
    -- señal de la posición.
    local ft = vim.bo[buf].filetype
    if ft == "explorer" or ft == "settings" or ft == "mason" then
      api.nvim_set_option_value("cursorline", true, { win = win, scope = "local" })
    end
    return
  end

  for name in pairs(CLEAN) do -- buffer normal: el global del usuario (en vivo)
    api.nvim_set_option_value(name, global_of(name), { win = win, scope = "local" })
  end

  -- Prosa (markdown, gitcommit) o su valor global si el buffer no lo es
  local prose = PROSE[vim.bo[buf].filetype]
  for name in pairs(PROSE_KEYS) do
    local value = prose and prose[name]
    if value == nil then
      value = global_of(name)
    end
    api.nvim_set_option_value(name, value, { win = win, scope = "local" })
  end
end

local group = api.nvim_create_augroup("WinOpts", { clear = true })

api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "TermOpen", "FileType" }, {
  group = group,
  desc = "Aplicar opciones de ventana según el tipo de buffer",
  callback = function()
    M.apply()
  end,
})

return M
