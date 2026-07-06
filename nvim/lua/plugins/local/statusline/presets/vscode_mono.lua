-- VSCode monocromático: barra neutra continua, texto atenuado, sin acento de color. El
-- color de la barra viene del TEMA: un gris oscurecido a partir de palette.bg_highlight
-- (más oscuro que el resaltado, sin llegar al casi-negro de bg_dark).
local function bar(p)
  local h = p.bg_highlight:gsub("#", "")
  local r = math.floor(tonumber(h:sub(1, 2), 16) * 0.65)
  local g = math.floor(tonumber(h:sub(3, 4), 16) * 0.65)
  local b = math.floor(tonumber(h:sub(5, 6), 16) * 0.65)
  return string.format("#%02x%02x%02x", r, g, b)
end

return {
  border = "square",
  fill = bar, -- barra del gris (más oscuro que el resaltado del tema)
  mono = true, -- sin acento de color: gitdiff/diagnósticos usan el color del texto
  layout = {
    left = { "git", "gitdiff", "mode" },
    center = { "diagnostics" },
    right = { "lsp", "indent", "position", "filetype" },
  },
  colors = function(pair, p)
    local bg, fg = bar(p), p.fg -- texto normal del tema sobre la barra gris oscura
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
