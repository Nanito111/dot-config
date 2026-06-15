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
  return vim.bo[buf].filetype ~= "netrw"
    and vim.bo[buf].filetype ~= "explorer"
    and vim.bo[buf].buftype ~= "terminal"
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

-- Dibuja el contenido centrado en la ventana
local function render(buf, win)
  local width = api.nvim_win_get_width(win)
  local height = api.nvim_win_get_height(win)

  local block = {}
  vim.list_extend(block, get_header())
  block[#block + 1] = ""
  block[#block + 1] = ""
  vim.list_extend(block, buttons)

  -- ancho máximo para centrar todo el bloque con un solo margen izquierdo
  local maxw = 0
  for _, l in ipairs(block) do
    maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
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
