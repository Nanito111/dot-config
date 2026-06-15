-- Descripciones curadas de prefijos integrados de Vim (g, z, <C-w>) para el
-- which-key. Datos puros: devuelve un map  prefijo-en-bytes -> lista de
-- { raw = <secuencia completa en bytes>, desc }.
local api = vim.api

local BUILTIN = {}

local function add_builtin(prefix_keys, list)
  local praw = api.nvim_replace_termcodes(prefix_keys, true, true, true)
  local entries = {}
  for _, e in ipairs(list) do
    entries[#entries + 1] = {
      raw = api.nvim_replace_termcodes(e[1], true, true, true),
      desc = e[2],
    }
  end
  BUILTIN[praw] = entries
end

add_builtin("g", {
  { "gg", "Ir al inicio del archivo" },
  { "gv", "Reseleccionar última selección" },
  { "gi", "Insertar en la última posición" },
  { "gI", "Insertar en la columna 1" },
  { "gJ", "Unir líneas sin espacio" },
  { "gp", "Pegar y mover el cursor al final" },
  { "gP", "Pegar antes y mover el cursor" },
  { "gf", "Abrir el archivo bajo el cursor" },
  { "gx", "Abrir URL/archivo con la app del sistema" },
  { "ga", "Mostrar el código del carácter" },
  { "g;", "Ir al cambio anterior" },
  { "g,", "Ir al cambio siguiente" },
  { "g_", "Último carácter no-blanco" },
  { "gj", "Bajar una línea visual" },
  { "gk", "Subir una línea visual" },
  { "gu", "Pasar a minúsculas (operador)" },
  { "gU", "Pasar a mayúsculas (operador)" },
  { "g~", "Invertir mayúsculas (operador)" },
  { "gq", "Reformatear texto (operador)" },
})

add_builtin("z", {
  { "zz", "Centrar la línea actual" },
  { "zt", "Línea actual arriba" },
  { "zb", "Línea actual abajo" },
  { "za", "Alternar fold" },
  { "zo", "Abrir fold" },
  { "zc", "Cerrar fold" },
  { "zR", "Abrir todos los folds" },
  { "zM", "Cerrar todos los folds" },
  { "zf", "Crear fold (operador)" },
  { "zd", "Borrar fold" },
  { "z=", "Sugerencias de ortografía" },
})

add_builtin("<C-w>", {
  { "<C-w>w", "Ciclar a la siguiente ventana" },
  { "<C-w>p", "Ventana anterior" },
  { "<C-w>h", "Ventana de la izquierda" },
  { "<C-w>j", "Ventana de abajo" },
  { "<C-w>k", "Ventana de arriba" },
  { "<C-w>l", "Ventana de la derecha" },
  { "<C-w>s", "Split horizontal" },
  { "<C-w>v", "Split vertical" },
  { "<C-w>q", "Cerrar ventana" },
  { "<C-w>o", "Cerrar las demás ventanas" },
  { "<C-w>=", "Igualar tamaños" },
  { "<C-w>x", "Intercambiar ventana" },
  { "<C-w>r", "Rotar ventanas" },
  { "<C-w>T", "Mover la ventana a una tab nueva" },
})

return BUILTIN
