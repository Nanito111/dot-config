-- Markdown: tratarlo como prosa, no como código
require("config.ft").indent(2)
vim.wo.wrap = true         -- envolver líneas largas en pantalla
vim.wo.linebreak = true    -- romper en espacios, no a mitad de palabra
vim.wo.breakindent = true  -- mantener la sangría al envolver
vim.wo.conceallevel = 2    -- ocultar marcas (**, _, etc.) mostrando el formato
vim.wo.spell = true        -- corrector ortográfico
