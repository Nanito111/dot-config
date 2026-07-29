-- Fuente de blink.cmp: al escribir DENTRO de un comentario, ofrece los tags del plugin
-- (TODO:, FIXME:, HACK:…) como sugerencias. Se registra en plugins/specs/completion.lua.
local source = {}

-- ¿el cursor está en un comentario? treesitter primero (fiable por lenguaje), con fallback
-- a la sintaxis clásica para buffers sin parser TS.
local function in_comment()
  local ok, captures = pcall(vim.treesitter.get_captures_at_cursor, 0)
  if ok and captures then
    for _, c in ipairs(captures) do
      if c:find("comment", 1, true) then
        return true
      end
    end
    -- con TS activo pero sin captura de comentario: no lo estamos
    if #captures > 0 then
      return false
    end
  end
  -- fallback: sintaxis de Vim
  local line, col = vim.fn.line("."), vim.fn.col(".") - 1
  local sid = vim.fn.synID(line, math.max(col, 1), 1)
  local name = vim.fn.synIDattr(vim.fn.synIDtrans(sid), "name")
  return name:lower():find("comment", 1, true) ~= nil
end

function source.new()
  return setmetatable({}, { __index = source })
end

function source:enabled()
  return vim.bo.buftype == "" -- solo archivos reales (no terminales, paneles, flotantes)
end

function source:get_completions(_, callback)
  if not in_comment() then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  local kind = vim.lsp.protocol.CompletionItemKind.Keyword
  local items = {}
  for _, kw in ipairs(require("plugins.local.todo").keywords) do
    items[#items + 1] = {
      label = kw,
      insertText = kw .. ": ",
      kind = kind,
    }
  end
  callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
end

return source
