-- Flotante genérico: encapsula el patrón repetido en ~18 sitios (crear buffer/ventana,
-- centrar, título/footer, backdrop, opciones window-local con scope local, y un cierre
-- idempotente con teclas / al perder el foco). Devuelve { win, buf, close }.
local api = vim.api
local geom = require("plugins.local.ui.geom")
local uiwin = require("plugins.local.ui.win")
local close_all = require("plugins.local.ui.close")

local M = {}

-- opts (todo opcional salvo width/height o que la ventana pueda medirse por contenido):
--   buf            buffer existente (si no, se crea un scratch y se borra al cerrar)
--   enter=false    entrar en la ventana al abrir
--   relative="editor" | "cursor" | "win" ; win / anchor / zindex   (passthrough)
--   width, height  tamaño
--   center=true    (solo relative="editor") centra si no se dan row/col ; row_off resta alto
--   row, col       posición explícita (desactiva el centrado)
--   style="minimal"
--   border         nil = hereda winborder global ; "none" = sin marco (marca w.borderless)
--   title, title_pos, footer, footer_pos
--   focusable, noautocmd
--   wo = { ... }   opciones window-local (se aplican con scope="local")
--   backdrop = true | { blend, zindex }   capa oscura, atada al close()
--   close_keys = { "<Esc>", "q", ... }    teclas (modo n) que cierran
--   close_on_leave = false                cerrar al salir del buffer (BufLeave once)
--   on_close(fn)   callback al cerrar
function M.open(opts)
  opts = opts or {}
  local buf = opts.buf
  local owns_buf = false
  if not buf then
    buf = api.nvim_create_buf(false, true)
    owns_buf = true
  end

  local cfg = {
    relative = opts.relative or "editor",
    width = opts.width,
    height = opts.height,
    style = opts.style or "minimal",
    focusable = opts.focusable,
    noautocmd = opts.noautocmd,
    zindex = opts.zindex,
    win = opts.win,
    anchor = opts.anchor,
    title = opts.title,
    title_pos = opts.title_pos,
    footer = opts.footer,
    footer_pos = opts.footer_pos,
  }
  if opts.border then
    cfg.border = opts.border
  end
  if opts.row ~= nil then
    cfg.row, cfg.col = opts.row, opts.col
  elseif cfg.relative == "editor" and opts.center ~= false then
    local pos = geom.center(opts.width, opts.height, { row_off = opts.row_off })
    cfg.row, cfg.col = pos.row, pos.col
  else
    cfg.row, cfg.col = opts.row, opts.col
  end

  local win = api.nvim_open_win(buf, opts.enter or false, cfg)
  if opts.border == "none" then
    vim.w[win].borderless = true -- que el reborde de config.borders lo respete
  end
  if opts.wo then
    uiwin.set_opts(win, opts.wo)
  end

  local backdrop_close
  if opts.backdrop then
    local bopts = type(opts.backdrop) == "table" and opts.backdrop or {}
    backdrop_close = require("plugins.local.ui.backdrop").open(bopts)
  end

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if backdrop_close then
      pcall(backdrop_close)
    end
    close_all(win, owns_buf and buf or nil)
    pcall(vim.cmd, "stopinsert")
    if opts.on_close then
      pcall(opts.on_close)
    end
  end

  for _, lhs in ipairs(opts.close_keys or {}) do
    vim.keymap.set("n", lhs, close, { buffer = buf, nowait = true, silent = true })
  end
  if opts.close_on_leave then
    api.nvim_create_autocmd("BufLeave", { buffer = buf, once = true, callback = close })
  end

  return { win = win, buf = buf, close = close }
end

return M
