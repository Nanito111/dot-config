-- Estilo VSCode: barra continua (sin píldoras), rama a la izquierda y posición/lenguaje
-- a la derecha. El color de la barra viene del TEMA: un azul oscurecido a partir de
-- palette.blue; `fill` pinta los huecos del mismo color para que se vea como una sola barra.
local function bar(p)
  local h = p.blue:gsub("#", "")
  local r = math.floor(tonumber(h:sub(1, 2), 16) * 0.6)
  local g = math.floor(tonumber(h:sub(3, 4), 16) * 0.6)
  local b = math.floor(tonumber(h:sub(5, 6), 16) * 0.6)
  return string.format("#%02x%02x%02x", r, g, b)
end

return {
  border = "square",
  fill = bar, -- barra del azul del tema, oscurecido
  layout = {
    left = { "git", "gitdiff", "mode" },
    center = { "diagnostics" },
    right = { "lsp", "indent", "position", "filetype" },
  },
  colors = function(pair, p)
    local bg, fg = bar(p), p.fg -- texto claro del tema sobre la barra azul oscura
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
}
