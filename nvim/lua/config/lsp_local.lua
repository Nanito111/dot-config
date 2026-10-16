-- Ajustes locales por servidor LSP. A diferencia de formatters/linters (binarios a los que se
-- les pasa un fichero de config con un flag), un servidor LSP se configura por el protocolo con
-- una tabla Lua (settings, cmd, capabilities…). Por eso aquí el fichero por nombre es un .lua que
-- devuelve esa tabla, no un JSON. apply() carga nvim/lua/config/tools-settings/lsp/<servidor>.lua
-- (ignorado por git; un fichero por nombre de servidor) y lo fusiona con vim.lsp.config, deep-merge sobre
-- la config base. Se llama al final del spec de nvim-lspconfig, para que gane sobre los ajustes
-- versionados. No hace nada si el directorio o el fichero no existen (un clon nuevo sigue igual).
-- Ver también config.lsp (qué servidor corre en cada filetype).
local M = {}

local dir = vim.fn.stdpath("config") .. "/lua/config/tools-settings/lsp/"

function M.apply()
  for _, path in ipairs(vim.fn.glob(dir .. "*.lua", false, true)) do
    local name = vim.fn.fnamemodify(path, ":t:r")
    local ok, cfg = pcall(dofile, path)
    if ok and type(cfg) == "table" then
      pcall(vim.lsp.config, name, cfg)
    else
      vim.notify("lsp-config/" .. name .. ".lua did not return a table", vim.log.levels.WARN)
    end
  end
end

return M
