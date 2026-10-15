-- Configuración por linter de nvim-lint. A diferencia de conform (que tiene `formatters` y
-- `prepend_args`), nvim-lint no expone una tabla de opciones: hay que inyectar el flag de
-- config en los `args` del linter. apply() lo hace para cada linter que tenga su fichero en
-- nvim/lua/config/tools-settings/linter/ (ignorado por git; un fichero por nombre). Es idempotente y
-- no hace nada si el fichero no existe, para que un clon nuevo siga lintando con los defaults.
-- Lo llama el spec de nvim-lint tras cargar. Ver también config.tools (qué linter corre en
-- cada filetype) y config.formatters (equivalente para conform).
local M = {}

local dir = vim.fn.stdpath("config") .. "/lua/config/tools-settings/linter/"

-- name = nombre del linter en nvim-lint; file = fichero esperado en linter-config/;
-- flag = cómo se le pasa su config.
local SPECS = {
  sqlfluff = { file = "sqlfluff", flag = "--config" },
}

-- Ruta a un fichero de linter-config/ si existe, o nil.
local function cfg(file)
  local path = dir .. file
  return vim.uv.fs_stat(path) and path or nil
end

-- Inserta `flag path` en args, antes del `-` de stdin si lo hay (si no, al final). No repite.
local function inject(args, flag, path)
  if vim.tbl_contains(args, flag) then
    return
  end
  local pos = #args + 1
  for i, a in ipairs(args) do
    if a == "-" then
      pos = i
      break
    end
  end
  table.insert(args, pos, path)
  table.insert(args, pos, flag)
end

function M.apply()
  local ok, lint = pcall(require, "lint")
  if not ok then
    return
  end
  for name, spec in pairs(SPECS) do
    local path = cfg(spec.file)
    if path then
      local linter = lint.linters[name]
      if type(linter) == "table" and type(linter.args) == "table" then
        inject(linter.args, spec.flag, path)
      end
    end
  end
end

return M
