-- Autoconfiguración de formatters/linters desde Mason: recorre los paquetes INSTALADOS,
-- mira sus metadatos (categoría Formatter/Linter y lenguajes) y arma las tablas por filetype
-- de conform (formatters_by_ft) y nvim-lint (linters_by_ft). Así, instalar una herramienta
-- con :Mason la activa sola, sin anotarla aquí. Se reconstruye al instalar/quitar en Mason.
local M = {}

-- Único mapeo que hay que mantener: etiqueta de lenguaje de Mason -> filetypes de Neovim.
local LANG2FT = {
  Lua = { "lua" },
  JavaScript = { "javascript", "javascriptreact" },
  TypeScript = { "typescript", "typescriptreact" },
  JSON = { "json", "jsonc" },
  YAML = { "yaml" },
  CSS = { "css", "scss", "less" },
  SCSS = { "scss" },
  LESS = { "less" },
  HTML = { "html" },
  Markdown = { "markdown" },
  Python = { "python" },
  Shell = { "sh", "bash" },
  Bash = { "sh", "bash" },
  Go = { "go" },
  Rust = { "rust" },
  ["C++"] = { "cpp" },
  C = { "c" },
  ["C#"] = { "cs" },
  TOML = { "toml" },
  XML = { "xml" },
  SQL = { "sql" },
  Docker = { "dockerfile" },
  Vim = { "vim" },
}

-- Excepciones: nombre de paquete Mason -> nombre en conform/nvim-lint (si difiere),
-- o false para ignorar un paquete concreto. Vacío: para las herramientas comunes coincide.
local OVERRIDES = {}

-- Agrega `tool` a tbl[ft] sin repetir (varias etiquetas de lenguaje pueden mapear al mismo ft).
local function add(tbl, ft, tool)
  tbl[ft] = tbl[ft] or {}
  for _, x in ipairs(tbl[ft]) do
    if x == tool then
      return
    end
  end
  table.insert(tbl[ft], tool)
end

-- Recorre lo instalado y devuelve { formatters_by_ft, linters_by_ft }.
local function collect()
  local fmt, lint = {}, {}
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return fmt, lint
  end
  for _, name in ipairs(registry.get_installed_package_names()) do
    local okp, pkg = pcall(registry.get_package, name)
    local spec = okp and pkg and pkg.spec or nil
    local tool = OVERRIDES[name]
    if tool == nil then
      tool = name
    end
    if spec and tool then
      local is_fmt, is_lint = false, false
      for _, c in ipairs(spec.categories or {}) do
        if c == "Formatter" then
          is_fmt = true
        elseif c == "Linter" then
          is_lint = true
        end
      end
      if is_fmt or is_lint then
        for _, lang in ipairs(spec.languages or {}) do
          for _, ft in ipairs(LANG2FT[lang] or {}) do
            if is_fmt then
              add(fmt, ft, tool)
            end
            if is_lint then
              add(lint, ft, tool)
            end
          end
        end
      end
    end
  end
  return fmt, lint
end

-- Aplica las tablas a conform / nvim-lint (a los que estén cargados).
function M.rebuild()
  local fmt, lint = collect()
  if package.loaded["conform"] then
    require("conform").formatters_by_ft = fmt
  end
  if package.loaded["lint"] then
    require("lint").linters_by_ft = lint
  end
end

-- Reconstruye cuando Mason instala o quita un paquete (una sola vez).
local hooked = false
function M.watch()
  if hooked then
    return
  end
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return
  end
  hooked = true
  registry:on("package:install:success", vim.schedule_wrap(M.rebuild))
  registry:on("package:uninstall:success", vim.schedule_wrap(M.rebuild))
end

return M
