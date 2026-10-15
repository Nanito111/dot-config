-- Configuración por formateador de conform (pasa tal cual a conform.setup como `formatters`).
-- Afina la definición de cada herramienta: comando, args, cwd, etc. Aquí es donde se agregan o
-- ajustan formateadores concretos.
-- No confundir con:
--   • config.tools  -> qué formateador corre en cada filetype (derivado de Mason).
--   • config.format -> fachada de "formatear al guardar" / format() / estado del panel.
--
-- Los ficheros de configuración propios de cada herramienta viven en nvim/formatter-config/
-- (ignorado por git; un fichero por nombre de formateador). Se le pasan con el flag que use
-- cada una SOLO si existen, para que un clon nuevo sin ellos siga formateando con los defaults.
local dir = vim.fn.stdpath("config") .. "/formatter-config/"

-- Ruta a un fichero de formatter-config/ si existe, o nil.
local function cfg(file)
  local path = dir .. file
  return vim.uv.fs_stat(path) and path or nil
end

local M = {}

-- sql-formatter: sin -c solo autodetecta subiendo desde el cwd, que no alcanza el home en
-- proyectos de /mnt/c; por eso se le pasa la config explícita.
local sql = cfg("sql-formatter.json")
if sql then
  M.sql_formatter = { prepend_args = { "-c", sql } }
end

return M
