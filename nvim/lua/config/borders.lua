-- Estilo de borde de TODAS las ventanas flotantes, centralizado en 'winborder' (opción
-- global de Neovim 0.11+): la respetan los flotantes que no fijan `border` en su config,
-- incluidos los del LSP (hover, firma, diagnósticos) y los de blink y mason.
-- Las que van sin marco a propósito (backdrop, peek del explorador) piden border="none".
local M = {}

-- { etiqueta, valor de winborder }. La etiqueta es lo que se muestra y se guarda.
M.styles = {
  { "rounded" },
  { "single" },
  { "double" },
  { "solid" },
  { "bold" },
  { "shadow" },
  { "none" },
}

local DEFAULT = "rounded"

function M.labels()
  return vim.tbl_map(function(s)
    return s[1]
  end, M.styles)
end

-- Marca de "esta ventana va SIN marco a propósito" (backdrop, peek del explorador). La
-- ponen ellas al abrirse; `reborder` la respeta.
M.BORDERLESS = "borderless"

-- Reborde de las flotantes YA abiertas (el picker que estás usando, sin ir más lejos):
-- winborder solo se lee al CREAR la ventana. Se salta únicamente las marcadas: mirar si
-- ahora mismo tienen borde no sirve, porque tras previsualizar "none" ninguna lo tendría
-- y se quedarían sin marco para siempre.
local function reborder(style)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" and not vim.w[win][M.BORDERLESS] then
      pcall(vim.api.nvim_win_set_config, win, { border = style })
    end
  end
end

-- Aplica sin persistir (lo usa la vista previa del selector/panel)
local function apply(style)
  vim.o.winborder = style
  reborder(style)
  -- lazy no mira 'winborder': tiene su propio ui.border, que lee al abrir su ventana.
  -- Actualizarlo en caliente hace que :Lazy salga con el borde elegido sin reiniciar.
  pcall(function()
    require("lazy.core.config").options.ui.border = style
  end)
end
M.apply = apply

function M.set(style)
  apply(style)
  require("config.settings").record("ui.border", style)
end

function M.setup()
  apply(require("config.settings").value("ui.border", DEFAULT))
end

-- Selector con vista previa en vivo (el propio picker cambia de borde al moverte)
function M.pick()
  local original = vim.o.winborder
  require("plugins.local.picker").pick({
    title = "Borde de las ventanas",
    items = M.labels(),
    on_move = function(style)
      if style then
        apply(style) -- vista previa sin guardar
      end
    end,
    on_select = function(style)
      if style then
        M.set(style)
      end
    end,
    on_cancel = function()
      apply(original)
    end,
  })
end

vim.api.nvim_create_user_command("Border", function(o)
  if o.args ~= "" then
    M.set(o.args)
  else
    M.pick()
  end
end, {
  nargs = "?",
  complete = function(lead)
    return vim.tbl_filter(function(s)
      return s:find(lead, 1, true) == 1
    end, M.labels())
  end,
  desc = "Borde de las ventanas flotantes (sin argumento abre el selector)",
})

return M
