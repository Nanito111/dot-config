-- diffview.nvim (fork dlyongemallo): visor de diffs y de historial de git en pestañas.
-- Se carga bajo demanda (por comando o atajo). Requiere plenary; los iconos son opcionales
-- (ya está nvim-web-devicons). Atajos en el grupo Git (<leader>g).
return {
  "dlyongemallo/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewRefresh",
    "DiffviewFileHistory",
  },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: cambios del árbol" },
    { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diffview: cerrar" },
    { "<leader>gh", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: historial del repo" },
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: historial del archivo" },
  },
  opts = {}, -- valores por defecto (use_icons se apoya en nvim-web-devicons)
}
