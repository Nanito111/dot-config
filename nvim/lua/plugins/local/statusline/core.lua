-- Motor de la statusline (agnóstico de la config): ajusta texto a ancho fijo,
-- envuelve contenido en píldoras redondeadas y arma la línea a partir de un
-- LAYOUT declarativo { left, center, right } de componentes.
--
-- Un COMPONENTE es una función  ctx -> segmento | nil  donde
--   segmento = { text = string, hl = "<grupo>", width = N?, align = "l"|"c"|"r"? }
-- Devolver nil (o text vacío) oculta el componente. `hl` es el nombre base de un
-- grupo de resaltado; debe existir además "<hl>Sep" para las medialunas (ver init).
local M = {}

M.CAP_L = "\u{e0b6}" -- glifo del extremo izquierdo de la píldora
M.CAP_R = "\u{e0b4}" -- glifo del extremo derecho
M.FILL = "StFill" -- grupo de resaltado del fondo de la línea (relleno y espacios)

-- Cambia los extremos de las píldoras (los dibuja el grupo "<hl>Sep", así que
-- cualquier glifo sólido —medialuna, flecha, diagonal— queda del color de la
-- píldora sobre el fondo de la línea). El próximo redraw los usa.
function M.set_caps(left, right)
  M.CAP_L, M.CAP_R = left, right
end

-- Ajusta `s` a un ancho fijo `w` (rellena con espacios o trunca).
-- align: "l" izquierda (def.), "r" derecha, "c" centro.
function M.fit(s, w, align)
  local len = vim.fn.strdisplaywidth(s)
  if len > w then
    s = vim.fn.strcharpart(s, 0, w)
    len = w
  end
  local pad = w - len
  if align == "r" then
    return string.rep(" ", pad) .. s
  elseif align == "c" then
    local l = math.floor(pad / 2)
    return string.rep(" ", l) .. s .. string.rep(" ", pad - l)
  end
  return s .. string.rep(" ", pad)
end

-- Envuelve `content` en una píldora con extremos redondeados del color `hl`
function M.pill(hl, content)
  return "%#" .. hl .. "Sep#" .. M.CAP_L .. "%#" .. hl .. "#" .. content .. "%#" .. hl .. "Sep#" .. M.CAP_R
end

-- Renderiza una sección (lista de componentes) a una cadena de píldoras separadas
local function render_section(list, components, ctx)
  local parts = {}
  for _, item in ipairs(list or {}) do
    local comp = type(item) == "function" and item or components[item]
    local seg = comp and comp(ctx)
    if seg and seg.text and seg.text ~= "" then
      local t = seg.width and M.fit(seg.text, seg.width, seg.align) or seg.text
      t = t:gsub("%%", "%%%%") -- escapar el % literal (no es código de statusline)
      local pill = M.pill(seg.hl, " " .. t .. " ")
      -- seg.click = nombre de función (p. ej. "v:lua.Fn"): hace la píldora clicable.
      -- Se envuelve AQUÍ (no en seg.text) para que los marcadores no se escapen ni
      -- cuenten como ancho. La función recibe (minwid, clicks, botón, modificadores).
      if seg.click then
        pill = "%@" .. seg.click .. "@" .. pill .. "%X"
      end
      parts[#parts + 1] = pill
    end
  end
  return table.concat(parts, "%#" .. M.FILL .. "# ") -- espacio entre píldoras
end

-- Arma la statusline completa: izquierda %= centro %= derecha, sobre el relleno
function M.build(layout, components, ctx_fn)
  local ctx = ctx_fn and ctx_fn() or {}
  local fill = "%#" .. M.FILL .. "#"
  return table.concat({
    fill, -- base de la línea
    render_section(layout.left, components, ctx),
    fill .. "%=", -- relleno hasta el centro
    render_section(layout.center, components, ctx),
    fill .. "%=", -- relleno hasta la derecha
    render_section(layout.right, components, ctx),
    fill .. " ",
  })
end

return M
