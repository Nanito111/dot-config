-- duck.nvim: una mascota (un patito por defecto) que se pasea caminando por el
-- editor. Puro juguete, sin dependencias. Se carga en diferido al usar sus keymaps.
--   <leader>pp  soltar un pato        (hatch)
--   <leader>pk  cocinar el último     (cook)   → lo quita
--   <leader>pa  cocinar todos         (cook_all)
-- hatch(char, speed): char = carácter/emoji de la mascota; speed = velocidad
-- (número mayor = más rápida). Cambia el emoji si prefieres otro bicho: 🐈 🐕 🐸 🦀
return {
  "tamton-aquib/duck.nvim",
  keys = {
    { "<leader>pp", function() require("duck").hatch("🦆", 10) end, desc = "Pato: soltar uno" },
    { "<leader>pk", function() require("duck").cook() end, desc = "Pato: cocinar el último" },
    { "<leader>pa", function() require("duck").cook_all() end, desc = "Pato: cocinar todos" },
  },
}
