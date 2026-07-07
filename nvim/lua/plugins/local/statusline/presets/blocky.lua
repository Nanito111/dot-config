-- Blocky: bloques sólidos y saturados, bordes rectos, todo en negrita.
return {
  border = "square",
  mono = true, -- fondos saturados: gitdiff/diagnósticos usan el color del texto (legibles)
  layout = {
    left = { "git", "gitdiff", "label", "diagnostics" },
    center = { "mode" },
    right = { "lsp", "indent", "filetype", "position", "percent" },
  },
  colors = function(pair, p)
    pair("StGit", p.bg, p.cyan, { bold = true }) -- rama sobre cian
    pair("StFile", p.bg, p.purple, { bold = true }) -- etiqueta sobre morado
    pair("StInfo", p.bg, p.blue, { bold = true }) -- info sobre azul (no gris)
  end,
}
