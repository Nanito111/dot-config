-- Cierre idempotente de flotantes: cierra ventanas válidas y borra buffers (force), en pcall.
-- Acepta un handle suelto o una lista para cada uno. Se expone como `ui.close(wins, bufs)`.
local api = vim.api

local function each(x, fn)
  if type(x) == "table" then
    for _, v in ipairs(x) do
      fn(v)
    end
  elseif x then
    fn(x)
  end
end

return function(wins, bufs)
  each(wins, function(w)
    if w and api.nvim_win_is_valid(w) then
      pcall(api.nvim_win_close, w, true)
    end
  end)
  each(bufs, function(b)
    if b and api.nvim_buf_is_valid(b) then
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end)
end
