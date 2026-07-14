-- Colorschemes. Se cargan al inicio (lazy=false) con prioridad alta para estar
-- disponibles antes de aplicar el tema guardado. Cada uno solo define highlights
-- cuando se ejecuta :colorscheme, así que tenerlos cargados es barato.
-- La lista de nombres seleccionables vive en lua/config/themes.lua.
return {
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000 },
  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
  { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
  { "EdenEast/nightfox.nvim", lazy = false, priority = 1000 },
  { "kepano/flexoki-neovim", name = "flexoki", lazy = false, priority = 1000 },
}
