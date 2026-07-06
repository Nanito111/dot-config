-- Fantasma: sin fondos, solo texto coloreado (bloques planos).
return {
  border = "square",
  layout = {
    left = { "label", "diagnostics" },
    center = { "mode" },
    right = { "lsp", "indent", "position", "percent" },
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
}
