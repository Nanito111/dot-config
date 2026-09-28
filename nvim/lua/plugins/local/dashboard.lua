local api = vim.api
local autocmd = api.nvim_create_autocmd

local M = {}

-- Arte ASCII por defecto del panel de inicio
local default_header = {
  "███╗   ██╗ ██╗   ██╗ ██╗ ███╗   ███╗",
  "████╗  ██║ ██║   ██║ ██║ ████╗ ████║",
  "██╔██╗ ██║ ██║   ██║ ██║ ██╔████╔██║",
  "██║╚██╗██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║",
  "██║ ╚████║  ╚████╔╝  ██║ ██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝   ╚═══╝   ╚═╝ ╚═╝     ╚═╝",
}

-- Arte ASCII personalizado: si existe un logo.txt en la raíz de la config, se usa
-- su contenido; si no, el logo por defecto. Se lee en cada apertura, así basta
-- crear/editar el archivo (sin reiniciar) para verlo.
local logo_path = vim.fs.joinpath(vim.fn.stdpath("config"), "logo.txt")
local function get_header()
  if vim.fn.filereadable(logo_path) ~= 1 then
    return default_header
  end
  local lines = {}
  for _, l in ipairs(vim.fn.readfile(logo_path)) do
    lines[#lines + 1] = (l:gsub("\r$", "")) -- quitar CR de archivos con saltos CRLF
  end
  return #lines > 0 and lines or default_header
end

local buttons = {
  "e   Explorador de archivos   (<leader>e)",
  "n   Nuevo archivo            (n)",
  "q   Salir                    (q)",
}

-- ¿Es un buffer "real" (archivo listado y normal)?
local function is_real_buffer(buf)
  return api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buflisted
    and vim.bo[buf].buftype == ""
    and api.nvim_buf_get_name(buf) ~= ""
end

local function has_real_buffers()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if is_real_buffer(buf) then
      return true
    end
  end
  return false
end

-- Las opciones de ventana "limpias" (sin números, signos, listchars) las maneja
-- de forma central config.winopts, según el filetype del buffer.

-- Una ventana "normal" no es netrw ni terminal
local function is_normal_win(win)
  if not api.nvim_win_is_valid(win) then
    return false
  end
  -- excluir ventanas flotantes (p. ej. pickers, terminales flotantes)
  if api.nvim_win_get_config(win).relative ~= "" then
    return false
  end
  local buf = api.nvim_win_get_buf(win)
  return vim.bo[buf].filetype ~= "netrw" and vim.bo[buf].filetype ~= "explorer" and vim.bo[buf].buftype ~= "terminal"
end

-- Buffer del dashboard (se crea una vez y se reutiliza)
local dash_buf = nil
local function get_buf()
  if dash_buf and api.nvim_buf_is_valid(dash_buf) then
    return dash_buf
  end
  dash_buf = api.nvim_create_buf(false, true) -- sin listar, scratch
  vim.bo[dash_buf].buftype = "nofile"
  vim.bo[dash_buf].bufhidden = "hide"
  vim.bo[dash_buf].swapfile = false
  vim.bo[dash_buf].filetype = "dashboard"

  local opts = { buffer = dash_buf, silent = true, nowait = true }
  vim.keymap.set("n", "e", "<leader>e", vim.tbl_extend("force", opts, { remap = true }))
  vim.keymap.set("n", "n", "<cmd>enew<CR>", opts)
  vim.keymap.set("n", "q", "<cmd>qa<CR>", opts)

  -- Al hacer :q desde el dashboard, cerrar el TAB completo (no solo su ventana,
  -- que dejaría al explorador solo y regeneraría otro dashboard). Cerramos las
  -- demás ventanas normales del tab; el :q pendiente cierra la última = el tab.
  autocmd("QuitPre", {
    buffer = dash_buf,
    desc = "Cerrar el tab completo al :q desde el dashboard",
    callback = function()
      local cur = api.nvim_get_current_win()
      for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
        if w ~= cur and api.nvim_win_get_config(w).relative == "" then
          pcall(api.nvim_win_close, w, false)
        end
      end
    end,
  })
  return dash_buf
end

-- ── Efecto del título (shimmer / degradado) ────────────────────────
-- Colorea el logo con extmarks por carácter. "shimmer" mueve una banda brillante con un
-- timer (solo mientras el dashboard está visible); "gradient" es un degradado estático;
-- "off" lo deja sin color. El nivel de brillo son grupos DashFx0..N interpolados del tema.
local fx_ns = api.nvim_create_namespace("dashboard_fx")
local fx_timer, fx_frame = nil, 0
local header_info = nil -- { first = línea 0-based, count, left = bytes, span = celdas }
local SHADES, BAND = 12, 7

local function hexok(c)
  return (type(c) == "string" and c:match("^#%x%x%x%x%x%x$")) and c or nil
end

-- mezcla dos colores hex (#rrggbb) con factor t (0..1)
local function blend(a, b, t)
  local function ch(s, i)
    return tonumber(s:sub(i, i + 1), 16)
  end
  local function mix(i)
    return math.floor(ch(a, i) + (ch(b, i) - ch(a, i)) * t + 0.5)
  end
  return string.format("#%02x%02x%02x", mix(2), mix(4), mix(6))
end

-- Color base del logo: elegido en ui.dashboard_color ("auto" = acento del tema). Se toma de
-- la paleta del tema, así respeta el colorscheme.
local function base_color()
  local p = require("config.palette")
  local key = require("config.settings").value("ui.dashboard_color", "auto")
  local map = {
    auto = p.blue,
    blue = p.blue,
    cyan = p.cyan,
    green = p.green,
    yellow = p.yellow,
    orange = p.orange,
    red = p.red,
    purple = p.purple,
    fg = p.fg,
  }
  return hexok(map[key]) or hexok(p.blue) or "#5aa0ff"
end

-- grupos de brillo, del color base (config) al brillante (se rehacen en cada ColorScheme y al
-- cambiar el color). El brillante siempre aclara hacia el blanco para que el shimmer contraste
-- sea cual sea el color base.
local function define_shades()
  local base = base_color()
  local bright = blend(base, "#ffffff", 0.65)
  for i = 0, SHADES do
    api.nvim_set_hl(0, "DashFx" .. i, { fg = blend(base, bright, i / SHADES), bold = true })
  end
end

local function effect_name()
  return require("config.settings").value("ui.dashboard_effect", "shimmer")
end

-- índice de brillo (0..SHADES) de la celda j según el efecto
local function shade_for(effect, j, span)
  if effect == "gradient" then
    return math.floor((span > 1 and j / (span - 1) or 0) * SHADES + 0.5)
  end
  local center = (fx_frame % (span + 2 * BAND)) - BAND -- barre de izq a der
  local d = math.abs(j - center)
  return (d >= BAND) and 0 or math.floor((1 - d / BAND) * SHADES + 0.5)
end

-- recorre los caracteres UTF-8 de s pasando (offset_byte 0-based, nº de bytes)
local function each_char(s, cb)
  local off = 0
  for c in s:gmatch("[\1-\127\194-\244][\128-\191]*") do
    cb(off, #c)
    off = off + #c
  end
end

local function apply_fx(buf)
  api.nvim_buf_clear_namespace(buf, fx_ns, 0, -1)
  if not header_info then
    return
  end
  local effect, left, span = effect_name(), header_info.left, header_info.span
  for i = 0, header_info.count - 1 do
    local lnum = header_info.first + i
    local line = api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1]
    if line then
      if effect == "off" then
        -- sin animación: color sólido (base) en todo el logo, de una sola marca por línea
        pcall(api.nvim_buf_set_extmark, buf, fx_ns, lnum, left, { end_col = #line, hl_group = "DashFx0" })
      else
        local j = 0
        each_char(line:sub(left + 1), function(coff, clen)
          local sh = shade_for(effect, j, span)
          pcall(api.nvim_buf_set_extmark, buf, fx_ns, lnum, left + coff, {
            end_col = left + coff + clen,
            hl_group = "DashFx" .. sh,
          })
          j = j + 1
        end)
      end
    end
  end
end

local function dash_visible()
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(w) and dash_buf and api.nvim_win_get_buf(w) == dash_buf then
      return true
    end
  end
  return false
end

local function tick()
  if not (dash_buf and api.nvim_buf_is_valid(dash_buf) and dash_visible()) then
    if fx_timer then
      fx_timer:stop()
    end
    return
  end
  fx_frame = fx_frame + 1
  apply_fx(dash_buf)
end

-- (re)aplica el efecto; anima con un timer solo si es "shimmer" y el dashboard está visible
local function refresh_fx()
  if not (dash_buf and api.nvim_buf_is_valid(dash_buf)) then
    return
  end
  apply_fx(dash_buf)
  if effect_name() == "shimmer" and dash_visible() then
    if not fx_timer then
      fx_timer = vim.uv.new_timer()
    end
    fx_timer:stop()
    fx_timer:start(90, 90, vim.schedule_wrap(tick))
  elseif fx_timer then
    fx_timer:stop()
  end
end

-- Dibuja el contenido centrado en la ventana
local function render(buf, win)
  local width = api.nvim_win_get_width(win)
  local height = api.nvim_win_get_height(win)

  local header = get_header()
  local block = {}
  vim.list_extend(block, header)
  block[#block + 1] = ""
  block[#block + 1] = ""
  vim.list_extend(block, buttons)

  -- ancho máximo para centrar todo el bloque con un solo margen izquierdo
  local maxw, span = 0, 0
  for _, l in ipairs(block) do
    maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
  end
  for _, l in ipairs(header) do
    span = math.max(span, vim.fn.strdisplaywidth(l))
  end
  local left = string.rep(" ", math.max(0, math.floor((width - maxw) / 2)))

  local lines = {}
  local top = math.max(0, math.floor((height - #block) / 2))
  for _ = 1, top do
    lines[#lines + 1] = ""
  end
  for _, l in ipairs(block) do
    lines[#lines + 1] = left .. l
  end

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- región del logo (para el efecto): líneas [top .. top+#header-1], tras el margen
  header_info = { first = top, count = #header, left = #left, span = span }
  refresh_fx()
end

-- Muestra el dashboard en una ventana normal si no hay buffers reales
function M.open()
  local win = api.nvim_get_current_win()
  if not is_normal_win(win) then
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      if is_normal_win(w) then
        win = w
        break
      end
    end
  end

  -- no hay ninguna ventana normal donde mostrarlo (p. ej. solo flotantes)
  if not is_normal_win(win) then
    return
  end
  -- ya estamos en el dashboard, nada que hacer
  if vim.bo[api.nvim_win_get_buf(win)].filetype == "dashboard" then
    return
  end

  local buf = get_buf()
  api.nvim_win_set_buf(win, buf)
  render(buf, win)
  require("config.winopts").apply(win) -- limpiar números/listchars (robusto en VimEnter)

  -- limpiar los [No Name] vacíos huérfanos (el inicial, el de cada tabnew,
  -- y el que netrw deja al abrir el panel)
  require("config.util").wipe_orphan_buffers()
end

-- Efecto del título: get/set para el panel de configuración (set reaplica en vivo).
function M.get_effect()
  return effect_name()
end
function M.set_effect(v)
  require("config.settings").record("ui.dashboard_effect", v, "shimmer")
  refresh_fx()
end

-- Color del logo: get/set para el panel (set rehace los tonos y reaplica en vivo).
function M.get_color()
  return require("config.settings").value("ui.dashboard_color", "auto")
end
function M.set_color(v)
  require("config.settings").record("ui.dashboard_color", v, "auto")
  define_shades()
  refresh_fx()
end

-- Colores del efecto: definirlos ya y en cada cambio de tema.
require("config.theme").register(define_shades)

local group = api.nvim_create_augroup("Dashboard", { clear = true })

-- Al iniciar sin argumentos
autocmd("VimEnter", {
  group = group,
  desc = "Mostrar dashboard al iniciar",
  callback = function()
    if vim.fn.argc() == 0 and not has_real_buffers() then
      M.open()
    end
  end,
})

-- Al cerrar el último buffer real
autocmd("BufDelete", {
  group = group,
  desc = "Mostrar dashboard al cerrar el último buffer",
  callback = function()
    vim.schedule(function()
      if not has_real_buffers() then
        M.open()
      end
    end)
  end,
})

-- Recentrar al redimensionar
autocmd("VimResized", {
  group = group,
  desc = "Recentrar dashboard",
  callback = function()
    local win = api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "dashboard" then
      render(buf, win)
    end
  end,
})

return M
