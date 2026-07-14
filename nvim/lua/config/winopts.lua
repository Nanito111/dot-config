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

-- Valores por defecto: el global de cada opción (lo que fija options.lua). Se lee
-- con scope "global" para ser robusto ante :ReloadConfig (no depende de la
-- ventana actual, que podría ser el dashboard al recargar).
local DEFAULT = {}
for name in pairs(CLEAN) do
  DEFAULT[name] = api.nvim_get_option_value(name, { scope = "global" })
end
-- Los de prosa se reponen a su global cuando el buffer no es de prosa
local PROSE_DEFAULT = {}
for _, opts in pairs(PROSE) do
  for name in pairs(opts) do
    PROSE_DEFAULT[name] = api.nvim_get_option_value(name, { scope = "global" })
  end
end

-- ¿el buffer debe verse "limpio"?
local function is_special(buf)
  local ft = vim.bo[buf].filetype
  return ft == "dashboard"
    or ft == "explorer"
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

  if api.nvim_win_get_config(win).relative ~= "" then
    -- Las flotantes (hover del LSP, diagnósticos, pickers) son visores: nunca corrigen
    -- ortografía. Heredan las opciones de la ventana desde la que se abren, así que
    -- desde un markdown llegaban con el corrector puesto. El resto no se toca.
    api.nvim_set_option_value("spell", false, { win = win })
    return
  end

  local opts = is_special(buf) and CLEAN or DEFAULT
  for name, value in pairs(opts) do
    api.nvim_set_option_value(name, value, { win = win })
  end

  -- Prosa (markdown, gitcommit) o su valor global si el buffer no lo es
  local prose = PROSE[vim.bo[buf].filetype]
  for name, default in pairs(PROSE_DEFAULT) do
    local value = prose and prose[name]
    if value == nil then
      value = default
    end
    api.nvim_set_option_value(name, value, { win = win })
  end
  -- El explorador es "especial" (limpio) pero SÍ quiere cursorline: con el cursor
  -- oculto, la línea marcada es la única señal de la posición.
  if vim.bo[buf].filetype == "explorer" then
    api.nvim_set_option_value("cursorline", true, { win = win })
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
