local api = vim.api
local M = {}

-- Enfoca una ventana donde abrir el terminal (evita netrw y flotantes)
local function goto_target_win()
  local function ok(w)
    if api.nvim_win_get_config(w).relative ~= "" then
      return false -- flotante
    end
    local ft = vim.bo[api.nvim_win_get_buf(w)].filetype
    return ft ~= "netrw" and ft ~= "explorer"
  end
  local win = api.nvim_get_current_win()
  if not ok(win) then
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      if ok(w) then
        win = w
        break
      end
    end
  end
  api.nvim_set_current_win(win)
end

-- Crea un terminal (con nombre opcional) en la ventana de edición
function M.new(name)
  goto_target_win()
  vim.cmd("terminal")
  if name and name ~= "" then
    vim.b[api.nvim_get_current_buf()].term_name = name
  end
  vim.cmd("startinsert")
end

-- Renombra el terminal actual
function M.rename(name)
  local buf = api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "terminal" then
    vim.notify("El buffer actual no es un terminal", vim.log.levels.WARN)
    return
  end
  vim.b[buf].term_name = name
  vim.cmd("redrawstatus")
end

return M
