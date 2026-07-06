-- Powerline: bloque de modo a la IZQUIERDA, segmentos de colores, flechas.
return {
  border = "arrow",
  layout = {
    left = { "mode", "git", "gitdiff", "label", "diagnostics" },
    center = {},
    right = { "lsp", "indent", "filetype", "position", "percent" },
  },
  colors = function(pair, p)
    pair("StGit", p.bg, p.green, { bold = true }) -- rama sobre verde
    pair("StFile", p.bg, p.blue) -- etiqueta sobre azul
  end,
}
