-- duck.nvim: una mascota (un patito por defecto) que se pasea caminando por el
-- editor. Puro juguete, sin dependencias. Se carga en diferido al usar sus keymaps.
--   <leader>pp  soltar un pato        (hatch)
--   <leader>pk  cocinar el último     (cook)   → lo quita
--   <leader>pa  cocinar todos         (cook_all)
-- hatch(char, speed): char = carácter/emoji de la mascota; speed = velocidad
-- (número mayor = más rápida). Cambia el emoji si prefieres otro bicho: 🦆 🐈 🐕 🐸 🦀 🐜 🦋

-- La mascota es una flotante SIN marco: el borde se leería del 'winborder' global (el
-- patito saldría enmarcado). La ventana lo lee al crearse, así que lo forzamos a "none"
-- solo durante el hatch y marcamos la ventana como borderless (que el reborde la respete).
local function hatch(char, speed)
  local duck = require("duck")
  local saved = vim.o.winborder
  vim.o.winborder = "none"
  duck.hatch(char, speed)
  vim.o.winborder = saved
  local last = duck.ducks_list[#duck.ducks_list]
  if last and vim.api.nvim_win_is_valid(last.name) then
    vim.w[last.name].borderless = true
  end
end

return {
  "tamton-aquib/duck.nvim",
  keys = {
    { "<leader>pp", function() hatch("🐜", 10) end, desc = "Pet: soltar uno" },
    { "<leader>pk", function() require("duck").cook() end, desc = "Pet: cocinar el último" },
    { "<leader>pa", function() require("duck").cook_all() end, desc = "Pet: cocinar todos" },
  },
}
