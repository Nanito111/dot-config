-- Fino: fondo transparente (se ve el del terminal), extremos finos y texto en negrita
-- que destaca. Requiere transparent=true para que los caps finos se pinten con el color
-- del texto y la línea no tenga relleno.
return {
  border = "thin",
  transparent = true,
  layout = {
    left = { "git", "gitdiff", "label", "diagnostics" },
    center = { "mode" },
    right = { "lsp", "indent", "filetype", "position", "percent" },
  },
  colors = function(pair, p)
    local function t(name, fg)
      pair(name, fg, nil, { bold = true })
    end
    t("StNormal", p.blue) -- modo: color del modo como texto
    t("StInsert", p.green)
    t("StVisual", p.purple)
    t("StReplace", p.red)
    t("StCommand", p.yellow)
    t("StTerminal", p.cyan)
    t("StGit", p.blue) -- rama
    t("StFile", p.fg) -- etiqueta
    t("StInfo", p.comment) -- info tenue
  end,
}
