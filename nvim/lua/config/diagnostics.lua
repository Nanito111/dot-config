-- UI de diagnósticos (texto virtual, signos, subrayado) e inlay hints, configurables desde
-- el panel (:Settings). Antes vivía hardcodeado en config.lspkeys; ahora los valores salen
-- de config.settings (overrides-only) y se reaplican al cambiarlos o al recargar.
local api = vim.api
local M = {}

-- Iconos de los signos en el gutter (nerd font)
local SIGN_TEXT = {
  [vim.diagnostic.severity.ERROR] = "\u{f057}",
  [vim.diagnostic.severity.WARN] = "\u{f071}",
  [vim.diagnostic.severity.INFO] = "\u{f05a}",
  [vim.diagnostic.severity.HINT] = "\u{f0eb}",
}

M.DEFAULTS = {
  virtual_text = false, -- el mensaje se lee en el flotante (D / <leader>dd)
  signs = true,
  underline = true,
  inlay_hints = false,
}

local function val(key)
  return require("config.settings").value("diag." .. key, M.DEFAULTS[key])
end
M.get = val

-- Aplica la configuración actual (diagnostic.config + inlay hints)
function M.apply()
  vim.diagnostic.config({
    virtual_lines = false,
    virtual_text = val("virtual_text"),
    signs = val("signs") and { text = SIGN_TEXT } or false,
    underline = val("underline"),
    update_in_insert = false,
    severity_sort = true,
    float = { source = true },
  })
  pcall(function()
    vim.lsp.inlay_hint.enable(val("inlay_hints"))
  end)
end

-- Fija una preferencia (persiste + reaplica)
function M.set(key, v)
  require("config.settings").record("diag." .. key, v, M.DEFAULTS[key])
  M.apply()
end

-- Los inlay hints son estado global, pero un servidor que se conecta DESPUÉS de activarlos
-- necesita que se habiliten en su buffer.
api.nvim_create_autocmd("LspAttach", {
  group = api.nvim_create_augroup("DiagnosticsInlay", { clear = true }),
  callback = function(args)
    if val("inlay_hints") then
      pcall(function()
        vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
      end)
    end
  end,
})

M.apply()

return M
