-- Backdrop: una capa oscura semitransparente sobre todo el editor, para resaltar un modal
-- (p. ej. el diálogo de rename) sobre el buffer de código. Va por DEBAJO del modal (zindex
-- menor) y por encima del contenido normal.
local api = vim.api
local M = {}

-- Abre el backdrop. Devuelve una función para cerrarlo. opts:
--   • blend  -> 'winblend' (0 = negro opaco, 100 = transparente). Menor = más oscuro.
--   • zindex -> por debajo del modal (default 45; los flotantes normales usan 50)
--
-- La opacidad por defecto depende del fondo del tema: el mismo 50% de negro que en un tema
-- oscuro apenas se nota, en uno claro ensucia el editor. En claro basta un velo suave.
local function default_blend()
  return vim.o.background == "light" and 80 or 50
end

function M.open(opts)
  opts = opts or {}
  api.nvim_set_hl(0, "Backdrop", { bg = "#000000" })
  local buf = api.nvim_create_buf(false, true)
  local ok, win = pcall(api.nvim_open_win, buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = math.max(1, vim.o.lines - vim.o.cmdheight),
    focusable = false,
    style = "minimal",
    border = "none", -- explícito: capa a pantalla completa, el winborder global no aplica
    zindex = opts.zindex or 45,
    noautocmd = true,
  })
  if not ok then
    pcall(api.nvim_buf_delete, buf, { force = true })
    return function() end
  end
  vim.w[win].borderless = true -- capa a pantalla completa: nunca lleva marco (ver config.borders)
  require("plugins.local.ui.win").set_opts(win, {
    winblend = opts.blend or default_blend(),
    winhighlight = "Normal:Backdrop,NormalNC:Backdrop,EndOfBuffer:Backdrop",
  })

  return function()
    pcall(api.nvim_win_close, win, true)
    pcall(api.nvim_buf_delete, buf, { force = true })
  end
end

return M
