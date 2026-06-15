local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

local function set_hl()
  api.nvim_set_hl(0, "WinBarPath", { fg = palette.comment }) -- carpetas (tenue)
  api.nvim_set_hl(0, "WinBarFile", { fg = palette.fg, bold = true }) -- archivo
  api.nvim_set_hl(0, "WinBarSep", { fg = palette.blue }) -- separador
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
  local out = { " " }
  for i, p in ipairs(parts) do
    local last = i == #parts
    if last then
      out[#out + 1] = "%#WinBarFile#" .. icon_for(p) .. "  " .. p:gsub("%%", "%%%%")
    else
      out[#out + 1] = "%#WinBarPath#" .. p:gsub("%%", "%%%%")
      out[#out + 1] = "%#WinBarSep# ▸ "
    end
  end
  out[#out + 1] = " %#WinBarFile#%m" -- indicador de modificado
  return table.concat(out)
end

-- Activa el winbar solo en ventanas de archivo normales
local function set_winbar()
  -- no tocar ventanas flotantes (pickers, blame, which-key): fijar winbar ahí
  -- puede dar E36 "Not enough room" en flotantes de 1 línea
  if api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  local buf = api.nvim_get_current_buf()
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
