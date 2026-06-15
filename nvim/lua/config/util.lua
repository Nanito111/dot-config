local api = vim.api
local M = {}

-- Elimina los buffers [No Name] vacíos, sin modificar y que no se ven en ninguna
-- ventana. netrw (`:Lexplore`) deja uno colgando cada vez que abre el panel.
function M.wipe_orphan_buffers()
  for _, b in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(b)
      and vim.bo[b].buflisted
      and vim.bo[b].buftype == ""
      and api.nvim_buf_get_name(b) == ""
      and not vim.bo[b].modified
      and #vim.fn.win_findbuf(b) == 0
    then
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end
end

return M
