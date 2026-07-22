-- Flotante genérico: encapsula el patrón repetido en ~18 sitios (crear buffer/ventana,
-- centrar, título/footer, backdrop, opciones window-local con scope local, y un cierre
-- idempotente con teclas / al perder el foco). Devuelve { win, buf, close }.
local api = vim.api
local geom = require("plugins.local.ui.geom")
local uiwin = require("plugins.local.ui.win")
local close_all = require("plugins.local.ui.close")
local M = {}

---@class FloatOpts
---@field buf? integer          Buffer existente (si no, se crea un scratch y se borra al cerrar)
---@field enter? boolean        Entrar en la ventana al abrir (default: false)
---@field relative? "editor"|"cursor"|"win"  Referencia de posición (default: "editor")
---@field win? integer          Ventana de referencia (cuando relative="win")
---@field anchor? "NW"|"NE"|"SW"|"SE"
---@field zindex? integer
---@field width integer         Ancho de la ventana
---@field height integer        Alto de la ventana
---@field center? boolean       Centrar en el editor (solo relative="editor", default: true)
---@field row_off? integer      Offset vertical al centrar (resta al row calculado)
---@field row? number           Posición vertical explícita (desactiva el centrado)
---@field col? number           Posición horizontal explícita (desactiva el centrado)
---@field style? "minimal"
---@field border? string        nil = hereda winborder global; "none" = sin marco
---@field title? string
---@field title_pos? "left"|"center"|"right"
---@field footer? string
---@field footer_pos? "left"|"center"|"right"
---@field focusable? boolean
---@field noautocmd? boolean
---@field wo? table             Opciones window-local (se aplican con scope="local")
---@field backdrop? boolean|{ blend?: integer, zindex?: integer }  Capa oscura atada al close()
---@field close_keys? string[]  Teclas (modo n) que llaman a close()
---@field close_on_leave? boolean  Cerrar al salir del buffer via BufLeave (default: false)
---@field on_close? fun()       Callback al cerrar

---@param opts FloatOpts
---@return { win: integer, buf: integer, close: fun() }
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
    vim.w[win].borderless = true
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

  -- neutralizar el ciclado de buffers global: es un flotante modal, Tab no debe cambiar de buffer
  vim.keymap.set("n", "<Tab>", function () end, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<S-Tab>", function () end, { buffer = buf, nowait = true, silent = true })

  return { win = win, buf = buf, close = close }
end

return M
