-- Estado compartido del explorador: namespace, augroup, constantes y el estado
-- POR TAB (cada workspace tiene su propio explorador independiente).
local api = vim.api
local M = {}

M.ns = api.nvim_create_namespace("explorer")
M.group = api.nvim_create_augroup("Explorer", { clear = true })

M.FOLDER_CLOSED = "\u{f07b}" --
M.FOLDER_OPEN = "\u{f07c}" --

-- handle de tab -> { root, expanded, buf, win, nodes, watcher, timer, git, ... }
M.states = {}

function M.cur()
  return M.states[api.nvim_get_current_tabpage()]
end

return M
