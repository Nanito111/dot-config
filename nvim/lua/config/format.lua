-- Formateo: fachada sobre conform.nvim. El "formatear al guardar" se controla con el ajuste
-- editor.format_on_save (persistente, con toggle en el panel de configuración y en <leader>lF).
local M = {}
local KEY = "editor.format_on_save"

-- ¿Formatear al guardar? (lo lee conform en cada guardado)
function M.on_save_enabled()
  return require("config.settings").value(KEY, true)
end

-- get/set para el panel de configuración (apply = set: solo persiste, sin efecto inmediato).
function M.get()
  return M.on_save_enabled()
end
function M.set(v)
  require("config.settings").record(KEY, v and true or false, true)
end

function M.toggle()
  local v = not M.on_save_enabled()
  M.set(v)
  vim.notify(
    "Formatear al guardar: " .. (v and "activado" or "desactivado"),
    vim.log.levels.INFO,
    { title = "Formato", ephemeral = true }
  )
end

-- Formatea el buffer ahora (conform; si no hay formateador, cae al del LSP).
function M.format()
  require("conform").format({ async = true, lsp_format = "fallback" })
end

return M
