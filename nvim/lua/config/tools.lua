-- Autoconfiguración de formatters/linters desde Mason: recorre los paquetes INSTALADOS,
-- mira sus metadatos (categoría Formatter/Linter y lenguajes) y arma las tablas por filetype
-- de conform (formatters_by_ft) y nvim-lint (linters_by_ft). Así, instalar una herramienta
-- con :Mason la activa sola, sin anotarla aquí. Se reconstruye al instalar/quitar en Mason.
local api = vim.api
local M = {}

-- Etiqueta de lenguaje de Mason -> filetypes de Neovim. Lista TODAS las etiquetas de Mason
-- (a la fecha) mapeadas a su filetype; para las que no estén aquí (p. ej. futuras) se cae al
-- nombre en minúsculas (ver fts_for). Si un filetype no existe en Neovim, simplemente nunca
-- dispara, así que no molesta. Las etiquetas que no son un lenguaje concreto van en SKIP.
local FT = {
  [".NET"] = { "cs" },
  AWK = { "awk" },
  Ada = { "ada" },
  Aiken = { "aiken" },
  Amber = { "amber" },
  Angular = { "htmlangular" },
  Ansible = { "yaml.ansible" },
  Antlers = { "antlers" },
  Apex = { "apexcode" },
  Arduino = { "arduino" },
  Assembly = { "asm" },
  Astro = { "astro" },
  AutoHotkey = { "autohotkey" },
  ["Azure Pipelines"] = { "yaml" },
  AzureResourceManager = { "json" },
  Bash = { "sh", "bash" },
  Bazel = { "bzl" },
  Beancount = { "beancount" },
  Bicep = { "bicep" },
  BitBake = { "bitbake" },
  Blade = { "blade" },
  BrighterScript = { "brighterscript" },
  C = { "c" },
  ["C#"] = { "cs" },
  ["C++"] = { "cpp" },
  C3 = { "c3" },
  CDS = { "cds" },
  CMake = { "cmake" },
  COBOL = { "cobol" },
  CQL = { "cql" },
  CSS = { "css" },
  Cairo = { "cairo" },
  Circom = { "circom" },
  Clarity = { "clarity" },
  Clojure = { "clojure" },
  ClojureScript = { "clojure" },
  CloudFormation = { "yaml", "json" },
  CodeQL = { "ql" },
  CoffeeScript = { "coffee" },
  Coq = { "coq" },
  Crystal = { "crystal" },
  Csh = { "csh" },
  Cucumber = { "cucumber" },
  Cue = { "cue" },
  Cypher = { "cypher" },
  D = { "d" },
  DOT = { "dot" },
  DTS = { "dts" },
  Dart = { "dart" },
  Dhall = { "dhall" },
  Dingo = { "dingo" },
  Django = { "htmldjango" },
  Docker = { "dockerfile" },
  Dockerfile = { "dockerfile" },
  Dotenv = { "dotenv" },
  Drools = { "drools" },
  Earthly = { "earthfile" },
  Elixir = { "elixir" },
  Elm = { "elm" },
  Ember = { "handlebars" },
  Emmet = {},
  Erg = { "erg" },
  Erlang = { "erlang" },
  ["F#"] = { "fsharp" },
  ["Facility Service Definition"] = {},
  Fennel = { "fennel" },
  Fish = { "fish" },
  Flow = { "javascript" },
  Flux = { "flux" },
  Fortran = { "fortran" },
  GDScript = { "gdscript" },
  GLSL = { "glsl" },
  GN = { "gn" },
  Glimmer = { "handlebars" },
  Go = { "go" },
  Gradle = { "groovy" },
  GraphQL = { "graphql" },
  Groovy = { "groovy" },
  HAML = { "haml" },
  HCL = { "hcl" },
  HTML = { "html" },
  HTMX = { "html" },
  Handlebars = { "handlebars" },
  Haskell = { "haskell" },
  Haxe = { "haxe" },
  Helm = { "helm" },
  Hoon = { "hoon" },
  Hylo = { "hylo" },
  Hypr = { "hyprlang" },
  IPython = { "python" },
  JSON = { "json", "jsonc" },
  ["JSON-LD"] = { "json" },
  JSX = { "javascriptreact" },
  Java = { "java" },
  JavaScript = { "javascript", "javascriptreact" },
  Jayvee = { "jayvee" },
  Jinja = { "jinja", "htmldjango" },
  Jq = { "jq" },
  Jsonnet = { "jsonnet" },
  Julia = { "julia" },
  Just = { "just" },
  KCL = { "kcl" },
  KDL = { "kdl" },
  Kerboscript = { "kerboscript" },
  Kotlin = { "kotlin" },
  Ksh = { "sh" },
  Kubernetes = { "yaml" },
  LESS = { "less" },
  LaTeX = { "tex" },
  ["Lean 3"] = { "lean" },
  Lelwel = { "lelwel" },
  Liquid = { "liquid" },
  Lua = { "lua" },
  Luau = { "luau" },
  M68K = { "asm68k" },
  MCFunction = { "mcfunction" },
  MDX = { "markdown.mdx", "mdx" },
  Makefile = { "make" },
  Markdown = { "markdown" },
  Marko = { "marko" },
  Matlab = { "matlab" },
  Mermaid = { "mermaid" },
  Meson = { "meson" },
  ["Metamath Zero"] = { "metamathzero" },
  Mksh = { "sh" },
  Motoko = { "motoko" },
  Move = { "move" },
  Mustache = { "mustache" },
  Nextflow = { "nextflow" },
  Nickel = { "nickel" },
  Nim = { "nim" },
  Nix = { "nix" },
  Nomad = { "hcl" },
  Nunjucks = { "html" },
  OCaml = { "ocaml" },
  ["OCaml-interface"] = { "ocamlinterface" },
  OCamllex = { "ocamllex" },
  Octave = { "octave" },
  Odin = { "odin" },
  OneScript = { "onescript" },
  OpenAPI = { "yaml", "json" },
  OpenCL = { "opencl" },
  OpenEdge = { "progress" },
  OpenFOAM = { "foam" },
  OpenGL = { "glsl" },
  OpenSCAD = { "openscad" },
  OpenTofu = { "terraform" },
  Org = { "org" },
  PHP = { "php" },
  ["PICO-8"] = { "lua" },
  Perl = { "perl" },
  Pest = { "pest" },
  Pkl = { "pkl" },
  Postgres = { "sql" },
  PowerShell = { "ps1" },
  Prisma = { "prisma" },
  Progress = { "progress" },
  PromQL = { "promql" },
  Protobuf = { "proto" },
  Pug = { "pug" },
  Puppet = { "puppet" },
  PureScript = { "purescript" },
  Python = { "python" },
  QML = { "qml" },
  Quarto = { "quarto" },
  R = { "r" },
  ["R Markdown"] = { "rmd" },
  Raku = { "raku" },
  ReScript = { "rescript" },
  Reason = { "reason" },
  Rego = { "rego" },
  ["Robot Framework"] = { "robot" },
  Roc = { "roc" },
  RsHtml = { "rhtml" },
  Ruby = { "ruby" },
  Rust = { "rust" },
  SCSS = { "scss" },
  SQL = { "sql" },
  Salt = { "sls" },
  Sass = { "sass" },
  Scala = { "scala" },
  Sh = { "sh" },
  Shell = { "sh", "bash" },
  Slang = { "slang" },
  Slint = { "slint" },
  Smithy = { "smithy" },
  Snakemake = { "snakemake" },
  Snakeskin = { "snakeskin" },
  Snyk = {},
  Solidity = { "solidity" },
  Sphinx = { "rst" },
  Stan = { "stan" },
  ["Standard ML"] = { "sml" },
  Starlark = { "starlark" },
  Stylelint = { "css", "scss" },
  SuperHTML = { "html" },
  Svelte = { "svelte" },
  Swift = { "swift" },
  SystemVerilog = { "systemverilog" },
  TOML = { "toml" },
  ["TTCN-3"] = { "ttcn" },
  Tcl = { "tcl" },
  Teal = { "teal" },
  Terraform = { "terraform" },
  Thrift = { "thrift" },
  Turtle = { "turtle" },
  Twig = { "twig" },
  TypeScript = { "typescript", "typescriptreact" },
  Typespec = { "typespec" },
  Typst = { "typst" },
  V = { "v" },
  VHDL = { "vhdl" },
  Vala = { "vala" },
  Verilog = { "verilog" },
  Veryl = { "veryl" },
  VimScript = { "vim" },
  Visualforce = { "visualforce" },
  Vue = { "vue" },
  WGSL = { "wgsl" },
  WebAssembly = { "wat" },
  Wing = { "wing" },
  XML = { "xml" },
  YAML = { "yaml" },
  YARA = { "yara" },
  Zeek = { "zeek" },
  Zig = { "zig" },
  Zsh = { "zsh" },
  bazelrc = { "bzl" },
  http = { "http" },
  nginx = { "nginx" },
  reStructuredText = { "rst" },
  sd = {},
  systemd = { "systemd" },
  ["yaml.docker-compose"] = { "yaml" },
  yql = { "sql" },
  ["1С:Enterprise"] = { "bsl" },
}

-- Etiquetas genéricas de Mason que NO son un lenguaje concreto: se ignoran (si no, un
-- formatter/linter etiquetado así se aplicaría a demasiados buffers).
local SKIP = { Text = true, Plain = true, Spec = true, Query = true, Generic = true, ["*"] = true }

-- Filetypes de Neovim para una etiqueta de Mason: excepción de FT, o el nombre en minúsculas
-- (sin espacios/puntos/guiones). Si el filetype no existe en Neovim, simplemente nunca dispara.
local function fts_for(lang)
  if SKIP[lang] then
    return {}
  end
  if FT[lang] then
    return FT[lang]
  end
  return { (lang:lower():gsub("[%s%.%-]", "")) }
end

-- Excepciones: nombre de paquete Mason -> nombre en conform/nvim-lint (si difiere),
-- o false para ignorar un paquete concreto. Vacío: para las herramientas comunes coincide.
local OVERRIDES = {
  ["sql-formatter"] = "sql_formatter", -- conform lo registra con guion bajo
}

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
          for _, ft in ipairs(fts_for(lang)) do
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

-- ── Overrides por (herramienta, filetype) ──────────────────────────
-- Igual que los servidores LSP: se deja elegir, por lenguaje, qué formateadores (conform) y
-- linters (nvim-lint) corren de los que Mason ofrece. Solo se persiste lo DESHABILITADO, en
-- dos claves (una por tipo); lo demás corre. La tabla del panel (settings.tools_table) edita
-- esto en vivo y config.tools filtra las tablas por filetype antes de empujarlas a cada plugin.
local KEYS = { fmt = "format.disabled", lint = "lint.disabled" } -- { [tool] = { [ft] = true } }
local disabled = { fmt = nil, lint = nil } -- cache por tipo; nil = sin cargar

local function dis(kind)
  if disabled[kind] == nil then
    disabled[kind] = vim.deepcopy(require("config.settings").value(KEYS[kind], {}))
  end
  return disabled[kind]
end

local function persist(kind)
  local d = disabled[kind]
  for tool, fts in pairs(d) do
    if next(fts) == nil then
      d[tool] = nil -- no dejar herramientas sin nada deshabilitado
    end
  end
  require("config.settings").record(KEYS[kind], d, {})
end

-- Candidatos "de fábrica" (lo que ofrece Mason, sin filtrar). Se recolectan de nuevo cada vez
-- que hace falta; collect() lee el registro de Mason de forma sincrónica una vez cargado.
local full = { fmt = nil, lint = nil }
local function full_tables()
  if not full.fmt then
    full.fmt, full.lint = collect()
  end
  return full
end

-- Tabla efectiva de un tipo: candidatos menos lo deshabilitado por (herramienta, filetype).
local function effective(kind)
  local src = full_tables()[kind]
  local d = dis(kind)
  local out = {}
  for ft, tools in pairs(src) do
    local keep = {}
    for _, t in ipairs(tools) do
      if not (d[t] and d[t][ft]) then
        keep[#keep + 1] = t
      end
    end
    out[ft] = keep
  end
  return out
end

-- Limpia los diagnósticos de un linter en los buffers de un filetype (al desactivarlo en vivo),
-- ya que nvim-lint no los retira solo hasta el próximo lintado.
local function clear_lint(tool, ft)
  local ok, lint = pcall(require, "lint")
  local ns = ok and lint.get_namespace and lint.get_namespace(tool)
  if not ns then
    return
  end
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == ft then
      pcall(vim.diagnostic.reset, ns, buf)
    end
  end
end

-- Empuja la tabla efectiva de un tipo al plugin correspondiente (si está cargado).
local function push(kind)
  if kind == "fmt" then
    if package.loaded["conform"] then
      require("conform").formatters_by_ft = effective("fmt")
    end
  else
    if package.loaded["lint"] then
      require("lint").linters_by_ft = effective("lint")
    end
  end
end

-- Aplica las tablas recolectadas (ya filtradas por overrides) a conform / nvim-lint y vuelve a
-- lintar el buffer actual, porque la primera pasada pudo correr con las tablas aún vacías.
local function apply()
  full.fmt, full.lint = collect()
  if package.loaded["conform"] then
    require("conform").formatters_by_ft = effective("fmt")
  end
  if package.loaded["lint"] then
    require("lint").linters_by_ft = effective("lint")
    pcall(function()
      require("lint").try_lint()
    end)
  end
end

-- Fuerza la carga de conform/nvim-lint (lazy: cargan al abrir un archivo) y refresca los
-- candidatos desde Mason. Se llama desde los puntos de entrada de la tabla del panel.
function M.ensure()
  if not package.loaded["conform"] or not package.loaded["lint"] then
    pcall(function()
      require("lazy").load({ plugins = { "conform.nvim", "nvim-lint" } })
    end)
  end
  -- nvim-lint no se auto-requiere al cargar su spec (solo registra autocomandos); forzarlo para
  -- que push() vea package.loaded["lint"] y pueda actualizar linters_by_ft en vivo.
  pcall(require, "conform")
  pcall(require, "lint")
  full.fmt, full.lint = collect()
end

-- ── Consulta / edición para la tabla del panel ─────────────────────
function M.is_enabled(kind, tool, ft)
  local d = dis(kind)[tool]
  return not (d and d[ft])
end

function M.set_enabled(kind, tool, ft, enabled)
  local d = dis(kind)
  if enabled then
    if d[tool] then
      d[tool][ft] = nil
    end
  else
    d[tool] = d[tool] or {}
    d[tool][ft] = true
  end
  persist(kind)
  push(kind)
  if kind == "lint" and not enabled then
    clear_lint(tool, ft)
  end
end

function M.toggle(kind, tool, ft)
  M.set_enabled(kind, tool, ft, not M.is_enabled(kind, tool, ft))
end

-- Reactiva todas las herramientas de un filetype (quita sus deshabilitados).
function M.reset_ft(kind, ft)
  local d = dis(kind)
  for _, fts in pairs(d) do
    fts[ft] = nil
  end
  persist(kind)
  push(kind)
end

-- Herramientas candidatas a un filetype, con su estado: { { name, enabled }, ... } (orden alfab.)
function M.tools_for_ft(kind, ft)
  M.ensure()
  local list = vim.deepcopy(full_tables()[kind][ft] or {})
  table.sort(list)
  local out = {}
  for _, t in ipairs(list) do
    out[#out + 1] = { name = t, enabled = M.is_enabled(kind, t, ft) }
  end
  return out
end

-- Filas del nivel 1 (lenguajes) de un tipo: un filetype por fila, con cuántas herramientas
-- corren de las candidatas y si tiene algo deshabilitado. Orden: varias herramientas primero.
function M.rows(kind)
  M.ensure()
  local src = full_tables()[kind]
  local rows = {}
  for ft, tools in pairs(src) do
    local list = vim.deepcopy(tools)
    table.sort(list)
    local on, overridden = 0, false
    for _, t in ipairs(list) do
      if M.is_enabled(kind, t, ft) then
        on = on + 1
      else
        overridden = true
      end
    end
    rows[#rows + 1] = { ft = ft, tools = list, total = #list, enabled = on, overridden = overridden }
  end
  table.sort(rows, function(a, b)
    if a.total ~= b.total then
      return a.total > b.total
    end
    return a.ft < b.ft
  end)
  return rows
end

-- Reconstruye las tablas desde Mason. El spec de cada paquete (sus categorías y lenguajes)
-- sale del índice de fuentes del registro, que carga de forma ASÍNCRONA; si se recolecta antes
-- de que esté listo, los spec vienen vacíos y no se mapea nada. Por eso se recolecta dentro de
-- refresh(), que garantiza las fuentes cargadas (usa caché; no descarga si está fresca).
function M.rebuild()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return
  end
  registry.refresh(vim.schedule_wrap(apply))
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
