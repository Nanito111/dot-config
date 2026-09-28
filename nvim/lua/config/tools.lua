-- Autoconfiguración de formatters/linters desde Mason: recorre los paquetes INSTALADOS,
-- mira sus metadatos (categoría Formatter/Linter y lenguajes) y arma las tablas por filetype
-- de conform (formatters_by_ft) y nvim-lint (linters_by_ft). Así, instalar una herramienta
-- con :Mason la activa sola, sin anotarla aquí. Se reconstruye al instalar/quitar en Mason.
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
