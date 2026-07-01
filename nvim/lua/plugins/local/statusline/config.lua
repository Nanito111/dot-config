-- Ajustes de la statusline EN UN SOLO LUGAR.
--   • presets -> bundles de { border + layout + colores opcionales }; el activo
--                se elige con preset / :StatuslinePreset / <leader>us (picker).
--   • borders -> catálogo de extremos de píldora (eje rápido: <leader>ub / cycle).
--   • width   -> ancho fijo (columnas) de cada componente.
--   • icons   -> glifos usados por los componentes.
-- Componentes nuevos -> components.lua. Forma de la píldora -> core.lua.
return {
  -- ── Presets de statusline ─────────────────────────────────────────
  preset = "default", -- preset activo al arrancar
  presets = {
    default = {
      border = "round",
      layout = {
        left = { "git", "label", "diagnostics" },
        center = { "mode" },
        right = { "lsp", "filetype", "position", "percent" },
      },
    },
    -- Powerline: bloque de modo a la IZQUIERDA, segmentos de colores, flechas.
    powerline = {
      border = "arrow",
      layout = {
        left = { "mode", "git", "label", "diagnostics" },
        center = {},
        right = { "lsp", "filetype", "position", "percent" },
      },
      colors = function(pair, p)
        pair("StGit", p.bg, p.green, { bold = true }) -- rama sobre verde
        pair("StFile", p.bg, p.blue) -- etiqueta sobre azul
      end,
    },
    -- Fantasma: sin fondos, solo texto coloreado (bloques planos).
    minimal = {
      border = "square",
      layout = {
        left = { "label", "diagnostics" },
        center = { "mode" },
        right = { "lsp", "position", "percent" },
      },
      colors = function(pair, p)
        -- modo: solo texto del color del modo, sin fondo
        pair("StNormal", p.blue)
        pair("StInsert", p.green)
        pair("StVisual", p.purple)
        pair("StReplace", p.red)
        pair("StCommand", p.yellow)
        pair("StTerminal", p.cyan)
        pair("StFile", p.fg) -- etiqueta en texto normal
        pair("StInfo", p.comment) -- info tenue
        pair("StGit", p.comment)
      end,
    },
    -- Atardecer: tonos cálidos y extremos diagonales.
    slant = {
      border = "slant",
      layout = {
        left = { "git", "label", "diagnostics" },
        center = { "mode" },
        right = { "lsp", "filetype", "position", "percent" },
      },
      colors = function(pair, p)
        pair("StGit", p.bg, p.orange, { bold = true })
        pair("StFile", p.bg, p.yellow)
        pair("StInfo", p.orange, p.bg_highlight)
      end,
    },
    -- Fino: fondo transparente (se ve el del terminal), extremos finos y texto en
    -- negrita que destaca. Requiere transparent=true para que los caps finos se
    -- pinten con el color del texto y la línea no tenga relleno.
    thin = {
      border = "thin",
      transparent = true,
      layout = {
        left = { "git", "label", "diagnostics" },
        center = { "mode" },
        right = { "lsp", "filetype", "position", "percent" },
      },
      colors = function(pair, p)
        local function t(name, fg)
          pair(name, fg, nil, { bold = true })
        end
        t("StNormal", p.blue) -- modo: color del modo como texto
        t("StInsert", p.green)
        t("StVisual", p.purple)
        t("StReplace", p.red)
        t("StCommand", p.yellow)
        t("StTerminal", p.cyan)
        t("StGit", p.blue) -- rama
        t("StFile", p.fg) -- etiqueta
        t("StInfo", p.comment) -- info tenue
      end,
    },
    -- Estilo VSCode: barra azul continua (sin píldoras), rama a la izquierda y
    -- posición/lenguaje a la derecha. `fill` pinta los huecos del mismo azul para
    -- que se vea como una sola barra; `colors` deja todos los segmentos planos.
    vscode = {
      border = "square",
      fill = "#007acc",
      layout = {
        left = { "git", "label", "diagnostics" },
        center = { "mode" },
        right = { "lsp", "position", "filetype" },
      },
      colors = function(pair)
        local bg, fg = "#007acc", "#ffffff"
        for _, g in ipairs({
          "StNormal",
          "StInsert",
          "StVisual",
          "StReplace",
          "StCommand",
          "StTerminal",
          "StGit",
          "StFile",
          "StInfo",
        }) do
          pair(g, fg, bg)
        end
      end,
    },
    -- VSCode monocromático: barra gris oscura continua, texto gris atenuado,
    -- sin acento de color (mismo layout plano que vscode).
    vscode_mono = {
      border = "square",
      fill = "#2d2d2d",
      layout = {
        left = { "git", "label", "diagnostics" },
        center = { "mode" },
        right = { "lsp", "position", "filetype" },
      },
      colors = function(pair)
        local bg, fg = "#2d2d2d", "#cccccc"
        for _, g in ipairs({
          "StNormal",
          "StInsert",
          "StVisual",
          "StReplace",
          "StCommand",
          "StTerminal",
          "StGit",
          "StFile",
          "StInfo",
        }) do
          pair(g, fg, bg)
        end
      end,
    },
    -- Blocky: bloques sólidos y saturados, bordes rectos, todo en negrita.
    blocky = {
      border = "square",
      layout = {
        left = { "git", "label", "diagnostics" },
        center = { "mode" },
        right = { "lsp", "filetype", "position", "percent" },
      },
      colors = function(pair, p)
        pair("StGit", p.bg, p.cyan, { bold = true }) -- rama sobre cian
        pair("StFile", p.bg, p.purple, { bold = true }) -- etiqueta sobre morado
        pair("StInfo", p.bg, p.blue, { bold = true }) -- info sobre azul (no gris)
      end,
    },
    -- Un preset puede además redefinir colores con un hook `colors(pair, palette)`
    -- donde pair(grupo, fg, bg, opts?) define el grupo y su "<grupo>Sep". Ej.:
    --
    -- focus = {
    --   border = "slant",
    --   layout = { left = {}, center = { "mode" }, right = { "position", "percent" } },
    --   colors = function(pair, palette)
    --     pair("StGit", palette.fg, palette.bg_highlight)
    --     -- ...los grupos que quieras cambiar; el resto usa los del preset por defecto
    --   end,
    -- },
  },

  -- ── Catálogo de bordes (extremos de píldora) ──────────────────────
  borders = {
    round = { left = "\u{e0b6}", right = "\u{e0b4}" }, --   mediaslunas
    arrow = { left = "\u{e0b2}", right = "\u{e0b0}" }, --   flechas
    slant = { left = "\u{e0ba}", right = "\u{e0b8}" }, --   diagonales
    thin = { left = "\u{e0b7}", right = "\u{e0b5}" }, --   medialuna fina
    square = { left = "", right = "" }, -- sin extremos (bloques planos)
  },

  -- ── Anchos fijos (columnas) de cada componente ────────────────────
  width = {
    git = 16,
    filetype = 8,
    position = 9,
    percent = 4,
  },

  -- ── Glifos (Nerd Font) ────────────────────────────────────────────
  icons = {
    branch = "\u{e0a0}", --  rama de git
    ahead = "\u{2191}", -- ↑ commits por delante del upstream
    behind = "\u{2193}", -- ↓ commits por detrás del upstream
    terminal = "\u{f489}", --  buffer de terminal
    files = "\u{f07b}", --  explorador de archivos
    lsp = "\u{f085}", --  servidor(es) LSP activos
    diag_error = "\u{f057}", --  diagnóstico: error
    diag_warn = "\u{f071}", --  diagnóstico: aviso
    diag_info = "\u{f05a}", --  diagnóstico: info
    diag_hint = "\u{f0eb}", --  diagnóstico: pista
  },
}
