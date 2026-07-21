-- Ajuste de texto por ancho de PANTALLA (respeta multibyte / dobles anchos).
local M = {}
local dw = vim.fn.strdisplaywidth

-- Rellena `str` con espacios hasta `width` celdas. align: "l" (izq, por defecto) | "r" (der).
function M.pad(str, width, align)
  local n = width - dw(str)
  if n <= 0 then
    return str
  end
  local sp = string.rep(" ", n)
  return align == "r" and (sp .. str) or (str .. sp)
end

-- Ajusta `str` a EXACTAMENTE `width` celdas: trunca por carácter si sobra, rellena si falta.
function M.fit(str, width, align)
  if dw(str) <= width then
    return M.pad(str, width, align)
  end
  local out, w = "", 0
  for _, ch in ipairs(vim.fn.split(str, "\\zs")) do
    local cw = dw(ch)
    if w + cw > width then
      break
    end
    out, w = out .. ch, w + cw
  end
  return M.pad(out, width, align)
end

return M
