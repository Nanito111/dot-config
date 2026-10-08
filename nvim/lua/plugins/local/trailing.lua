-- Resaltado de espacios finales (trailing whitespace), plugin-free. Opción persistente del
-- panel de settings (editor.trailing_whitespace). Mejoras: no resalta la línea que se está
-- editando en modo insert, y expone M.trim() para quitar los espacios finales del buffer.
local api = vim.api
local fn = vim.fn
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

local KEY = "editor.trailing_whitespace"
local PAT = [[\s\+$]] -- espacios/tabs al final de la línea
local PAT_INS = [[\s\+\%#\@<!$]] -- en insert: no resaltar justo donde está el cursor
local group = api.nvim_create_augroup("TrailingWS", { clear = true })
local enabled = false

local function set_hl()
  api.nvim_set_hl(0, "TrailingWhitespace", { bg = palette.red })
end
theme.register(set_hl)

-- ¿la ventana muestra un buffer normal (no netrw/terminal/dashboard)?
local function is_normal()
  local buf = api.nvim_get_current_buf()
  return vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "netrw"
end

-- (re)aplica el match en una ventana con el patrón dado (quita el anterior)
local function set_match(win, pat)
  if not api.nvim_win_is_valid(win) then
    return
  end
  api.nvim_win_call(win, function()
    if vim.w.trailing_match then
      pcall(fn.matchdelete, vim.w.trailing_match)
      vim.w.trailing_match = nil
    end
    if is_normal() then
      vim.w.trailing_match = fn.matchadd("TrailingWhitespace", pat)
    end
  end)
end

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

local function activate()
  for _, w in ipairs(api.nvim_list_wins()) do
    set_match(w, PAT)
  end
  -- aplicar en ventanas futuras (con el patrón según el modo actual)
  api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter" }, {
    group = group,
    callback = function()
      local pat = fn.mode():sub(1, 1) == "i" and PAT_INS or PAT
      set_match(api.nvim_get_current_win(), pat)
    end,
  })
  -- ocultar el resaltado en la línea que se está editando
  api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      set_match(api.nvim_get_current_win(), PAT_INS)
    end,
  })
  api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      set_match(api.nvim_get_current_win(), PAT)
    end,
  })
end

local function deactivate()
  api.nvim_clear_autocmds({ group = group })
  for _, w in ipairs(api.nvim_list_wins()) do
    clear_win(w)
  end
end

function M.is_enabled()
  return enabled
end

-- Aplica (en vivo) y persiste el estado del resaltado
function M.set(v)
  v = not not v
  enabled = v
  if v then
    activate()
  else
    deactivate()
  end
  require("config.settings").record(KEY, v)
end
M.set_enabled = M.set

function M.toggle()
  M.set(not enabled)
  vim.notify("Espacios finales: " .. (enabled and "resaltado ON" or "resaltado OFF"))
end

-- Quita los espacios finales del buffer actual (un solo undo, conserva cursor/vista)
function M.trim()
  if not is_normal() or not vim.bo.modifiable then
    return
  end
  local view = fn.winsaveview()
  pcall(vim.cmd, [[keeppatterns %s/\s\+$//e]])
  fn.winrestview(view)
  vim.notify("Espacios finales eliminados")
end

-- Restaura el estado persistido al arrancar
function M.setup()
  if require("config.settings").value(KEY, false) then
    M.set(true)
  end
end

return M
