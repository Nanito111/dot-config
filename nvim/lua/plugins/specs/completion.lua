-- blink.cmp: motor de completado moderno y rápido (fuzzy en Rust). Trae fuentes
-- LSP/path/snippets/buffer integradas y un binario precompilado vía release.
return {
  "saghen/blink.cmp",
  version = "*", -- usar la última release (incluye el binario de fuzzy precompilado)
  event = "InsertEnter",
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    -- preset 'default': <C-y> confirma, <C-Space> abre/documenta, <C-n>/<C-p> navegan
    keymap = { preset = "default" },
    appearance = { nerd_font_variant = "mono" },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      menu = { border = "rounded" },
    },
    signature = { enabled = true, window = { border = "rounded" } },
    -- si no se pudo bajar el binario de Rust, cae al matcher en Lua con aviso
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
