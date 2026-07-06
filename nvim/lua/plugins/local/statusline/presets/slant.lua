-- Atardecer: tonos cálidos y extremos diagonales.
return {
  border = "slant",
  layout = {
    left = { "git", "gitdiff", "label", "diagnostics" },
    center = { "mode" },
    right = { "lsp", "indent", "filetype", "position", "percent" },
  },
  colors = function(pair, p)
    pair("StGit", p.bg, p.orange, { bold = true })
    pair("StFile", p.bg, p.yellow)
    pair("StInfo", p.orange, p.bg_highlight)
  end,
}
