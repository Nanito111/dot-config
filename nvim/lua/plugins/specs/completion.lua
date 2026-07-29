-- blink.cmp: motor de completado moderno y rápido (fuzzy en Rust). Trae fuentes
-- LSP/path/snippets/buffer integradas y un binario precompilado vía release.
return {
  "saghen/blink.cmp",
  version = "*", -- usar la última release (incluye el binario de fuzzy precompilado)
  -- CmdlineEnter además de InsertEnter: sin él, blink no se carga al abrir ":" (si no
  -- has entrado antes en inserción) y no hay completado en la línea de comandos.
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    -- preset 'default': <C-y> confirma, <C-n>/<C-p> navegan. Encima añadimos:
    --   <C-k>  -> abrir el menú de autocompletado (Ctrl+Space no lo envía esta terminal)
    --   <Tab>  -> aceptar la sugerencia seleccionada; si no hay menú, Tab normal
    keymap = {
      preset = "default",
      ["<C-k>"] = { "show", "show_documentation", "hide_documentation" },
      ["<Tab>"] = { "accept", "fallback" },
    },
    appearance = { nerd_font_variant = "mono" },
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "todo" },
      providers = {
        -- tags del plugin de TODO (TODO:/FIXME:/…) al escribir en un comentario
        todo = { name = "TODO", module = "plugins.local.todo.source" },
      },
    },
    completion = {
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = {}, -- el borde lo da vim.o.winborder
      },
      menu = {},
    },
    signature = { enabled = true },
    -- Completado en la línea de comandos (":"): por defecto blink NO muestra el menú
    -- automáticamente ahí (solo en la ventana de comandos q:). Lo forzamos a mostrarse
    -- al escribir, con el borde a juego. Navegación: <Tab>/<S-Tab> (preset 'cmdline').
    cmdline = {
      -- Mismos atajos que en el editor: el preset 'cmdline' ya trae <C-n>/<C-p> para
      -- moverse y <C-e> para cerrar; solo cambiamos <Tab> para que CONFIRME la opción
      -- (como el <Tab> de inserción), en vez de mostrar/ciclar.
      keymap = {
        preset = "cmdline",
        ["<Tab>"] = { "accept", "fallback" },
      },
      completion = {
        menu = { auto_show = true },
      },
    },
    -- si no se pudo bajar el binario de Rust, cae al matcher en Lua con aviso
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
