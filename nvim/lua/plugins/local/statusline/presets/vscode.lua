-- Estilo VSCode: barra continua (sin píldoras), rama a la izquierda y posición/lenguaje
-- a la derecha. El color de la barra viene del PROPIO TEMA: usa el color que el
-- colorscheme define para la StatusLine (palette.statusline_bg/fg); si el tema no lo
-- define, cae a un fondo oscuro derivado. `fill` pinta los huecos del mismo color para
-- que se vea como una sola barra.
return {
  border = "square",
  fill = function(p)
    return p.statusline_bg -- barra del color de statusline del tema
  end,
  layout = {
    left = { "git", "gitdiff", "diagnostics", "mode" },
    center = {},
    right = { "lsp", "indent", "position_lncol", "filetype" },
  },
  colors = function(pair, p)
    local bg, fg = p.statusline_bg, p.statusline_fg -- colores de statusline del tema
    -- Aplanar solo los segmentos NO-modo al color de la barra; los grupos del modo
    -- (StNormal/StInsert/…) se dejan con su color por modo (default_colors) para que el
    -- bloque de modo destaque como acento sobre la barra oscura.
    for _, g in ipairs({ "StGit", "StFile", "StInfo" }) do
      pair(g, fg, bg)
    end
  end,
}
