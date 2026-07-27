-- Iconos de archivo por nombre/extensión. La fachada config.icons lee de aquí (antes de
-- tablas locales copiadas a mano). Debe estar en el rtp desde el arranque: lo usa la
-- statusline en el primer render, antes de cualquier lazy-load.
return {
  "nvim-tree/nvim-web-devicons",
  lazy = false,
  priority = 900,
  opts = {},
}
