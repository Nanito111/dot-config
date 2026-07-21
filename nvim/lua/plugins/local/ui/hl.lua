-- Resaltado por tramos de línea con extmarks (el patrón repetido en settings/picker/…).
local api = vim.api
local M = {}

-- Colorea el tramo [col, end_col) de la línea `row` (0-based) con `group`.
function M.span(buf, ns, row, col, end_col, group)
  pcall(api.nvim_buf_set_extmark, buf, ns, row, col, { end_col = end_col, hl_group = group })
end

-- Aplica una lista de marcas con el estilo { {row, col, {end_col=, hl_group=, ...}}, ... }.
function M.line_marks(buf, ns, marks)
  for _, m in ipairs(marks) do
    pcall(api.nvim_buf_set_extmark, buf, ns, m[1], m[2], m[3])
  end
end

return M
