local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

local function set_hl()
  api.nvim_set_hl(0, "WinBarPath", { fg = palette.comment }) -- carpetas (tenue)
  api.nvim_set_hl(0, "WinBarFile", { fg = palette.fg, bold = true }) -- archivo
  api.nvim_set_hl(0, "WinBarSep", { fg = palette.blue }) -- separador
  api.nvim_set_hl(0, "WinBarDeleted", { fg = palette.red, bold = true }) -- archivo borrado
end
theme.register(set_hl)

local icon_for = require("config.icons").icon

-- Breadcrumbs de la ruta (relativa al cwd): carpeta ▸ carpeta ▸ archivo
function _G.breadcrumbs()
  local win = vim.g.statusline_winid
  if not (win and win ~= 0 and api.nvim_win_is_valid(win)) then
    win = api.nvim_get_current_win()
  end
  local buf = api.nvim_win_get_buf(win)
  local name = api.nvim_buf_get_name(buf)
  if name == "" then
    return ""
  end

  local parts = vim.split(vim.fn.fnamemodify(name, ":."), "[/\\]", { trimempty = true })
  local n = #parts
  local file = parts[n] or ""
  -- Orden invertido: primero el ARCHIVO actual, luego sus carpetas padre hacia la
  -- derecha (padre inmediato → raíz). El separador ◂ se lee como "contenido en".
  local out = { " %#WinBarFile#" .. icon_for(file) .. "  " .. file:gsub("%%", "%%%%") }
  out[#out + 1] = "%#WinBarFile#%m" -- indicador de modificado, junto al archivo
  -- marca [deleted] si el archivo del buffer fue borrado en disco (la fija el
  -- autocomando FileChangedShell en config.autocmds; se limpia al reguardar)
  if vim.b[buf].file_deleted then
    out[#out + 1] = " %#WinBarDeleted#[deleted]"
  end
  for i = n - 1, 1, -1 do
    out[#out + 1] = "%#WinBarSep# ◂ "
    out[#out + 1] = "%#WinBarPath#" .. parts[i]:gsub("%%", "%%%%")
  end
  return table.concat(out)
end

local TERM_ICON = "\u{f489}" --  icono de terminal (a juego con la statusline)

-- Winbar de un buffer de terminal: su nombre (term_name; si no, se deriva del
-- nombre term://). Se usa solo en terminales NO flotantes.
function _G.terminal_winbar()
  local win = vim.g.statusline_winid
  if not (win and win ~= 0 and api.nvim_win_is_valid(win)) then
    win = api.nvim_get_current_win()
  end
  local buf = api.nvim_win_get_buf(win)
  local label = vim.b[buf].term_name
  if not label or label == "" then
    local name = api.nvim_buf_get_name(buf)
    label = vim.fn.fnamemodify(name:gsub("^term://.*//%d+:", ""), ":t")
    if label == "" then
      label = "terminal"
    end
  end
  return " %#WinBarFile#" .. TERM_ICON .. "  " .. label:gsub("%%", "%%%%")
end

-- Activa el winbar en archivos normales (breadcrumbs) y en terminales no flotantes
-- (nombre de la terminal).
local function set_winbar()
  -- no tocar ventanas flotantes (pickers, blame, which-key, terminales flotantes de
  -- claude/lazygit): fijar winbar ahí puede dar E36 "Not enough room" en 1 línea
  if api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  local buf = api.nvim_get_current_buf()
  if vim.bo[buf].buftype == "terminal" then
    vim.wo.winbar = "%!v:lua.terminal_winbar()"
    return
  end
  local normal = vim.bo[buf].buftype == ""
    and api.nvim_buf_get_name(buf) ~= ""
    and vim.bo[buf].filetype ~= "netrw"
    and vim.bo[buf].filetype ~= "dashboard"
  vim.wo.winbar = normal and "%!v:lua.breadcrumbs()" or ""
end

local group = api.nvim_create_augroup("WinBar", { clear = true })

api.nvim_create_autocmd({ "BufWinEnter", "BufEnter", "WinEnter", "TermOpen" }, {
  group = group,
  desc = "Mostrar breadcrumbs solo en archivos",
  callback = set_winbar,
})

return M
