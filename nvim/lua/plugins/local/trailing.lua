local api = vim.api
local fn = vim.fn
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

local PATTERN = [[\s\+$]] -- uno o más espacios/tabs al final de la línea
local enabled = false
local group = api.nvim_create_augroup("TrailingWS", { clear = true })

local function set_hl()
  api.nvim_set_hl(0, "TrailingWhitespace", { bg = palette.red })
end
theme.register(set_hl)

-- ¿la ventana muestra un buffer normal (no netrw/terminal/dashboard)?
local function is_normal()
  local buf = api.nvim_get_current_buf()
  return vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "netrw"
end

-- Aplica el match en la ventana actual (sin duplicar)
local function apply()
  if not is_normal() or vim.w.trailing_match then
    return
  end
  vim.w.trailing_match = fn.matchadd("TrailingWhitespace", PATTERN)
end

-- Quita el match de una ventana
local function clear_win(win)
  if not api.nvim_win_is_valid(win) then
    return
  end
  api.nvim_win_call(win, function()
    if vim.w.trailing_match then
      pcall(fn.matchdelete, vim.w.trailing_match)
      vim.w.trailing_match = nil
    end
  end)
end

-- Alterna el resaltado de espacios al final
function M.toggle()
  enabled = not enabled
  if enabled then
    for _, w in ipairs(api.nvim_list_wins()) do
      api.nvim_win_call(w, apply)
    end
    -- aplicar también en ventanas futuras
    api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter" }, {
      group = group,
      callback = apply,
    })
    vim.notify("Trailing spaces: resaltado ON")
  else
    api.nvim_clear_autocmds({ group = group })
    for _, w in ipairs(api.nvim_list_wins()) do
      clear_win(w)
    end
    vim.notify("Trailing spaces: resaltado OFF")
  end
end

return M
