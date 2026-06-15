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

-- Valores por defecto: el global de cada opción (lo que fija options.lua). Se lee
-- con scope "global" para ser robusto ante :ReloadConfig (no depende de la
-- ventana actual, que podría ser el dashboard al recargar).
local DEFAULT = {}
for name in pairs(CLEAN) do
  DEFAULT[name] = api.nvim_get_option_value(name, { scope = "global" })
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
  if api.nvim_win_get_config(win).relative ~= "" then
    return -- no tocar ventanas flotantes (pickers, terminales flotantes, popups)
  end
  local buf = api.nvim_win_get_buf(win)
  local opts = is_special(buf) and CLEAN or DEFAULT
  for name, value in pairs(opts) do
    api.nvim_set_option_value(name, value, { win = win })
  end
end

local group = api.nvim_create_augroup("WinOpts", { clear = true })

api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "TermOpen" }, {
  group = group,
  desc = "Aplicar opciones de ventana según el tipo de buffer",
  callback = function()
    M.apply()
  end,
})

return M
